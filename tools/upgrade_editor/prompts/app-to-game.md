Upgrade-Editor -> Spiel anwenden.

Das Skript hat soeben `data/upgrades.edited.json` validiert und per `python3 -m upgrade_editor apply` nach `data/upgrades.json` übernommen (Original archiviert unter `data/archive/`, geänderte Texte in `i18n/translations.csv`). Die Liste der Änderungen steht in `tools/upgrade_editor/data/last_changes.jsonl`.

Aufgaben:
1. Das Spiel liest `data/upgrades.json` bei jedem Build selbst; es ist kein Umschreiben von Spielcode nötig. Prüfe nur, ob die Änderungen vom Code verarbeitet werden (`src/core/upgrade_data.gd`, `game_config.gd`, `upgrade_catalog.gd`, `src/ui/sheets/upgrades_sheet.gd`), und behebe Lücken, falls etwas nicht greift (z. B. neue Felder).
2. Passe Tests an, die feste Werte der alten Daten annehmen (`tests/unit/test_upgrade_data.gd`, `test_game_config.gd`, `test_upgrade_catalog.gd`, `test_formulas.gd`). Die Tests sind die Wahrheit für das Verhalten; ändere nur Daten-Annahmen, nicht die Logik. Führe keine Gradle-Befehle und keine Godot-Tests aus, prüfe sie nur gedanklich.
3. Kosten-Nutzen-Faktor: Erstelle für jedes geänderte Upgrade einen Bericht vorher/nachher (Faktor = relativer Effektzuwachs in % pro 1.000 Kosten, Definition in `tools/upgrade_editor/web/js/benefit.js`). Nutze dafür `last_changes.jsonl` und die Formeln aus `web/js/formulas.js`. Weise auf Upgrades hin, deren Faktor sich stark verschlechtert oder verbessert.
4. Erzeuge `docs/upgrades.md` und `docs/upgrades_levels.csv` neu mit `tests/tools/upgrade_overview.gd`, falls das Skript lauffähig ist, und ergänze den Faktor-Bericht dort oder in der Antwort.
5. Upgrades mit `cost_model`/`value_model` werden vom Spiel nativ über `FormulaParser` ausgewertet; Faktor-Bericht dafür mit den Werten aus der Formel/Tabelle berechnen.
6. Aktualisiere `FEATURES.md` und `context.md` nur, wenn sich Funktionen geändert haben (context.md nur aktueller Stand).

Regeln: keine Code-Kommentare, UI-Texte nur über i18n (de + en Fallback), keine Gradle-Befehle. Berichte am Ende auf Deutsch.
