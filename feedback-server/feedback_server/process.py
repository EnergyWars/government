from __future__ import annotations

import os
import signal
import subprocess
import threading
from collections.abc import Callable, Sequence
from dataclasses import dataclass
from pathlib import Path
from typing import Protocol

LineSink = Callable[[str], None]


@dataclass(frozen=True, slots=True)
class CommandResult:
    returncode: int | None
    timed_out: bool = False
    cancelled: bool = False

    @property
    def ok(self) -> bool:
        return self.returncode == 0 and not self.timed_out and not self.cancelled


class CommandRunner(Protocol):
    def run(
        self,
        args: Sequence[str],
        cwd: Path,
        timeout: float,
        on_line: LineSink,
        stdin_text: str | None = None,
    ) -> CommandResult: ...

    def cancel(self) -> None: ...


class SubprocessRunner:
    def __init__(self, grace_seconds: float = 10.0) -> None:
        self._lock = threading.Lock()
        self._process: subprocess.Popen[str] | None = None
        self._cancelled = False
        self._grace = grace_seconds

    def run(
        self,
        args: Sequence[str],
        cwd: Path,
        timeout: float,
        on_line: LineSink,
        stdin_text: str | None = None,
    ) -> CommandResult:
        try:
            process = subprocess.Popen(
                list(args),
                cwd=cwd,
                stdin=subprocess.PIPE if stdin_text is not None else subprocess.DEVNULL,
                stdout=subprocess.PIPE,
                stderr=subprocess.STDOUT,
                text=True,
                encoding="utf-8",
                errors="replace",
                start_new_session=True,
            )
        except OSError as error:
            on_line(str(error))
            return CommandResult(returncode=None)
        timed_out = threading.Event()
        with self._lock:
            self._process = process
            self._cancelled = False
        timer = threading.Timer(timeout, self._expire, (process, timed_out))
        timer.daemon = True
        timer.start()
        try:
            self._feed_stdin(process, stdin_text)
            for line in process.stdout or ():
                on_line(line.rstrip("\n"))
            returncode = process.wait()
        finally:
            timer.cancel()
            if process.stdout is not None:
                process.stdout.close()
            with self._lock:
                self._process = None
                cancelled = self._cancelled
        return CommandResult(returncode=returncode, timed_out=timed_out.is_set(), cancelled=cancelled)

    def cancel(self) -> None:
        with self._lock:
            self._cancelled = True
            process = self._process
        if process is not None:
            self._terminate(process)

    @staticmethod
    def _feed_stdin(process: subprocess.Popen[str], stdin_text: str | None) -> None:
        if stdin_text is None or process.stdin is None:
            return
        try:
            process.stdin.write(stdin_text)
        except OSError:
            pass
        try:
            process.stdin.close()
        except OSError:
            pass

    def _expire(self, process: subprocess.Popen[str], timed_out: threading.Event) -> None:
        timed_out.set()
        self._terminate(process)

    def _terminate(self, process: subprocess.Popen[str]) -> None:
        _signal_group(process, signal.SIGTERM)
        killer = threading.Timer(self._grace, _kill_if_running, (process,))
        killer.daemon = True
        killer.start()


def _kill_if_running(process: subprocess.Popen[str]) -> None:
    if process.poll() is None:
        _signal_group(process, signal.SIGKILL)


def _signal_group(process: subprocess.Popen[str], sig: signal.Signals) -> None:
    try:
        os.killpg(process.pid, sig)
    except (ProcessLookupError, PermissionError):
        pass
