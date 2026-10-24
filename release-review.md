# Release-Review – Idle Germany (Google Play)

Stand: 24.10.2026. Geprüft wurden Quellcode (`src/`), Projekt- und Export-Konfiguration, Übersetzungen, Lizenzdateien, Repository-Inhalt sowie der gebaute `build/idle-germany.apk` (Manifest dekodiert, Signatur, native Bibliotheken). Die Todos sind abhakbar; nach Erledigung abhaken und `FEATURES.md`/`context.md` nachziehen.

Legende: **[K]** Blocker für die Veröffentlichung · **[H]** vor dem ersten Release erledigen · **[M]** vor Monetarisierung oder bald danach · **[N]** nice to have.

---

## 0. Kurzfassung

Der Code selbst ist für den Play Store unkritisch: keine Netzwerkzugriffe, keine Berechtigungen, keine Systemaufrufe, keine personenbezogenen Daten, keine Debug-Ausgaben. Die Blocker liegen im Build, in der Lizenz-Attribution und in den fehlenden rechtlichen Texten:

| Nr. | Blocker | Beleg |
|---|---|---|
| 1 | **Debug-Build** – Manifest `debuggable=true` | APK-Manifest, `context.md` nennt `--export-debug` als Build-Befehl |
| 2 | **Debug-Signatur** – signiert mit dem Godot-Standardzertifikat (`CN=Godot, O=Stichting Godot`) | `META-INF/ANDROIDD.RSA` |
| 3 | **APK statt AAB** – Play akzeptiert für neue Apps nur App Bundles; dafür muss der Gradle-Build im Preset aktiv sein | `export_presets.cfg`: `gradle_build/use_gradle_build=false`, `export_format=0` |
| 4 | **Godot-Lizenz nicht vollständig beigelegt** – der Über-Text nennt nur „MIT“, die MIT-Lizenz verlangt Copyright-Hinweis und Lizenztext, dazu die Drittkomponenten der Engine | `ABOUT_TEXT` in `i18n/translations.csv` |
| 5 | **Keine Datenschutzerklärung** – Play verlangt für jede App eine URL im Play Console; in der App gibt es keinen Hinweis | Settings-Sheet, Übersetzungen |
| 6 | **Monetarisierungs-Platzhalter im Build** – Fake-Werbung (3 s) und „Testkauf“ von Dienstsiegeln ohne Geld | `src/ui/ad_placeholder.gd`, `src/ui/sheets/boost_sheet.gd` |

Positiv: keine `uses-permission`-Einträge, `targetSdk 36` erfüllt die Frist 31.08.2026, native Bibliotheken sind 16-KB-ausgerichtet, Skripte werden als Binär-Tokens (`.gdc`) exportiert, Launcher-Icon ist das eigene Design, `allowBackup=false`, Spielstand wird atomar geschrieben, geladene Werte werden geklemmt.

---

## 1. Messwerte des aktuellen Builds

| Merkmal | Wert | Bewertung |
|---|---|---|
| Paket | `com.wafflehq.idlegermany`, versionCode 1, versionName 1.0.0 | ok |
| minSdk / targetSdk / compileSdk | 24 / 36 / 36 (Godot 4.7.2 Templates) | ok, erfüllt Play-Frist 31.08.2026 (API 36) |
| `debuggable` | **true** | **[K]** |
| Signatur | Godot-Debug-Zertifikat, RSA 2048, gültig bis 2054 | **[K]** |
| Format | APK, 58 MB (arm64-v8a + armeabi-v7a, `libgodot_android.so` 76 MB unkomprimiert) | **[K]** AAB nötig; AAB liefert pro ABI aus |
| Berechtigungen | keine | sehr gut (kein INTERNET, keine AD_ID) |
| `allowBackup` | false | ok, bewusst (siehe 3.3) |
| `isGame` / `appCategory` | true / Spiel | ok |
| Aktivität | `exported=false`, `resizeableActivity=true`, `supportsPictureInPicture=true`, Hochformat | siehe 5.4 |
| 16-KB-Seiten | ELF `LOAD`-Alignment 0x4000 | ok (Pflicht seit 11/2025) |
| Skript-Export | `.gdc` (Binär-Tokens) + `.remap` | ok; kein Klartext, aber kein Schutz gegen Dekompilierung (akzeptabel) |
| Icon | eigenes SVG, adaptive Icons generiert (Vorder-/Hintergrund/monochrom) | ok |
| Engine | Godot 4.7.2 stable – laut Websuche aktuellstes 4.x (4.7.2 vom 18.08.2026, kein 4.8) | ok, vor Release erneut prüfen |

---

## 2. Sicherheit

### 2.1 Code (keine Befunde mit Handlungsbedarf)
Geprüft per Volltextsuche über `src/`: keine `HTTPRequest`, kein `OS.execute`/`shell_open`, kein `JavaScriptBridge`, keine `print`-Ausgaben, kein dynamisches Laden von Code, keine Intents. Einzige Systemaufrufe: `Time.get_unix_time_from_system()` (Offline-Ertrag), `OS.get_locale_language()` (Sprache), `DisplayServer`-Safe-Area. OWASP-Mobile-Themen (Injection, unsichere Kommunikation, WebView) sind nicht anwendbar.

### 2.2 Spielstand und Einstellungen
- Pfad `user://savegame.json`, Klartext-JSON, Schreiben über `.tmp` + `rename_absolute` (atomar, gut). Einstellungen `user://settings.cfg` mit Whitelist der Sprachen (gut).
- `GameState.from_dict` klemmt Zahlen (`maxf`, `clampi`), prüft IDs gegen `GameConfig`, kappt Listen (`MAX_RUNNERS` …). Gut.
- Lücke: typisierte Zwischenvariablen (`var dept_data: Dictionary = data.get("departments", {})`, `Department.from_dict(dept_data[dept_id])`, `Station.from_dict(...)`) brechen bei falschem Typ (z. B. Array statt Dictionary, String statt Zahl) mit Laufzeitfehler ab. Im Release-Build endet das vermutlich in `load_state() == null` → neues Spiel, also stiller Fortschrittsverlust, kein Absturz. Getestet ist nur „kein JSON“ (`test_load_rejects_corrupt_file`).
- Keine Integritätsprüfung: Geld, Ansehen und **Dienstsiegel** sind frei editierbar (Root/ADB-Backup ist durch `allowBackup=false` erschwert). Für ein Einzelspieler-Idle ohne echten Shop akzeptabel.

- [ ] [H] Tests ergänzen: Spielstand mit falsch typisierten Feldern (`departments` als Array, `money` als String, `stations`-Eintrag ohne `key`, `runners` mit Nicht-Dictionary) lädt ohne Fehler und fällt feldweise auf Defaults zurück; dafür in `from_dict` jedes `data.get(...)` vor dem Typ-Cast mit `is Dictionary`/`is Array` absichern (`tests/unit/test_services.gd`, `test_game_state.gd`).
- [ ] [H] Beschädigten Spielstand nicht stillschweigend verwerfen: vor dem Überschreiben nach `savegame.json.corrupt` kopieren und einmalig einen Dialog zeigen („Spielstand konnte nicht gelesen werden“), Strings in beiden Sprachen.
- [ ] [M] Sobald Siegel echtes Geld kosten: Siegel-Saldo und Käufe signieren (HMAC mit app-internem Schlüssel plus Play-Billing-Kaufbelege serverlos über `Purchase.getOriginalJson`-Verifikation) oder bewusst als „Cheaten erlaubt“ dokumentieren.

### 2.3 Zeitmanipulation (Offline-Ertrag)
`OfflineCalculator` nutzt die Systemuhr. Uhr vorstellen → bis zu 4 h Offline-Ertrag je Resume, mit „×2 mit Werbung“ verdoppelt; Uhr zurückstellen ist unschädlich (`now <= saved_at` → 0). Einzelspieler, daher **[M]**, aber bei echten Rewarded Ads ein Anreiz zu Ad-Fraud-ähnlichem Verhalten.

- [ ] [M] Offline-Ertrag nur gewähren, wenn `now - saved_at` plausibel ist: zusätzlich monotone Zeit (`Time.get_ticks_msec()` seit App-Start) für Pausen innerhalb der Sitzung verwenden; Zeitsprünge über den Deckel hinaus höchstens einmal je Kalendertag anrechnen (`saved_at`-Tag speichern).
- [ ] [M] Offline-Verdopplung je Resume auf einmal begrenzen (bereits implizit, da `apply` `saved_at` setzt – als Test festhalten).

### 2.4 Build-Hygiene
- `export_credentials.cfg`, `build/`, `*.apk`, `*.aab`, `*.idsig` sind ignoriert (gut). Keystore-Muster fehlten und wurden in `.gitignore` ergänzt (`*.keystore`, `*.jks`, `*.pepk`).
- Git-Historie enthält die private E-Mail-Adresse des Entwicklers; relevant nur, wenn das Repository öffentlich wird.

- [ ] [K] Release-Export statt Debug: `--export-release "Android"`; Build-Befehl in `context.md` anpassen.
- [ ] [K] Eigenen Upload-Keystore erzeugen (`keytool -genkeypair -v -keystore upload.keystore -alias upload -keyalg RSA -keysize 2048 -validity 10000`), außerhalb des Repos ablegen, Passwörter in `export_credentials.cfg` (ignoriert), Play App Signing aktivieren, Keystore sichern (Verlust = kein Update mehr möglich).
- [ ] [K] Im Preset `gradle_build/use_gradle_build=true`, `gradle_build/export_format=1` (AAB), Android-Build-Template installieren (`Projekt → Android-Build-Template installieren`), JDK 17 + Android SDK (Build-Tools 35/36) auf dem Build-Rechner. Projektregel „Kein Gradle“ in `FEATURES.md` auf „nur für den Store-Export“ einschränken (die Gradle-Sperre gilt für Tests/Zwischenschritte, nicht für den Store-Build).
- [ ] [H] `version/code` je Upload erhöhen (Vorschlag: `JJMMTTnn` oder fortlaufend), `version/name` semantisch.
- [ ] [N] Prüfen, ob `screen/immersive_mode` und `package/exclude_from_recents` den Erwartungen entsprechen; `supportsPictureInPicture` ist Godot-Default und harmlos.

---

## 3. Datenschutz

### 3.1 Ist-Zustand
- Es werden **keine Daten erhoben, gespeichert oder übertragen**, die eine Person betreffen. Keine Werbe-ID, keine Analyse, keine Crash-Reports, kein Netzwerk, keine Konten.
- Lokal gespeichert: Spielstand (Spielzustand, Zähler wie `ads_watched`), Sprache. Beides im App-Privatspeicher; `allowBackup=false` → kein Google-Backup, kein ADB-Backup.
- Gerätesprache wird nur lokal gelesen.

Damit ist die Data-Safety-Deklaration „Es werden keine Daten erhoben oder weitergegeben“ korrekt. Eine Datenschutzerklärung ist trotzdem Pflicht (Play Console verlangt für jede App eine URL; zusätzlich Art. 13 DSGVO, sobald irgendeine Verarbeitung dazukommt).

- [ ] [K] Datenschutzerklärung (DE + EN) auf einer öffentlich erreichbaren URL veröffentlichen und im Play Console hinterlegen. Inhalt: Verantwortlicher mit Anschrift, „keine Datenerhebung“, lokale Speicherung des Spielstands, Hinweis auf Google Play (Store-Daten liegen bei Google), Rechte der Betroffenen, Kontakt.
- [ ] [H] In der App unter „Einstellungen → Über“ den Punkt „Datenschutz“ mit `OS.shell_open(URL)` ergänzen (Strings `ACTION_PRIVACY`, `PRIVACY_HINT` in beiden Sprachen); alternativ Kurzfassung als Text im Sheet, damit kein Netz nötig ist.
- [ ] [H] Data-Safety-Formular: „keine Daten erhoben“, „keine Daten geteilt“, Daten verschlüsselt bei Übertragung: n/a, Löschung: durch Deinstallation bzw. „Alle Akten schreddern“.
- [ ] [H] Zielgruppe im Play Console auf „13+“/„nicht für Kinder“ setzen. Die App ist zwar harmlos, aber eine Kinder-Zielgruppe zieht die Families-Policy nach sich (zertifizierte Werbe-SDKs, eingeschränkte Monetarisierung, keine Werbe-ID).

### 3.2 Bei späterer Monetarisierung (Werbung, Käufe)
- [ ] [M] AdMob/Rewarded Ads: Google-UMP-SDK für Einwilligung (DSGVO/TDDDG, TCF 2.2) **vor** dem ersten Ad-Request; Werbe-ID-Berechtigung `com.google.android.gms.permission.AD_ID` kommt automatisch mit, muss im Data-Safety-Formular (Geräte-IDs, Werbung) deklariert werden; Datenschutzerklärung um AdMob-Abschnitt ergänzen; „Werbung enthalten“ im Store-Eintrag anhaken; Altersfreigabe neu beantworten.
- [ ] [M] Play Billing für Siegel: Kaufbelege werden lokal verifiziert; keine eigenen Server → keine zusätzlichen Daten, aber Datenschutzerklärung um Google-Play-Zahlungsabwicklung ergänzen.
- [ ] [M] Crash-Reporting nur mit Hinweis in der Datenschutzerklärung und Data Safety (Gerätedaten, Diagnose); vorerst besser den Play-Pre-Launch-Report und Android Vitals nutzen (kein SDK nötig).

### 3.3 Produktentscheidung Backup / Gerätewechsel
`allowBackup=false` bedeutet: Gerätewechsel oder Neuinstallation löscht den Fortschritt. Für ein Langzeit-Idle ist das ein Retention-Risiko.

- [ ] [N] Entscheiden: Android Auto Backup (`user_data_backup/allow=true`, Daten liegen dann verschlüsselt im Google-Konto des Nutzers → in Datenschutzerklärung nennen) oder Play Games Saved Games (Google-Login, Data Safety). Spielstand ist mit < 1 MB backup-tauglich. Bis dahin im Reset-Text und FAQ klar sagen, dass der Fortschritt nur auf dem Gerät liegt (Text `RESET_HINT` tut das bereits).

---

## 4. Lizenzen und Urheberrecht

### 4.1 Eingesetzte Komponenten
| Komponente | Lizenz | Kommerziell nutzbar | Im APK enthalten | Attribution vorhanden |
|---|---|---|---|---|
| Godot Engine 4.7.2 + Drittkomponenten (FreeType, mbedTLS, ENet, zlib, miniupnpc, …) | MIT bzw. jeweils eigene permissive Lizenzen | ja | ja (`libgodot_android.so`) | **unvollständig**: nur „made with Godot Engine (MIT)“ |
| Geist (Regular/SemiBold/Bold) | SIL OFL 1.1 | ja | ja, `assets/fonts/OFL.txt` wird mit exportiert | ja (Über-Text) |
| Material Icons Regular | Apache 2.0 | ja | ja, `MaterialIcons-LICENSE.txt` wird mit exportiert | ja (Über-Text) |
| GUT 9.7.1 (inkl. Fonts Anonymous Pro, Courier Prime, Lobster Two) | MIT / OFL | ja | nein (`exclude_filter`) | nicht nötig |
| App-Icon, alle Grafiken | selbst gezeichnet (Code) | – | ja | ja |

- [ ] [K] Godot-Lizenzpflicht erfüllen: Lizenz-Sheet „Lizenzen“ unter Einstellungen mit `Engine.get_license_text()` (MIT-Text mit Copyright-Zeile) und den Drittlizenzen aus `Engine.get_license_info()`/`Engine.get_copyright_info()`, dazu die OFL- und Apache-Texte aus `assets/fonts`. Scrollbarer, read-only Text reicht. Unit-Test, dass das Sheet alle Komponenten listet.
- [ ] [H] Store-Beschreibung oder „Über“: Hinweis „Godot Engine“-Logo-Nutzung ist optional, wenn verwendet gelten die Godot-Logo-Richtlinien (CC BY 4.0).
- [ ] [N] `assets/fonts/OFL.txt` und `MaterialIcons-LICENSE.txt` von `export_filter` ausnehmen, sobald das Lizenz-Sheet die Texte als eingebettete Strings/Ressourcen trägt (sonst doppelt), oder bewusst so lassen.

### 4.2 Eigene Inhalte und Rechte Dritter
- **Name „Idle Germany“ / Entwicklername „WaffleHQ“**: keine Markenrecherche dokumentiert.
- **Hoheitszeichen**: Die schwarz-rot-goldene Flagge wird dekorativ gezeichnet (`office_painter.gd`), das ist erlaubt. Bundesadler, Landeswappen oder echte Dienstsiegel-Nachbildungen werden nicht verwendet (geprüft: `Icons.SEAL` ist ein Material-Icon). Beibehalten.
- **Satire über Behörden**: fiktive Ämter, fiktive Bewertungs-Autoren (Heinz K., Frau Yilmaz, …), keine realen Personen, keine Marken. Unkritisch. Die Behörden-Bezeichnungen (Bürgeramt, Zollamt …) sind generische Begriffe.
- **Konzeptmaterial `docs/concept/`**: PDF mit Metadaten `Author: OpenAI` (KI-Text), drei Infografiken ohne EXIF und ohne Quellenangabe (optisch KI-generiert, enthalten Fantasie-Logos wie „Customs Authority“). Wird nicht exportiert (`exclude_filter docs/*`, `.gdignore`), liegt aber im Repository. Projektregel: zu Bildern immer eine Quelle hinterlegen.
- **Übersetzungen/Texte**: eigene Texte; eine Zeile wechselt die Anrede („Schön, dass Sie wieder da sind“ gegen „du“) – Kosmetik.

- [ ] [H] Markenrecherche „Idle Germany“ und „WaffleHQ“ bei DPMA/EUIPO (Klasse 9, 41) und im Play Store; Ergebnis hier vermerken. Bei Konflikt umbenennen, bevor der Store-Eintrag mit Paketname fixiert ist (Paketname ist später unveränderlich).
- [ ] [H] `docs/concept/README.md` anlegen: Herkunft jeder Datei (Werkzeug, Datum, Prompt-Kontext, Nutzungsrecht); Dateien ohne klärbare Herkunft entfernen. Dateinamen ohne Leerzeichen.
- [ ] [N] `FMT_OFFLINE_TEXT`/`OFFLINE_TITLE` auf „du“ vereinheitlichen.

---

## 5. Play-Store-Anforderungen (Technik)

### 5.1 Build und Upload
Siehe Blocker in 2.4 (Release, Signatur, AAB). Zusätzlich:

- [ ] [H] Vor jedem Upload prüfen: `debuggable` fehlt, Signatur = Upload-Key, `targetSdk ≥ 36`, keine `uses-permission`. Als Skript `tests/tools/check_release.sh` (unzip + Python-AXML-Parser wie in diesem Review) ablegen.
- [ ] [H] Pre-Launch-Report im Play Console aktiv lassen und beim ersten internen Test auswerten (Abstürze, ANR, Barrierefreiheit, Screenshots auf Tablets).
- [ ] [N] `armeabi-v7a` prüfen: 32-Bit-Geräte sind 2026 selten; AAB liefert ohnehin pro ABI aus, daher ohne Nachteil belassen.

### 5.2 Ziel-API und Plattformverhalten (targetSdk 36 / Android 16)
- **Große Bildschirme**: Ab targetSdk 36 ignoriert Android 16 auf Displays ≥ 600 dp (Tablets, aufgeklappte Foldables) die Hochformat-Sperre und `resizeableActivity`. Die App läuft dort im Querformat bzw. frei skaliert. Stretch `canvas_items`/`expand` zeigt dann mehr Welt, aber HUD, Sheets (`custom_minimum_size.x = 560`) und Joystick sind für 720 px Breite ausgelegt.
- **Predictive Back**: Für targetSdk 36 ist der Back-Callback standardmäßig aktiv. Die App reagiert über `NOTIFICATION_WM_GO_BACK_REQUEST` (Sheet schließen, sonst speichern + beenden). Verhalten mit Zurück-Geste und Vorschau-Animation ist ungetestet.
- **Edge-to-Edge**: Pflicht ab targetSdk 35. Oben wird die Safe-Area berücksichtigt (`_safe_top`), unten nicht; Immersive Mode blendet die Navigationsleiste aus, bei Wischgesten erscheint sie transient über der Bottom-Bar.
- **App-Beenden per Zurück**: `get_tree().quit()` ist auf Android erlaubt, aber unüblich; Google empfiehlt in den Hintergrund zu gehen.

- [ ] [H] Tablet-/Querformat-Test (Emulator Pixel Tablet, API 36; Foldable): Sheets zentriert mit Maximalbreite, HUD-Bottom-Bar nicht überdehnt, Joystick erreichbar. Falls nicht sinnvoll lösbar: in den Store-Einstellungen Formfaktor „Tablets“ nicht bewerben (Play zeigt Hinweis „für Tablets nicht optimiert“), oder Layout anpassen.
- [ ] [H] Zurück-Geste auf Android 16 testen (Sheet offen, Dialog offen, Tutorial-Karte, Hauptansicht). Beenden durch `quit()` durch `get_tree().root.propagate_notification(NOTIFICATION_APPLICATION_PAUSED)` + „Zurück ins System“ (`OS.move_window_to_background` gibt es nicht; stattdessen `quit()` beibehalten oder nur speichern und Android die Geste ausführen lassen, `quit_on_go_back=true`).
- [ ] [M] Bottom-Safe-Area analog zu `_safe_top` an `Hud.bottom_bar` durchreichen.

### 5.3 Qualität
- [ ] [H] Manuelle Testrunde auf echtem Gerät mit Release-AAB (über internen Test-Track installiert): Start ohne Spielstand, Tutorial komplett, Offline-Dialog nach > 60 s, Pausieren/Resume, Sprache wechseln, Reset, Rotationsverhalten, Low-End-Gerät (RAM, FPS bei vielen Bürgern).
- [ ] [H] Startzeit prüfen: 76 MB native Bibliothek, Fonts werden beim Start geladen; Ziel < 2 s auf Mittelklasse. Android Vitals „Slow cold start“ beobachten.
- [ ] [N] `run/max_fps=60` und `low_processor_mode=false`: Akku-Verbrauch im Idle beobachten; optional Frame-Limit im Hintergrund/Sheet senken.

---

## 6. Play-Store-Anforderungen (Konto, Eintrag, Recht)

### 6.1 Entwicklerkonto
- Identitätsprüfung ist für alle Konten Pflicht: Name, Anschrift, E-Mail und Telefon werden verifiziert; **Name und Anschrift werden im Store öffentlich angezeigt**. Als Organisation (z. B. „WaffleHQ“ als Firma) wird eine D-U-N-S-Nummer benötigt.
- **DSA (Digital Services Act)**: Händler-/Nicht-Händler-Erklärung im Play Console. Mit Werbung oder Käufen ist man Händler → Kontaktdaten müssen für EU-Nutzer sichtbar sein.
- Neue Privatkonten (seit 11/2023) müssen vor dem Produktions-Release einen **geschlossenen Test mit mindestens 20 Testern über 14 Tage** durchlaufen und dann den Produktionszugang beantragen.
- Play-Console-Richtlinie wird zum 30.09.2026 aktualisiert (vollständige Konto-Angaben, verknüpfte Profile) – vor Einreichung die aktuelle Fassung lesen.

- [ ] [K] Entwicklerkonto verifizieren, Kontotyp (Privatperson/Organisation) festlegen; wenn die öffentliche Anschrift unerwünscht ist, Geschäftsadresse/Postfach-Lösung prüfen, bevor die Verifizierung läuft.
- [ ] [K] DSA-Erklärung abgeben (vor Monetarisierung „Nicht-Händler“ nur, wenn wirklich keine Einnahmen; sonst „Händler“).
- [ ] [H] 20 Tester für 14 Tage organisieren (interner/geschlossener Track), Feedback dokumentieren.

### 6.2 Rechtliches (Deutschland/EU)
- **Impressum (§ 5 DDG)**: Pflicht für geschäftsmäßige Telemedien; eine kostenlose, werbefreie Hobby-App ist umstritten, mit Werbung/IAP klar pflichtig. Play zeigt Name/Anschrift des Entwicklers; ein eigenes Impressum in der App und auf der Datenschutz-Seite ist die sichere Variante.
- **Verbraucherrecht bei In-App-Käufen**: Preisangabe inkl. USt, Widerrufsbelehrung und Verzichtserklärung für digitale Inhalte (Google übernimmt im Bestellfluss, die Datenschutz-/Impressum-Seite sollte darauf verweisen). Der aktuelle „Testkauf“ ist ohne echtes Geld rechtlich unproblematisch, darf aber nicht als Kauf erscheinen (siehe 7).
- **Jugendschutz / IARC**: Inhalt ist Humor über Verwaltung, „Verleumdung anzeigen“, Krankmeldungs-Sprüche („ich sterbe. Ein bisschen.“). Kein Glücksspiel (Siegel-Boosts sind deterministisch), keine Gewalt. Erwartung: USK 0/PEGI 3. Rewarded Ads und Käufe im Fragebogen angeben.
- **Behörden-Richtlinie von Play**: Apps dürfen nicht den Eindruck erwecken, offizielle Regierungs-Apps zu sein. Titel „Idle Germany“ und Satire sind in Ordnung, solange Store-Text und Icon keine amtliche Herkunft suggerieren (kein Adler, kein „offiziell“, keine behördliche Domain).

- [ ] [H] Impressum-Text (DE/EN) als Abschnitt der Datenschutz-Seite und in der App unter „Über“ (Name, Anschrift, E-Mail; bei Gewerbe USt-ID).
- [ ] [H] IARC-Fragebogen vorbereiten (Antworten hier notieren, damit spätere Updates konsistent bleiben).
- [ ] [H] Store-Beschreibung so formulieren, dass klar „Spiel/Satire“ erkennbar ist („Idle-Spiel“, „fiktive Behörde“); keine Formulierungen wie „offiziell“, „Behörden-App“.

### 6.3 Store-Eintrag (Assets und Texte)
Vorhanden: `assets/icon.svg` (512 px), `config/description` (nur Englisch), Screenshot-Werkzeug `tests/tools/screenshot.gd`.

- [ ] [H] App-Icon 512 × 512 PNG (aus SVG rendern, ohne Transparenz an den Ecken: Play nutzt eigene Maske).
- [ ] [H] Feature-Grafik 1024 × 500 (eigenes Design, Quelle dokumentieren).
- [ ] [H] Mindestens 4 Telefon-Screenshots 9:16 (per `screenshot.gd`, beide Sprachen), 7″- und 10″-Tablet-Screenshots, falls Tablets beworben werden.
- [ ] [H] Kurzbeschreibung (≤ 80 Zeichen) und Beschreibung (≤ 4000) in DE und EN; `config/description` in `project.godot` ebenfalls lokalisieren oder entfernen.
- [ ] [H] Kategorie „Simulation“, Tags (Idle, Management), Kontakt-E-Mail (wird öffentlich), Website optional.
- [ ] [H] Formular „App-Inhalte“: Datenschutz-URL, Werbung (aktuell nein), Zielgruppe, Data Safety, Behördlichkeit („nein“), Finanz-Features („nein“), Gesundheit („nein“).
- [ ] [N] Release-Notes-Vorlage DE/EN (`docs/release-notes/`), damit jedes Update die Play-Felder füllt.

---

## 7. Monetarisierungs-Platzhalter

Ist-Zustand im Build:
- `AdPlaceholder`: Vollbild-Overlay mit Pill „Anzeige“, Fantasie-Slogan, 3 s Countdown, Text „Platzhalter – hier läuft später echte Werbung“; gewährt danach den Boost bzw. die Offline-Verdopplung. Aufrufe: Offline-Dialog (`ACTION_DOUBLE_AD`), Boost-Karten, Krankenschein per Werbung (`cure_by_ad`).
- Siegel-Shop: drei Buttons „10/30/80 Siegel“, Dialog „Testkauf – es wird nichts berechnet“, schreibt Siegel direkt gut.
- `FEATURES.md` sagt unter Ausnahmen „Keine Monetarisierung“ – das ist überholt (Boosts, Siegel, Werbe-Platzhalter sind implementiert).

Risiken: Ein als „Anzeige“ beschriftetes Fake-Ad kann im Review als irreführend gelten; ein „Kauf“-Flow ohne Play Billing widerspricht der Zahlungs-Richtlinie, selbst wenn kein Geld fließt (Tester sehen „Testkauf“); kostenlose Siegel entwerten den späteren echten Shop für Early Adopter.

- [ ] [K] Vor dem Store-Build entscheiden: (a) Werbung und Shop per Feature-Flag in `GameConfig` (`MONETIZATION_ENABLED := false`) ausblenden – Boosts dann nur über Siegel aus Zielen/Start, Shop-Abschnitt und „×2 mit Werbung“ verborgen; oder (b) echt umsetzen (AdMob Rewarded über ein Godot-Android-Plugin, Play Billing Library 7/8 über Godot-Plugin). Für den ersten Release wird (a) empfohlen; die Siegel-Wirtschaft bleibt dadurch testbar.
- [ ] [K] `AD_PLACEHOLDER_NOTE`, `SEAL_SHOP_MOCK`, `ACTION_TEST_BUY` dürfen in keinem Store-Build sichtbar sein (Test: bei deaktiviertem Flag existieren die Knoten nicht; `tests/unit/test_boost_ui.gd` erweitern).
- [ ] [M] Bei echter Werbung: UMP-Consent (3.2), Belohnung nur nach `onUserEarnedReward`, Fallback bei No-Fill (Boost per Siegel anbieten), Frequency Cap aus `cooldown` behalten; Werbung nie unter 13 Jahren ausspielen (Zielgruppe!).
- [ ] [M] Bei echten Käufen: Produkt-IDs in `GameConfig` (`SEAL_PACKS` ↔ SKU), Wiederherstellung verbrauchter Käufe über `queryPurchases` beim Start, Preisanzeige aus Play (lokalisiert) statt Konstante, Quittung lokal speichern.
- [ ] [H] `FEATURES.md`-Ausnahme „Keine Monetarisierung“ ersetzen durch „Monetarisierung als Platzhalter/Feature-Flag“ und die Boost-/Siegel-Features dort beschreiben, falls noch nicht geschehen.

---

## 8. Dokumentation und Projektpflege
- [ ] [H] `context.md`: Build-Befehl auf Release-Export + AAB ändern, Abschnitt „Release“ mit Keystore-Ablage (Pfad außerhalb Repo), Play-Console-Zugang, Versionsschema.
- [ ] [H] `.gitignore`: ergänzt um `*.keystore`, `*.jks`, `*.pepk` (erledigt in diesem Review); zusätzlich `android/` ist bereits ignoriert (Gradle-Build-Template landet dort).
- [ ] [N] `docs/store/` mit Store-Texten, IARC-Antworten, Datenschutz- und Impressum-Quelltexten versionieren.

---

## 9. Empfohlene Reihenfolge
1. Entscheidung Monetarisierung (7) → Feature-Flag, Platzhalter aus dem Build.
2. Lizenz-Sheet (4.1) und Datenschutz/Impressum-Texte + URL (3.1, 6.2).
3. Build-Kette: Gradle-Template, Upload-Key, Release-AAB, Prüfskript (2.4, 5.1).
4. Spielstand-Robustheit und Tests (2.2).
5. Entwicklerkonto, DSA, 20-Tester-Phase mit Pre-Launch-Report, Tablet-/Back-Geste-Tests (6.1, 5.2, 5.3).
6. Store-Assets und -Texte, IARC, Data Safety (6.3).
7. Nach Release: Backup-Strategie, Zeitmanipulation, Monetarisierung echt (3.3, 2.3, 7 [M]).

Quellen zu Fristen und Richtlinien (Stand der Websuche vom 24.10.2026): Google Play „Target API level requirements“ (API 36 ab 31.08.2026, Verlängerung bis 01.11.2026 beantragbar), Play-Console-Anforderungen (Identitätsprüfung, Aktualisierung zum 30.09.2026), Godot-Release-Blog (4.7.2 stable). Vor Einreichung erneut gegen die aktuellen Play-Richtlinien prüfen.
