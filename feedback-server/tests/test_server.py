import http.client
import io
import json
import threading
import unittest
from contextlib import redirect_stderr
from unittest import mock

from feedback_server import server as server_module
from feedback_server.server import FeedbackServer, main
from feedback_server.store import JobKind, JobStatus
from feedback_server.web import MAX_BODY_BYTES

from tests.helpers import TOKEN, FakeRunner, TempDirCase, make_config


class FeedbackServerTest(TempDirCase, unittest.TestCase):
    def setUp(self) -> None:
        self.config = make_config(self.make_temp())
        self.server = FeedbackServer(self.config, FakeRunner())
        self.thread = threading.Thread(target=self.server.serve_forever)
        self.thread.start()
        self.addCleanup(self.stop)

    def stop(self) -> None:
        self.server.shutdown()
        self.thread.join(5)
        self.server.close()

    def connect(self) -> http.client.HTTPConnection:
        connection = http.client.HTTPConnection("127.0.0.1", self.server.port, timeout=5)
        self.addCleanup(connection.close)
        return connection

    def test_health_over_http(self) -> None:
        connection = self.connect()
        connection.request("GET", "/api/health?x=1")
        response = connection.getresponse()
        self.assertEqual(response.status, 200)
        self.assertEqual(json.loads(response.read()), {"ok": True})
        self.assertEqual(response.getheader("X-Frame-Options"), "DENY")

    def test_discovery_status_over_http(self) -> None:
        connection = self.connect()
        connection.request("GET", "/status")
        response = connection.getresponse()
        self.assertEqual(response.status, 204)
        self.assertEqual(response.read(), b"")
        self.assertIsNone(response.getheader("Content-Type"))
        connection.request("GET", "/api/health")
        follow_up = connection.getresponse()
        self.assertEqual(follow_up.status, 200)
        follow_up.read()

    def test_post_feedback_over_http(self) -> None:
        connection = self.connect()
        body = json.dumps({"feedback": "Test"})
        connection.request("POST", "/api/feedback", body,
                           {"Content-Type": "application/json", "Authorization": f"Bearer {TOKEN}"})
        response = connection.getresponse()
        self.assertEqual(response.status, 201)
        self.assertEqual(json.loads(response.read())["feedback"], "Test")
        for method in ("PUT", "DELETE"):
            connection.request(method, "/api/feedback", headers={"Authorization": f"Bearer {TOKEN}"})
            reply = connection.getresponse()
            reply.read()
            self.assertEqual(reply.status, 405)

    def test_rejects_oversized_and_invalid_length(self) -> None:
        for length in (str(MAX_BODY_BYTES + 1), "abc"):
            with self.subTest(length=length):
                connection = self.connect()
                connection.putrequest("POST", "/api/feedback")
                connection.putheader("Content-Length", length)
                connection.endheaders()
                response = connection.getresponse()
                self.assertEqual(response.status, 413)

    def test_streams_apk_file(self) -> None:
        job = self.server.store.create(JobKind.BUILD)
        self.config.apk_dir.mkdir(parents=True, exist_ok=True)
        (self.config.apk_dir / "a.apk").write_bytes(b"x" * 100_000)
        self.server.store.record_apk(job.id, "a.apk")
        connection = self.connect()
        connection.request("GET", "/apk/latest", headers={"Authorization": f"Bearer {TOKEN}"})
        response = connection.getresponse()
        self.assertEqual(response.status, 200)
        self.assertEqual(len(response.read()), 100_000)
        self.assertEqual(response.getheader("Content-Length"), "100000")


class WeakPasswordTest(TempDirCase, unittest.TestCase):
    def test_short_password_logs_warning(self) -> None:
        config = make_config(self.make_temp(), token="123")
        with self.assertLogs("feedback_server.server", "WARNING") as logs:
            server = FeedbackServer(config, FakeRunner())
        self.addCleanup(server.close)
        self.assertIn("VPN", logs.output[0])


class RecoveryTest(TempDirCase, unittest.TestCase):
    def test_interrupted_jobs_fail_on_start(self) -> None:
        config = make_config(self.make_temp())
        first = FeedbackServer(config, FakeRunner())
        job = first.store.create(JobKind.FEEDBACK, "x")
        first.store.start(job.id, JobStatus.AGENT)
        first.close()
        with self.assertLogs("feedback_server.server", "WARNING"):
            second = FeedbackServer(config, FakeRunner())
        self.addCleanup(second.close)
        self.assertEqual(second.store.get(job.id).error, "interrupted")


class MainTest(TempDirCase, unittest.TestCase):
    def test_invalid_config_exits_with_2(self) -> None:
        path = self.make_temp() / "config.json"
        path.write_text("{}", encoding="utf-8")
        stderr = io.StringIO()
        with mock.patch.dict("os.environ", {}, clear=True), redirect_stderr(stderr):
            self.assertEqual(main(["--config", str(path)]), 2)
        self.assertIn("Missing password", stderr.getvalue())

    def test_runs_until_interrupted(self) -> None:
        root = self.make_temp()
        config = make_config(root)
        instances: list[FeedbackServer] = []

        class InterruptingServer(FeedbackServer):
            def __init__(self, cfg) -> None:
                super().__init__(cfg, FakeRunner())
                instances.append(self)

            def serve_forever(self) -> None:
                raise KeyboardInterrupt

        with mock.patch.object(server_module, "load_config", return_value=config), \
                mock.patch.object(server_module, "FeedbackServer", InterruptingServer), \
                mock.patch.object(server_module.signal, "signal") as register:
            self.assertEqual(main([]), 0)
        handler = register.call_args.args[1]
        with mock.patch.object(instances[0].httpd, "shutdown") as shutdown:
            handler()
            threading.Event().wait(0.2)
        shutdown.assert_called_once()


if __name__ == "__main__":
    unittest.main()
