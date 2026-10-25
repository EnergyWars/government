from __future__ import annotations

import json
from dataclasses import dataclass
from typing import Any

from .config import Config
from .process import CommandRunner, LineSink
from .router import Route

_DESCRIBED_INPUTS = ("command", "file_path", "pattern", "path", "description")
_MAX_DETAIL = 200


@dataclass(frozen=True, slots=True)
class AgentOutcome:
    success: bool
    session_id: str | None = None
    summary: str | None = None
    error: str | None = None
    cancelled: bool = False


class StreamParser:
    def __init__(self, emit: LineSink) -> None:
        self._emit = emit
        self.session_id: str | None = None
        self.result: str | None = None
        self.is_error = False
        self.finished = False

    def feed(self, line: str) -> None:
        stripped = line.strip()
        if not stripped:
            return
        try:
            event = json.loads(stripped)
        except json.JSONDecodeError:
            self._emit(line)
            return
        if not isinstance(event, dict):
            self._emit(line)
            return
        session_id = event.get("session_id")
        if isinstance(session_id, str) and session_id:
            self.session_id = session_id
        match event.get("type"):
            case "assistant":
                self._assistant(event)
            case "result":
                self._result(event)

    def _assistant(self, event: dict[str, Any]) -> None:
        message = event.get("message")
        content = message.get("content") if isinstance(message, dict) else None
        if not isinstance(content, list):
            return
        for block in content:
            if not isinstance(block, dict):
                continue
            match block.get("type"):
                case "text":
                    text = str(block.get("text", "")).strip()
                    if text:
                        self._emit(f"» {text}")
                case "tool_use":
                    self._emit(f"⚙ {block.get('name', '?')}{_describe(block.get('input'))}")

    def _result(self, event: dict[str, Any]) -> None:
        self.finished = True
        self.is_error = bool(event.get("is_error")) or event.get("subtype") != "success"
        result = event.get("result")
        self.result = result if isinstance(result, str) else None
        if self.result:
            self._emit(f"✔ {self.result}")


def _describe(tool_input: Any) -> str:
    if not isinstance(tool_input, dict):
        return ""
    for key in _DESCRIBED_INPUTS:
        value = tool_input.get(key)
        if isinstance(value, str) and value:
            return f" {value[:_MAX_DETAIL]}"
    return ""


class AgentStep:
    def __init__(self, config: Config, runner: CommandRunner) -> None:
        self._config = config
        self._runner = runner

    def build_command(self, resume_session: str | None, route: Route) -> list[str]:
        command = [
            self._config.claude_bin,
            "-p",
            "--model",
            route.model,
            "--effort",
            route.effort,
            "--output-format",
            "stream-json",
            "--verbose",
        ]
        if resume_session:
            command += ["--resume", resume_session]
        command += self._config.claude_args
        if self._config.allowed_tools:
            command += ["--allowedTools", *self._config.allowed_tools]
        return command

    def build_prompt(self, feedback: str) -> str:
        return self._config.prompt_template.replace("{feedback}", feedback)

    def run(
        self, feedback: str, resume_session: str | None, route: Route, log: LineSink
    ) -> AgentOutcome:
        parser = StreamParser(log)
        result = self._runner.run(
            self.build_command(resume_session, route),
            cwd=self._config.project_dir,
            timeout=self._config.agent_timeout,
            on_line=parser.feed,
            stdin_text=self.build_prompt(feedback),
        )
        if result.cancelled:
            return AgentOutcome(False, parser.session_id, parser.result, "cancelled", cancelled=True)
        if result.timed_out:
            return AgentOutcome(False, parser.session_id, parser.result, "agent_timeout")
        if result.returncode != 0 or not parser.finished or parser.is_error:
            return AgentOutcome(False, parser.session_id, parser.result, "agent_failed")
        return AgentOutcome(True, parser.session_id, parser.result)
