import time
import unittest

from feedback_server.builder import ApkBuilder
from feedback_server.process import CommandResult
from feedback_server.store import JobKind, JobStore

from tests.helpers import FakeRunner, Script, TempDirCase, make_config, write_apk


class ApkBuilderTest(TempDirCase, unittest.TestCase):
    def setUp(self) -> None:
        self.config = make_config(self.make_temp(), keep_apks=2)
        self.lines: list[str] = []

    def builder(self, *scripts: Script) -> tuple[ApkBuilder, FakeRunner]:
        runner = FakeRunner(scripts)
        return ApkBuilder(self.config, runner), runner

    def test_commands(self) -> None:
        builder, _ = self.builder()
        project = str(self.config.project_dir)
        self.assertEqual(
            builder.commands(),
            [
                ["godot", "--headless", "--path", project, "--import"],
                ["godot", "--headless", "--path", project, "--export-debug", "Android",
                 str(self.config.project_dir / "build/idle-germany.apk")],
            ],
        )
        self.assertEqual(builder.apk_file_name(7), "idle-germany-7.apk")

    def test_success_copies_apk(self) -> None:
        builder, runner = self.builder(Script(), Script(action=lambda: write_apk(self.config)))
        outcome = builder.run(5, self.lines.append)
        self.assertTrue(outcome.success)
        self.assertEqual(outcome.apk_file, "idle-germany-5.apk")
        self.assertEqual((self.config.apk_dir / "idle-germany-5.apk").read_bytes(), b"apk-bytes")
        self.assertEqual(len(runner.calls), 2)
        self.assertTrue(self.lines[0].startswith("$ godot"))
        self.assertEqual(runner.calls[0].timeout, self.config.build_timeout)

    def test_stale_or_missing_apk(self) -> None:
        builder, _ = self.builder()
        self.assertEqual(builder.run(1, self.lines.append).error, "apk_missing")
        write_apk(self.config, mtime=time.time() - 3600)
        builder, _ = self.builder()
        self.assertEqual(builder.run(1, self.lines.append).error, "apk_missing")

    def test_step_failures_stop_build(self) -> None:
        cases = [
            (CommandResult(0, cancelled=True), "cancelled", True),
            (CommandResult(None, timed_out=True), "build_timeout", False),
            (CommandResult(1), "build_failed", False),
        ]
        for result, error, cancelled in cases:
            with self.subTest(error=error):
                builder, runner = self.builder(Script(result=result))
                outcome = builder.run(1, self.lines.append)
                self.assertFalse(outcome.success)
                self.assertEqual(outcome.error, error)
                self.assertEqual(outcome.cancelled, cancelled)
                self.assertEqual(len(runner.calls), 1)

    def test_prune_keeps_newest(self) -> None:
        store = JobStore(":memory:")
        self.addCleanup(store.close)
        self.config.apk_dir.mkdir(parents=True)
        builder, _ = self.builder()
        ids = []
        for _ in range(4):
            job = store.create(JobKind.BUILD)
            name = builder.apk_file_name(job.id)
            (self.config.apk_dir / name).write_bytes(b"x")
            store.record_apk(job.id, name)
            ids.append(job.id)
        (self.config.apk_dir / builder.apk_file_name(ids[0])).unlink()
        builder.prune(store)
        self.assertEqual([job.id for job in store.apk_jobs()], ids[:1:-1])
        self.assertEqual(sorted(path.name for path in self.config.apk_dir.iterdir()),
                         sorted(builder.apk_file_name(i) for i in ids[2:]))


if __name__ == "__main__":
    unittest.main()
