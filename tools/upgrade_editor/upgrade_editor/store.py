import json
import os
import shutil
import tempfile
from datetime import datetime
from pathlib import Path

from . import changes, model, texts, validation

ORIGINAL_NAME = "upgrades.json"
EDITED_NAME = "upgrades.edited.json"
ARCHIVE_DIR = "archive"
CONTEXT_NAME = "app_context.json"
TRANSLATIONS_NAME = "game_translations.json"


class ValidationFailed(Exception):
    def __init__(self, errors):
        super().__init__(f"{len(errors)} validation errors")
        self.errors = errors


class MissingFile(Exception):
    pass


def read_json(path):
    try:
        with open(path, encoding="utf-8") as handle:
            return json.load(handle)
    except FileNotFoundError as error:
        raise MissingFile(str(path)) from error


def write_json(path, document):
    path = Path(path)
    path.parent.mkdir(parents=True, exist_ok=True)
    handle, temp_name = tempfile.mkstemp(dir=path.parent, suffix=".tmp")
    try:
        with os.fdopen(handle, "w", encoding="utf-8") as stream:
            json.dump(document, stream, indent="\t", ensure_ascii=False)
            stream.write("\n")
        os.replace(temp_name, path)
    except BaseException:
        if os.path.exists(temp_name):
            os.unlink(temp_name)
        raise


class DocumentStore:
    def __init__(self, game_data_dir, context_dir, translations_csv=None):
        self.game_data_dir = Path(game_data_dir)
        self.context_dir = Path(context_dir)
        self.translations_csv = Path(translations_csv) if translations_csv else None

    @property
    def original_path(self):
        return self.game_data_dir / ORIGINAL_NAME

    @property
    def edited_path(self):
        return self.game_data_dir / EDITED_NAME

    @property
    def archive_path(self):
        return self.game_data_dir / ARCHIVE_DIR

    def has_edited(self):
        return self.edited_path.is_file()

    def source(self):
        return "edited" if self.has_edited() else "original"

    def load_original(self):
        return read_json(self.original_path)

    def load_active(self):
        return read_json(self.edited_path if self.has_edited() else self.original_path)

    def context(self):
        return read_json(self.context_dir / CONTEXT_NAME)

    def translations(self):
        return read_json(self.context_dir / TRANSLATIONS_NAME)

    def validate(self, document):
        return validation.validate(document)

    def save_edited(self, document):
        errors = validation.validate(document)
        if errors:
            raise ValidationFailed(errors)
        normalised = model.normalise(document)
        errors = validation.validate(normalised)
        if errors:
            raise ValidationFailed(errors)
        write_json(self.edited_path, normalised)
        return normalised

    def changes(self):
        return changes.diff(self.load_original(), self.load_active())

    def changes_for(self, document):
        return changes.diff(self.load_original(), document)

    def reset_edited(self):
        if not self.has_edited():
            return None
        return self._archive(self.edited_path, "edited", move=True)

    def promote(self):
        if not self.has_edited():
            raise MissingFile(str(self.edited_path))
        edited = self.load_active()
        errors = validation.validate(edited)
        if errors:
            raise ValidationFailed(errors)
        summary = {"changes": self.changes(), "texts_written": 0}
        if self.translations_csv is not None and edited.get("text_overrides"):
            summary["texts_written"] = texts.apply_overrides(self.translations_csv, edited["text_overrides"])
        summary["archived_original"] = str(self._archive(self.original_path, "original", move=False))
        edited["text_overrides"] = {}
        write_json(self.original_path, edited)
        summary["archived_edited"] = str(self._archive(self.edited_path, "edited", move=True))
        return summary

    def _archive(self, path, label, move):
        self.archive_path.mkdir(parents=True, exist_ok=True)
        stamp = datetime.now().strftime("%Y%m%d-%H%M%S-%f")
        target = self.archive_path / f"upgrades.{label}.{stamp}.json"
        if move:
            shutil.move(str(path), str(target))
        else:
            shutil.copy2(path, target)
        return target
