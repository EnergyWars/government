from __future__ import annotations

import sqlite3
import threading
import time
from collections.abc import Callable
from dataclasses import dataclass
from enum import StrEnum
from pathlib import Path
from typing import Any


class JobKind(StrEnum):
    FEEDBACK = "feedback"
    BUILD = "build"


class JobStatus(StrEnum):
    QUEUED = "queued"
    ROUTE = "route"
    AGENT = "agent"
    BUILD = "build"
    DONE = "done"
    FAILED = "failed"
    CANCELLED = "cancelled"


ACTIVE_STATUSES = frozenset({JobStatus.ROUTE, JobStatus.AGENT, JobStatus.BUILD})
INTERRUPTED = "interrupted"

MIGRATIONS: tuple[str, ...] = (
    """
    CREATE TABLE jobs (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        kind TEXT NOT NULL,
        status TEXT NOT NULL,
        feedback TEXT NOT NULL DEFAULT '',
        resume INTEGER NOT NULL DEFAULT 0,
        created_at REAL NOT NULL,
        started_at REAL,
        finished_at REAL,
        session_id TEXT,
        summary TEXT,
        error TEXT,
        apk_file TEXT
    );
    CREATE INDEX idx_jobs_status ON jobs(status, id);
    CREATE INDEX idx_jobs_session ON jobs(id) WHERE session_id IS NOT NULL;
    CREATE INDEX idx_jobs_apk ON jobs(id) WHERE apk_file IS NOT NULL;
    """,
    """
    ALTER TABLE jobs ADD COLUMN model TEXT;
    ALTER TABLE jobs ADD COLUMN effort TEXT;
    ALTER TABLE jobs ADD COLUMN route_reason TEXT;
    """,
)

SCHEMA_VERSION = len(MIGRATIONS)

_COLUMNS = (
    "id, kind, status, feedback, resume, created_at, started_at, finished_at, "
    "session_id, summary, error, apk_file, model, effort, route_reason"
)


class SchemaError(RuntimeError):
    pass


@dataclass(frozen=True, slots=True)
class Job:
    id: int
    kind: JobKind
    status: JobStatus
    feedback: str
    resume: bool
    created_at: float
    started_at: float | None
    finished_at: float | None
    session_id: str | None
    summary: str | None
    error: str | None
    apk_file: str | None
    model: str | None
    effort: str | None
    route_reason: str | None

    @classmethod
    def from_row(cls, row: sqlite3.Row) -> Job:
        return cls(
            id=row["id"],
            kind=JobKind(row["kind"]),
            status=JobStatus(row["status"]),
            feedback=row["feedback"],
            resume=bool(row["resume"]),
            created_at=row["created_at"],
            started_at=row["started_at"],
            finished_at=row["finished_at"],
            session_id=row["session_id"],
            summary=row["summary"],
            error=row["error"],
            apk_file=row["apk_file"],
            model=row["model"],
            effort=row["effort"],
            route_reason=row["route_reason"],
        )

    def to_dict(self) -> dict[str, Any]:
        return {
            "id": self.id,
            "kind": self.kind.value,
            "status": self.status.value,
            "feedback": self.feedback,
            "resume": self.resume,
            "created_at": self.created_at,
            "started_at": self.started_at,
            "finished_at": self.finished_at,
            "summary": self.summary,
            "error": self.error,
            "has_apk": self.apk_file is not None,
            "model": self.model,
            "effort": self.effort,
            "route_reason": self.route_reason,
        }


def schema_version(conn: sqlite3.Connection) -> int:
    return conn.execute("PRAGMA user_version").fetchone()[0]


def migrate(conn: sqlite3.Connection, migrations: tuple[str, ...] = MIGRATIONS) -> int:
    current = schema_version(conn)
    if current > len(migrations):
        raise SchemaError(f"Database schema {current} is newer than supported {len(migrations)}")
    for version in range(current, len(migrations)):
        try:
            conn.executescript(
                f"BEGIN;\n{migrations[version]}\nPRAGMA user_version = {version + 1};\nCOMMIT;"
            )
        except sqlite3.Error:
            if conn.in_transaction:
                conn.execute("ROLLBACK")
            raise
    return schema_version(conn)


class JobStore:
    def __init__(self, path: Path | str, clock: Callable[[], float] = time.time) -> None:
        self._conn = sqlite3.connect(str(path), check_same_thread=False, isolation_level=None)
        self._conn.row_factory = sqlite3.Row
        self._lock = threading.Lock()
        self._clock = clock
        with self._lock:
            self._conn.execute("PRAGMA journal_mode=WAL")
            migrate(self._conn)

    def close(self) -> None:
        with self._lock:
            self._conn.close()

    def create(self, kind: JobKind, feedback: str = "", resume: bool = False) -> Job:
        with self._lock:
            cursor = self._conn.execute(
                "INSERT INTO jobs (kind, status, feedback, resume, created_at) VALUES (?, ?, ?, ?, ?)",
                (kind.value, JobStatus.QUEUED.value, feedback, int(resume), self._clock()),
            )
            return self._fetch_one("WHERE id = ?", (cursor.lastrowid,))

    def get(self, job_id: int) -> Job | None:
        with self._lock:
            return self._fetch_one("WHERE id = ?", (job_id,))

    def list_recent(self, limit: int) -> list[Job]:
        with self._lock:
            rows = self._conn.execute(
                f"SELECT {_COLUMNS} FROM jobs ORDER BY id DESC LIMIT ?", (limit,)
            ).fetchall()
        return [Job.from_row(row) for row in rows]

    def next_queued(self) -> Job | None:
        with self._lock:
            return self._fetch_one("WHERE status = ? ORDER BY id LIMIT 1", (JobStatus.QUEUED.value,))

    def start(self, job_id: int, status: JobStatus) -> None:
        self._execute(
            "UPDATE jobs SET status = ?, started_at = COALESCE(started_at, ?) WHERE id = ?",
            (status.value, self._clock(), job_id),
        )

    def set_status(self, job_id: int, status: JobStatus) -> None:
        self._execute("UPDATE jobs SET status = ? WHERE id = ?", (status.value, job_id))

    def finish(self, job_id: int, status: JobStatus, error: str | None = None) -> None:
        self._execute(
            "UPDATE jobs SET status = ?, error = ?, finished_at = ? WHERE id = ?",
            (status.value, error, self._clock(), job_id),
        )

    def record_agent(self, job_id: int, session_id: str | None, summary: str | None) -> None:
        self._execute(
            "UPDATE jobs SET session_id = ?, summary = ? WHERE id = ?", (session_id, summary, job_id)
        )

    def record_route(self, job_id: int, model: str, effort: str, reason: str | None) -> None:
        self._execute(
            "UPDATE jobs SET model = ?, effort = ?, route_reason = ? WHERE id = ?",
            (model, effort, reason, job_id),
        )

    def record_apk(self, job_id: int, apk_file: str) -> None:
        self._execute("UPDATE jobs SET apk_file = ? WHERE id = ?", (apk_file, job_id))

    def clear_apk(self, job_id: int) -> None:
        self._execute("UPDATE jobs SET apk_file = NULL WHERE id = ?", (job_id,))

    def count_queued(self) -> int:
        with self._lock:
            row = self._conn.execute(
                "SELECT COUNT(*) FROM jobs WHERE status = ?", (JobStatus.QUEUED.value,)
            ).fetchone()
        return row[0]

    def latest_session_id(self) -> str | None:
        with self._lock:
            row = self._conn.execute(
                "SELECT session_id FROM jobs WHERE session_id IS NOT NULL ORDER BY id DESC LIMIT 1"
            ).fetchone()
        return row["session_id"] if row else None

    def latest_apk(self) -> Job | None:
        with self._lock:
            return self._fetch_one("WHERE apk_file IS NOT NULL ORDER BY id DESC LIMIT 1", ())

    def apk_jobs(self) -> list[Job]:
        with self._lock:
            rows = self._conn.execute(
                f"SELECT {_COLUMNS} FROM jobs WHERE apk_file IS NOT NULL ORDER BY id DESC"
            ).fetchall()
        return [Job.from_row(row) for row in rows]

    def cancel_queued(self, job_id: int) -> bool:
        with self._lock:
            cursor = self._conn.execute(
                "UPDATE jobs SET status = ?, error = ?, finished_at = ? WHERE id = ? AND status = ?",
                (JobStatus.CANCELLED.value, "cancelled", self._clock(), job_id, JobStatus.QUEUED.value),
            )
        return cursor.rowcount == 1

    def recover_interrupted(self) -> int:
        placeholders = ", ".join("?" for _ in ACTIVE_STATUSES)
        with self._lock:
            cursor = self._conn.execute(
                f"UPDATE jobs SET status = ?, error = ?, finished_at = ? WHERE status IN ({placeholders})",
                (JobStatus.FAILED.value, INTERRUPTED, self._clock(), *sorted(ACTIVE_STATUSES)),
            )
        return cursor.rowcount

    def _execute(self, sql: str, params: tuple[Any, ...]) -> None:
        with self._lock:
            self._conn.execute(sql, params)

    def _fetch_one(self, clause: str, params: tuple[Any, ...]) -> Job | None:
        row = self._conn.execute(f"SELECT {_COLUMNS} FROM jobs {clause}", params).fetchone()
        return Job.from_row(row) if row else None
