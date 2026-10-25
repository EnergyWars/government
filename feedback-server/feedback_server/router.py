from __future__ import annotations

import json
from dataclasses import dataclass
from typing import Any

from .config import Config
from .process import CommandRunner, LineSink

MAX_REASON_LENGTH = 500
MAX_LOGGED_OUTPUT = 2000


@dataclass(frozen=True, slots=True)
class Route:
    model: str
    effort: str
    reason: str | None = None
    fallback: bool = False


@dataclass(frozen=True, slots=True)
class RouteOutcome:
    route: Route
    cancelled: bool = False


class ModelRouter:
    def __init__(self, config: Config, runner: CommandRunner) -> None:
        self._config = config
        self._runner = runner

    @property
    def fallback(self) -> Route:
        return Route(self._config.fallback_model, self._config.fallback_effort, fallback=True)

    def schema(self) -> dict[str, Any]:
        return {
            "type": "object",
            "properties": {
                "model": {"type": "string", "enum": list(self._config.model_choices)},
                "effort": {"type": "string", "enum": list(self._config.effort_choices)},
                "reason": {"type": "string"},
            },
            "required": ["model", "effort", "reason"],
            "additionalProperties": False,
        }

    def build_command(self) -> list[str]:
        return [
            self._config.claude_bin,
            "-p",
            "--model",
            self._config.router_model,
            "--effort",
            self._config.router_effort,
            "--tools",
            "",
            "--output-format",
            "json",
            "--json-schema",
            json.dumps(self.schema()),
        ]

    def build_prompt(self, feedback: str) -> str:
        return (
            self._config.router_prompt.replace("{models}", ", ".join(self._config.model_choices))
            .replace("{efforts}", ", ".join(self._config.effort_choices))
            .replace("{feedback}", feedback)
        )

    def route(self, feedback: str, log: LineSink) -> RouteOutcome:
        log(f"Routing with {self._config.router_model}/{self._config.router_effort}")
        lines: list[str] = []
        result = self._runner.run(
            self.build_command(),
            cwd=self._config.project_dir,
            timeout=self._config.router_timeout,
            on_line=lines.append,
            stdin_text=self.build_prompt(feedback),
        )
        if result.cancelled:
            return RouteOutcome(self.fallback, cancelled=True)
        route = self.parse(lines) if result.ok else None
        if route is None:
            output = "\n".join(lines)[-MAX_LOGGED_OUTPUT:]
            log(f"Routing failed (exit {result.returncode}, timeout {result.timed_out}), using fallback")
            if output:
                log(output)
            route = self.fallback
        log(f"Route: {route.model}/{route.effort}" + (f" – {route.reason}" if route.reason else ""))
        return RouteOutcome(route)

    def parse(self, lines: list[str]) -> Route | None:
        for event in _json_objects(lines):
            if event.get("type") != "result" or event.get("is_error"):
                continue
            choice = event.get("structured_output")
            if not isinstance(choice, dict):
                choice = _loads_object(event.get("result"))
            if choice is not None:
                return self._validate(choice)
        return None

    def _validate(self, choice: dict[str, Any]) -> Route | None:
        model, effort, reason = choice.get("model"), choice.get("effort"), choice.get("reason")
        if model not in self._config.model_choices or effort not in self._config.effort_choices:
            return None
        text = reason.strip()[:MAX_REASON_LENGTH] if isinstance(reason, str) else ""
        return Route(model, effort, text or None)


def _loads_object(text: Any) -> dict[str, Any] | None:
    if not isinstance(text, str):
        return None
    try:
        value = json.loads(text)
    except json.JSONDecodeError:
        return None
    return value if isinstance(value, dict) else None


def _json_objects(lines: list[str]) -> list[dict[str, Any]]:
    whole = _loads_object("\n".join(lines))
    if whole is not None:
        return [whole]
    return [event for line in reversed(lines) if (event := _loads_object(line.strip())) is not None]
