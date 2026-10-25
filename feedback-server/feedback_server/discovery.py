from __future__ import annotations

import argparse
import fcntl
import http.client
import ipaddress
import socket
import struct
import sys
from collections.abc import Callable, Iterable, Sequence
from concurrent.futures import FIRST_COMPLETED, Future, ThreadPoolExecutor, wait

DEFAULT_PORT = 8787
SCAN_CONCURRENCY = 32
PROBE_TIMEOUT_SECONDS = 0.6
STATUS_PATH = "/status"
_ROUTE_PROBE_TARGET = ("10.255.255.255", 1)
_SIOCGIFADDR = 0x8915
_VIRTUAL_INTERFACES = ("lo", "docker", "br-", "veth", "virbr", "mpqemu", "lxc", "lxd", "cni", "flannel")

Probe = Callable[[str, int], bool]


def subnet_hosts(local_ipv4: str) -> list[str]:
    base = local_ipv4.rsplit(".", 1)[0]
    return [f"{base}.{suffix}" for suffix in range(1, 255)]


def is_lan_ipv4(address: str) -> bool:
    try:
        ip = ipaddress.IPv4Address(address)
    except ipaddress.AddressValueError:
        return False
    return ip.is_private and not ip.is_loopback and not ip.is_link_local


def local_ipv4_addresses(
    route_lookup: Callable[[], str | None] | None = None,
    host_lookup: Callable[[], Iterable[str]] | None = None,
) -> list[str]:
    candidates = [(route_lookup or _default_route_address)(), *(host_lookup or _interface_addresses)()]
    unique: list[str] = []
    for address in candidates:
        if address and is_lan_ipv4(address) and address not in unique:
            unique.append(address)
    return unique


def _default_route_address() -> str | None:
    try:
        with socket.socket(socket.AF_INET, socket.SOCK_DGRAM) as probe:
            probe.connect(_ROUTE_PROBE_TARGET)
            return probe.getsockname()[0]
    except OSError:
        return None


def _interface_addresses() -> list[str]:
    try:
        interfaces = socket.if_nameindex()
    except OSError:
        return []
    addresses: list[str] = []
    for _, name in interfaces:
        if name.startswith(_VIRTUAL_INTERFACES):
            continue
        try:
            with socket.socket(socket.AF_INET, socket.SOCK_DGRAM) as sock:
                packed = fcntl.ioctl(sock.fileno(), _SIOCGIFADDR, struct.pack("256s", name.encode()[:15]))
        except OSError:
            continue
        addresses.append(socket.inet_ntoa(packed[20:24]))
    return addresses


def probe_status(host: str, port: int, timeout: float = PROBE_TIMEOUT_SECONDS) -> bool:
    connection = http.client.HTTPConnection(host, port, timeout=timeout)
    try:
        connection.request("GET", STATUS_PATH)
        response = connection.getresponse()
        response.read()
        return response.status == 204
    except (OSError, http.client.HTTPException):
        return False
    finally:
        connection.close()


def race_first_match(
    hosts: Sequence[str], port: int, probe: Probe = probe_status, concurrency: int = SCAN_CONCURRENCY
) -> str | None:
    if not hosts:
        return None
    executor = ThreadPoolExecutor(max_workers=concurrency)
    try:
        pending: dict[Future[bool], str] = {executor.submit(probe, host, port): host for host in hosts}
        while pending:
            done, _ = wait(pending, return_when=FIRST_COMPLETED)
            for future in done:
                host = pending.pop(future)
                if future.result():
                    return host
        return None
    finally:
        executor.shutdown(wait=False, cancel_futures=True)


def discover(port: int = DEFAULT_PORT, local_ip: str | None = None, probe: Probe = probe_status) -> str | None:
    addresses = [local_ip] if local_ip else local_ipv4_addresses()
    for address in addresses:
        if host := race_first_match(subnet_hosts(address), port, probe):
            return host
    return None


def server_urls(port: int, addresses: Iterable[str] | None = None) -> list[str]:
    return [f"http://{address}:{port}" for address in (local_ipv4_addresses() if addresses is None else addresses)]


def main(argv: Sequence[str] | None = None) -> int:
    parser = argparse.ArgumentParser(prog="feedback_server.discovery")
    parser.add_argument("--port", type=int, default=DEFAULT_PORT)
    parser.add_argument("--ip", default=None)
    args = parser.parse_args(argv)
    if args.ip and not is_lan_ipv4(args.ip):
        print(f"Invalid LAN IPv4 address: {args.ip}", file=sys.stderr)
        return 2
    host = discover(args.port, args.ip)
    if host is None:
        print("No feedback server found in the local network.", file=sys.stderr)
        return 1
    print(f"http://{host}:{args.port}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
