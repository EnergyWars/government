import json
import threading
import unittest
from unittest import mock

from feedback_server.agent import AgentStep
from feedback_server.builder import ApkBuilder
from feedback_server.process import CommandResult
from feedback_server.router import ModelRouter
from feedback_server.store import JobKind, JobStatus, JobStore
from feedback_server.worker import Worker, read_log_tail, strip_ansi

from tests.helpers import FakeRunner, Script, TempDirCase, make_config, write_apk

RESULT = json.dumps({"type": "result", "subtype": "success", "result": "ok", "session_id": "s1"})
CHOICE = json.dumps({"type": "result", "subtype": "success",
                     "structured_output": {"model": "sonnet", "effort": "medium", "reason": "mittel"}})


def routed() -> Script:
    return Script([CHOICE])


class ReadLogTailTest(TempDirCase, unittest.TestCase):
    def test_tail(self) -> None:
        path = self.make_temp() / "log"
        self.assertEqual(read_log_tail(path), "")
        path.write_text("first line\nsecond\nthird\n", encoding="utf-8")
        self.assertEqual(read_log_tail(path), "first line\nsecond\nthird\n")
        self.assertEqual(read_log_tail(path, max_bytes=10), "third\n")

    def test_strip_ansi(self) -> None:
        self.assertEqual(strip_ansi("\x1b[90m\x1b[1mexport\x1b[22m | ok\x1b[39m\x1b[0m"), "export | ok")
        self.assertEqual(strip_ansi("plain"), "plain")


class WorkerTest(TempDirCase, unittest.TestCase):
    def setUp(self) -> None:
        self.config = make_config(self.make_temp(), keep_apks=1)
        self.store = JobStore(":memory:")
        self.addCleanup(self.store.close)

    def worker(self, *scripts: Script) -> tuple[Worker, FakeRunner]:
        runner = FakeRunner(scripts)
        worker = Worker(
            self.store,
            ModelRouter(self.config, runner),
            AgentStep(self.config, runner),
            ApkBuilder(self.config, runner),
            runner,
            self.config.log_dir,
        )
        return worker, runner

    def build_scripts(self) -> list[Script]:
        return [Script(["imported"]), Script(action=lambda: write_apk(self.config))]

    def test_idle_returns_false(self) -> None:
        worker, _ = self.worker()
        self.assertFalse(worker.process_next())
        self.assertIsNone(worker.current_job_id)

    def test_feedback_job_runs_agent_then_build(self) -> None:
        job = self.store.create(JobKind.FEEDBACK, "Bitte blauer")
        worker, runner = self.worker(routed(), Script([RESULT, "\x1b[92mcolored\x1b[0m"]), *self.build_scripts())
        self.assertTrue(worker.process_next())
        done = self.store.get(job.id)
        self.assertEqual(done.status, JobStatus.DONE)
        self.assertEqual(done.session_id, "s1")
        self.assertEqual(done.summary, "ok")
        self.assertEqual(done.apk_file, f"idle-germany-{job.id}.apk")
        self.assertEqual((done.model, done.effort, done.route_reason), ("sonnet", "medium", "mittel"))
        self.assertEqual(len(runner.calls), 4)
        agent_args = runner.calls[1].args
        self.assertEqual(agent_args[2:6], ["--model", "sonnet", "--effort", "medium"])
        log = worker.log_path(job.id).read_text(encoding="utf-8")
        self.assertIn("✔ ok", log)
        self.assertIn("imported", log)
        self.assertIn("\ncolored\n", log)

    def test_resume_uses_latest_session(self) -> None:
        previous = self.store.create(JobKind.FEEDBACK, "a")
        self.store.record_agent(previous.id, "old-session", None)
        self.store.finish(previous.id, JobStatus.DONE)
        self.store.create(JobKind.FEEDBACK, "b", resume=True)
        worker, runner = self.worker(routed(), Script([RESULT]), *self.build_scripts())
        worker.process_next()
        args = runner.calls[1].args
        self.assertEqual(args[args.index("--resume") + 1], "old-session")

    def test_build_job_skips_agent_and_prunes(self) -> None:
        older = self.store.create(JobKind.BUILD)
        self.store.record_apk(older.id, "old.apk")
        job = self.store.create(JobKind.BUILD)
        self.store.cancel_queued(older.id)
        worker, runner = self.worker(*self.build_scripts())
        worker.process_next()
        self.assertEqual(self.store.get(job.id).status, JobStatus.DONE)
        self.assertIsNone(self.store.get(older.id).apk_file)
        self.assertEqual(runner.calls[0].args[-1], "--import")

    def test_agent_failure_and_cancel(self) -> None:
        cases = [
            (Script(["garbage"]), JobStatus.FAILED, "agent_failed"),
            (Script([RESULT], CommandResult(0, cancelled=True)), JobStatus.CANCELLED, "cancelled"),
        ]
        for script, status, error in cases:
            with self.subTest(error=error):
                job = self.store.create(JobKind.FEEDBACK, "x")
                worker, runner = self.worker(routed(), script)
                worker.process_next()
                finished = self.store.get(job.id)
                self.assertEqual((finished.status, finished.error), (status, error))
                self.assertEqual(len(runner.calls), 2)

    def test_build_failure_and_cancel(self) -> None:
        cases = [
            (CommandResult(2), JobStatus.FAILED, "build_failed"),
            (CommandResult(0, cancelled=True), JobStatus.CANCELLED, "cancelled"),
        ]
        for result, status, error in cases:
            with self.subTest(error=error):
                job = self.store.create(JobKind.BUILD)
                worker, _ = self.worker(Script(result=result))
                worker.process_next()
                finished = self.store.get(job.id)
                self.assertEqual((finished.status, finished.error), (status, error))

    def test_cancel_between_agent_and_build(self) -> None:
        job = self.store.create(JobKind.FEEDBACK, "x")
        holder: dict[str, Worker] = {}
        worker, runner = self.worker(routed(), Script([RESULT], action=lambda: holder["w"].cancel(job.id)))
        holder["w"] = worker
        worker.process_next()
        self.assertEqual(self.store.get(job.id).status, JobStatus.CANCELLED)
        self.assertEqual(runner.cancelled, 1)
        self.assertEqual(len(runner.calls), 2)

    def test_cancel_during_routing(self) -> None:
        cases = [
            Script([CHOICE], CommandResult(0, cancelled=True)),
            Script([CHOICE], action=lambda: self.holder["w"].cancel(self.holder["job"])),
        ]
        for script in cases:
            with self.subTest(script=script):
                job = self.store.create(JobKind.FEEDBACK, "x")
                worker, runner = self.worker(script)
                self.holder = {"w": worker, "job": job.id}
                worker.process_next()
                finished = self.store.get(job.id)
                self.assertEqual((finished.status, finished.error), (JobStatus.CANCELLED, "cancelled"))
                self.assertIsNone(finished.model)
                self.assertEqual(len(runner.calls), 1)

    def test_routing_failure_uses_fallback_model(self) -> None:
        job = self.store.create(JobKind.FEEDBACK, "x")
        worker, runner = self.worker(Script(["kaputt"]), Script([RESULT]), *self.build_scripts())
        worker.process_next()
        done = self.store.get(job.id)
        self.assertEqual((done.status, done.model, done.effort), (JobStatus.DONE, "opus", "high"))
        self.assertIsNone(done.route_reason)
        self.assertEqual(runner.calls[1].args[2:6], ["--model", "opus", "--effort", "high"])

    def test_cancel_queued_and_unknown(self) -> None:
        job = self.store.create(JobKind.BUILD)
        worker, runner = self.worker()
        self.assertTrue(worker.cancel(job.id))
        self.assertEqual(self.store.get(job.id).status, JobStatus.CANCELLED)
        self.assertFalse(worker.cancel(job.id))
        self.assertEqual(runner.cancelled, 0)

    def test_crash_marks_job_failed(self) -> None:
        job = self.store.create(JobKind.BUILD)
        worker, _ = self.worker()
        with mock.patch.object(ApkBuilder, "run", side_effect=RuntimeError("boom")), \
                self.assertLogs("feedback_server.worker", "ERROR"):
            worker.process_next()
        self.assertEqual(self.store.get(job.id).error, "internal_error")
        self.assertIn("RuntimeError: boom", worker.log_path(job.id).read_text(encoding="utf-8"))

    def test_run_forever_processes_until_stopped(self) -> None:
        worker, _ = self.worker(*self.build_scripts())
        thread = threading.Thread(target=worker.run_forever)
        thread.start()
        job = self.store.create(JobKind.BUILD)
        worker.notify()
        for _ in range(200):
            if self.store.get(job.id).status is JobStatus.DONE:
                break
            threading.Event().wait(0.02)
        worker.stop()
        thread.join(5)
        self.assertFalse(thread.is_alive())
        self.assertEqual(self.store.get(job.id).status, JobStatus.DONE)
        self.store.create(JobKind.BUILD)
        self.assertFalse(worker.process_next())

    def test_stop_cancels_current_job(self) -> None:
        job = self.store.create(JobKind.FEEDBACK, "x")
        holder: dict[str, Worker] = {}
        worker, runner = self.worker(
            routed(), Script([RESULT], CommandResult(0, cancelled=True), action=lambda: holder["w"].stop())
        )
        holder["w"] = worker
        worker.process_next()
        self.assertEqual(runner.cancelled, 1)
        self.assertEqual(self.store.get(job.id).status, JobStatus.CANCELLED)


if __name__ == "__main__":
    unittest.main()
