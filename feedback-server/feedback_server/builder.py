from __future__ import annotations

import shlex
import shutil
import time
from collections.abc import Callable
from dataclasses import dataclass
from pathlib import Path

from .config import Config
from .process import CommandRunner, LineSink
from .store import JobStore

_MTIME_TOLERANCE = 1.0


@dataclass(frozen=True, slots=True)
class BuildOutcome:
    success: bool
    apk_file: str | None = None
    error: str | None = None
    cancelled: bool = False


class ApkBuilder:
    def __init__(
        self, config: Config, runner: CommandRunner, clock: Callable[[], float] = time.time
    ) -> None:
        self._config = config
        self._runner = runner
        self._clock = clock

    @property
    def source_apk(self) -> Path:
        return self._config.project_dir / self._config.apk_path

    def commands(self) -> list[list[str]]:
        base = [self._config.godot_bin, "--headless", "--path", str(self._config.project_dir)]
        return [
            [*base, "--import"],
            [*base, "--export-debug", self._config.export_preset, str(self.source_apk)],
        ]

    def apk_file_name(self, job_id: int) -> str:
        return f"{self._config.apk_name}-{job_id}.apk"

    def run(self, job_id: int, log: LineSink) -> BuildOutcome:
        started = self._clock()
        for command in self.commands():
            log(f"$ {shlex.join(command)}")
            result = self._runner.run(
                command, cwd=self._config.project_dir, timeout=self._config.build_timeout, on_line=log
            )
            if result.cancelled:
                return BuildOutcome(False, error="cancelled", cancelled=True)
            if result.timed_out:
                return BuildOutcome(False, error="build_timeout")
            if not result.ok:
                return BuildOutcome(False, error="build_failed")
        if not self._fresh_apk_exists(started):
            return BuildOutcome(False, error="apk_missing")
        self._config.apk_dir.mkdir(parents=True, exist_ok=True)
        name = self.apk_file_name(job_id)
        shutil.copy2(self.source_apk, self._config.apk_dir / name)
        log(f"APK: {name}")
        return BuildOutcome(True, apk_file=name)

    def prune(self, store: JobStore) -> None:
        for job in store.apk_jobs()[self._config.keep_apks :]:
            if job.apk_file:
                (self._config.apk_dir / job.apk_file).unlink(missing_ok=True)
            store.clear_apk(job.id)

    def _fresh_apk_exists(self, started: float) -> bool:
        source = self.source_apk
        return source.is_file() and source.stat().st_mtime >= started - _MTIME_TOLERANCE
