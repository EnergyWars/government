import sys
import threading
import time
import unittest
from pathlib import Path

from feedback_server.process import CommandResult, SubprocessRunner


class CommandResultTest(unittest.TestCase):
    def test_ok(self) -> None:
        self.assertTrue(CommandResult(0).ok)
        self.assertFalse(CommandResult(1).ok)
        self.assertFalse(CommandResult(None).ok)
        self.assertFalse(CommandResult(0, timed_out=True).ok)
        self.assertFalse(CommandResult(0, cancelled=True).ok)


class SubprocessRunnerTest(unittest.TestCase):
    def setUp(self) -> None:
        self.runner = SubprocessRunner(grace_seconds=0.5)
        self.lines: list[str] = []

    def python(self, code: str, timeout: float = 10, stdin_text: str | None = None) -> CommandResult:
        return self.runner.run(
            [sys.executable, "-c", code], Path.cwd(), timeout, self.lines.append, stdin_text
        )

    def test_streams_output_and_returncode(self) -> None:
        result = self.python("import sys; print('a'); print('b', file=sys.stderr); sys.exit(3)")
        self.assertEqual(result.returncode, 3)
        self.assertEqual(sorted(self.lines), ["a", "b"])

    def test_passes_stdin_without_shell(self) -> None:
        result = self.python("import sys; print(sys.stdin.read().upper())", stdin_text="--x; rm -rf $HOME")
        self.assertTrue(result.ok)
        self.assertEqual(self.lines, ["--X; RM -RF $HOME"])

    def test_stdin_ignored_when_process_exits(self) -> None:
        result = self.python("pass", stdin_text="x" * 1_000_000)
        self.assertTrue(result.ok)

    def test_timeout_terminates(self) -> None:
        started = time.monotonic()
        result = self.python("import time; time.sleep(30)", timeout=0.3)
        self.assertTrue(result.timed_out)
        self.assertFalse(result.ok)
        self.assertLess(time.monotonic() - started, 10)

    def test_timeout_kills_process_ignoring_sigterm(self) -> None:
        code = "import signal, time; signal.signal(signal.SIGTERM, signal.SIG_IGN); print('ready', flush=True); time.sleep(30)"
        result = self.python(code, timeout=0.5)
        self.assertTrue(result.timed_out)
        self.assertIsNotNone(result.returncode)

    def test_cancel_running_process(self) -> None:
        started = threading.Event()

        def collect(line: str) -> None:
            started.set()

        outcome: list[CommandResult] = []
        thread = threading.Thread(
            target=lambda: outcome.append(
                self.runner.run(
                    [sys.executable, "-c", "import time; print('go', flush=True); time.sleep(30)"],
                    Path.cwd(),
                    30,
                    collect,
                )
            )
        )
        thread.start()
        self.assertTrue(started.wait(10))
        self.runner.cancel()
        thread.join(10)
        self.assertTrue(outcome[0].cancelled)

    def test_cancel_without_process_is_noop(self) -> None:
        self.runner.cancel()
        self.assertTrue(self.python("pass").ok)

    def test_missing_binary(self) -> None:
        result = self.runner.run(["/nonexistent/binary"], Path.cwd(), 5, self.lines.append)
        self.assertIsNone(result.returncode)
        self.assertEqual(len(self.lines), 1)


if __name__ == "__main__":
    unittest.main()
