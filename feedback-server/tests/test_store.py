import sqlite3
import unittest

from feedback_server.store import (
    INTERRUPTED,
    MIGRATIONS,
    SCHEMA_VERSION,
    JobKind,
    JobStatus,
    JobStore,
    SchemaError,
    migrate,
    schema_version,
)

from tests.helpers import TempDirCase


class Clock:
    def __init__(self) -> None:
        self.now = 1000.0

    def __call__(self) -> float:
        self.now += 1
        return self.now


class MigrationTest(TempDirCase, unittest.TestCase):
    def connect(self) -> sqlite3.Connection:
        conn = sqlite3.connect(":memory:", isolation_level=None)
        self.addCleanup(conn.close)
        return conn

    def test_fresh_database_gets_current_schema(self) -> None:
        conn = self.connect()
        self.assertEqual(migrate(conn), SCHEMA_VERSION)
        columns = {row[1] for row in conn.execute("PRAGMA table_info(jobs)")}
        self.assertEqual(
            columns,
            {"id", "kind", "status", "feedback", "resume", "created_at", "started_at",
             "finished_at", "session_id", "summary", "error", "apk_file", "model", "effort",
             "route_reason"},
        )
        indexes = {row[1] for row in conn.execute("PRAGMA index_list(jobs)")}
        self.assertTrue({"idx_jobs_status", "idx_jobs_session", "idx_jobs_apk"} <= indexes)

    def test_v1_to_v2_keeps_jobs_and_adds_route_columns(self) -> None:
        path = self.make_temp() / "jobs.db"
        conn = sqlite3.connect(str(path), isolation_level=None)
        self.assertEqual(migrate(conn, MIGRATIONS[:1]), 1)
        conn.execute(
            "INSERT INTO jobs (kind, status, feedback, resume, created_at, session_id, apk_file) "
            "VALUES ('feedback', 'done', 'alt', 1, 5.0, 's-old', 'a.apk')"
        )
        conn.close()
        store = JobStore(path)
        self.addCleanup(store.close)
        job = store.get(1)
        self.assertEqual((job.feedback, job.status, job.resume, job.apk_file), ("alt", JobStatus.DONE, True, "a.apk"))
        self.assertEqual((job.model, job.effort, job.route_reason), (None, None, None))
        self.assertEqual(store.latest_session_id(), "s-old")
        store.record_route(1, "opus", "high", "komplex")
        self.assertEqual(store.get(1).to_dict()["model"], "opus")

    def test_migration_is_idempotent_and_keeps_data(self) -> None:
        path = self.make_temp() / "jobs.db"
        store = JobStore(path)
        store.create(JobKind.BUILD)
        store.close()
        reopened = JobStore(path)
        self.addCleanup(reopened.close)
        self.assertEqual(len(reopened.list_recent(10)), 1)

    def test_newer_schema_is_rejected(self) -> None:
        conn = self.connect()
        conn.execute(f"PRAGMA user_version = {SCHEMA_VERSION + 1}")
        with self.assertRaises(SchemaError):
            migrate(conn)

    def test_failed_migration_rolls_back(self) -> None:
        conn = self.connect()
        broken = (*MIGRATIONS, "CREATE TABLE extra (id INTEGER); INSERT INTO missing VALUES (1);")
        with self.assertRaises(sqlite3.Error):
            migrate(conn, broken)
        self.assertEqual(schema_version(conn), SCHEMA_VERSION)
        tables = {row[0] for row in conn.execute("SELECT name FROM sqlite_master WHERE type='table'")}
        self.assertNotIn("extra", tables)

    def test_queue_query_uses_index(self) -> None:
        conn = self.connect()
        migrate(conn)
        plan = " ".join(
            str(row[3])
            for row in conn.execute(
                "EXPLAIN QUERY PLAN SELECT id FROM jobs WHERE status = 'queued' ORDER BY id LIMIT 1"
            )
        )
        self.assertIn("idx_jobs_status", plan)


class JobStoreTest(unittest.TestCase):
    def setUp(self) -> None:
        self.clock = Clock()
        self.store = JobStore(":memory:", clock=self.clock)
        self.addCleanup(self.store.close)

    def test_create_and_get(self) -> None:
        job = self.store.create(JobKind.FEEDBACK, "Mehr Kaffee", resume=True)
        self.assertEqual(job.status, JobStatus.QUEUED)
        self.assertTrue(job.resume)
        self.assertEqual(self.store.get(job.id), job)
        self.assertIsNone(self.store.get(999))
        data = job.to_dict()
        self.assertEqual(data["kind"], "feedback")
        self.assertFalse(data["has_apk"])
        self.assertNotIn("session_id", data)

    def test_queue_order_and_lifecycle(self) -> None:
        first = self.store.create(JobKind.FEEDBACK, "a")
        second = self.store.create(JobKind.BUILD)
        self.assertEqual(self.store.next_queued().id, first.id)
        self.store.start(first.id, JobStatus.AGENT)
        started = self.store.get(first.id).started_at
        self.store.start(first.id, JobStatus.BUILD)
        self.assertEqual(self.store.get(first.id).started_at, started)
        self.store.set_status(first.id, JobStatus.BUILD)
        self.assertEqual(self.store.next_queued().id, second.id)
        self.store.finish(first.id, JobStatus.FAILED, "build_failed")
        finished = self.store.get(first.id)
        self.assertEqual(finished.error, "build_failed")
        self.assertIsNotNone(finished.finished_at)
        self.assertEqual([job.id for job in self.store.list_recent(1)], [second.id])

    def test_sessions_and_apks(self) -> None:
        self.assertIsNone(self.store.latest_session_id())
        self.assertIsNone(self.store.latest_apk())
        first = self.store.create(JobKind.FEEDBACK, "a")
        second = self.store.create(JobKind.FEEDBACK, "b")
        self.store.record_agent(first.id, "s1", "summary")
        self.store.record_agent(second.id, None, None)
        self.assertEqual(self.store.latest_session_id(), "s1")
        self.store.record_apk(first.id, "a.apk")
        self.store.record_apk(second.id, "b.apk")
        self.assertEqual(self.store.latest_apk().id, second.id)
        self.assertEqual([job.id for job in self.store.apk_jobs()], [second.id, first.id])
        self.store.clear_apk(second.id)
        self.assertEqual(self.store.latest_apk().id, first.id)
        self.assertEqual(self.store.get(first.id).summary, "summary")

    def test_cancel_only_queued(self) -> None:
        job = self.store.create(JobKind.BUILD)
        self.assertTrue(self.store.cancel_queued(job.id))
        self.assertEqual(self.store.get(job.id).status, JobStatus.CANCELLED)
        self.assertFalse(self.store.cancel_queued(job.id))

    def test_recover_interrupted(self) -> None:
        routing = self.store.create(JobKind.FEEDBACK, "r")
        agent = self.store.create(JobKind.FEEDBACK, "a")
        build = self.store.create(JobKind.BUILD)
        queued = self.store.create(JobKind.BUILD)
        self.store.start(routing.id, JobStatus.ROUTE)
        self.store.start(agent.id, JobStatus.AGENT)
        self.store.start(build.id, JobStatus.BUILD)
        self.assertEqual(self.store.recover_interrupted(), 3)
        self.assertEqual(self.store.get(routing.id).status, JobStatus.FAILED)
        self.assertEqual(self.store.get(agent.id).error, INTERRUPTED)
        self.assertEqual(self.store.get(build.id).status, JobStatus.FAILED)
        self.assertEqual(self.store.get(queued.id).status, JobStatus.QUEUED)


if __name__ == "__main__":
    unittest.main()
