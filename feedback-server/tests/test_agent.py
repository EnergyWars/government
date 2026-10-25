import json
import unittest
from dataclasses import replace

from feedback_server.agent import AgentStep, StreamParser
from feedback_server.process import CommandResult
from feedback_server.router import Route

from tests.helpers import FakeRunner, Script, TempDirCase, make_config


def event(**data: object) -> str:
    return json.dumps(data)


def assistant(*blocks: object) -> str:
    return event(type="assistant", session_id="s1", message={"content": list(blocks)})


ROUTE = Route("haiku", "low")
SUCCESS = event(type="result", subtype="success", is_error=False, result="Erledigt", session_id="s1")


class StreamParserTest(unittest.TestCase):
    def setUp(self) -> None:
        self.lines: list[str] = []
        self.parser = StreamParser(self.lines.append)

    def test_formats_text_and_tools(self) -> None:
        for line in (
            event(type="system", subtype="init", session_id="abc"),
            assistant(
                {"type": "text", "text": "  Ich lese  "},
                {"type": "text", "text": "   "},
                {"type": "tool_use", "name": "Bash", "input": {"command": "ls -la"}},
                {"type": "tool_use", "name": "Read", "input": {"file_path": "/a.gd"}},
                {"type": "tool_use", "name": "Grep", "input": {"other": 1}},
                {"type": "tool_use", "input": "raw"},
                {"type": "thinking"},
                "not a block",
            ),
            SUCCESS,
        ):
            self.parser.feed(line)
        self.assertEqual(
            self.lines,
            ["» Ich lese", "⚙ Bash ls -la", "⚙ Read /a.gd", "⚙ Grep", "⚙ ?", "✔ Erledigt"],
        )
        self.assertEqual(self.parser.session_id, "s1")
        self.assertTrue(self.parser.finished)
        self.assertFalse(self.parser.is_error)
        self.assertEqual(self.parser.result, "Erledigt")

    def test_long_tool_detail_is_truncated(self) -> None:
        self.parser.feed(assistant({"type": "tool_use", "name": "Bash", "input": {"command": "x" * 500}}))
        self.assertEqual(len(self.lines[0]), len("⚙ Bash ") + 200)

    def test_passes_through_non_json(self) -> None:
        for line in ("", "   ", "plain text", "[1, 2]", "{broken"):
            self.parser.feed(line)
        self.assertEqual(self.lines, ["plain text", "[1, 2]", "{broken"])

    def test_ignores_malformed_events(self) -> None:
        self.parser.feed(event(type="assistant", message="nope", session_id=""))
        self.parser.feed(event(type="assistant", message={"content": "nope"}))
        self.assertEqual(self.lines, [])
        self.assertIsNone(self.parser.session_id)

    def test_error_results(self) -> None:
        self.parser.feed(event(type="result", subtype="error_max_turns", is_error=False))
        self.assertTrue(self.parser.is_error)
        self.assertIsNone(self.parser.result)
        other = StreamParser(self.lines.append)
        other.feed(event(type="result", subtype="success", is_error=True, result=5))
        self.assertTrue(other.is_error)
        self.assertIsNone(other.result)


class AgentStepTest(TempDirCase, unittest.TestCase):
    def setUp(self) -> None:
        self.config = make_config(self.make_temp(), claude_args=("--permission-mode", "acceptEdits"))
        self.lines: list[str] = []

    def step(self, *scripts: Script) -> tuple[AgentStep, FakeRunner]:
        runner = FakeRunner(scripts)
        return AgentStep(self.config, runner), runner

    def test_command_and_prompt(self) -> None:
        step, _ = self.step()
        self.assertEqual(
            step.build_command(None, ROUTE),
            ["claude", "-p", "--model", "haiku", "--effort", "low", "--output-format", "stream-json",
             "--verbose", "--permission-mode", "acceptEdits", "--allowedTools", "Read", "Edit"],
        )
        self.assertIn("--resume", step.build_command("sid", ROUTE))
        self.assertTrue(step.build_prompt("Mehr {Kaffee}").endswith("Feedback:\nMehr {Kaffee}"))

    def test_command_without_allowed_tools(self) -> None:
        self.config = replace(self.config, allowed_tools=())
        step, _ = self.step()
        self.assertNotIn("--allowedTools", step.build_command(None, ROUTE))

    def test_success_passes_prompt_via_stdin(self) -> None:
        step, runner = self.step(Script([assistant({"type": "text", "text": "Hi"}), SUCCESS]))
        outcome = step.run("-rf feedback", "previous", Route("opus", "max"), self.lines.append)
        self.assertTrue(outcome.success)
        self.assertEqual(outcome.session_id, "s1")
        self.assertEqual(outcome.summary, "Erledigt")
        call = runner.calls[0]
        self.assertIn("-rf feedback", call.stdin_text)
        self.assertNotIn("-rf feedback", call.args)
        self.assertEqual(call.args[call.args.index("--resume") + 1], "previous")
        self.assertEqual(call.args[2:6], ["--model", "opus", "--effort", "max"])
        self.assertEqual(call.cwd, self.config.project_dir)
        self.assertEqual(call.timeout, self.config.agent_timeout)

    def test_failures(self) -> None:
        cases = [
            (Script([SUCCESS], CommandResult(0, cancelled=True)), "cancelled", True),
            (Script([], CommandResult(None, timed_out=True)), "agent_timeout", False),
            (Script([SUCCESS], CommandResult(1)), "agent_failed", False),
            (Script(["no result"]), "agent_failed", False),
            (Script([event(type="result", subtype="error_during_execution", is_error=True)]), "agent_failed", False),
        ]
        for script, error, cancelled in cases:
            with self.subTest(error=error):
                step, _ = self.step(script)
                outcome = step.run("x", None, ROUTE, self.lines.append)
                self.assertFalse(outcome.success)
                self.assertEqual(outcome.error, error)
                self.assertEqual(outcome.cancelled, cancelled)


if __name__ == "__main__":
    unittest.main()
