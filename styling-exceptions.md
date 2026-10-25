# Styling-Ausnahmen

### Custom-Elemente
| Element | Datei | Kriterium (Abschnitt 7) | Begründung |
|---|---|---|---|
| Spielwelt (Grundriss, Räume inklusive Servicezeile Beschwerdebüro, Schredderraum und Technikraum (`_service_shell`), Stationen, Tische, Maschinen, Fächer, Figuren, Fahrzeuge) | `src/ui/world_view.gd` | Fachliche Geometrie | Die begehbare Draufsicht ist der Kern des Spiels; kein UI-Baustein bildet Räume, Laufwege und Figuren ab. Raum-Kopfleisten in der Raumfarbe mit Kontrastschrift (`_on_color`) sind zugleich anklickbare Bereiche. |
| Schwarze Bretter (Schichtpläne für Boten, Ablehnungs-Boten, Praktikanten, Kaffeedienst, Wachen, Krankenliste, Schulungen, Betriebsrat) | `src/ui/world_view.gd` (`_draw_board`) | Fachliche Geometrie | Aushänge sind Möbel der Spielwelt und zugleich anklickbare Bereiche; sie zeigen die Besetzung (z. B. „3/30“) direkt am Ort des Personals. Farben nur aus `AppTheme` (`SIGN_BOARD`, `SIGN_TEXT`, `FLAG_GOLD`, `WALL`), Schrift `SIZE_LABEL_SMALL`. |
| Technik der Spielwelt (Serverschrank mit Einschüben je Ausbaustand, Klimagerät mit Lüfter, Rohrpost-Zentrale mit Schloss vor der Freischaltung, Rohrpost-Stationen je Raum) | `src/ui/office_painter.gd` (`server_rack`, `climate_unit`, `tube_hub`, `tube_station`), `src/ui/world_view.gd` (`_draw_tech_room`, `_draw_tube_slot`) | Datenvisualisierung | Der Ausbaustand (aktive Einschübe, Lüftertempo, freigeschaltet, eingebaut) ist am Gerät auf der Karte ablesbar; kein UI-Baustein bildet Geräte der Draufsicht ab. |
| Leere Bau-Plätze (gestrichelter Rahmen mit gedimmtem Symbol) | `src/ui/office_painter.gd` (`empty_slot`), `src/ui/world_view.gd` (`_draw_tube_slot`, `_draw_shredder_slot`) | Fachliche Geometrie | Markieren auf der Karte, wo ein Raum-Upgrade (Abteilungsschredder, Rohrpost-Station) gebaut werden kann, und sind dessen anklickbarer Bereich. Rahmen und Symbol in `OUTLINE` mit 0,38 (abgeblendeter Inhalt). |
| Hervorhebung eines Bereichs (pulsierender Rahmen bzw. Ring um die Spielfigur) | `src/ui/world_view.gd` (`_draw_spot_highlight`) | Fachliche Geometrie | „Auf der Karte zeigen“ markiert einen Ort in Weltkoordinaten; kein UI-Baustein kann Bereiche der Draufsicht hervorheben. Farbe und Puls wie die übrigen Aufmerksamkeits-Ringe der Spielwelt (Warning-Akzent, Alpha pulsiert 0,5–1,0 als Animation), damit sich die Markierung von den Abteilungsfarben abhebt. |
| Akten und Endprodukte je Abteilung | `src/ui/item_painter.gd` | Datenvisualisierung | Zustand jeder Akte (Abteilung, dringend, fertig, markiert, festgehalten) muss auf wenigen Pixeln erkennbar sein. |
| Büromöbel, Deko und Maschinen der Spielwelt (Schreibtische, Aktenschränke, Archiv, Uhr, Flagge, Pflanzen, Bänke, Nummernautomaten, Aufrufanzeige, Foto-Kabine, Rechenmaschine, Stempel, Schilderdrucker, Scanner, Küche, Toilettenkabinen, Beschwerdehaufen, Beschwerde-Briefkasten mit Füllstand, Aufsteller „Schalter 13“, Aktenschredder und Abteilungsschredder) | `src/ui/office_painter.gd` | Fachliche Geometrie | Illustrationen der Spielwelt mit Zeichenbefehlen; jede Abteilung braucht ein eigenes erkennbares Objekt, das kein UI-Baustein liefert. |
| Rohrpost-Röhren, Kapseln, Akten-Marker, Ablehnungs-Ablage | `src/ui/world_view.gd`, `src/ui/item_painter.gd` | Datenvisualisierung | Röhrenverlauf, Kapselfarbe je Abteilung und Marker (Prüfdienst, Meldung, ungültig) zeigen Spielzustand auf der Karte; kein UI-Baustein bildet das ab. |
| Poststelle (Briefregal mit Füllstand, gelber Briefkasten, Briefträger, Briefumschläge, Briefhaufen auf dem Boden) | `src/ui/world_view.gd`, `src/ui/office_painter.gd`, `src/ui/item_painter.gd` | Datenvisualisierung | Der Füllstand des Briefregals und die Briefe im Umlauf zeigen den Lagerstand auf der Karte; Post-Gelb (`AppTheme.POST_YELLOW`) unterscheidet Briefe von Bürgerakten. |
| Werbe-Platzhalter | `src/ui/ad_placeholder.gd` | Technische Unmöglichkeit | Vollbild-Overlay mit Countdown, das nicht abgebrochen werden kann. `AppDialog` hat immer einen Bestätigen-Knopf und eignet sich daher nicht. Innen werden nur Library-Bausteine verwendet (`Dialog`-Karte, `Pill`, `progress`). |
| Virtueller Joystick | `src/ui/joystick_view.gd` | Technische Unmöglichkeit | Weder Material 3 noch die Library kennen eine analoge Bewegungssteuerung. |
| Auslastungsbalken im Aufgaben-Panel | `src/ui/task_panel.gd` | Datenvisualisierung | Farbwechsel grün/gelb/rot nach Auslastung über `ProgressBar` mit Rollenfarben. |
| Switch-Icons | `src/ui/app_theme.gd` | Technische Unmöglichkeit | Godot liefert kein M3-Switch-Design; die Icons werden aus Theme-Farben erzeugt. |

### Abweichungen vom Basis-Projekt
| Thema | Basis-Projekt | Diese App | Grund |
|---|---|---|---|
| UI-Technik | Jetpack Compose + `uikit` | Godot-Theme `AppTheme` + `UiKit`-Fabrik mit gleichnamigen Varianten (`PrimaryTonal`, `CardOutlined` …) | Spiel-Engine Godot vorgegeben |
| Übersetzungen | `values/strings.xml`, `values-de/strings.xml` | `i18n/translations.csv` | Godot-Lokalisierungsformat |
| Farbmodus | Hell und dunkel | Nur hell | Spielwelt-Farben sind auf helle Böden abgestimmt |
| Abteilungsfarben | App-Zusatz-Token | `AppTheme.DEPARTMENT_COLORS` | Bereichsidentität (Farbe + großes Icon + eigenes Endprodukt) |
| Bottom Sheets | `ModalBottomSheet` | `Sheet` (Scrim, `RADIUS_SHEET` oben) | Godot-Nachbau nach Spezifikation |
