# Kontext – Idle Germany

## Aufbau eines Projektes
- **FEATURES.md**: Im Projektstamm, enthält alle Features vollständig; nach jeder abgeschlossenen Feature-Änderung aktualisieren; projektspezifische Ausnahmen dort vermerken. Nur bei Bedarf nachschlagen.
- **.gitignore**: Im Projektstamm, laufend pflegen.
- **context.md**: Diese Datei. Zuerst lesen; beschreibt nur den aktuellen Stand (keine Historie), Features mit zugehörigen Dateien, Architekturentscheidungen; nach jeder Codeänderung aktualisieren und kurz halten. Bei Widerspruch hat `CLAUDE.md` Vorrang.
- Git-Repository im Projektstamm.

## Technik
- Godot 4.7.2 stable (`~/.local/opt/godot-4.7.2/Godot_v4.7.2-stable_linux.x86_64`), GDScript typisiert, Renderer Mobile, Hochformat 720×1280, Stretch `canvas_items`/`expand`.
- Android-Export ohne Gradle über Templates in `~/.local/share/godot/export_templates/4.7.2.stable`; Preset in `export_presets.cfg` (Paket `com.wafflehq.idlegermany`, arm64-v8a + armeabi-v7a). Build: `$G --headless --export-debug "Android" build/idle-germany.apk`.
- Tests: GUT 9.7.1 in `addons/gut`, Konfiguration `.gutconfig.json`, Aufruf `$G --headless -s addons/gut/gut_cmdln.gd`. Vorher bei neuen Klassen `$G --headless --import`. Jede `.gd` braucht eine `.uid`.
- Werkzeuge: `tests/tools/balance_bot.gd` (Balancing-Simulation, `--hours=`, `--active=`), `tests/tools/screenshot.gd` (`--out --sheet --arg --simulate --rich --focus --locale --spot=`, mit `--rendering-driver opengl3`).
- Schriften Geist (OFL) und Material Icons (Apache 2.0) in `assets/fonts` mit Lizenzdateien; App-Icon `assets/icon.svg` (eigenes Design).
- Übersetzungen `i18n/translations.csv` (keys,en,de), Fallback Englisch.
- Kosmetische Zufallslogik (Besucher, Streits, Bewertungen) nutzt `GameState.life_rng`/`review_rng` statt `rng`, damit Spielabläufe reproduzierbar bleiben. Besucher, Telefonate, Kapseln und Statistik-Messwerte sind transient.

## Architektur
- `src/core/` reine Spiellogik ohne Nodes (RefCounted), vollständig getestet; `src/ui/` Darstellung.
- Feste Simulationsschritte (`GameConfig.TICK` = 1/30 s) über `Game.advance`, max. `MAX_STEPS_PER_FRAME`.
- Fälle (`CaseFile`) tragen ihre Route (`RouteBuilder`); Stationen heißen `<abteilung>/<art>` bzw. `shared/<art>`.
- **Upgrades**: Alle stufenbasierten Verbesserungen sind Spuren in `GameConfig.UPGRADES` (53 Spuren; Felder `spot`, `topic`, `max`, `cost`, `growth`, `curve` linear/decay/unlock_decay/chance/unlock, `base`/`step`/`rate`, `unit`, optional `reputation`/`stage`/`requires`/`rooms` (`ROOMS_ALL_DEPARTMENTS`/`ROOMS_SHREDDERS`/`ROOMS_TUBES` für Spuren je Raum)). Stufen in `GameState.upgrades` (Schlüssel `id` bzw. `id@raum` über `GameConfig.upgrade_key`), Wert `Formulas.track_value`/`upgrade_value`, Preis `track_cost`/`track_bulk_cost` (geometrische Summe). Kaufregeln in `Progression`, Kauf über `GameActions.buy_entry(entry_id, count)`.
- **Katalog**: `UpgradeCatalog` erzeugt aus Spuren und Spielstand `UpgradeEntry`-Objekte aller Arten (track, level, desk, hire, specialist, supervisor, staff, runner_level, segment, storage, unlock, rank, stage) mit `id`, `spot`, `topic`, `room`, Stufe, Preis, Wachstum und Sperrgrund; `expansion_entries` vergleicht Eröffnung, Amtsstufen und Gebäudestufe nach Amortisation (`income_gain`, `payback`). UI-Fenster lesen nur den Katalog.
- **Bereiche (Spots)**: `WorldLayout.spots` ordnet jedem Bereich Rechtecke zu (`_build_spots`; Präfixe `room:`, `dept:`, `station:`, `shredder:`, `tube:`); `spot_at` wählt das kleinste Rechteck. `WorldView.tap_spot` (Spielfigur → „player“, sonst Spot, sonst Raum) → `UpgradeCatalog.resolve_spot` → `SpotSheet`.
- Weltkoordinaten zentral in `WorldLayout` (1400 breit; von oben Abteilungsräume, Küche + Sanitär, Telefonzentrale, Poststelle, Servicezeile Beschwerdebüro | Schredderraum | Technikraum, Publikumshalle).
- Speichern als JSON (`SaveService`, `GameState.SAVE_VERSION` 3); Version 2 wird über `SaveMigration.migrate_v2` umgerechnet, ältere Stände starten neu. `tutorial_step` optional (fehlt → beendet), `rank` je Abteilung optional (fehlt → 1, begrenzt auf 1–10).
- Tutorial-Schritte sind Daten in `Tutorial.STEPS` (Arten info/move/sheet/stat), Texte `TUTORIAL_<ID>_TITLE/_TEXT`.
- Zielplattform vorerst nur Android; keine Desktop-Hinweise in Texten (Tastatursteuerung bleibt technisch erhalten).

## Features und Dateien (Status: umgesetzt)
| Feature | Dateien |
|---|---|
| Konfiguration (Abteilungen, Stationen, Gebäudestufen, Upgrade-Spuren, Personal, Ziele, Ereignisse, Boosts) | `src/core/game_config.gd` |
| Spielstand, Speichern/Laden, Validierung | `src/core/game_state.gd`, `department.gd`, `station.gd`, `station_job.gd`, `case_file.gd`, `save_service.gd` |
| Spielstand-Migration v2 → v3 (Skalierung `LEVEL_SCALES`/`LEVEL_STEPS`/`SPLITS`/`DERIVED`, Hallen-Ausbauten, Briefregal, Schulungen, Röhrenstufen, Rohrpost-Stationen, Tutorial-Schritte) | `src/core/save_migration.gd`, `tests/unit/test_save_migration.gd` |
| Upgrade-Spuren, Katalog, Kauf (Mengen, Sperrgründe, Voraussetzungen, Ansehen = Höchstwert) | `src/core/upgrade_catalog.gd`, `upgrade_entry.gd`, `formulas.gd` (`track_*`, `upgrade_value`, `geometric_sum`/`geometric_affordable`), `progression.gd`, `game_actions.gd` (`buy_entry`), `tests/unit/test_upgrade_catalog.gd`, `test_formulas.gd`, `test_game_actions.gd` |
| Anklickbare Bereiche und Raum-Übersichten (Spots, Hervorhebung, „Auf der Karte zeigen“) | `src/core/world_layout.gd` (`spots`, `spot_at`, `room_at`, `slot_rect`, Bretter `*_board`), `src/ui/world_view.gd` (`tap_spot`, `focus_spot`, `_draw_spot_highlight`), `src/ui/main.gd` (`locate`, `spot`), `src/ui/sheets/spot_sheet.gd`, `src/ui/spot_status.gd`, `tests/unit/test_map_spots.gd`, `test_rooms.gd` |
| Upgrade-Übersicht (Räume/Themen/Kaufbar/Empfohlen/Ausbau, Kaufmenge ×1/×10/Max außer in „Ausbau“) | `src/ui/sheets/upgrades_sheet.gd`, `upgrade_entry_card.gd`, `src/ui/upgrade_texts.gd`, `tests/unit/test_upgrade_ui.gd` |
| Amtsstufen (Stufe 1–10 je Abteilung, Gebühren ×`RANK_FEE_FACTOR` je Stufe, Preis/Ansehen aus der Eröffnungsleiter, danach ×`RANK_COST_GROWTH`; Ausbau-Vergleich, Abzeichen und Floater auf der Karte, Statistik) | `src/core/department_rank.gd`, `department.gd` (`rank`), `formulas.gd` (`department_fee`, `potential_income`), `simulation.gd` (`rank_up`, `department_ranked_up`), `game_actions.gd` (`rank_up_department`), `upgrade_catalog.gd` (`rank`, `expansion_entries`), `src/ui/upgrade_texts.gd` (`rank_name`, `fee_factor_text`, `rank_effect`, `gain_text`), `sheets/upgrades_sheet.gd`, `sheets/statistics_sheet.gd`, `world_view.gd` (`_draw_rank_badge`), `tests/tools/balance_bot.gd`, `tests/unit/test_department_rank.gd` |
| Schwarze Bretter (Botenplan, Ablehnungs-Boten, Praktikanten, Kaffeedienst, Wachplan, Krankenliste, Schulungsbrett, Betriebsrat) | `src/core/world_layout.gd`, `src/ui/sheets/board_section.gd`, `src/ui/world_view.gd` (`_draw_board`), `tests/unit/test_upgrade_ui.gd` |
| Abteilungsverwaltung (Kennzahlen, Route, Stau, Arbeitsweise, Legende) | `src/ui/sheets/department_section.gd`, `station_card.gd` |
| Routen inkl. Verweis, Prüfdienst, Wiedervorlage, Zoll | `src/core/route_builder.gd` |
| Simulation (Ankünfte, Geduld, Tische, Effekte, Abschluss, Ereignisse) | `src/core/simulation.gd` |
| Spielfigur, Tragen, Arbeiten, Eröffnungskreise | `src/core/player.gd`, `carrier.gd`, `simulation.gd` |
| Boten (Aufgaben `Runner.role`, Zuständigkeit `dept_id`, Botenstufen, Nachladen und Mehrfachziele, Einsatz trotz Rohrpost über `runner_takes`/`Station.is_backlogged` (`TUBE_OVERFLOW_SHARE`); Kapazität `transport_throughput`/`role_capacity`/`runner_trip_time`, Bedarf `runner_share`/`runner_transfers`/`role_demand`) | `src/core/runner.gd`, `simulation.gd`, `formulas.gd`, `game_state.gd`, `guidance.gd`, `tests/unit/test_runner_roles.gd` |
| Rohrpost je Raum (Freischaltung `pneumatic_tubes`, Stationen `tube_station@raum`, `has_tube_station`, `tube_link`, `fits_capsule` mit `large_capsules`, `is_piped`; Kapazität `tube_capacity`, Tempo `tube_speed`, Abschnittsstufen `tube_levels`, `Formulas.tube_segment_*`) | `src/core/game_state.gd`, `tube_parcel.gd`, `simulation.gd` (`_launch_parcels`), `formulas.gd`, `route_builder.gd` (`segments`, `tube_id`), `upgrade_catalog.gd` (`segment`), `src/ui/world_view.gd` (`tube_pairs`, `_draw_tubes`, `_draw_capsules`, `_draw_tube_slot`), `office_painter.gd` (`tube_station`, `tube_hub`), `tests/unit/test_tube_connections.gd` |
| Beschwerdebüro, Briefkasten, Schredderraum (Beschwerden, Praktikanten, Beschwerde-Röhre, Beschwerdetisch-Abwimmeln, Wachleute, Besucher) | `src/core/simulation.gd`, `complaint_intern.gd`, `complaint_visitor.gd`, `game_state.gd`, `formulas.gd` (`complaint_*`, `guard_*`, `intern_*`), `world_layout.gd` (`complaint_office`, `shredder_room`, `complaint_box_point`, `intern_home`, `guard_post`), `guidance.gd`, `src/ui/world_view.gd` (`_draw_complaint_office`, `_draw_shredder_room`, `_draw_visitors`), `flavor.gd`, `sheets/complaints_sheet.gd`, `tests/unit/test_complaints.gd`, `test_complaint_clerk.gd`, `test_complaint_guard.gd`, `test_hall_life.gd` |
| Ablehnungen, Ablehnungs-Boten, Abteilungsschredder (`shredder@abteilung`, `_update_dept_shredders`, `shredder_interval`, `shredder_rooms`, `nearest_shredder`) | `src/core/simulation.gd`, `reject_collector.gd`, `formulas.gd`, `game_state.gd`, `world_layout.gd` (`reject_point`, `dept_shredder_point`, `nearest_shredder`), `throughput_report.gd` (`reject_area`, `collector_trip`), `src/ui/world_view.gd` (`_draw_shredder_slot`), `tests/unit/test_feedback_features.gd`, `test_throughput_report.gd` |
| Technikraum (Serverschrank, Klimagerät, Rohrpost-Zentrale, Botenplan) | `src/core/world_layout.gd` (`tech_room`, `server_rect`, `climate_rect`, `tube_hub_point`), `src/ui/world_view.gd` (`_draw_tech_room`), `office_painter.gd` (`server_rack`, `climate_unit`) |
| Online-Bewertungen (Löschen, Klagen, Werbungs-Klage, Ablauf) | `src/core/review.gd`, `game_state.gd`, `simulation.gd`, `boosts.gd`, `formulas.gd` (`review_*`), `src/ui/sheets/reviews_sheet.gd`, `hud.gd`, `ui_kit.gd` (`stars`), `tests/unit/test_reviews.gd` |
| Formeln (Kosten, Zeiten, Fehler, Durchsatz, Engpass, Auslastung) | `src/core/formulas.gd` |
| Aktionen und Freischalt-Bedingungen | `src/core/game_actions.gd`, `progression.gd` |
| Leit-Pfeil | `src/core/guidance.gd`, `src/ui/world_view.gd` |
| Ziele, Offline-Ertrag, Zahlenformat | `src/core/goal_tracker.gd`, `offline_calculator.gd`, `number_format.gd` |
| Spielwelt, Joystick, Effekte, Grafiken | `src/ui/world_view.gd`, `joystick_view.gd`, `item_painter.gd`, `office_painter.gd`, Palette in `app_theme.gd` |
| HUD, Aufgaben-Panel, Navigation (Upgrades, Statistik, Ziele) | `src/ui/hud.gd`, `task_panel.gd` |
| Panels und Theme | `src/ui/sheet.gd`, `src/ui/sheets/*.gd`, `app_theme.gd`, `icons.gd`, `ui_kit.gd`, `app_dialog.gd`, `app_settings.gd`, `goal_text.gd`, `fling_scroll.gd` |
| App-Start, Autospeichern, Offline-Dialog | `src/ui/main.gd`, `scenes/main.tscn` |
| Tutorial (24 Schritte) | `src/core/tutorial.gd`, `game.gd`, `src/ui/tutorial_card.gd`, `hud.gd` (`highlight`), `main.gd`, `sheets/settings_sheet.gd`, `tests/unit/test_tutorial.gd` |
| Humor (Sprüche, Floater, Amtsweisheit, Besucher-Dialoge) | `src/ui/flavor.gd`, `world_view.gd` (`_speech`, `_float`), `sheets/goals_sheet.gd`, Texte `QUIP_*`, `FLOAT_*`, `WISDOM_*`, `SIGN_*`, `VISIT_*`, `YELL_*` u. a. |
| Küche, Kaffeekränzchen, Kaffee-Praktikanten, Betriebsrat | `src/core/simulation.gd` (`_update_kranz`, `_update_coffee_interns`), `coffee_intern.gd`, `desk_mood.gd`, `formulas.gd` (`doze_weights`, `rest_limit`, `kranz_*`), `world_layout.gd` (`kitchen`), `src/ui/world_view.gd` (`_draw_kitchen`), `tests/unit/test_kitchen_life.gd` |
| Toiletten (Kabinen, Verweildauer, Weckdienst) | `src/core/desk_mood.gd` (`LOO`), `game_state.gd` (`free_loo_slot`), `formulas.gd`, `world_layout.gd` (`toilets`), `src/ui/world_view.gd` (`_draw_toilets`), `office_painter.gd` (`toilet_stalls`), `tests/unit/test_sick_and_loo.gd` |
| Telefonzentrale und Krankmeldungen | `src/core/phone_call.gd`, `simulation.gd` (`report_sick`, `_update_phones`), `game_state.gd`, `desk_mood.gd`, `world_layout.gd` (`phone_office`, `sick_board`), `src/ui/world_view.gd` (`_draw_phone_office`), `tests/unit/test_phone_office.gd` |
| Halle (Warteschlange, Sitz-/Stehplätze, Wartemarken, Aufrufanzeige, Radau, Archiv, Eingang) | `src/core/game_state.gd` (`seat_capacity`, `standing_capacity`, `lobby_*`, `ticket_*`), `simulation.gd` (`spawn_case`, `_update_tickets`, `_update_ruckus`), `formulas.gd`, `world_layout.gd`, `throughput_report.gd`, `src/ui/world_view.gd` (`_draw_hall`, `_draw_ticket_corner`), `tests/unit/test_hall_life.gd`, `test_tickets.gd` |
| Faule Beamte, Bürostreits, Schulungen, Krankheits-Bonus | `src/core/desk_mood.gd`, `dispute.gd`, `simulation.gd`, `formulas.gd`, `game_actions.gd` (`train_official`), `src/ui/sheets/officials_sheet.gd`, `hud.gd`, `tests/unit/test_moods.gd`, `test_officials.gd`, `test_sick_bonus.gd` |
| Ereignisse (datengetrieben, Minderung anteilig zur Spur-Stufe) | `src/core/game_config.gd` (`EVENTS`), `formulas.gd` (`event_*`), `simulation.gd`, `src/ui/hud.gd`, `tests/unit/test_feedback_features.gd` |
| Poststelle (Lieferungen, Briefregal, Boden-Überlauf, fehlende Unterlagen) | `src/core/simulation.gd` (`_update_mail`, `deliver_mail`, `pick_up_mail`), `station.gd` (`storage_capacity`), `formulas.gd` (`mail_*`), `world_layout.gd` (`mail_room`), `src/ui/world_view.gd` (`_draw_mail_room`), `office_painter.gd`, `tests/unit/test_mail_room.gd` |
| Statistik und Durchsatz-Analyse (Bereiche, Ausbau-Gewinn je Upgrade, Empfehlungen, Gesamtwerte) | `src/core/rate_counter.gd`, `production_stats.gd`, `throughput_report.gd`, `src/ui/sheets/statistics_sheet.gd` (`upgrade_target` → Bereich), `tests/unit/test_statistics.gd`, `test_throughput_report.gd` |
| Boosts + Werbe-Attrappe (Raum-Übersichten und Spielfigur) | `src/core/boosts.gd`, `game_state.gd`, `formulas.gd`, `simulation.gd`, `src/ui/ad_placeholder.gd`, `sheets/boost_sheet.gd`, `boost_card.gd`, `spot_sheet.gd` (`room_boosts`), `tests/unit/test_boosts.gd`, `test_boost_ui.gd` |
| Engpässe durch Ausbau, Mehrfachanträge, Ansehen gedämpft, Handarbeit-Bonus | `src/core/formulas.gd`, `station.gd`, `department.gd`, `simulation.gd`, `case_file.gd`, `game_state.gd`, `tests/unit/test_bottleneck_dynamics.gd`, `test_reputation_damping.gd` |
| Sichtbare Laufwege (Bürger, Beamte) und Performance (Ebenen, Drosselung) | `src/ui/citizen_tracker.gd`, `world_view.gd`, `item_painter.gd`, `project.godot`, `tests/unit/test_citizen_tracker.gd`, `test_ui_scenes.gd` |

## Konzept
Quellen in `docs/concept/` (PDF, drei Infografiken, drei Textdateien zum Spielprinzip).

## Release
`release-review.md` im Projektstamm: Befunde und Todos zu Sicherheit, Datenschutz, Lizenzen und Play-Store-Veröffentlichung. Blocker: Release-Export mit eigenem Upload-Key als AAB, vollständige Godot-Lizenz-Attribution, Datenschutzerklärung/Impressum, Monetarisierungs-Platzhalter ausblenden. Beim Erledigen dort abhaken.

## Balancing
`balancing.md` im Projektstamm: Befunde, Designziel (häufige Engpässe, Boosts als Ausweg) und Status je Punkt. Konstanten stehen ausschließlich in `game_config.gd`; Upgrade-Werte und -Preise je Spur in `GameConfig.UPGRADES`.
