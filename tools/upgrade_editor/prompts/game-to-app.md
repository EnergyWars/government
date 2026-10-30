Spiel -> Upgrade-Editor synchronisieren.

Das Spiel liest `data/upgrades.json` nativ (siehe `src/core/upgrade_data.gd`). Der Exporter `tools/upgrade_editor/export_game.gd` hat soeben `tools/upgrade_editor/data/app_context.json` und `game_translations.json` neu geschrieben.

Aufgaben:
1. Prüfe, ob sich Spielcode (`src/core/game_config.gd`, `upgrade_catalog.gd`, `formulas.gd`, `world_layout.gd`) so geändert hat, dass der Editor nicht mehr passt: neue Upgrade-Arten, neue Konstanten in `UpgradeData.constant(...)`, neue Räume/Spots, geänderte Kostenformeln.
2. Passe den Editor an, wo nötig: `tools/upgrade_editor/web/js/formulas.js`, `benefit.js`, `model.js`, `texts.js`, Python-Validierung in `tools/upgrade_editor/upgrade_editor/`. Die Formeln in `formulas.js` müssen die Spielwerte aus `app_context.json` (`check`) exakt reproduzieren.
3. Neue Upgrades und Konstanten müssen in `data/upgrades.json` (Original) und im Menübaum (`menu.rooms`, `menu.topics`) stehen; ergänze fehlende Einträge, ohne bestehende Werte zu ändern. Neue Konstanten brauchen einen Namen in `web/i18n/de.json` und `en.json` (`const.<NAME>`).
4. Kosten-Nutzen-Faktor: Er ist definiert als relativer Effektzuwachs in Prozent pro 1.000 Kosten (`web/js/benefit.js`, `PER_COST = 1000`). Stelle sicher, dass er für alle neuen Upgrade-Arten berechnet und in Karten, Inspector und Übersicht angezeigt wird.
5. Rechenmodelle: `cost_model`/`value_model` (Formel oder Tabelle) müssen in `formulas.js` und `formula.js` dieselben Ergebnisse wie `Formulas.track_cost/track_value` liefern; die drei Formelparser (JS, Python, GDScript) müssen dieselben Vektoren in `tests/shared/formula_vectors.json` bestehen.
6. Führe `make upgrades-test` aus (JS und Python des Editors). Gradle und Godot-Tests dürfen nicht ausgeführt werden.

Regeln: keine Code-Kommentare, UI-Texte nur über i18n (de + en Fallback), keine Gradle-Befehle, nur kommerziell nutzbare Bibliotheken. Berichte am Ende auf Deutsch, was angepasst wurde.
