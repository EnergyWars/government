# Styling-Ausnahmen – Feedback Commander

### Custom-Elemente
| Element | Datei | Kriterium (Abschnitt 7) | Begründung |
|---|---|---|---|
| – | – | – | Keine Custom-Elemente; alle Flächen und Bedienelemente sind Library-Bausteine. |

### Abweichungen vom Basis-Projekt
| Thema | Basis-Projekt | Diese App | Grund |
|---|---|---|---|
| Hauptseite ohne FAB | Listen-Screen mit `AppFab(Primary)` | Startseite ohne FAB, Aktionen „Senden“ und „Nur APK bauen“ als `AppButton` in der Feedback-Karte | Die Hauptaktion ist das Absenden eines Textes direkt auf der Startseite, nicht das Anlegen eines Listeneintrags; ein FAB würde nur auf das Feld darüber verweisen. |
| `SettingsScaffold` | `onBack` Pflicht, kein Aktions-Slot | `onBack` optional, `actions`- und `snackbarHost`-Slot | Startseite, Setup und Anmeldung nutzen dasselbe Gerüst ohne Zurück; Titelleisten-Aktionen (Verbindung wechseln, Abmelden) und Snackbars brauchen Slots. Generisch sinnvoll, Rückführung ins Basis-Projekt vorgesehen. |
| `AppTextField` | ohne `singleLine`, `visualTransformation`, `supportingText` | Parameter ergänzt | Passwortfeld und einzeilige Adress-/Portfelder. Generisch sinnvoll, Rückführung ins Basis-Projekt vorgesehen. |
| Protokoll-Schrift | – | `AppTextStyles.code` (Geist Mono 12 sp) in `ui/theme/Type.kt` | Mehrzeiliges Server-Protokoll braucht eine kompakte Monospace-Schrift; liegt als Theme-Token, nicht im Screen. |
