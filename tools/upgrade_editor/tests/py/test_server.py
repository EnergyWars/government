import http.client
import json
import socket
import tempfile
import threading
import unittest
import urllib.error
import urllib.request
from pathlib import Path
from unittest import mock

from upgrade_editor import store as store_module
from upgrade_editor.server import ALL_INTERFACES, create_server, is_trusted_ip, lan_addresses
from upgrade_editor.store import DocumentStore
from .fixtures import make_document


class ServerTestCase(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory()
        root = Path(self.directory.name)
        store_module.write_json(root / "data" / "upgrades.json", make_document())
        store_module.write_json(root / "context" / "app_context.json", {"schema": 1})
        store_module.write_json(root / "context" / "game_translations.json", {})
        web = root / "web"
        (web / "js").mkdir(parents=True)
        (web / "index.html").write_text("<html>home</html>", encoding="utf-8")
        (web / "js" / "app.js").write_text("export const x = 1;", encoding="utf-8")
        (root / "secret.txt").write_text("secret", encoding="utf-8")
        self.server = create_server(DocumentStore(root / "data", root / "context"), web)
        self.port = self.server.server_address[1]
        self.thread = threading.Thread(target=self.server.serve_forever, daemon=True)
        self.thread.start()

    def tearDown(self):
        self.server.shutdown()
        self.server.server_close()
        self.thread.join()
        self.directory.cleanup()

    def request(self, method, path, body=None, guard=True, host=None):
        data = json.dumps(body).encode("utf-8") if body is not None else None
        request = urllib.request.Request(f"http://127.0.0.1:{self.port}{path}", data=data, method=method)
        if data is not None:
            request.add_header("Content-Type", "application/json")
        if guard:
            request.add_header("X-Upgrade-Editor", "1")
        if host:
            request.add_header("Host", host)
        try:
            with urllib.request.urlopen(request) as response:
                return response.status, response.read(), response.headers
        except urllib.error.HTTPError as error:
            return error.code, error.read(), error.headers

    def json(self, method, path, body=None, **options):
        status, content, _ = self.request(method, path, body, **options)
        return status, json.loads(content)


class PortTest(ServerTestCase):
    def test_server_binds_a_free_random_port_on_localhost(self):
        self.assertGreater(self.port, 0)
        self.assertEqual(self.server.server_address[0], "127.0.0.1")

    def test_two_servers_get_different_ports(self):
        other = create_server(self.server.store, self.server.web_dir)
        try:
            self.assertNotEqual(other.server_address[1], self.port)
        finally:
            other.server_close()


class NetworkTest(ServerTestCase):
    def test_private_ip_hosts_are_accepted(self):
        for name in ("192.168.1.20", "10.0.0.5", "172.16.4.4", "169.254.1.1", "[::1]"):
            self.assertEqual(self.request("GET", "/", host=f"{name}:{self.port}")[0], 200, name)

    def test_public_ip_and_foreign_names_are_rejected(self):
        for name in ("8.8.8.8", "evil.example", "192.168.1.20.evil.example"):
            self.assertEqual(self.request("GET", "/", host=f"{name}:{self.port}")[0], 403, name)

    def test_wrong_port_is_rejected(self):
        self.assertEqual(self.request("GET", "/", host="192.168.1.20:1")[0], 403)
        self.assertEqual(self.request("GET", "/", host="192.168.1.20")[0], 403)

    def test_own_host_name_is_accepted(self):
        name = socket.gethostname().lower()
        self.assertEqual(self.request("GET", "/", host=f"{name}:{self.port}")[0], 200)
        self.assertEqual(self.request("GET", "/", host=f"{name.split('.')[0]}.local:{self.port}")[0], 200)

    def test_server_can_bind_all_interfaces(self):
        other = create_server(self.server.store, self.server.web_dir, 0, ALL_INTERFACES)
        try:
            self.assertEqual(other.server_address[0], "0.0.0.0")
        finally:
            other.server_close()

    def test_lan_addresses_are_private_and_not_loopback(self):
        for address in lan_addresses():
            self.assertTrue(is_trusted_ip(address))
            self.assertFalse(address.startswith("127."))

    def test_trusted_ip_helper(self):
        self.assertTrue(is_trusted_ip("192.168.0.1"))
        self.assertFalse(is_trusted_ip("8.8.8.8"))
        self.assertFalse(is_trusted_ip("not-an-ip"))


class StaticTest(ServerTestCase):
    def test_index(self):
        status, content, headers = self.request("GET", "/")
        self.assertEqual((status, content), (200, b"<html>home</html>"))
        self.assertIn("text/html", headers["Content-Type"])

    def test_javascript_content_type(self):
        _, _, headers = self.request("GET", "/js/app.js")
        self.assertIn("javascript", headers["Content-Type"])

    def test_unknown_file(self):
        self.assertEqual(self.request("GET", "/nothing.html")[0], 404)

    def test_security_headers_on_pages_and_api(self):
        for path in ("/", "/api/context", "/nothing.html"):
            _, _, headers = self.request("GET", path)
            self.assertIn("frame-ancestors 'none'", headers["Content-Security-Policy"])
            self.assertEqual(headers["X-Frame-Options"], "DENY")
            self.assertEqual(headers["X-Content-Type-Options"], "nosniff")
            self.assertEqual(headers["Referrer-Policy"], "no-referrer")

    def test_path_traversal_is_blocked(self):
        self.assertEqual(self.request("GET", "/../secret.txt")[0], 404)
        self.assertEqual(self.request("GET", "/%2e%2e/secret.txt")[0], 404)

    def test_foreign_host_header_is_rejected(self):
        self.assertEqual(self.request("GET", "/", host="evil.example:" + str(self.port))[0], 403)
        self.assertEqual(self.request("GET", "/api/context", host="evil.example")[0], 403)


class ApiReadTest(ServerTestCase):
    def test_document(self):
        status, payload = self.json("GET", "/api/document")
        self.assertEqual(status, 200)
        self.assertEqual(payload["source"], "original")
        self.assertEqual(payload["document"], payload["original"])

    def test_context_and_translations(self):
        self.assertEqual(self.json("GET", "/api/context"), (200, {"schema": 1}))
        self.assertEqual(self.json("GET", "/api/translations"), (200, {}))

    def test_changes_are_empty_without_a_copy(self):
        self.assertEqual(self.json("GET", "/api/changes"), (200, {"changes": []}))

    def test_unknown_route(self):
        self.assertEqual(self.json("GET", "/api/other")[0], 404)

    def test_missing_context_file(self):
        (Path(self.directory.name) / "context" / "app_context.json").unlink()
        self.assertEqual(self.json("GET", "/api/context")[1], {"error": "MISSING_FILE"})


class ApiWriteTest(ServerTestCase):
    def edited(self):
        document = make_document()
        document["upgrades"]["briefcase"]["cost"] = 77.0
        return document

    def test_guard_header_is_required(self):
        self.assertEqual(self.json("PUT", "/api/document", {"document": self.edited()}, guard=False), (403, {"error": "GUARD"}))

    def test_foreign_host_cannot_write(self):
        status, _ = self.json("PUT", "/api/document", {"document": self.edited()}, host="evil.example")
        self.assertEqual(status, 403)

    def test_save_creates_the_copy_and_switches_the_source(self):
        status, payload = self.json("PUT", "/api/document", {"document": self.edited()})
        self.assertEqual((status, payload["source"]), (200, "edited"))
        _, current = self.json("GET", "/api/document")
        self.assertEqual(current["source"], "edited")
        self.assertEqual(current["document"]["upgrades"]["briefcase"]["cost"], 77.0)
        self.assertEqual(current["original"]["upgrades"]["briefcase"]["cost"], 150.0)
        self.assertEqual(self.json("GET", "/api/changes")[1]["changes"][0]["after"], 77.0)

    def test_invalid_document_returns_error_list(self):
        document = self.edited()
        document["upgrades"]["briefcase"]["curve"] = "x"
        status, payload = self.json("PUT", "/api/document", {"document": document})
        self.assertEqual(status, 422)
        self.assertEqual(payload["errors"][0]["code"], "CURVE")

    def test_missing_body(self):
        self.assertEqual(self.json("PUT", "/api/document", {"other": 1})[1], {"error": "BODY"})
        self.assertEqual(self.json("PUT", "/api/document")[1], {"error": "BODY"})

    def test_garbage_body(self):
        request = urllib.request.Request(f"http://127.0.0.1:{self.port}/api/document", data=b"{nope", method="PUT")
        request.add_header("X-Upgrade-Editor", "1")
        with self.assertRaises(urllib.error.HTTPError) as raised:
            urllib.request.urlopen(request)
        self.assertEqual(raised.exception.code, 400)

    def test_oversized_body_is_rejected(self):
        request = urllib.request.Request(f"http://127.0.0.1:{self.port}/api/document", data=b"x" * 10, method="PUT")
        request.add_header("X-Upgrade-Editor", "1")
        request.add_header("Content-Length", str(9 * 1024 * 1024))
        with self.assertRaises((urllib.error.HTTPError, urllib.error.URLError, ConnectionError)):
            urllib.request.urlopen(request, timeout=3)

    def test_validate_endpoint(self):
        document = make_document()
        document["upgrades"]["briefcase"]["cost"] = -5
        _, payload = self.json("POST", "/api/validate", {"document": document})
        self.assertEqual(payload["errors"][0]["code"], "RANGE")
        self.assertEqual(self.json("POST", "/api/validate", {"x": 1})[1], {"error": "BODY"})

    def test_diff_endpoint_compares_unsaved_documents(self):
        status, payload = self.json("POST", "/api/diff", {"document": self.edited()})
        self.assertEqual(status, 200)
        self.assertEqual(payload["changes"][0]["after"], 77.0)
        self.assertFalse((Path(self.directory.name) / "data" / "upgrades.edited.json").exists())

    def test_diff_endpoint_rejects_invalid_documents(self):
        document = self.edited()
        document["upgrades"]["briefcase"]["growth"] = 0
        status, payload = self.json("POST", "/api/diff", {"document": document})
        self.assertEqual((status, payload["error"]), (422, "VALIDATION"))
        self.assertEqual(self.json("POST", "/api/diff", {"x": 1})[1], {"error": "BODY"})

    def test_reset_returns_to_the_original(self):
        self.json("PUT", "/api/document", {"document": self.edited()})
        status, payload = self.json("POST", "/api/reset")
        self.assertEqual((status, payload["source"]), (200, "original"))
        self.assertIsNotNone(payload["archived"])
        self.assertNotIn("/", payload["archived"])
        self.assertEqual(self.json("POST", "/api/reset")[1]["archived"], None)

    def test_invalid_content_length_is_a_bad_request(self):
        connection = http.client.HTTPConnection("127.0.0.1", self.port, timeout=5)
        connection.putrequest("PUT", "/api/document")
        connection.putheader("X-Upgrade-Editor", "1")
        connection.putheader("Content-Length", "abc")
        connection.endheaders()
        response = connection.getresponse()
        self.assertEqual(response.status, 400)
        connection.close()

    def test_unexpected_errors_do_not_leak_details(self):
        with mock.patch.object(DocumentStore, "validate", side_effect=TypeError("secret detail")):
            status, content, _ = self.request("POST", "/api/validate", {"document": {}})
        self.assertEqual(status, 500)
        self.assertEqual(json.loads(content), {"error": "INTERNAL"})

    def test_unknown_write_route(self):
        self.assertEqual(self.json("POST", "/api/nothing", {})[0], 404)
        self.assertEqual(self.json("PUT", "/api/reset", {})[0], 404)



class MainPortTest(unittest.TestCase):
    def test_default_port_is_fixed(self):
        from upgrade_editor import __main__ as entry
        self.assertEqual(entry.DEFAULT_PORT, 47321)

    def test_busy_port_reports_an_error(self):
        import io
        import socket
        from contextlib import redirect_stderr
        from upgrade_editor import __main__ as entry
        blocker = socket.socket()
        blocker.bind(("127.0.0.1", 0))
        blocker.listen(1)
        try:
            buffer = io.StringIO()
            with redirect_stderr(buffer):
                code = entry.main(["serve", "--no-browser", "--port", str(blocker.getsockname()[1])])
            self.assertEqual(code, 3)
            self.assertIn("unavailable", buffer.getvalue())
        finally:
            blocker.close()


if __name__ == "__main__":
    unittest.main()
