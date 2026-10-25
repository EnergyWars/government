from __future__ import annotations

import argparse
import logging
import signal
import sys
import threading
from collections.abc import Sequence
from http.server import ThreadingHTTPServer
from pathlib import Path

from .agent import AgentStep
from .auth import Authenticator, LoginThrottle
from .builder import ApkBuilder
from .config import RECOMMENDED_TOKEN_LENGTH, SERVER_DIR, Config, ConfigError, load_config
from .discovery import server_urls
from .i18n import Translator
from .process import CommandRunner, SubprocessRunner
from .router import ModelRouter
from .store import JobStore
from .web import FeedbackApp, make_handler
from .worker import Worker

logger = logging.getLogger(__name__)

PACKAGE_DIR = Path(__file__).resolve().parent
DEFAULT_CONFIG = SERVER_DIR / "config.json"
SECONDS_PER_DAY = 86400
SHUTDOWN_JOIN_SECONDS = 15.0


class FeedbackServer:
    def __init__(self, config: Config, runner: CommandRunner | None = None) -> None:
        config.data_dir.mkdir(parents=True, exist_ok=True)
        config.log_dir.mkdir(parents=True, exist_ok=True)
        self.config = config
        if len(config.token) < RECOMMENDED_TOKEN_LENGTH:
            logger.warning("Password is shorter than %d characters, only expose the server via VPN", RECOMMENDED_TOKEN_LENGTH)
        self.runner = runner or SubprocessRunner()
        self.store = JobStore(config.database_path)
        recovered = self.store.recover_interrupted()
        if recovered:
            logger.warning("Marked %d interrupted jobs as failed", recovered)
        self.worker = Worker(
            self.store,
            ModelRouter(config, self.runner),
            AgentStep(config, self.runner),
            ApkBuilder(config, self.runner),
            self.runner,
            config.log_dir,
        )
        self.app = FeedbackApp(
            config,
            self.store,
            self.worker,
            Authenticator(config.token, config.session_days * SECONDS_PER_DAY),
            LoginThrottle(),
            Translator(PACKAGE_DIR / "i18n"),
            PACKAGE_DIR / "static",
        )
        self.httpd = ThreadingHTTPServer((config.host, config.port), make_handler(self.app))
        self.httpd.daemon_threads = True
        self._worker_thread = threading.Thread(target=self.worker.run_forever, name="worker", daemon=True)

    @property
    def port(self) -> int:
        return self.httpd.server_address[1]

    def serve_forever(self) -> None:
        self._worker_thread.start()
        logger.info("Listening on http://%s:%d", self.config.host, self.port)
        for url in server_urls(self.port):
            logger.info("Reachable at %s", url)
        self.httpd.serve_forever()

    def shutdown(self) -> None:
        threading.Thread(target=self.httpd.shutdown, daemon=True).start()

    def close(self) -> None:
        self.worker.stop()
        if self._worker_thread.is_alive():
            self._worker_thread.join(SHUTDOWN_JOIN_SECONDS)
        self.httpd.server_close()
        self.store.close()


def _parse_args(argv: Sequence[str] | None) -> argparse.Namespace:
    parser = argparse.ArgumentParser(prog="feedback_server")
    parser.add_argument("--config", type=Path, default=None)
    return parser.parse_args(argv)


def main(argv: Sequence[str] | None = None) -> int:
    logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s %(name)s: %(message)s")
    args = _parse_args(argv)
    config_path = args.config or (DEFAULT_CONFIG if DEFAULT_CONFIG.is_file() else None)
    try:
        config = load_config(config_path)
    except ConfigError as error:
        print(error, file=sys.stderr)
        return 2
    server = FeedbackServer(config)
    signal.signal(signal.SIGTERM, lambda *_: server.shutdown())
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        pass
    finally:
        server.close()
    return 0
