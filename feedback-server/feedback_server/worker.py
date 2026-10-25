from __future__ import annotations

import logging
import re
import threading
import traceback
from pathlib import Path
from typing import TextIO

from .agent import AgentStep
from .builder import ApkBuilder
from .process import CommandRunner, LineSink
from .router import ModelRouter, Route
from .store import Job, JobKind, JobStatus, JobStore

logger = logging.getLogger(__name__)

IDLE_WAIT_SECONDS = 60.0
DEFAULT_LOG_TAIL_BYTES = 65536
_ANSI_ESCAPE = re.compile(r"\x1b\[[0-9;?]*[A-Za-z]")


def read_log_tail(path: Path, max_bytes: int = DEFAULT_LOG_TAIL_BYTES) -> str:
    try:
        with path.open("rb") as handle:
            handle.seek(0, 2)
            size = handle.tell()
            handle.seek(max(0, size - max_bytes))
            data = handle.read()
    except FileNotFoundError:
        return ""
    text = data.decode("utf-8", errors="replace")
    if size > max_bytes:
        text = text.partition("\n")[2]
    return text


def strip_ansi(text: str) -> str:
    return _ANSI_ESCAPE.sub("", text)


def _line_writer(handle: TextIO) -> LineSink:
    def write(line: str) -> None:
        handle.write(strip_ansi(line) + "\n")
        handle.flush()

    return write


class Worker:
    def __init__(
        self,
        store: JobStore,
        router: ModelRouter,
        agent: AgentStep,
        builder: ApkBuilder,
        runner: CommandRunner,
        log_dir: Path,
    ) -> None:
        self._store = store
        self._router = router
        self._agent = agent
        self._builder = builder
        self._runner = runner
        self._log_dir = log_dir
        self._wake = threading.Event()
        self._stop = threading.Event()
        self._lock = threading.Lock()
        self._current_id: int | None = None
        self._cancel_requested = False

    @property
    def current_job_id(self) -> int | None:
        with self._lock:
            return self._current_id

    def log_path(self, job_id: int) -> Path:
        return self._log_dir / f"{job_id}.log"

    def notify(self) -> None:
        self._wake.set()

    def stop(self) -> None:
        self._stop.set()
        self._wake.set()
        current = self.current_job_id
        if current is not None:
            self.cancel(current)

    def run_forever(self) -> None:
        while not self._stop.is_set():
            if not self.process_next():
                self._wake.wait(IDLE_WAIT_SECONDS)
                self._wake.clear()

    def process_next(self) -> bool:
        if self._stop.is_set():
            return False
        job = self._store.next_queued()
        if job is None:
            return False
        with self._lock:
            self._current_id = job.id
            self._cancel_requested = False
        try:
            self._process(job)
        finally:
            with self._lock:
                self._current_id = None
        return True

    def cancel(self, job_id: int) -> bool:
        if self._store.cancel_queued(job_id):
            return True
        with self._lock:
            if self._current_id != job_id:
                return False
            self._cancel_requested = True
        self._runner.cancel()
        return True

    def _cancel_pending(self) -> bool:
        with self._lock:
            return self._cancel_requested

    def _process(self, job: Job) -> None:
        self._log_dir.mkdir(parents=True, exist_ok=True)
        with self.log_path(job.id).open("a", encoding="utf-8") as handle:
            log = _line_writer(handle)
            try:
                self._run_steps(job, log)
            except Exception:
                logger.exception("Job %s crashed", job.id)
                log(traceback.format_exc())
                self._store.finish(job.id, JobStatus.FAILED, "internal_error")

    def _run_steps(self, job: Job, log: LineSink) -> None:
        if job.kind is JobKind.FEEDBACK:
            route = self._run_router(job, log)
            if route is None or not self._run_agent(job, route, log):
                return
            self._store.set_status(job.id, JobStatus.BUILD)
        else:
            self._store.start(job.id, JobStatus.BUILD)
        if self._cancel_pending():
            self._store.finish(job.id, JobStatus.CANCELLED, "cancelled")
            return
        build = self._builder.run(job.id, log)
        if not build.success or build.apk_file is None:
            status = JobStatus.CANCELLED if build.cancelled else JobStatus.FAILED
            self._store.finish(job.id, status, build.error)
            return
        self._store.record_apk(job.id, build.apk_file)
        self._store.finish(job.id, JobStatus.DONE)
        self._builder.prune(self._store)

    def _run_router(self, job: Job, log: LineSink) -> Route | None:
        self._store.start(job.id, JobStatus.ROUTE)
        outcome = self._router.route(job.feedback, log)
        if outcome.cancelled or self._cancel_pending():
            self._store.finish(job.id, JobStatus.CANCELLED, "cancelled")
            return None
        route = outcome.route
        self._store.record_route(job.id, route.model, route.effort, route.reason)
        return route

    def _run_agent(self, job: Job, route: Route, log: LineSink) -> bool:
        self._store.set_status(job.id, JobStatus.AGENT)
        resume_session = self._store.latest_session_id() if job.resume else None
        outcome = self._agent.run(job.feedback, resume_session, route, log)
        self._store.record_agent(job.id, outcome.session_id, outcome.summary)
        if outcome.success:
            return True
        status = JobStatus.CANCELLED if outcome.cancelled else JobStatus.FAILED
        self._store.finish(job.id, status, outcome.error)
        return False
