# Styling-Ausnahmen

### Custom-Elemente
| Element | Datei | Kriterium (Abschnitt 7) | Begründung |
|---|---|---|---|
| Spielwelt (Grundriss, Räume, Stationen, Tische, Maschinen, Fächer, Figuren, Fahrzeuge) | `src/ui/world_view.gd` | Fachliche Geometrie | Die begehbare Draufsicht ist der Kern des Spiels; kein UI-Baustein bildet Räume, Laufwege und Figuren ab. |
| Akten und Endprodukte je Abteilung | `src/ui/item_painter.gd` | Datenvisualisierung | Zustand jeder Akte (Abteilung, dringend, fertig, markiert, festgehalten) muss auf wenigen Pixeln erkennbar sein. |
| Büromöbel, Deko und Maschinen der Spielwelt (Schreibtische, Aktenschränke, Uhr, Flagge, Pflanzen, Bänke, Nummernautomat, Foto-Kabine, Rechenmaschine, Stempel, Schilderdrucker, Scanner, Küche, Beschwerdehaufen, Aktenschredder) | `src/ui/office_painter.gd` | Fachliche Geometrie | Illustrationen der Spielwelt mit Zeichenbefehlen; jede Abteilung braucht ein eigenes erkennbares Objekt, das kein UI-Baustein liefert. |
| Rohrpost-Röhren, Kapseln, Akten-Marker, Ablehnungs-Ablage | `src/ui/world_view.gd`, `src/ui/item_painter.gd` | Datenvisualisierung | Röhrenverlauf, Kapselfarbe je Abteilung und Marker (Prüfdienst, Meldung, ungültig) zeigen Spielzustand auf der Karte; kein UI-Baustein bildet das ab. |
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
