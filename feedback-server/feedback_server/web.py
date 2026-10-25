from __future__ import annotations

import html
import json
import logging
import re
import shutil
import time
from collections.abc import Callable, Mapping
from dataclasses import dataclass, field
from http import HTTPStatus
from http.cookies import CookieError, SimpleCookie
from http.server import BaseHTTPRequestHandler
from pathlib import Path
from typing import Any
from urllib.parse import parse_qs, urlsplit

from .auth import Authenticator, LoginThrottle
from .config import Config
from .i18n import Translator
from .store import Job, JobKind, JobStore
from .worker import Worker, read_log_tail

logger = logging.getLogger(__name__)

SESSION_COOKIE = "feedback_session"
MAX_BODY_BYTES = 256 * 1024
JOB_LIST_LIMIT = 50
APK_MIME = "application/vnd.android.package-archive"
JSON_MIME = "application/json; charset=utf-8"
HTML_MIME = "text/html; charset=utf-8"

SECURITY_HEADERS: tuple[tuple[str, str], ...] = (
    ("Content-Security-Policy", "default-src 'none'; script-src 'self'; style-src 'self'; "
     "connect-src 'self'; img-src 'self'; form-action 'self'; base-uri 'none'; frame-ancestors 'none'"),
    ("X-Content-Type-Options", "nosniff"),
    ("X-Frame-Options", "DENY"),
    ("Referrer-Policy", "no-referrer"),
    ("Cache-Control", "no-store"),
)

STATIC_FILES: dict[str, tuple[str, str]] = {
    "/static/app.js": ("app.js", "text/javascript; charset=utf-8"),
    "/static/style.css": ("style.css", "text/css; charset=utf-8"),
}

_JOB_PATH = re.compile(r"/api/jobs/(\d{1,12})")
_CANCEL_PATH = re.compile(r"/api/jobs/(\d{1,12})/cancel")
_APK_PATH = re.compile(r"/apk/(\d{1,12})")
_PLACEHOLDER = re.compile(r"\{\{(\w+)\}\}")
_JSON_ESCAPES = str.maketrans({"<": "\\u003c", ">": "\\u003e", "&": "\\u0026"})


@dataclass(slots=True)
class Request:
    method: str
    path: str
    headers: Mapping[str, str] = field(default_factory=dict)
    body: bytes = b""
    client_ip: str = ""

    def header(self, name: str) -> str:
        return self.headers.get(name.lower(), "")


@dataclass(slots=True)
class Response:
    status: int
    body: bytes = b""
    content_type: str = "text/plain; charset=utf-8"
    headers: list[tuple[str, str]] = field(default_factory=list)
    file: Path | None = None


class ApiError(Exception):
    def __init__(self, status: HTTPStatus, code: str) -> None:
        super().__init__(code)
        self.status = status
        self.code = code


def json_response(status: int, payload: Any, headers: list[tuple[str, str]] | None = None) -> Response:
    body = json.dumps(payload, ensure_ascii=False).encode("utf-8")
    return Response(status, body, JSON_MIME, headers or [])


def error_response(status: HTTPStatus, code: str) -> Response:
    return json_response(status, {"error": code})


def redirect(location: str, headers: list[tuple[str, str]] | None = None) -> Response:
    return Response(HTTPStatus.SEE_OTHER, headers=[("Location", location), *(headers or [])])


class FeedbackApp:
    def __init__(
        self,
        config: Config,
        store: JobStore,
        worker: Worker,
        authenticator: Authenticator,
        throttle: LoginThrottle,
        translator: Translator,
        static_dir: Path,
        clock: Callable[[], float] = time.time,
    ) -> None:
        self._config = config
        self._clock = clock
        self._started_at = clock()
        self._store = store
        self._worker = worker
        self._auth = authenticator
        self._throttle = throttle
        self._translator = translator
        self._templates = {
            name: (static_dir / f"{name}.html").read_text(encoding="utf-8") for name in ("index", "login")
        }
        self._static = {
            route: ((static_dir / file_name).read_bytes(), mime)
            for route, (file_name, mime) in STATIC_FILES.items()
        }

    def handle(self, request: Request) -> Response:
        try:
            response = self._route(request)
        except ApiError as error:
            response = error_response(error.status, error.code)
        except Exception:
            logger.exception("Unhandled error for %s %s", request.method, request.path)
            response = error_response(HTTPStatus.INTERNAL_SERVER_ERROR, "internal_error")
        response.headers.extend(SECURITY_HEADERS)
        return response

    def payload_too_large(self) -> Response:
        response = error_response(HTTPStatus.REQUEST_ENTITY_TOO_LARGE, "payload_too_large")
        response.headers.extend(SECURITY_HEADERS)
        return response

    def client_id(self, request: Request) -> str:
        if self._config.trust_forwarded_for:
            forwarded = request.header("x-forwarded-for").split(",")[0].strip()
            if forwarded:
                return forwarded
        return request.client_ip

    def _route(self, request: Request) -> Response:
        path, method = request.path, request.method
        if path == "/api/health":
            return self._only(method, "GET", lambda: json_response(HTTPStatus.OK, {"ok": True}))
        if path == "/status":
            return self._only(method, "GET", lambda: Response(HTTPStatus.NO_CONTENT))
        if path in self._static:
            return self._only(method, "GET", lambda: self._static_file(path))
        if path == "/":
            return self._only(method, "GET", lambda: self._home(request))
        if path == "/login":
            return self._only(method, "POST", lambda: self._login(request))
        if path == "/logout":
            return self._only(method, "POST", self._logout)
        if path.startswith("/apk/"):
            return self._only(method, "GET", lambda: self._download(request))
        if path.startswith("/api/"):
            return self._api(request)
        raise ApiError(HTTPStatus.NOT_FOUND, "not_found")

    @staticmethod
    def _only(method: str, expected: str, action: Callable[[], Response]) -> Response:
        if method != expected:
            return Response(HTTPStatus.METHOD_NOT_ALLOWED, headers=[("Allow", expected)])
        return action()

    def _static_file(self, path: str) -> Response:
        body, mime = self._static[path]
        return Response(HTTPStatus.OK, body, mime)

    def _home(self, request: Request) -> Response:
        if self._authenticated(request):
            return self._page(request, "index", HTTPStatus.OK)
        return self._page(request, "login", HTTPStatus.OK)

    def _login(self, request: Request) -> Response:
        client = self.client_id(request)
        if self._throttle.is_blocked(client):
            return self._page(request, "login", HTTPStatus.TOO_MANY_REQUESTS, "login_blocked")
        form = parse_qs(request.body.decode("utf-8", errors="replace"))
        token = form.get("token", [""])[0].strip()
        if not token or not self._auth.check_token(token):
            self._throttle.record_failure(client)
            return self._page(request, "login", HTTPStatus.UNAUTHORIZED, "login_error")
        self._throttle.reset(client)
        return redirect("/", [("Set-Cookie", self._session_cookie(self._auth.issue_session(), self._auth.session_seconds))])

    def _logout(self) -> Response:
        return redirect("/", [("Set-Cookie", self._session_cookie("", 0))])

    def _session_cookie(self, value: str, max_age: int) -> str:
        secure = "; Secure" if self._config.secure_cookie else ""
        return f"{SESSION_COOKIE}={value}; Max-Age={max_age}; Path=/; HttpOnly; SameSite=Strict{secure}"

    def _download(self, request: Request) -> Response:
        if not self._authenticated(request):
            return redirect("/")
        job = self._apk_job(request.path)
        if job is None or job.apk_file is None:
            raise ApiError(HTTPStatus.NOT_FOUND, "not_found")
        apk_dir = self._config.apk_dir.resolve()
        path = (apk_dir / job.apk_file).resolve()
        if path.parent != apk_dir or not path.is_file():
            raise ApiError(HTTPStatus.NOT_FOUND, "not_found")
        disposition = f'attachment; filename="{path.name}"'
        return Response(HTTPStatus.OK, content_type=APK_MIME, headers=[("Content-Disposition", disposition)], file=path)

    def _apk_job(self, path: str) -> Job | None:
        if path == "/apk/latest":
            return self._store.latest_apk()
        match = _APK_PATH.fullmatch(path)
        return self._store.get(int(match.group(1))) if match else None

    def _api(self, request: Request) -> Response:
        if not self._authenticated(request):
            raise ApiError(HTTPStatus.UNAUTHORIZED, "unauthorized")
        path, method = request.path, request.method
        if path == "/api/jobs":
            return self._only(method, "GET", self._list_jobs)
        if path == "/api/status":
            return self._only(method, "GET", self._status)
        if path == "/api/feedback":
            return self._only(method, "POST", lambda: self._create_feedback(request))
        if path == "/api/build":
            return self._only(method, "POST", lambda: self._create_build(request))
        if match := _CANCEL_PATH.fullmatch(path):
            return self._only(method, "POST", lambda: self._cancel(request, int(match.group(1))))
        if match := _JOB_PATH.fullmatch(path):
            return self._only(method, "GET", lambda: self._job_detail(int(match.group(1))))
        raise ApiError(HTTPStatus.NOT_FOUND, "not_found")

    def _list_jobs(self) -> Response:
        latest = self._store.latest_apk()
        return json_response(
            HTTPStatus.OK,
            {
                "jobs": [job.to_dict() for job in self._store.list_recent(JOB_LIST_LIMIT)],
                "latest_apk": latest.id if latest else None,
            },
        )

    def _status(self) -> Response:
        current_id = self._worker.current_job_id
        current = self._store.get(current_id) if current_id is not None else None
        latest = self._store.latest_apk()
        return json_response(
            HTTPStatus.OK,
            {
                "state": "busy" if current else "idle",
                "current_job": current.to_dict() if current else None,
                "queued": self._store.count_queued(),
                "latest_apk": latest.id if latest else None,
                "uptime_seconds": int(self._clock() - self._started_at),
                "router": {"model": self._config.router_model, "effort": self._config.router_effort},
                "model_choices": list(self._config.model_choices),
                "effort_choices": list(self._config.effort_choices),
            },
        )

    def _job_detail(self, job_id: int) -> Response:
        job = self._store.get(job_id)
        if job is None:
            raise ApiError(HTTPStatus.NOT_FOUND, "not_found")
        log = read_log_tail(self._worker.log_path(job_id))
        return json_response(HTTPStatus.OK, {"job": job.to_dict(), "log": log})

    def _create_feedback(self, request: Request) -> Response:
        data = self._json_body(request)
        feedback = data.get("feedback")
        resume = data.get("resume", False)
        if not isinstance(feedback, str) or not feedback.strip():
            raise ApiError(HTTPStatus.BAD_REQUEST, "feedback_empty")
        if len(feedback) > self._config.max_feedback_length:
            raise ApiError(HTTPStatus.BAD_REQUEST, "feedback_too_long")
        if not isinstance(resume, bool):
            raise ApiError(HTTPStatus.BAD_REQUEST, "invalid_resume")
        job = self._store.create(JobKind.FEEDBACK, feedback.strip(), resume)
        self._worker.notify()
        return json_response(HTTPStatus.CREATED, job.to_dict())

    def _create_build(self, request: Request) -> Response:
        self._json_body(request)
        job = self._store.create(JobKind.BUILD)
        self._worker.notify()
        return json_response(HTTPStatus.CREATED, job.to_dict())

    def _cancel(self, request: Request, job_id: int) -> Response:
        self._json_body(request)
        if self._store.get(job_id) is None:
            raise ApiError(HTTPStatus.NOT_FOUND, "not_found")
        if not self._worker.cancel(job_id):
            raise ApiError(HTTPStatus.CONFLICT, "not_cancellable")
        return json_response(HTTPStatus.OK, {"cancelled": job_id})

    @staticmethod
    def _json_body(request: Request) -> dict[str, Any]:
        if not request.header("content-type").startswith("application/json"):
            raise ApiError(HTTPStatus.UNSUPPORTED_MEDIA_TYPE, "unsupported_media_type")
        if not request.body:
            return {}
        try:
            data = json.loads(request.body.decode("utf-8"))
        except (UnicodeDecodeError, json.JSONDecodeError) as error:
            raise ApiError(HTTPStatus.BAD_REQUEST, "invalid_json") from error
        if not isinstance(data, dict):
            raise ApiError(HTTPStatus.BAD_REQUEST, "invalid_json")
        return data

    def _authenticated(self, request: Request) -> bool:
        authorization = request.header("authorization")
        if authorization.startswith("Bearer "):
            client = self.client_id(request)
            if self._throttle.is_blocked(client):
                raise ApiError(HTTPStatus.TOO_MANY_REQUESTS, "too_many_attempts")
            if self._auth.check_token(authorization.removeprefix("Bearer ").strip()):
                return True
            self._throttle.record_failure(client)
            return False
        return self._auth.verify_session(self._session_value(request))

    @staticmethod
    def _session_value(request: Request) -> str | None:
        raw = request.header("cookie")
        if not raw:
            return None
        cookies = SimpleCookie()
        try:
            cookies.load(raw)
        except CookieError:
            return None
        morsel = cookies.get(SESSION_COOKIE)
        return morsel.value if morsel else None

    def _page(self, request: Request, name: str, status: int, message_key: str | None = None) -> Response:
        language = self._translator.pick(request.header("accept-language"))
        strings = self._translator.strings(language)
        values = {
            **strings,
            "lang": language,
            "max_feedback_length": str(self._config.max_feedback_length),
            "login_message": strings.get(message_key, "") if message_key else "",
        }
        i18n_json = json.dumps(strings, ensure_ascii=False).translate(_JSON_ESCAPES)

        def substitute(match: re.Match[str]) -> str:
            key = match.group(1)
            if key == "i18n_json":
                return i18n_json
            return html.escape(values.get(key, key))

        body = _PLACEHOLDER.sub(substitute, self._templates[name]).encode("utf-8")
        return Response(status, body, HTML_MIME)


def make_handler(app: FeedbackApp) -> type[BaseHTTPRequestHandler]:
    class Handler(BaseHTTPRequestHandler):
        server_version = "FeedbackServer"
        sys_version = ""
        protocol_version = "HTTP/1.1"

        def do_GET(self) -> None:
            self._dispatch("GET")

        def do_POST(self) -> None:
            self._dispatch("POST")

        def do_PUT(self) -> None:
            self._dispatch("PUT")

        def do_DELETE(self) -> None:
            self._dispatch("DELETE")

        def _dispatch(self, method: str) -> None:
            try:
                length = int(self.headers.get("Content-Length", "0") or "0")
            except ValueError:
                length = -1
            if length < 0 or length > MAX_BODY_BYTES:
                self.close_connection = True
                self._send(app.payload_too_large())
                return
            body = self.rfile.read(length) if length else b""
            parsed = urlsplit(self.path)
            request = Request(
                method=method,
                path=parsed.path,
                headers={name.lower(): value for name, value in self.headers.items()},
                body=body,
                client_ip=self.client_address[0],
            )
            self._send(app.handle(request))

        def _send(self, response: Response) -> None:
            try:
                self.send_response(response.status)
                for name, value in response.headers:
                    self.send_header(name, value)
                if response.status == HTTPStatus.NO_CONTENT:
                    self.end_headers()
                    return
                self.send_header("Content-Type", response.content_type)
                if response.file is not None:
                    self.send_header("Content-Length", str(response.file.stat().st_size))
                    self.end_headers()
                    with response.file.open("rb") as source:
                        shutil.copyfileobj(source, self.wfile)
                else:
                    self.send_header("Content-Length", str(len(response.body)))
                    self.end_headers()
                    self.wfile.write(response.body)
            except (BrokenPipeError, ConnectionResetError):
                self.close_connection = True

        def log_message(self, format: str, *args: Any) -> None:
            logger.info("%s %s", self.address_string(), format % args)

    return Handler
