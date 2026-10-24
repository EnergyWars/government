# Kontext – Amts-Tycoon

## Aufbau eines Projektes
- **FEATURES.md**: Im Projektstamm, enthält alle Features vollständig; nach jeder abgeschlossenen Feature-Änderung aktualisieren; projektspezifische Ausnahmen dort vermerken. Nur bei Bedarf nachschlagen.
- **.gitignore**: Im Projektstamm, laufend pflegen.
- **context.md**: Diese Datei. Zuerst lesen; beschreibt nur den aktuellen Stand (keine Historie), Features mit zugehörigen Dateien, Architekturentscheidungen; nach jeder Codeänderung aktualisieren und kurz halten. Bei Widerspruch hat `CLAUDE.md` Vorrang.
- Git-Repository im Projektstamm.

## Technik
- Godot 4.7.2 stable (`~/.local/opt/godot-4.7.2/Godot_v4.7.2-stable_linux.x86_64`), GDScript typisiert, Renderer Mobile, Hochformat 720×1280, Stretch `canvas_items`/`expand`.
- Android-Export ohne Gradle über Templates in `~/.local/share/godot/export_templates/4.7.2.stable`; Preset in `export_presets.cfg` (Paket `com.wafflehq.departmenttycoon`, arm64-v8a + armeabi-v7a). Build: `$G --headless --export-debug "Android" build/department-tycoon.apk`.
- Tests: GUT 9.7.1 in `addons/gut`, Konfiguration `.gutconfig.json`, Aufruf `$G --headless -s addons/gut/gut_cmdln.gd`. Vorher bei neuen Klassen `$G --headless --import`.
- Werkzeuge: `tests/tools/balance_bot.gd` (Balancing-Simulation, `--hours=`, `--active=`), `tests/tools/screenshot.gd` (`--out --sheet --arg --simulate --rich --focus --locale`, mit `--rendering-driver opengl3`).
- Schriften Geist (OFL) und Material Icons (Apache 2.0) in `assets/fonts` mit Lizenzdateien; App-Icon `assets/icon.svg` (eigenes Design).
- Übersetzungen `i18n/translations.csv` (keys,en,de), Fallback Englisch.

## Architektur
- `src/core/` reine Spiellogik ohne Nodes (RefCounted), vollständig getestet; `src/ui/` Darstellung.
- Feste Simulationsschritte (`GameConfig.TICK` = 1/30 s) über `Game.advance`, max. `MAX_STEPS_PER_FRAME`.
- Fälle (`CaseFile`) tragen ihre Route (`RouteBuilder`); Stationen werden über Schlüssel `<abteilung>/<art>` bzw. `shared/<art>` angesprochen.
- Weltkoordinaten zentral in `WorldLayout` (1400 breit, Abteilungsräume oben, Publikumshalle unten); Simulation, Leit-Pfeil und Darstellung nutzen dieselben Punkte.
- Speichern als JSON (`SaveService`, Version 2 in `GameState.SAVE_VERSION`). `tutorial_step` ist ein optionales Feld: fehlt es, gilt das Tutorial als beendet (-1).
- Tutorial-Schritte sind Daten in `Tutorial.STEPS` (Arten info/move/sheet/stat); Texte unter `TUTORIAL_<ID>_TITLE/_TEXT` in der CSV.

## Features und Dateien (Status: umgesetzt)
| Feature | Dateien |
|---|---|
| Konfiguration (Abteilungen, Stationen, Stufen, Technik, Ziele, Ereignisse) | `src/core/game_config.gd` |
| Spielstand, Speichern/Laden, Validierung | `src/core/game_state.gd`, `department.gd`, `station.gd`, `station_job.gd`, `case_file.gd`, `save_service.gd` |
| Routen inkl. Verweis, Prüfdienst, Wiedervorlage, Zoll | `src/core/route_builder.gd` |
| Simulation (Ankünfte, Geduld, Tische, Effekte, Abschluss, Ereignisse) | `src/core/simulation.gd` |
| Spielfigur, Tragen, Arbeiten, Eröffnungskreise | `src/core/player.gd`, `carrier.gd`, `simulation.gd` |
| Boten mit Reservierung, Rohrpost | `src/core/runner.gd`, `simulation.gd` |
| Formeln (Kosten, Zeiten, Fehler, Durchsatz, Engpass, Auslastung) | `src/core/formulas.gd` |
| Aktionen und Freischalt-Bedingungen | `src/core/game_actions.gd`, `progression.gd` |
| Leit-Pfeil | `src/core/guidance.gd`, `src/ui/world_view.gd` |
| Ziele, Offline-Ertrag, Zahlenformat | `src/core/goal_tracker.gd`, `offline_calculator.gd`, `number_format.gd` |
| Weltlayout | `src/core/world_layout.gd` |
| Spielwelt, Joystick, Effekte, Abteilungs-Grafiken | `src/ui/world_view.gd`, `joystick_view.gd`, `item_painter.gd` |
| HUD, Aufgaben-Panel, Navigation | `src/ui/hud.gd`, `task_panel.gd` |
| Panels | `src/ui/sheet.gd`, `src/ui/sheets/*.gd` (`station_card.gd` gemeinsam für Abteilung/Team) |
| Theme, Icons, UI-Bausteine, Dialoge, Einstellungen | `src/ui/app_theme.gd`, `icons.gd`, `ui_kit.gd`, `app_dialog.gd`, `app_settings.gd`, `goal_text.gd` |
| App-Start, Autospeichern, Offline-Dialog | `src/ui/main.gd`, `scenes/main.tscn` |
| Tutorial (26 Schritte, Fortschritt in `GameState.tutorial_step`, Karte, Hervorhebung, Wiederholen in Einstellungen) | `src/core/tutorial.gd`, `src/core/game.gd`, `src/ui/tutorial_card.gd`, `src/ui/hud.gd` (`highlight`), `src/ui/main.gd`, `src/ui/sheets/settings_sheet.gd`, `tests/unit/test_tutorial.gd` |
| Humor (Bürgersprüche, Abschluss-Kommentare, Amtsweisheit) | `src/ui/flavor.gd`, `src/ui/world_view.gd`, `src/ui/sheets/goals_sheet.gd`, `i18n/translations.csv` (`QUIP_*`, `FLOAT_DONE_*`, `FLOAT_FLAWED_*`, `WISDOM_*`, `SIGN_*`) |
| Optik (Figuren, Möbel, Maschinen, Fahrzeuge, Halle) | `src/ui/item_painter.gd`, `src/ui/office_painter.gd`, `src/ui/world_view.gd`, Palette in `src/ui/app_theme.gd` |
| Küche (Kaffeemaschine, Tratschende holen, Selbstholer, 12 Plätze) | `src/core/world_layout.gd` (`kitchen`, `kitchen_slot`), `src/core/desk_mood.gd` (`CHAT`, `FETCH`, `slot`), `src/core/game_state.gd` (`free_kitchen_slot`), `src/ui/world_view.gd` (`_draw_kitchen`), `src/ui/office_painter.gd` (Küchenobjekte) |
| Beschwerdestelle + Aktenschredder (Beschwerden entstehen ab 5 Fällen, Spieler trägt sie zum Schredder, Technik `shredder_service`) | `src/core/simulation.gd` (`_update_complaints`, `file_complaint`, `shred_complaints`, `move_complaints`), `src/core/game_state.gd` (`complaints`), `src/core/player.gd` (`complaints`), `src/core/world_layout.gd` (`complaint_desk_point`, `shredder_point`), `src/core/guidance.gd` (`COMPLAINT`, `SHRED`), `src/ui/world_view.gd` (`_draw_complaint_corner`), `src/ui/office_painter.gd` (`complaint_pile`, `shredder`), `tests/unit/test_complaints.gd` |
| Küchenleben (Kaffeekränzchen `kranz`, gemächliche Läufer `slow` antreiben, Technik `coffee_machine`/`kitchen`, Doze-Gewichte) | `src/core/simulation.gd` (`_update_kranz`, `call_kranz`, `end_kranz`, `_wake_nearby`), `src/core/formulas.gd` (`doze_weights`, `rest_limit`, `wake_alert`), `src/core/desk_mood.gd` (`SLOW`), `src/core/game_state.gd` (`kranz`), `src/core/guidance.gd` (`KRANZ`), `src/ui/world_view.gd` (`_draw_kranz_banner`), `tests/unit/test_kitchen_life.gd` |
| Scrollen in Sheets (Touch-Weitergabe, Auslaufen) | `src/ui/fling_scroll.gd`, `src/ui/sheet.gd`, `tests/unit/test_fling_scroll.gd` |
| Krankmeldung + Krankentelefon (Beamte melden sich krank, Spieler/Telefonisten `hr` rufen an, Telefonate als Sprechblasen) | `src/core/simulation.gd` (`_update_sickness`, `report_sick`, `call_in_sick`), `src/core/game_state.gd` (`hr`, `sick_count`), `src/core/game_actions.gd` (`hire_hr`), `src/core/world_layout.gd` (`phone_point`), `src/ui/sheets/team_sheet.gd` (`_hr_card`), `src/ui/world_view.gd` (`_draw_phone_corner`), `tests/unit/test_sick_and_loo.gd` |
| Sanitärraum (eigener Raum rechts neben der Küche mit Toiletten und Krankentelefon, `layout.toilets`; Rückkehr-Laufanimation `return` in `world_view`) | `src/core/world_layout.gd` (`toilets`), `src/ui/world_view.gd` (`_draw_toilets`, `_start_return_walk`) |
| Toiletten (Zustand `loo`, 4 Kabinen, Ermutigen durch Danebenstehen 2 s) | `src/core/desk_mood.gd` (`LOO`), `src/core/world_layout.gd` (`slot_point`, `LOO_SPOTS`), `src/core/game_state.gd` (`free_loo_slot`), `src/ui/world_view.gd` (`_draw_loo_block`), `src/ui/office_painter.gd` (`toilet_stalls`) |
| Beschwerde-Malus (`COMPLAINT_DRAIN` Ansehen pro Beschwerde/s) | `src/core/simulation.gd` (`_update_complaints`), `src/core/formulas.gd` (`complaint_malus_per_minute`) |
| Performance (Simulation: gecachte Layout-Punkte, gedrosselte Weck-/Pad-Prüfung, Drowsiness lazy; Weltansicht in Ebenen: statisch einmalig, Räume reihum max. 8 Hz, Menschenmenge 30 Hz, Spieler 60 Hz; Lite-Personen, kein Lift-Schatten bei großen Flächen, MSAA aus, max_fps 60) | `src/ui/world_view.gd` (`_layers`, `_refresh_layers`, `_draw_crowd`), `src/ui/item_painter.gd` (`draw_person_lite`), `project.godot` |
| Performance (Textur-Kacheln/Schatten, Zeichen-Throttle 0,1 s, getrennte Akteurs-Ebene, Culling, gecachte Stationslisten, `changed` max. 10×/s, Kamera pixelgerundet, Sheet-Scroll-Deadzone 4) | `src/ui/world_view.gd`, `src/ui/item_painter.gd`, `src/core/game.gd`, `src/core/game_state.gd`, `src/core/route_builder.gd` |
| Faule Beamte (Einnicken, Kaffeepause, Aufwecken, Kaffeequalität, Weckdienst, Teamleitungs-Bremse) | `src/core/desk_mood.gd`, `src/core/station.gd` (`moods`), `src/core/simulation.gd` (`_update_moods`, `doze_off`, `wake_up`, `_wake_nearby`), `src/core/formulas.gd` (`alert_duration`, `drowsiness_rate`, `rest_limit`), `src/core/game_config.gd` (`BASE_ALERT_SECONDS`, `WAKE_SERVICE_DELAYS`, Technik `coffee`/`wake_service`), `src/core/guidance.gd` (`WAKE`), `src/ui/world_view.gd` (`_draw_rest`), `tests/unit/test_moods.gd` |
| Ereignisse (12 neue, datengetrieben, Geltungsbereich/Auswahl/Minderung, Banner mit Auswahl) | `src/core/game_config.gd` (`EVENTS`), `src/core/formulas.gd` (`event_*`), `src/core/simulation.gd` (`start_event`, `resolve_event`, `_end_event`, `_add_backlog`, `_add_big_case`), `src/core/game_state.gd` (`event_scope`, `event_choice`), `src/ui/hud.gd` (`_refresh_event_actions`), `src/ui/world_view.gd` (Ereignis-Symbol), `tests/unit/test_feedback_features.gd` |
| Ablehnungen (`CaseFile.invalid`, `Station.rejects`, `Player.rejects`, Schredder, Leit-Pfeil `REJECT`) | `src/core/simulation.gd` (`finish_job`, `_reject_case`, `shred_rejects`, `move_complaints`), `src/core/formulas.gd` (`is_invalid_case`), `src/core/world_layout.gd` (`reject_point`), `src/ui/world_view.gd` (`_reject_tray`) |
| Akten-Marker, Fachkraft-Optik | `src/ui/item_painter.gd` (`_badges`, `draw_person` expert), `src/ui/office_painter.gd` (`desk` expert), `src/core/case_file.gd` (`needs_inspection`, `needs_referral`) |
| Stau-Anzeige | `src/core/formulas.gd` (`full_boxes`), `src/ui/sheets/departments_sheet.gd` |
| Einwohner, Nachfragewachstum, Rang | `src/core/formulas.gd` (`population`, `settlement`, `demand_growth`), `src/ui/sheets/building_sheet.gd` |
| Rohrpost-Röhren und Kapseln (Layer `_tubes`, Signal `case_piped`) | `src/core/world_layout.gd` (`tube_path`, `path_point`), `src/ui/world_view.gd` (`_draw_tubes`, `_draw_capsules`) |
| Ziel-Belohnung ohne Einnahmen (`GameState.grant`) | `src/core/game_state.gd`, `src/core/goal_tracker.gd` |
| Tür-Seiten für Bürger | `src/core/world_layout.gd` (`door_in`, `door_out`), `src/ui/world_view.gd` |
| Gemeinsame Stationen im Abteilungsfenster | `src/ui/sheets/department_sheet.gd` |
| Tests | `tests/unit/test_*.gd` |

## Konzept
Quellen in `docs/concept/` (PDF, drei Infografiken, drei Textdateien zum Spielprinzip).
