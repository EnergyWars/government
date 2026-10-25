from __future__ import annotations

import hashlib
import hmac
import threading
import time
from collections import deque
from collections.abc import Callable

_SESSION_KEY_PREFIX = b"feedback-session:"


class Authenticator:
    def __init__(
        self, token: str, session_seconds: int, clock: Callable[[], float] = time.time
    ) -> None:
        self._token = token.encode("utf-8")
        self._key = hashlib.sha256(_SESSION_KEY_PREFIX + self._token).digest()
        self._session_seconds = session_seconds
        self._clock = clock

    @property
    def session_seconds(self) -> int:
        return self._session_seconds

    def check_token(self, candidate: str) -> bool:
        return hmac.compare_digest(candidate.encode("utf-8"), self._token)

    def issue_session(self) -> str:
        expires = int(self._clock()) + self._session_seconds
        return f"{expires}.{self._sign(expires)}"

    def verify_session(self, value: str | None) -> bool:
        if not value:
            return False
        expires_text, _, signature = value.partition(".")
        if not (expires_text.isascii() and expires_text.isdigit()) or not signature:
            return False
        expires = int(expires_text)
        if not hmac.compare_digest(signature, self._sign(expires)):
            return False
        return expires > self._clock()

    def _sign(self, expires: int) -> str:
        return hmac.new(self._key, str(expires).encode("ascii"), hashlib.sha256).hexdigest()


class LoginThrottle:
    def __init__(
        self,
        max_failures: int = 5,
        window_seconds: float = 900.0,
        clock: Callable[[], float] = time.time,
    ) -> None:
        self._max_failures = max_failures
        self._window = window_seconds
        self._clock = clock
        self._failures: dict[str, deque[float]] = {}
        self._lock = threading.Lock()

    def is_blocked(self, client: str) -> bool:
        with self._lock:
            return len(self._recent(client)) >= self._max_failures

    def record_failure(self, client: str) -> None:
        with self._lock:
            self._recent(client).append(self._clock())

    def reset(self, client: str) -> None:
        with self._lock:
            self._failures.pop(client, None)

    def _recent(self, client: str) -> deque[float]:
        attempts = self._failures.setdefault(client, deque())
        limit = self._clock() - self._window
        while attempts and attempts[0] <= limit:
            attempts.popleft()
        return attempts
