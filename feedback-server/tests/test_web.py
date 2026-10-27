import json
import unittest
from dataclasses import replace
from http import HTTPStatus
from unittest import mock

from feedback_server.agent import AgentStep
from feedback_server.auth import Authenticator, LoginThrottle
from feedback_server.builder import ApkBuilder
from feedback_server.i18n import Translator
from feedback_server.router import ModelRouter
from feedback_server.server import PACKAGE_DIR
from feedback_server.store import JobKind, JobStatus, JobStore
from feedback_server.web import SESSION_COOKIE, FeedbackApp, Request, Response
from feedback_server.worker import Worker

from tests.helpers import TOKEN, FakeRunner, TempDirCase, make_config

JSON = {"content-type": "application/json"}
BEARER = {"authorization": f"Bearer {TOKEN}"}


class FeedbackAppTest(TempDirCase, unittest.TestCase):
    def setUp(self) -> None:
        self.config = make_config(self.make_temp(), max_feedback_length=50)
        self.build_app()

    def build_app(self) -> None:
        self.store = JobStore(":memory:")
        self.addCleanup(self.store.close)
        self.runner = FakeRunner()
        self.worker = Worker(
            self.store,
            ModelRouter(self.config, self.runner),
            AgentStep(self.config, self.runner),
            ApkBuilder(self.config, self.runner),
            self.runner,
            self.config.log_dir,
        )
        self.auth = Authenticator(TOKEN, 3600)
        self.app = FeedbackApp(
            self.config,
            self.store,
            self.worker,
            self.auth,
            LoginThrottle(max_failures=2),
            Translator(PACKAGE_DIR / "i18n"),
            PACKAGE_DIR / "static",
        )

    def request(self, method: str, path: str, headers: dict[str, str] | None = None,
                body: bytes = b"", client_ip: str = "1.2.3.4") -> Response:
        return self.app.handle(Request(method, path, headers or {}, body, client_ip))

    def api(self, method: str, path: str, payload: object | None = None,
            headers: dict[str, str] | None = None) -> Response:
        body = json.dumps(payload).encode() if payload is not None else b""
        return self.request(method, path, {**JSON, **BEARER, **(headers or {})}, body)

    @staticmethod
    def data(response: Response) -> dict:
        return json.loads(response.body)

    def session_cookie(self) -> str:
        return f"{SESSION_COOKIE}={self.auth.issue_session()}"

    def test_security_headers_and_health(self) -> None:
        response = self.request("GET", "/api/health")
        self.assertEqual(response.status, HTTPStatus.OK)
        headers = dict(response.headers)
        self.assertIn("frame-ancestors 'none'", headers["Content-Security-Policy"])
        self.assertEqual(headers["X-Content-Type-Options"], "nosniff")

    def test_discovery_status_is_public_and_empty(self) -> None:
        response = self.request("GET", "/status")
        self.assertEqual(response.status, HTTPStatus.NO_CONTENT)
        self.assertEqual(response.body, b"")
        self.assertEqual(self.request("POST", "/status").status, HTTPStatus.METHOD_NOT_ALLOWED)

    def test_api_status(self) -> None:
        self.assertEqual(self.request("GET", "/api/status").status, HTTPStatus.UNAUTHORIZED)
        idle = self.data(self.api("GET", "/api/status"))
        self.assertEqual((idle["state"], idle["current_job"], idle["queued"], idle["latest_apk"]),
                         ("idle", None, 0, None))
        self.assertEqual(idle["router"], {"model": "sonnet", "effort": "low"})
        self.assertEqual(idle["model_choices"], ["haiku", "sonnet", "opus"])
        self.assertGreaterEqual(idle["uptime_seconds"], 0)
        running = self.store.create(JobKind.FEEDBACK, "a")
        self.store.create(JobKind.BUILD)
        self.store.record_apk(running.id, "x.apk")
        self.worker._current_id = running.id
        busy = self.data(self.api("GET", "/api/status"))
        self.assertEqual((busy["state"], busy["current_job"]["id"], busy["queued"], busy["latest_apk"]),
                         ("busy", running.id, 2, running.id))

    def test_static_files_and_unknown_routes(self) -> None:
        response = self.request("GET", "/static/app.js")
        self.assertEqual(response.status, HTTPStatus.OK)
        self.assertTrue(response.content_type.startswith("text/javascript"))
        self.assertEqual(self.request("GET", "/static/../config.py").status, HTTPStatus.NOT_FOUND)
        self.assertEqual(self.request("GET", "/nope").status, HTTPStatus.NOT_FOUND)
        response = self.request("POST", "/api/health")
        self.assertEqual(response.status, HTTPStatus.METHOD_NOT_ALLOWED)
        self.assertIn(("Allow", "GET"), response.headers)

    def test_home_shows_login_or_app_localized(self) -> None:
        login = self.request("GET", "/", {"accept-language": "de-DE,de;q=0.9"})
        self.assertIn('lang="de"', login.body.decode())
        self.assertIn(">Passwort<", login.body.decode())
        app = self.request("GET", "/", {"cookie": self.session_cookie(), "accept-language": "fr"})
        page = app.body.decode()
        self.assertIn('lang="en"', page)
        self.assertIn('id="feedback-form"', page)
        self.assertIn('maxlength="50"', page)
        self.assertNotIn("{{", page)

    def test_i18n_json_cannot_break_out_of_script(self) -> None:
        with mock.patch.object(Translator, "strings", return_value={"app_title": "</script><b>"}):
            page = self.request("GET", "/", {"cookie": self.session_cookie()}).body.decode()
        self.assertNotIn("</script><b>", page)
        self.assertIn("&lt;/script&gt;&lt;b&gt;", page)
        self.assertIn("\\u003c/script\\u003e", page)

    def test_login_success_sets_session_cookie(self) -> None:
        response = self.request("POST", "/login", body=f"token={TOKEN}".encode())
        self.assertEqual(response.status, HTTPStatus.SEE_OTHER)
        cookie = dict(response.headers)["Set-Cookie"]
        self.assertIn("HttpOnly", cookie)
        self.assertIn("SameSite=Strict", cookie)
        self.assertNotIn("Secure", cookie)
        value = cookie.split(";")[0]
        self.assertEqual(self.request("GET", "/api/jobs", {"cookie": value}).status, HTTPStatus.OK)

    def test_secure_cookie_flag(self) -> None:
        self.config = replace(self.config, secure_cookie=True)
        self.build_app()
        response = self.request("POST", "/login", body=f"token={TOKEN}".encode())
        self.assertIn("; Secure", dict(response.headers)["Set-Cookie"])

    def test_login_failure_and_throttle(self) -> None:
        for _ in range(2):
            response = self.request("POST", "/login", body=b"token=wrong")
            self.assertEqual(response.status, HTTPStatus.UNAUTHORIZED)
        blocked = self.request("POST", "/login", body=f"token={TOKEN}".encode())
        self.assertEqual(blocked.status, HTTPStatus.TOO_MANY_REQUESTS)
        other = self.request("POST", "/login", body=f"token={TOKEN}".encode(), client_ip="5.6.7.8")
        self.assertEqual(other.status, HTTPStatus.SEE_OTHER)
        empty = self.request("POST", "/login", body=b"", client_ip="9.9.9.9")
        self.assertEqual(empty.status, HTTPStatus.UNAUTHORIZED)

    def test_forwarded_for_only_when_trusted(self) -> None:
        request = Request("GET", "/", {"x-forwarded-for": "9.9.9.9, 10.0.0.1"}, b"", "127.0.0.1")
        self.assertEqual(self.app.client_id(request), "127.0.0.1")
        self.config = replace(self.config, trust_forwarded_for=True)
        self.build_app()
        self.assertEqual(self.app.client_id(request), "9.9.9.9")
        self.assertEqual(self.app.client_id(Request("GET", "/", {}, b"", "127.0.0.1")), "127.0.0.1")

    def test_logout_clears_cookie(self) -> None:
        response = self.request("POST", "/logout")
        self.assertIn("Max-Age=0", dict(response.headers)["Set-Cookie"])

    def test_api_requires_auth(self) -> None:
        for headers in ({}, {"cookie": f"{SESSION_COOKIE}=bad"}, {"cookie": "a=\"\\x"},
                        {"cookie": "other=1"}, {"authorization": "Bearer wrong"}):
            with self.subTest(headers=headers):
                response = self.request("GET", "/api/jobs", headers)
                self.assertEqual(response.status, HTTPStatus.UNAUTHORIZED)

    def test_bearer_failures_are_throttled(self) -> None:
        for _ in range(2):
            self.request("GET", "/api/jobs", {"authorization": "Bearer wrong"})
        response = self.request("GET", "/api/jobs", BEARER)
        self.assertEqual(response.status, HTTPStatus.TOO_MANY_REQUESTS)
        self.assertEqual(self.data(response)["error"], "too_many_attempts")

    def test_create_feedback(self) -> None:
        response = self.api("POST", "/api/feedback", {"feedback": "  Mehr Kaffee  ", "resume": True})
        self.assertEqual(response.status, HTTPStatus.CREATED)
        job = self.data(response)
        self.assertEqual((job["feedback"], job["resume"], job["status"]), ("Mehr Kaffee", True, "queued"))
        listing = self.data(self.api("GET", "/api/jobs"))
        self.assertEqual([item["id"] for item in listing["jobs"]], [job["id"]])
        self.assertIsNone(listing["latest_apk"])

    def test_feedback_validation(self) -> None:
        cases = [
            ({"feedback": "   "}, "feedback_empty"),
            ({"feedback": 5}, "feedback_empty"),
            ({}, "feedback_empty"),
            ({"feedback": "x" * 51}, "feedback_too_long"),
            ({"feedback": "ok", "resume": "yes"}, "invalid_resume"),
            ([1], "invalid_json"),
        ]
        for payload, code in cases:
            with self.subTest(code=code):
                response = self.api("POST", "/api/feedback", payload)
                self.assertEqual(response.status, HTTPStatus.BAD_REQUEST)
                self.assertEqual(self.data(response)["error"], code)
        broken = self.request("POST", "/api/feedback", {**JSON, **BEARER}, b"{nope")
        self.assertEqual(self.data(broken)["error"], "invalid_json")
        binary = self.request("POST", "/api/feedback", {**JSON, **BEARER}, b"\xff")
        self.assertEqual(self.data(binary)["error"], "invalid_json")
        form = self.request("POST", "/api/feedback", BEARER, b"feedback=x")
        self.assertEqual(form.status, HTTPStatus.UNSUPPORTED_MEDIA_TYPE)
        self.assertEqual(self.api("GET", "/api/feedback").status, HTTPStatus.METHOD_NOT_ALLOWED)

    def test_create_build_and_detail(self) -> None:
        job = self.data(self.api("POST", "/api/build"))
        self.assertEqual(job["kind"], "build")
        self.config.log_dir.mkdir(parents=True)
        self.worker.log_path(job["id"]).write_text("hello\n", encoding="utf-8")
        detail = self.data(self.api("GET", f"/api/jobs/{job['id']}"))
        self.assertEqual(detail["log"], "hello\n")
        self.assertEqual(self.api("GET", "/api/jobs/999").status, HTTPStatus.NOT_FOUND)
        self.assertEqual(self.api("GET", "/api/unknown").status, HTTPStatus.NOT_FOUND)

    def test_cancel(self) -> None:
        job = self.store.create(JobKind.BUILD)
        response = self.api("POST", f"/api/jobs/{job.id}/cancel", {})
        self.assertEqual(self.data(response), {"cancelled": job.id})
        self.assertEqual(self.store.get(job.id).status, JobStatus.CANCELLED)
        conflict = self.api("POST", f"/api/jobs/{job.id}/cancel", {})
        self.assertEqual(conflict.status, HTTPStatus.CONFLICT)
        self.assertEqual(self.api("POST", "/api/jobs/999/cancel", {}).status, HTTPStatus.NOT_FOUND)

    def test_apk_download(self) -> None:
        self.assertEqual(self.request("GET", "/apk/latest").status, HTTPStatus.SEE_OTHER)
        wrong = self.request("GET", "/apk/latest", {"authorization": "Bearer falsch"})
        self.assertEqual(wrong.status, HTTPStatus.UNAUTHORIZED)
        self.assertEqual(self.api("GET", "/apk/latest").status, HTTPStatus.NOT_FOUND)
        job = self.store.create(JobKind.BUILD)
        self.store.record_apk(job.id, "idle-germany-1.apk")
        self.assertEqual(self.api("GET", "/apk/latest").status, HTTPStatus.NOT_FOUND)
        self.config.apk_dir.mkdir(parents=True)
        apk = self.config.apk_dir / "idle-germany-1.apk"
        apk.write_bytes(b"apk")
        for path in ("/apk/latest", f"/apk/{job.id}"):
            with self.subTest(path=path):
                response = self.request("GET", path, {"cookie": self.session_cookie()})
                self.assertEqual(response.status, HTTPStatus.OK)
                self.assertEqual(response.file, apk.resolve())
                self.assertEqual(response.content_type, "application/vnd.android.package-archive")
                self.assertIn(("Content-Disposition", 'attachment; filename="idle-germany-1.apk"'),
                              response.headers)
        self.assertEqual(self.data(self.api("GET", "/api/jobs"))["latest_apk"], job.id)
        self.assertEqual(self.api("GET", "/apk/abc").status, HTTPStatus.NOT_FOUND)
        self.assertEqual(self.api("GET", "/apk/999").status, HTTPStatus.NOT_FOUND)

    def test_apk_path_traversal_is_blocked(self) -> None:
        job = self.store.create(JobKind.BUILD)
        self.store.record_apk(job.id, "../jobs.db")
        self.config.data_dir.mkdir(parents=True, exist_ok=True)
        (self.config.data_dir / "jobs.db").write_bytes(b"secret")
        self.assertEqual(self.api("GET", f"/apk/{job.id}").status, HTTPStatus.NOT_FOUND)

    def test_unexpected_errors_become_500(self) -> None:
        with mock.patch.object(JobStore, "list_recent", side_effect=RuntimeError("boom")), \
                self.assertLogs("feedback_server.web", "ERROR"):
            response = self.api("GET", "/api/jobs")
        self.assertEqual(response.status, HTTPStatus.INTERNAL_SERVER_ERROR)
        self.assertEqual(self.data(response)["error"], "internal_error")

    def test_payload_too_large_response(self) -> None:
        response = self.app.payload_too_large()
        self.assertEqual(response.status, HTTPStatus.REQUEST_ENTITY_TOO_LARGE)
        self.assertIn("X-Frame-Options", dict(response.headers))


if __name__ == "__main__":
    unittest.main()
