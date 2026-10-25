import json
import unittest
from pathlib import Path

from feedback_server.config import (
    DEFAULT_PROMPT,
    ConfigError,
    default_allowed_tools,
    default_godot_bin,
    load_config,
)

from tests.helpers import TOKEN, TempDirCase


class LoadConfigTest(TempDirCase, unittest.TestCase):
    def write(self, data: object) -> Path:
        path = self.make_temp() / "config.json"
        path.write_text(json.dumps(data), encoding="utf-8")
        return path

    def test_token_from_env_and_defaults(self) -> None:
        config = load_config(None, {"FEEDBACK_TOKEN": TOKEN})
        self.assertEqual(config.token, TOKEN)
        self.assertEqual(config.port, 8787)
        self.assertEqual(config.godot_bin, default_godot_bin())
        self.assertEqual(config.allowed_tools, default_allowed_tools(default_godot_bin()))
        self.assertEqual(config.prompt_template, DEFAULT_PROMPT)
        self.assertEqual(config.apk_dir, config.data_dir / "apks")
        self.assertEqual(config.log_dir, config.data_dir / "logs")
        self.assertEqual(config.database_path, config.data_dir / "jobs.db")

    def test_file_values_are_converted(self) -> None:
        path = self.write(
            {
                "token": TOKEN,
                "project_dir": "~/project",
                "data_dir": "/tmp/data",
                "port": 9000,
                "claude_args": ["--permission-mode", "bypassPermissions"],
                "allowed_tools": ["Read"],
                "secure_cookie": True,
                "godot_bin": "/opt/godot",
            }
        )
        config = load_config(path, {})
        self.assertEqual(config.project_dir, Path("~/project").expanduser())
        self.assertEqual(config.data_dir, Path("/tmp/data"))
        self.assertEqual(config.port, 9000)
        self.assertEqual(config.claude_args, ("--permission-mode", "bypassPermissions"))
        self.assertEqual(config.allowed_tools, ("Read",))
        self.assertTrue(config.secure_cookie)

    def test_router_defaults_and_overrides(self) -> None:
        config = load_config(None, {"FEEDBACK_TOKEN": TOKEN})
        self.assertEqual((config.router_model, config.router_effort), ("sonnet", "low"))
        self.assertEqual((config.fallback_model, config.fallback_effort), ("opus", "high"))
        custom = load_config(
            self.write({"token": TOKEN, "model_choices": ["sonnet", "fable"], "fallback_model": "fable"}), {}
        )
        self.assertEqual(custom.model_choices, ("sonnet", "fable"))

    def test_default_tools_use_configured_godot(self) -> None:
        config = load_config(self.write({"token": TOKEN, "godot_bin": "/opt/godot"}), {})
        self.assertIn("Bash(/opt/godot:*)", config.allowed_tools)

    def test_binaries_expand_home(self) -> None:
        config = load_config(self.write({"token": TOKEN, "claude_bin": "~/.local/bin/claude"}), {})
        self.assertEqual(config.claude_bin, str(Path.home() / ".local/bin/claude"))

    def test_short_password_is_allowed(self) -> None:
        self.assertEqual(load_config(None, {"FEEDBACK_TOKEN": "123"}).token, "123")

    def test_env_token_overrides_file(self) -> None:
        other = "x" * 20
        config = load_config(self.write({"token": TOKEN}), {"FEEDBACK_TOKEN": other})
        self.assertEqual(config.token, other)

    def test_rejections(self) -> None:
        cases = [
            {"token": TOKEN, "unknown": 1},
            {"token": "ab"},
            {"token": TOKEN, "port": 70000},
            {"token": TOKEN, "port": True},
            {"token": TOKEN, "port": "80"},
            {"token": TOKEN, "keep_apks": 0},
            {"token": TOKEN, "claude_args": "--x"},
            {"token": TOKEN, "claude_args": [1]},
            {"token": TOKEN, "secure_cookie": "yes"},
            {"token": TOKEN, "project_dir": 5},
            {"token": TOKEN, "prompt_template": "no placeholder"},
            {"token": TOKEN, "apk_path": "/abs/app.apk"},
            {"token": TOKEN, "apk_path": "../app.apk"},
            {"token": TOKEN, "router_prompt": "ohne"},
            {"token": TOKEN, "router_timeout": 0},
            {"token": TOKEN, "model_choices": []},
            {"token": TOKEN, "effort_choices": []},
            {"token": TOKEN, "fallback_model": "gpt"},
            {"token": TOKEN, "fallback_effort": "extreme"},
            {"token": TOKEN, "claude_args": ["--model", "opus"]},
            {"token": TOKEN, "claude_args": ["--effort=high"]},
            {"token": 123456789012345678},
            {},
        ]
        for data in cases:
            with self.subTest(data=data), self.assertRaises(ConfigError):
                load_config(self.write(data), {})

    def test_invalid_files(self) -> None:
        directory = self.make_temp()
        broken = directory / "broken.json"
        broken.write_text("{", encoding="utf-8")
        for path in (broken, directory / "missing.json", self.write([1, 2])):
            with self.subTest(path=path), self.assertRaises(ConfigError):
                load_config(path, {})


if __name__ == "__main__":
    unittest.main()
