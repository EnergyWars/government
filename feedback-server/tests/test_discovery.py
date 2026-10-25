import io
import threading
import unittest
from contextlib import redirect_stderr, redirect_stdout
from unittest import mock

from feedback_server import discovery
from feedback_server.discovery import (
    discover,
    is_lan_ipv4,
    local_ipv4_addresses,
    main,
    probe_status,
    race_first_match,
    server_urls,
    subnet_hosts,
)
from feedback_server.server import FeedbackServer

from tests.helpers import FakeRunner, TempDirCase, make_config


class SubnetTest(unittest.TestCase):
    def test_subnet_hosts(self) -> None:
        hosts = subnet_hosts("192.168.178.55")
        self.assertEqual(len(hosts), 254)
        self.assertEqual((hosts[0], hosts[-1]), ("192.168.178.1", "192.168.178.254"))

    def test_is_lan_ipv4(self) -> None:
        for address, expected in (
            ("192.168.178.55", True),
            ("10.0.0.2", True),
            ("172.16.4.1", True),
            ("127.0.0.1", False),
            ("169.254.1.1", False),
            ("8.8.8.8", False),
            ("::1", False),
            ("nope", False),
        ):
            with self.subTest(address=address):
                self.assertEqual(is_lan_ipv4(address), expected)

    def test_local_addresses_dedupe_and_filter(self) -> None:
        addresses = local_ipv4_addresses(
            lambda: "192.168.178.55", lambda: ["127.0.1.1", "192.168.178.55", "192.168.2.150", "8.8.8.8"]
        )
        self.assertEqual(addresses, ["192.168.178.55", "192.168.2.150"])
        self.assertEqual(local_ipv4_addresses(lambda: None, lambda: []), [])

    def test_default_lookups_survive_os_errors(self) -> None:
        with mock.patch.object(discovery.socket, "socket", side_effect=OSError), \
                mock.patch.object(discovery.socket, "if_nameindex", side_effect=OSError):
            self.assertEqual(local_ipv4_addresses(), [])

    def test_interface_addresses_skip_virtual_and_failing(self) -> None:
        def ioctl(fd: int, request: int, arg: bytes) -> bytes:
            name = arg.rstrip(b"\0").decode()
            if name == "wlan0":
                raise OSError
            return bytes(20) + discovery.socket.inet_aton({"enp1s0": "192.168.178.55"}.get(name, "10.8.0.2")) + bytes(232)

        interfaces = [(1, "lo"), (2, "enp1s0"), (3, "docker0"), (4, "br-abc"), (5, "wlan0"), (6, "tailscale0")]
        with mock.patch.object(discovery.socket, "if_nameindex", return_value=interfaces), \
                mock.patch.object(discovery.fcntl, "ioctl", side_effect=ioctl) as patched:
            self.assertEqual(discovery._interface_addresses(), ["192.168.178.55", "10.8.0.2"])
        self.assertEqual(patched.call_count, 3)

    def test_default_lookups_return_strings(self) -> None:
        for address in local_ipv4_addresses():
            self.assertTrue(is_lan_ipv4(address))

    def test_server_urls(self) -> None:
        self.assertEqual(server_urls(8787, ["10.0.0.2"]), ["http://10.0.0.2:8787"])
        with mock.patch.object(discovery, "local_ipv4_addresses", return_value=["10.0.0.3"]):
            self.assertEqual(server_urls(1), ["http://10.0.0.3:1"])


class RaceTest(unittest.TestCase):
    def test_first_match_wins(self) -> None:
        release = threading.Event()

        def probe(host: str, port: int) -> bool:
            if host == "a":
                release.wait(5)
                return True
            return host == "b"

        self.assertEqual(race_first_match(["a", "b", "c"], 1, probe, concurrency=3), "b")
        release.set()

    def test_no_match(self) -> None:
        self.assertIsNone(race_first_match(["a", "b"], 1, lambda host, port: False))
        self.assertIsNone(race_first_match([], 1, lambda host, port: True))

    def test_discover_uses_given_or_local_addresses(self) -> None:
        probe = lambda host, port: host == "10.0.0.7" and port == 9000
        self.assertEqual(discover(9000, "10.0.0.1", probe), "10.0.0.7")
        with mock.patch.object(discovery, "local_ipv4_addresses", return_value=["192.168.1.2", "10.0.0.2"]):
            self.assertEqual(discover(9000, None, probe), "10.0.0.7")
        with mock.patch.object(discovery, "local_ipv4_addresses", return_value=[]):
            self.assertIsNone(discover(9000, None, probe))


class ProbeAgainstServerTest(TempDirCase, unittest.TestCase):
    def setUp(self) -> None:
        self.server = FeedbackServer(make_config(self.make_temp()), FakeRunner())
        self.thread = threading.Thread(target=self.server.serve_forever)
        self.thread.start()
        self.addCleanup(self.stop)

    def stop(self) -> None:
        self.server.shutdown()
        self.thread.join(5)
        self.server.close()

    def test_probe_finds_running_server(self) -> None:
        self.assertTrue(probe_status("127.0.0.1", self.server.port))
        self.assertEqual(race_first_match(["127.0.0.2", "127.0.0.1"], self.server.port), "127.0.0.1")

    def test_probe_rejects_closed_port_and_other_servers(self) -> None:
        with mock.patch.object(discovery, "STATUS_PATH", "/api/health"):
            self.assertFalse(probe_status("127.0.0.1", self.server.port))
        self.assertFalse(probe_status("127.0.0.1", 1, timeout=0.2))

    def test_cli(self) -> None:
        out, err = io.StringIO(), io.StringIO()
        with mock.patch.object(discovery, "discover", return_value="10.0.0.9"), redirect_stdout(out):
            self.assertEqual(main(["--port", "8787"]), 0)
        self.assertEqual(out.getvalue().strip(), "http://10.0.0.9:8787")
        with mock.patch.object(discovery, "discover", return_value=None), redirect_stderr(err):
            self.assertEqual(main(["--ip", "10.0.0.1"]), 1)
        with redirect_stderr(err):
            self.assertEqual(main(["--ip", "8.8.8.8"]), 2)
        self.assertIn("No feedback server", err.getvalue())


if __name__ == "__main__":
    unittest.main()
