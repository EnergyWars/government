import tempfile
import unittest
from pathlib import Path

from upgrade_editor import texts

CSV = 'keys,en,de\nA,Hello,Hallo\nB,"One, two","Eins, zwei"\n'


class TextsTest(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory()
        self.path = Path(self.directory.name) / "translations.csv"
        self.path.write_text(CSV, encoding="utf-8")

    def tearDown(self):
        self.directory.cleanup()

    def test_no_overrides_keep_the_file_identical(self):
        self.assertEqual(texts.apply_overrides(self.path, {}), 0)
        self.assertEqual(self.path.read_text(encoding="utf-8"), CSV)

    def test_existing_key_is_updated(self):
        self.assertEqual(texts.apply_overrides(self.path, {"A": {"de": "Servus"}}), 1)
        self.assertIn("A,Hello,Servus\n", self.path.read_text(encoding="utf-8"))

    def test_unchanged_text_is_not_counted(self):
        self.assertEqual(texts.apply_overrides(self.path, {"A": {"de": "Hallo", "en": "Hello"}}), 0)

    def test_quoting_is_preserved(self):
        texts.apply_overrides(self.path, {"B": {"en": "Three, four"}})
        self.assertIn('B,"Three, four","Eins, zwei"\n', self.path.read_text(encoding="utf-8"))

    def test_new_key_is_appended(self):
        self.assertEqual(texts.apply_overrides(self.path, {"C": {"de": "Neu", "en": "New"}}), 1)
        self.assertTrue(self.path.read_text(encoding="utf-8").endswith("C,New,Neu\n"))

    def test_new_key_with_one_language_falls_back(self):
        texts.apply_overrides(self.path, {"C": {"en": "Only"}})
        self.assertTrue(self.path.read_text(encoding="utf-8").endswith("C,Only,Only\n"))

    def test_short_rows_are_extended(self):
        self.path.write_text("keys,en,de\nA,Hello\n", encoding="utf-8")
        texts.apply_overrides(self.path, {"A": {"de": "Hallo"}})
        self.assertIn("A,Hello,Hallo\n", self.path.read_text(encoding="utf-8"))


if __name__ == "__main__":
    unittest.main()
