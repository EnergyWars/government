import json
import unittest

from feedback_server.auth import Authenticator, LoginThrottle
from feedback_server.i18n import Translator, parse_accept_language
from feedback_server.server import PACKAGE_DIR

from tests.helpers import TOKEN, TempDirCase


class Clock:
    def __init__(self, now: float = 1000.0) -> None:
        self.now = now

    def __call__(self) -> float:
        return self.now


class AuthenticatorTest(unittest.TestCase):
    def setUp(self) -> None:
        self.clock = Clock()
        self.auth = Authenticator(TOKEN, 60, self.clock)

    def test_token_check(self) -> None:
        self.assertTrue(self.auth.check_token(TOKEN))
        self.assertFalse(self.auth.check_token(TOKEN + "x"))
        self.assertFalse(self.auth.check_token("ü"))
        self.assertEqual(self.auth.session_seconds, 60)

    def test_session_roundtrip_and_expiry(self) -> None:
        session = self.auth.issue_session()
        self.assertTrue(self.auth.verify_session(session))
        self.clock.now += 61
        self.assertFalse(self.auth.verify_session(session))

    def test_tampered_sessions(self) -> None:
        session = self.auth.issue_session()
        expires, _, signature = session.partition(".")
        other = Authenticator("another-token-0123456789", 60, self.clock).issue_session()
        for value in (None, "", "abc", f"{expires}.", f"{int(expires) + 999}.{signature}",
                      f"²³.{signature}", f"-5.{signature}", other):
            with self.subTest(value=value):
                self.assertFalse(self.auth.verify_session(value))


class LoginThrottleTest(unittest.TestCase):
    def test_blocks_after_failures_until_window_passes(self) -> None:
        clock = Clock()
        throttle = LoginThrottle(max_failures=2, window_seconds=10, clock=clock)
        throttle.record_failure("a")
        self.assertFalse(throttle.is_blocked("a"))
        throttle.record_failure("a")
        self.assertTrue(throttle.is_blocked("a"))
        self.assertFalse(throttle.is_blocked("b"))
        clock.now += 11
        self.assertFalse(throttle.is_blocked("a"))
        throttle.record_failure("a")
        throttle.record_failure("a")
        throttle.reset("a")
        self.assertFalse(throttle.is_blocked("a"))


class AcceptLanguageTest(unittest.TestCase):
    def test_parsing(self) -> None:
        self.assertEqual(parse_accept_language(None), [])
        self.assertEqual(parse_accept_language("de-DE,de;q=0.9,en;q=0.8"), ["de", "de", "en"])
        self.assertEqual(parse_accept_language("en;q=0.5, fr, *;q=0.1"), ["fr", "en"])
        self.assertEqual(parse_accept_language("de;q=0, en;q=abc, it; level=1"), ["it"])
        self.assertEqual(parse_accept_language(" , ;q=1"), [])


class TranslatorTest(TempDirCase, unittest.TestCase):
    def test_bundled_catalogs_have_same_keys(self) -> None:
        directory = PACKAGE_DIR / "i18n"
        de = json.loads((directory / "de.json").read_text(encoding="utf-8"))
        en = json.loads((directory / "en.json").read_text(encoding="utf-8"))
        self.assertEqual(set(de), set(en))
        self.assertTrue(all(isinstance(value, str) and value for value in de.values()))

    def test_pick_and_fallback(self) -> None:
        directory = self.make_temp()
        (directory / "en.json").write_text('{"a": "A", "b": "B"}', encoding="utf-8")
        (directory / "de.json").write_text('{"a": "Ä"}', encoding="utf-8")
        translator = Translator(directory)
        self.assertEqual(translator.languages, ["de", "en"])
        self.assertEqual(translator.pick("de-AT"), "de")
        self.assertEqual(translator.pick("fr, en;q=0.5"), "en")
        self.assertEqual(translator.pick("fr"), "en")
        self.assertEqual(translator.strings("de"), {"a": "Ä", "b": "B"})
        self.assertEqual(translator.strings("xx"), {"a": "A", "b": "B"})

    def test_missing_fallback(self) -> None:
        with self.assertRaises(ValueError):
            Translator(self.make_temp())


if __name__ == "__main__":
    unittest.main()
