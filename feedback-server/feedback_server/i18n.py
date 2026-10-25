from __future__ import annotations

import json
from pathlib import Path

FALLBACK_LANGUAGE = "en"


def parse_accept_language(header: str | None) -> list[str]:
    if not header:
        return []
    weighted: list[tuple[float, int, str]] = []
    for index, part in enumerate(header.split(",")):
        tag, *params = (piece.strip() for piece in part.split(";"))
        if not tag or tag == "*":
            continue
        quality = 1.0
        for param in params:
            name, _, value = param.partition("=")
            if name.strip() == "q":
                try:
                    quality = float(value)
                except ValueError:
                    quality = 0.0
        if quality > 0:
            weighted.append((-quality, index, tag.split("-")[0].lower()))
    return [language for _, _, language in sorted(weighted)]


class Translator:
    def __init__(self, directory: Path, fallback: str = FALLBACK_LANGUAGE) -> None:
        self._catalogs: dict[str, dict[str, str]] = {
            path.stem: json.loads(path.read_text(encoding="utf-8"))
            for path in sorted(directory.glob("*.json"))
        }
        if fallback not in self._catalogs:
            raise ValueError(f"Missing fallback catalog '{fallback}' in {directory}")
        self._fallback = fallback

    @property
    def languages(self) -> list[str]:
        return sorted(self._catalogs)

    def pick(self, accept_language: str | None) -> str:
        for language in parse_accept_language(accept_language):
            if language in self._catalogs:
                return language
        return self._fallback

    def strings(self, language: str) -> dict[str, str]:
        return {**self._catalogs[self._fallback], **self._catalogs.get(language, {})}
