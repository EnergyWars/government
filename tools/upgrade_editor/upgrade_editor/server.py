import ipaddress
import json
import mimetypes
import socket
import threading
from http import HTTPStatus
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path

from .store import DocumentStore, MissingFile, ValidationFailed

MAX_BODY = 8 * 1024 * 1024
GUARD_HEADER = "X-Upgrade-Editor"
LOOPBACK_HOST = "127.0.0.1"
ALL_INTERFACES = "0.0.0.0"
REQUEST_TIMEOUT_SECONDS = 30
SECURITY_HEADERS = {
    "Content-Security-Policy": "default-src 'self'; img-src 'self' data:; style-src 'self' 'unsafe-inline'; frame-ancestors 'none'; base-uri 'none'; form-action 'none'",
    "X-Frame-Options": "DENY",
    "X-Content-Type-Options": "nosniff",
    "Referrer-Policy": "no-referrer",
}


def own_host_names():
    names = {"localhost"}
    for name in (socket.gethostname(), socket.getfqdn()):
        if name:
            lowered = name.lower()
            names.add(lowered)
            names.add(lowered.split(".")[0])
            names.add(lowered.split(".")[0] + ".local")
    return names


def is_trusted_ip(name):
    try:
        address = ipaddress.ip_address(name)
    except ValueError:
        return False
    return address.is_private or address.is_loopback or address.is_link_local


def lan_addresses():
    found = []
    probe = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    try:
        probe.connect(("10.255.255.255", 1))
        found.append(probe.getsockname()[0])
    except OSError:
        pass
    finally:
        probe.close()
    try:
        found.extend(socket.gethostbyname_ex(socket.gethostname())[2])
    except OSError:
        pass
    result = []
    for address in found:
        if is_trusted_ip(address) and not address.startswith("127.") and address not in result:
            result.append(address)
    return result


def create_server(store, web_dir, port=0, host=LOOPBACK_HOST):
    server = ThreadingHTTPServer((host, port), EditorHandler)
    server.host_names = own_host_names()
    server.store = store
    server.web_dir = Path(web_dir).resolve()
    server.write_lock = threading.Lock()
    return server


class EditorHandler(BaseHTTPRequestHandler):
    server_version = "UpgradeEditor"
    timeout = REQUEST_TIMEOUT_SECONDS

    def log_message(self, format, *args):
        pass

    def _host_allowed(self):
        host = self.headers.get("Host", "")
        name, _, port = host.rpartition(":")
        if port != str(self.server.server_address[1]):
            return False
        name = name.strip("[]").lower()
        return name in self.server.host_names or is_trusted_ip(name)

    def _send_security_headers(self):
        for name, value in SECURITY_HEADERS.items():
            self.send_header(name, value)

    def _send_json(self, payload, status=HTTPStatus.OK):
        body = json.dumps(payload, ensure_ascii=False).encode("utf-8")
        self.send_response(status)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Content-Length", str(len(body)))
        self.send_header("Cache-Control", "no-store")
        self._send_security_headers()
        self.end_headers()
        self.wfile.write(body)

    def _send_error_code(self, status, code):
        self._send_json({"error": code}, status)

    def _read_body(self):
        try:
            length = int(self.headers.get("Content-Length", "0") or 0)
        except ValueError:
            return None
        if length <= 0 or length > MAX_BODY:
            return None
        try:
            return json.loads(self.rfile.read(length).decode("utf-8"))
        except (UnicodeDecodeError, json.JSONDecodeError):
            return None

    def do_GET(self):
        if not self._host_allowed():
            return self._send_error_code(HTTPStatus.FORBIDDEN, "HOST")
        path = self.path.split("?", 1)[0]
        if path.startswith("/api/"):
            return self._get_api(path)
        self._get_static(path)

    def do_PUT(self):
        self._mutate()

    def do_POST(self):
        self._mutate()

    def _mutate(self):
        if not self._host_allowed():
            return self._send_error_code(HTTPStatus.FORBIDDEN, "HOST")
        if self.headers.get(GUARD_HEADER) != "1":
            return self._send_error_code(HTTPStatus.FORBIDDEN, "GUARD")
        path = self.path.split("?", 1)[0]
        store = self.server.store
        try:
            self._route_mutation(store, path)
        except ValidationFailed as failure:
            self._send_json({"error": "VALIDATION", "errors": failure.errors}, HTTPStatus.UNPROCESSABLE_ENTITY)
        except MissingFile:
            self._send_error_code(HTTPStatus.NOT_FOUND, "MISSING_FILE")
        except Exception:
            self._send_error_code(HTTPStatus.INTERNAL_SERVER_ERROR, "INTERNAL")

    def _route_mutation(self, store, path):
        if path == "/api/document" and self.command == "PUT":
            body = self._read_body()
            if not isinstance(body, dict) or "document" not in body:
                return self._send_error_code(HTTPStatus.BAD_REQUEST, "BODY")
            with self.server.write_lock:
                saved = store.save_edited(body["document"])
            return self._send_json({"source": "edited", "document": saved})
        if path == "/api/validate" and self.command == "POST":
            body = self._read_body()
            if not isinstance(body, dict) or "document" not in body:
                return self._send_error_code(HTTPStatus.BAD_REQUEST, "BODY")
            return self._send_json({"errors": store.validate(body["document"])})
        if path == "/api/diff" and self.command == "POST":
            body = self._read_body()
            if not isinstance(body, dict) or "document" not in body:
                return self._send_error_code(HTTPStatus.BAD_REQUEST, "BODY")
            errors = store.validate(body["document"])
            if errors:
                return self._send_json({"error": "VALIDATION", "errors": errors}, HTTPStatus.UNPROCESSABLE_ENTITY)
            return self._send_json({"changes": store.changes_for(body["document"])})
        if path == "/api/reset" and self.command == "POST":
            with self.server.write_lock:
                archived = store.reset_edited()
            return self._send_json({"source": store.source(), "archived": archived.name if archived else None})
        self._send_error_code(HTTPStatus.NOT_FOUND, "ROUTE")

    def _get_api(self, path):
        store = self.server.store
        try:
            if path == "/api/document":
                return self._send_json({"source": store.source(), "document": store.load_active(), "original": store.load_original()})
            if path == "/api/context":
                return self._send_json(store.context())
            if path == "/api/translations":
                return self._send_json(store.translations())
            if path == "/api/changes":
                return self._send_json({"changes": store.changes()})
        except MissingFile:
            return self._send_error_code(HTTPStatus.NOT_FOUND, "MISSING_FILE")
        self._send_error_code(HTTPStatus.NOT_FOUND, "ROUTE")

    def _get_static(self, path):
        relative = "index.html" if path in ("", "/") else path.lstrip("/")
        target = (self.server.web_dir / relative).resolve()
        if self.server.web_dir not in target.parents or not target.is_file():
            return self._send_error_code(HTTPStatus.NOT_FOUND, "FILE")
        content = target.read_bytes()
        content_type = mimetypes.guess_type(target.name)[0] or "application/octet-stream"
        self.send_response(HTTPStatus.OK)
        self.send_header("Content-Type", content_type + ("; charset=utf-8" if content_type.startswith("text/") or content_type.endswith("javascript") or content_type.endswith("json") else ""))
        self.send_header("Content-Length", str(len(content)))
        self.send_header("Cache-Control", "no-store")
        self._send_security_headers()
        self.end_headers()
        self.wfile.write(content)
