from __future__ import annotations

import json
import os
import shutil
from collections.abc import Mapping
from dataclasses import dataclass, fields
from pathlib import Path
from typing import Any

SERVER_DIR = Path(__file__).resolve().parents[1]
MIN_TOKEN_LENGTH = 3
RECOMMENDED_TOKEN_LENGTH = 16
TOKEN_ENV = "FEEDBACK_TOKEN"

DEFAULT_PROMPT = (
    "Folgendes Feedback wurde unterwegs über den Feedback-Server gesendet. "
    "Setze es vollständig um und halte Tests, context.md und FEATURES.md aktuell. "
    "Den Android-Export (APK) übernimmt der Server danach automatisch, führe ihn nicht selbst aus. "
    "Fasse am Ende kurz auf Deutsch zusammen, was du geändert hast.\n\n"
    "Feedback:\n{feedback}"
)

DEFAULT_ROUTER_PROMPT = (
    "Du bist ein Router für Programmieraufträge. Analysiere das folgende Feedback zu einem "
    "Godot-4-Android-Spiel (GDScript) und wähle das günstigste Claude-Modell und den niedrigsten "
    "Effort, mit denen die Aufgabe noch zuverlässig und vollständig umgesetzt wird, inklusive Tests "
    "und Pflege von context.md und FEATURES.md.\n"
    "Modelle aufsteigend nach Fähigkeit und Kosten: {models}.\n"
    "Effort-Stufen aufsteigend: {efforts}.\n"
    "Faustregeln: Texte, Farben oder einzelne Zahlenwerte → kleinstes Modell, niedrigster Effort. "
    "Klar umrissene Änderung an wenigen Dateien → mittleres Modell, mittlerer Effort. "
    "Neue Features, Spielmechanik, Balancing, Architektur, mehrere Systeme oder unklare Anforderungen "
    "→ stärkstes Modell, hoher Effort oder mehr. Im Zweifel eine Stufe höher.\n"
    "Begründe die Wahl in einem kurzen deutschen Satz.\n\n"
    "Feedback:\n{feedback}"
)


class ConfigError(ValueError):
    pass


def default_godot_bin() -> str:
    return str(Path.home() / ".local/opt/godot-4.7.2/Godot_v4.7.2-stable_linux.x86_64")


def default_claude_bin() -> str:
    return shutil.which("claude") or "claude"


def default_allowed_tools(godot_bin: str) -> tuple[str, ...]:
    return (
        "Read",
        "Edit",
        "Write",
        "Glob",
        "Grep",
        "TodoWrite",
        "Bash(git status:*)",
        "Bash(git diff:*)",
        "Bash(git log:*)",
        f"Bash({godot_bin}:*)",
    )


@dataclass(frozen=True, slots=True)
class Config:
    token: str
    project_dir: Path = SERVER_DIR.parent
    data_dir: Path = SERVER_DIR / "data"
    host: str = "0.0.0.0"
    port: int = 8787
    claude_bin: str = "claude"
    claude_args: tuple[str, ...] = ("--permission-mode", "acceptEdits")
    allowed_tools: tuple[str, ...] = ()
    prompt_template: str = DEFAULT_PROMPT
    router_model: str = "sonnet"
    router_effort: str = "low"
    router_timeout: int = 300
    router_prompt: str = DEFAULT_ROUTER_PROMPT
    model_choices: tuple[str, ...] = ("haiku", "sonnet", "opus")
    effort_choices: tuple[str, ...] = ("low", "medium", "high", "xhigh", "max")
    fallback_model: str = "opus"
    fallback_effort: str = "high"
    godot_bin: str = ""
    export_preset: str = "Android"
    apk_path: str = "build/idle-germany.apk"
    apk_name: str = "idle-germany"
    agent_timeout: int = 3600
    build_timeout: int = 1800
    keep_apks: int = 10
    max_feedback_length: int = 20000
    session_days: int = 30
    secure_cookie: bool = False
    trust_forwarded_for: bool = False

    @property
    def apk_dir(self) -> Path:
        return self.data_dir / "apks"

    @property
    def log_dir(self) -> Path:
        return self.data_dir / "logs"

    @property
    def database_path(self) -> Path:
        return self.data_dir / "jobs.db"


_PATH_FIELDS = {"project_dir", "data_dir"}
_BINARY_FIELDS = {"claude_bin", "godot_bin"}
_TUPLE_FIELDS = {"claude_args", "allowed_tools", "model_choices", "effort_choices"}
_INT_FIELDS = {"port", "agent_timeout", "router_timeout", "build_timeout", "keep_apks", "max_feedback_length", "session_days"}
_BOOL_FIELDS = {"secure_cookie", "trust_forwarded_for"}
_KNOWN_FIELDS = {item.name for item in fields(Config)}
_RESERVED_ARGS = {"--model", "--effort"}


def load_config(path: Path | None = None, env: Mapping[str, str] | None = None) -> Config:
    environment = os.environ if env is None else env
    raw = _read_file(path) if path is not None else {}
    unknown = sorted(set(raw) - _KNOWN_FIELDS)
    if unknown:
        raise ConfigError(f"Unknown config keys: {', '.join(unknown)}")
    if token := environment.get(TOKEN_ENV):
        raw["token"] = token
    values = {key: _convert(key, value) for key, value in raw.items()}
    values.setdefault("claude_bin", default_claude_bin())
    values.setdefault("godot_bin", default_godot_bin())
    values.setdefault("allowed_tools", default_allowed_tools(values["godot_bin"]))
    if "token" not in values:
        raise ConfigError(f"Missing password: set {TOKEN_ENV} or 'token' in the config file")
    config = Config(**values)
    _validate(config)
    return config


def _read_file(path: Path) -> dict[str, Any]:
    try:
        raw = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as error:
        raise ConfigError(f"Cannot read config {path}: {error}") from error
    if not isinstance(raw, dict):
        raise ConfigError("Config file must contain a JSON object")
    return raw


def _convert(key: str, value: Any) -> Any:
    if key in _PATH_FIELDS:
        return Path(_expect(key, value, str)).expanduser()
    if key in _BINARY_FIELDS:
        return os.path.expanduser(_expect(key, value, str))
    if key in _TUPLE_FIELDS:
        items = _expect(key, value, list)
        if not all(isinstance(item, str) for item in items):
            raise ConfigError(f"{key} must be a list of strings")
        return tuple(items)
    if key in _BOOL_FIELDS:
        return _expect(key, value, bool)
    if key in _INT_FIELDS:
        if isinstance(value, bool):
            raise ConfigError(f"{key} must be int")
        return _expect(key, value, int)
    return _expect(key, value, str)


def _expect(key: str, value: Any, kind: type) -> Any:
    if not isinstance(value, kind):
        raise ConfigError(f"{key} must be {kind.__name__}")
    return value


def _validate(config: Config) -> None:
    if len(config.token) < MIN_TOKEN_LENGTH:
        raise ConfigError(f"Password must have at least {MIN_TOKEN_LENGTH} characters")
    if not 0 <= config.port <= 65535:
        raise ConfigError("port must be between 0 and 65535")
    positive = ("agent_timeout", "router_timeout", "build_timeout", "keep_apks", "max_feedback_length", "session_days")
    for name in positive:
        if getattr(config, name) <= 0:
            raise ConfigError(f"{name} must be positive")
    for name in ("prompt_template", "router_prompt"):
        if "{feedback}" not in getattr(config, name):
            raise ConfigError(f"{name} must contain {{feedback}}")
    if not config.model_choices or not config.effort_choices:
        raise ConfigError("model_choices and effort_choices must not be empty")
    if config.fallback_model not in config.model_choices:
        raise ConfigError("fallback_model must be one of model_choices")
    if config.fallback_effort not in config.effort_choices:
        raise ConfigError("fallback_effort must be one of effort_choices")
    if _RESERVED_ARGS & {argument.split("=")[0] for argument in config.claude_args}:
        raise ConfigError("claude_args must not contain --model or --effort, they are chosen per job")
    if Path(config.apk_path).is_absolute() or ".." in Path(config.apk_path).parts:
        raise ConfigError("apk_path must be relative to project_dir")
