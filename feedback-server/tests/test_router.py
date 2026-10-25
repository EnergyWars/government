import json
import unittest
from dataclasses import replace

from feedback_server.process import CommandResult
from feedback_server.router import MAX_REASON_LENGTH, ModelRouter, Route

from tests.helpers import FakeRunner, Script, TempDirCase, make_config


def result_line(choice: object = None, **extra: object) -> str:
    payload = {"type": "result", "subtype": "success", "is_error": False, **extra}
    if choice is not None:
        payload["structured_output"] = choice
    return json.dumps(payload)


GOOD = {"model": "sonnet", "effort": "medium", "reason": "  Klar umrissen.  "}


class ModelRouterTest(TempDirCase, unittest.TestCase):
    def setUp(self) -> None:
        self.config = make_config(self.make_temp())
        self.lines: list[str] = []

    def router(self, *scripts: Script) -> tuple[ModelRouter, FakeRunner]:
        runner = FakeRunner(scripts)
        return ModelRouter(self.config, runner), runner

    def test_command_uses_router_model_without_tools(self) -> None:
        router, _ = self.router()
        command = router.build_command()
        self.assertEqual(command[:7], ["claude", "-p", "--model", "sonnet", "--effort", "low", "--tools"])
        self.assertEqual(command[7], "")
        schema = json.loads(command[command.index("--json-schema") + 1])
        self.assertEqual(schema["properties"]["model"]["enum"], ["haiku", "sonnet", "opus"])
        self.assertEqual(schema["properties"]["effort"]["enum"], ["low", "medium", "high", "xhigh", "max"])
        self.assertEqual(schema["required"], ["model", "effort", "reason"])

    def test_prompt_lists_choices(self) -> None:
        router, _ = self.router()
        prompt = router.build_prompt("Mehr {models} Kaffee")
        self.assertIn("haiku, sonnet, opus", prompt)
        self.assertIn("low, medium, high, xhigh, max", prompt)
        self.assertTrue(prompt.endswith("Mehr {models} Kaffee"))

    def test_successful_route(self) -> None:
        router, runner = self.router(Script([result_line(GOOD)]))
        outcome = router.route("Feedback", self.lines.append)
        self.assertFalse(outcome.cancelled)
        self.assertEqual(outcome.route, Route("sonnet", "medium", "Klar umrissen."))
        call = runner.calls[0]
        self.assertEqual(call.stdin_text, router.build_prompt("Feedback"))
        self.assertEqual(call.timeout, self.config.router_timeout)
        self.assertEqual(self.lines[-1], "Route: sonnet/medium – Klar umrissen.")

    def test_result_text_and_line_fallbacks(self) -> None:
        router, _ = self.router()
        as_text = result_line(result=json.dumps(GOOD))
        self.assertEqual(router.parse([as_text]).model, "sonnet")
        pretty = json.dumps(json.loads(result_line(GOOD)), indent=2).splitlines()
        self.assertEqual(router.parse(pretty).effort, "medium")
        self.assertEqual(router.parse(["noise", result_line(GOOD), "[1]"]).model, "sonnet")

    def test_reason_is_trimmed_or_dropped(self) -> None:
        router, _ = self.router()
        long = router.parse([result_line({**GOOD, "reason": "x" * 900})])
        self.assertEqual(len(long.reason), MAX_REASON_LENGTH)
        self.assertIsNone(router.parse([result_line({**GOOD, "reason": 5})]).reason)
        self.assertIsNone(router.parse([result_line({**GOOD, "reason": "  "})]).reason)

    def test_invalid_outputs_are_rejected(self) -> None:
        router, _ = self.router()
        for lines in (
            [],
            ["not json"],
            [json.dumps({"type": "assistant"})],
            [result_line(GOOD, is_error=True)],
            [result_line({**GOOD, "model": "gpt"})],
            [result_line({**GOOD, "effort": "extreme"})],
            [result_line(result="kein json")],
            [result_line(result="[1]")],
            [result_line(result=7)],
        ):
            with self.subTest(lines=lines):
                self.assertIsNone(router.parse(lines))

    def test_failures_use_fallback(self) -> None:
        for script in (
            Script(["garbage"]),
            Script([result_line(GOOD)], CommandResult(1)),
            Script([], CommandResult(None, timed_out=True)),
        ):
            with self.subTest(result=script.result):
                self.lines.clear()
                router, _ = self.router(script)
                outcome = router.route("x", self.lines.append)
                self.assertEqual(outcome.route, Route("opus", "high", fallback=True))
                self.assertTrue(any("fallback" in line for line in self.lines))
                self.assertEqual(self.lines[-1], "Route: opus/high")

    def test_cancelled(self) -> None:
        router, _ = self.router(Script([result_line(GOOD)], CommandResult(0, cancelled=True)))
        outcome = router.route("x", self.lines.append)
        self.assertTrue(outcome.cancelled)

    def test_custom_choices(self) -> None:
        self.config = replace(self.config, model_choices=("fable",), fallback_model="fable")
        router, _ = self.router()
        self.assertEqual(router.fallback.model, "fable")
        self.assertIsNone(router.parse([result_line(GOOD)]))


if __name__ == "__main__":
    unittest.main()
