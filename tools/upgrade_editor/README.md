# Upgrade-Editor

Web-App zum Bearbeiten von `data/upgrades.json`, der Datei, die das Spiel nativ liest.

## Start

```
make upgrades
```

Der Server läuft fest auf Port 47321 (`--port N` ändert ihn, `--port 0` wählt einen freien), ist im lokalen Netz erreichbar (beim Start werden die Adressen als `network: http://<IP>:47321/` ausgegeben) und öffnet den Browser: http://127.0.0.1:47321/. Nur lokal: `--local-only`. Es gibt keine Anmeldung: jeder im lokalen Netz kann Änderungen speichern, daher nur in vertrauenswürdigen Netzen verwenden. Zugriff erlauben nur Hostnamen der eigenen Maschine und private IP-Adressen; eine Firewall muss den Port ggf. freigeben. Ohne Browser: `python3 -m upgrade_editor serve --no-browser` (im Ordner `tools/upgrade_editor`).

## Ablauf

1. Werte, Menüstruktur und Texte in der Oberfläche ändern.
2. Speichern erzeugt `data/upgrades.edited.json`; ab dann wird nur diese Kopie angezeigt.
3. `make upgrades-app-to-game` (oder `app-to-game.sh`) validiert die Kopie, archiviert das Original in `data/archive/`, übernimmt die Kopie als `data/upgrades.json` und schreibt geänderte Texte nach `i18n/translations.csv`. Mit `--no-ai` entfällt der Claude-Aufruf.
4. Hat sich das Spiel geändert, `make upgrades-game-to-app` ausführen: Der Exporter (`export_game.gd`, braucht Godot über `GODOT` oder `G`) schreibt `data/app_context.json` und `game_translations.json` neu.

## Mehrfach-Platzierung, Untergruppen, Suchlisten

- Ein Upgrade kann in beliebig vielen Bereichen gleichzeitig stehen (Inspector → „Bereiche“, Palette-Drop oder Auswahl im Bereichspanel). Es bleibt ein Upgrade mit einer Stufe; das Spiel zeigt es in jedem Bereich (`UpgradeData.placed_rooms/placed_spots`, `UpgradeCatalog.shows_at/entries_for_room`).
- Untergruppen mit Zwischenüberschrift legt man je Raum (Menü-Tab) oder im Bereichspanel an; Titel de/en, per Drag & Drop oder Pfeilen sortierbar; Löschen verschiebt die Upgrades in die Hauptgruppe. Das Spiel zeigt sie als Überschrift (`UpgradeCatalog.sections_for_room`).
- Alle Auswahlfelder sind durchsuchbar (`web/js/search.js`, `select` in `views/components.js`): tippen filtert (Groß-/Kleinschreibung und Umlaute egal, mehrere Begriffe), Pfeiltasten/Enter/Esc steuern die Liste.

## Bereiche anpassen und löschen

- In der Bereichsansicht öffnet „Bereich anpassen“ eine Karte, auf der nur dieser Bereich bearbeitbar ist: Kasten ziehen (verschieben), Griffe an Ecken und Kantenmitten (Größe, Mindestgröße 8, innerhalb der Karte), „Weiteren Kasten hinzufügen“ zeichnet einen neuen, „Kasten entfernen“ löscht den gewählten. In der Seitenleiste stehen alle Kästen auch als Zahlenfelder. „Fertig“ oder Esc führt zurück.
- Das gilt für eigene und vorhandene Bereiche. Bei vorhandenen wird die Änderung als `spot_rects` gespeichert, die Spielkarte selbst bleibt unverändert; „Auf das Original zurücksetzen“ nimmt sie zurück.
- „Bereich löschen“: Eigene Bereiche verschwinden samt Untergruppen, ihre Upgrades werden entfernt (sie bleiben an anderen Orten bestehen oder liegen wieder in der Palette). Vorhandene Bereiche verlieren ihre Kästen auf der Karte (im Spiel nicht mehr antippbar), Menügruppe und Upgrades bleiben erhalten.

## Kosten-Nutzen-Faktor

Relativer Effektzuwachs einer Stufe in Prozent pro 1.000 Kosten (`web/js/benefit.js`), live aus den aktuellen Werten berechnet. Höher ist besser.

Zusätzlich je Stufe zwei Verhältnisse in Prozent (`trackRatios`): **Faktor Stufe %** = (Nutzenzuwachs der Stufe ÷ Basiswert) ÷ (Kosten der Stufe ÷ Basiskosten) und **Faktor gesamt %** = (1 + Nutzenzuwachs bis hier ÷ Basiswert) ÷ (1 + Kosten bis hier ÷ Basiskosten), also einschließlich Anfangswert und Anfangskosten. Basiswert = Wert auf Stufe 0, Basiskosten = Kosten der ersten Stufe; ohne Basiswert (0) bleibt der Wert leer. Beispiel mit Basis 10 Leben / 10 Geld: +4 Leben für 8 Geld = 50 %, +4 Leben für 16 Geld = 25 %; gesamt nach beiden Stufen (10 + 4 + 4) / (10 + 8 + 16) = 18 / 34 ≈ 52,9 %. Beide stehen in der Vorschau-Tabelle und als Linien im Diagramm (neben Kosten je Stufe, Gesamtkosten und Faktor je 1.000).

## Tests

```
make upgrades-test
```

Python (`tests/py`, unittest) und JavaScript (`tests/js`, `node --test`). Die JS-Formeln werden gegen die vom Spiel exportierten Kosten geprüft.

## Datenformat

Schema 1: `upgrades` (Definitionen), `system` (`constants`, `station_kinds`, `departments`), `menu` (`rooms` mit Gruppen und Einträgen, `topics` mit Items; eine Gruppe ist `{spot, entries}`, optional als frei benennbare Untergruppe/Zwischenüberschrift mit `id` und `title` (`{de, en}`) – mehrere Gruppen eines Spots sind erlaubt, ohne `id` ist es die Hauptgruppe; dieselbe Referenz darf in beliebig vielen Bereichen (Raum + Spot) stehen, aber höchstens einmal je Spot, der Hauptbereich ist weiterhin `upgrades.<id>.spot` bzw. die Raumvorlage), `areas` (id → `room`, `rects` als `[x, y, breite, höhe]`; Spot `area:<id>`, Titel über Textschlüssel `SPOT_AREA_<ID>`), `spot_rects` (vorhandener Spot → vollständige Liste der Kästen `[x, y, breite, höhe]`, leere Liste = von der Karte entfernt; ersetzt die Tipp-Kästen des Spiels, Spots `area:<id>` stehen stattdessen in `areas`), `text_overrides` (Schlüssel → de/en). Referenzen: `track:<id>`, `track:<id>@<raum>`, `desk:<station>` und weitere Systemeinträge.

## Rechenmodelle

Pro Upgrade lassen sich Kosten und Nutzen getrennt per Formel oder Tabelle festlegen (`cost_model`, `value_model`):

- `{"mode": "formula", "formula": "cost * growth ^ level"}`
- `{"mode": "table", "levels": [..]}` (Kosten je Stufe, Länge = `max`)
- `{"mode": "table", "increments": [..]}` (Nutzenzuwachs je Stufe, Länge = `max`; Wert = `base` + Summe der Zuwächse)

Im Editor ist die **Wertetabelle** (ganz unten im Inspector) der eigentliche Bearbeitungsort: je Stufe sind Kosten, Zuwachs und Wert einzeln änderbar, abhängige Werte werden sofort neu berechnet, „Tabelle anwenden“ schreibt sie als `cost_model`/`value_model` (`mode: table`, optional `formula` = zuletzt verwendete Formel); entsprechen die Werte den Parametern, wird kein Modell gespeichert. Parameter, Formel und Werkzeuge befüllen nur den Tabellenentwurf (Formel einmalig; Historie je Upgrade und Art in `formula_history`, neueste zuerst, höchstens 30, per Liste wählbar und löschbar). Der Modus `formula` (live ausgewertet) wird weiterhin gelesen und beim Anwenden in eine Tabelle überführt.

Kosten-Formeln liefern die Kosten der Stufe `level + 1` vor dem Raumfaktor (ohne Frührabatt). Formelparser: `web/js/formula.js`, `upgrade_editor/formula.py` und `src/core/formula_parser.gd` müssen dieselben Vektoren aus `tests/shared/formula_vectors.json` bestehen.
