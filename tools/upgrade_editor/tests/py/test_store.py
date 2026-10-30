import json
import tempfile
import unittest
from pathlib import Path

from upgrade_editor import store as store_module
from upgrade_editor.store import DocumentStore, MissingFile, ValidationFailed
from .fixtures import make_document


class StoreTestCase(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory()
        root = Path(self.directory.name)
        self.game_dir = root / "data"
        self.context_dir = root / "context"
        self.csv = root / "translations.csv"
        self.csv.write_text("keys,en,de\nTRACK_COFFEE,Coffee,Kaffee\n", encoding="utf-8")
        store_module.write_json(self.game_dir / "upgrades.json", make_document())
        store_module.write_json(self.context_dir / "app_context.json", {"schema": 1})
        store_module.write_json(self.context_dir / "game_translations.json", {"A": {"de": "a", "en": "a"}})
        self.store = DocumentStore(self.game_dir, self.context_dir, self.csv)

    def tearDown(self):
        self.directory.cleanup()

    def edited_document(self):
        document = make_document()
        document["upgrades"]["briefcase"]["cost"] = 99.0
        return document


class ReadingTest(StoreTestCase):
    def test_original_is_the_source_without_a_copy(self):
        self.assertEqual(self.store.source(), "original")
        self.assertEqual(self.store.load_active(), make_document())

    def test_context_and_translations(self):
        self.assertEqual(self.store.context(), {"schema": 1})
        self.assertEqual(self.store.translations()["A"]["de"], "a")

    def test_missing_file(self):
        with self.assertRaises(MissingFile):
            DocumentStore(self.game_dir / "none", self.context_dir).load_original()


class SavingTest(StoreTestCase):
    def test_save_creates_the_copy_next_to_the_original(self):
        self.store.save_edited(self.edited_document())
        self.assertEqual(self.store.edited_path.parent, self.store.original_path.parent)
        self.assertEqual(self.store.source(), "edited")

    def test_original_stays_untouched(self):
        before = self.store.original_path.read_text(encoding="utf-8")
        self.store.save_edited(self.edited_document())
        self.assertEqual(self.store.original_path.read_text(encoding="utf-8"), before)

    def test_only_the_copy_is_rendered_afterwards(self):
        self.store.save_edited(self.edited_document())
        self.assertEqual(self.store.load_active()["upgrades"]["briefcase"]["cost"], 99.0)
        self.assertEqual(self.store.load_original()["upgrades"]["briefcase"]["cost"], 150.0)

    def test_invalid_document_is_rejected_and_nothing_is_written(self):
        document = self.edited_document()
        document["upgrades"]["briefcase"]["growth"] = 0
        with self.assertRaises(ValidationFailed) as raised:
            self.store.save_edited(document)
        self.assertEqual(raised.exception.errors[0]["code"], "RANGE")
        self.assertFalse(self.store.has_edited())

    def test_saved_document_is_normalised(self):
        document = self.edited_document()
        document["upgrades"]["briefcase"]["cost"] = 99
        saved = self.store.save_edited(document)
        self.assertIsInstance(saved["upgrades"]["briefcase"]["cost"], float)

    def test_no_temp_files_remain(self):
        self.store.save_edited(self.edited_document())
        self.assertEqual([path.name for path in self.game_dir.glob("*.tmp")], [])

    def test_failed_write_cleans_up(self):
        with self.assertRaises(TypeError):
            store_module.write_json(self.game_dir / "broken.json", {"value": object()})
        self.assertEqual(list(self.game_dir.glob("*.tmp")), [])
        self.assertFalse((self.game_dir / "broken.json").exists())

    def test_changes_compare_original_and_copy(self):
        self.store.save_edited(self.edited_document())
        self.assertEqual(self.store.changes()[0]["field"], "cost")

    def test_validate_reports_errors(self):
        self.assertEqual(self.store.validate({}), [{"code": "SCHEMA", "path": "schema", "detail": {"expected": 1}}, {"code": "MISSING_SECTION", "path": "upgrades", "detail": {}}, {"code": "MISSING_SECTION", "path": "menu", "detail": {}}])


class ResetAndPromoteTest(StoreTestCase):
    def test_reset_without_copy_does_nothing(self):
        self.assertIsNone(self.store.reset_edited())

    def test_reset_archives_the_copy(self):
        self.store.save_edited(self.edited_document())
        archived = self.store.reset_edited()
        self.assertTrue(archived.is_file())
        self.assertEqual(self.store.source(), "original")

    def test_promote_requires_a_copy(self):
        with self.assertRaises(MissingFile):
            self.store.promote()

    def test_promote_replaces_the_original_and_archives_both(self):
        self.store.save_edited(self.edited_document())
        summary = self.store.promote()
        self.assertEqual(self.store.load_original()["upgrades"]["briefcase"]["cost"], 99.0)
        self.assertFalse(self.store.has_edited())
        self.assertTrue(Path(summary["archived_original"]).is_file())
        self.assertTrue(Path(summary["archived_edited"]).is_file())
        self.assertEqual(json.loads(Path(summary["archived_original"]).read_text())["upgrades"]["briefcase"]["cost"], 150.0)
        self.assertEqual(summary["changes"][0]["field"], "cost")

    def test_promote_writes_text_overrides_into_the_translations(self):
        document = self.edited_document()
        document["text_overrides"] = {"TRACK_COFFEE": {"de": "Filterkaffee"}}
        self.store.save_edited(document)
        summary = self.store.promote()
        self.assertEqual(summary["texts_written"], 1)
        self.assertIn("TRACK_COFFEE,Coffee,Filterkaffee", self.csv.read_text(encoding="utf-8"))
        self.assertEqual(self.store.load_original()["text_overrides"], {})

    def test_promote_without_translations_file_skips_texts(self):
        store = DocumentStore(self.game_dir, self.context_dir)
        document = self.edited_document()
        document["text_overrides"] = {"TRACK_COFFEE": {"de": "X"}}
        store.save_edited(document)
        self.assertEqual(store.promote()["texts_written"], 0)

    def test_promote_rejects_a_broken_copy(self):
        store_module.write_json(self.store.edited_path, {"schema": 1})
        with self.assertRaises(ValidationFailed):
            self.store.promote()
        self.assertTrue(self.store.has_edited())


if __name__ == "__main__":
    unittest.main()
