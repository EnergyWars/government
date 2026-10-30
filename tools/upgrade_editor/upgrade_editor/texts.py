import csv
import io
from pathlib import Path

LANGUAGE_COLUMNS = {"en": 1, "de": 2}


def apply_overrides(csv_path, overrides):
    path = Path(csv_path)
    with path.open(newline="", encoding="utf-8") as handle:
        rows = list(csv.reader(handle))
    index = {row[0]: position for position, row in enumerate(rows) if row}
    touched = 0
    for key, languages in overrides.items():
        if key not in index:
            rows.append([key, languages.get("en", ""), languages.get("de", languages.get("en", ""))])
            index[key] = len(rows) - 1
            touched += 1
            continue
        row = rows[index[key]]
        for language, text in languages.items():
            column = LANGUAGE_COLUMNS[language]
            while len(row) <= column:
                row.append("")
            if row[column] != text:
                row[column] = text
                touched += 1
    buffer = io.StringIO()
    csv.writer(buffer, lineterminator="\n").writerows(rows)
    path.write_text(buffer.getvalue(), encoding="utf-8")
    return touched
