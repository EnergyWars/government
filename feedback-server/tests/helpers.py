from __future__ import annotations

import os
import tempfile
from collections.abc import Callable, Sequence
from dataclasses import dataclass, field, replace
from pathlib import Path

from feedback_server.config import Config
from feedback_server.process import CommandResult, LineSink

TOKEN = "test-token-0123456789abcdef"


def make_config(root: Path, **overrides: object) -> Config:
    project = root / "project"
    project.mkdir(exist_ok=True)
    base = Config(
        token=TOKEN,
        project_dir=project,
        data_dir=root / "data",
        host="127.0.0.1",
        port=0,
        claude_bin="claude",
        allowed_tools=("Read", "Edit"),
        godot_bin="godot",
    )
    return replace(base, **overrides)


class TempDirCase:
    def make_temp(self) -> Path:
        directory = tempfile.TemporaryDirectory()
        self.addCleanup(directory.cleanup)
        return Path(directory.name)


@dataclass
class Call:
    args: list[str]
    cwd: Path
    timeout: float
    stdin_text: str | None


@dataclass
class Script:
    lines: Sequence[str] = ()
    result: CommandResult = field(default_factory=lambda: CommandResult(0))
    action: Callable[[], None] | None = None


class FakeRunner:
    def __init__(self, scripts: Sequence[Script] = ()) -> None:
        self.scripts = list(scripts)
        self.calls: list[Call] = []
        self.cancelled = 0

    def run(
        self,
        args: Sequence[str],
        cwd: Path,
        timeout: float,
        on_line: LineSink,
        stdin_text: str | None = None,
    ) -> CommandResult:
        self.calls.append(Call(list(args), cwd, timeout, stdin_text))
        script = self.scripts.pop(0) if self.scripts else Script()
        if script.action is not None:
            script.action()
        for line in script.lines:
            on_line(line)
        return script.result

    def cancel(self) -> None:
        self.cancelled += 1


def write_apk(config: Config, mtime: float | None = None) -> Path:
    path = config.project_dir / config.apk_path
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(b"apk-bytes")
    if mtime is not None:
        os.utime(path, (mtime, mtime))
    return path
