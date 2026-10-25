# Feedback-Server

Kleiner HTTP-Server, über den du von unterwegs Feedback an Claude Code schickst. Claude setzt das Feedback im Projekt um, danach baut der Server per Godot die Android-APK. Die fertige APK lädst du direkt im Browser herunter.

Reine Python-Standardbibliothek (Python ≥ 3.12), keine Fremdpakete.

## Ablauf

1. Auf dem Handy die Weboberfläche öffnen, mit dem Passwort anmelden, Feedback eingeben, „Senden“.
2. Der Auftrag landet in der Warteschlange (SQLite, `data/jobs.db`). Es läuft immer genau ein Auftrag.
3. **Analyse:** Ein Router-Agent (`claude -p --model sonnet --effort low --tools ""` mit `--json-schema`) bewertet die Komplexität und wählt Modell (`haiku`/`sonnet`/`opus`) und Effort (`low` … `max`) samt kurzer Begründung. Scheitert die Analyse, gilt `opus`/`high`.
4. **Umsetzung:** Ein neuer Agent `claude -p --model <wahl> --effort <wahl>` (headless, Stream-JSON) läuft im Projektstamm, der Feedback-Text geht über stdin rein (keine Shell, keine Argument-Injection). Das Live-Protokoll steht in `data/logs/<id>.log` und ist in der Oberfläche sichtbar, ebenso die Modellwahl.
5. Danach `godot --import` und `godot --export-debug Android`. Die APK wird nach `data/apks/idle-germany-<id>.apk` kopiert, die letzten `keep_apks` bleiben erhalten.
6. „Neueste APK laden“ oder Download direkt am Auftrag.

Mit „Im letzten Gespräch fortsetzen“ wird die letzte Claude-Sitzung per `--resume` weitergeführt (z. B. für Nachbesserungen). „Nur APK bauen“ überspringt Claude.

## Einrichtung

```sh
cd feedback-server
cp config.example.json config.json   # Passwort unter "token" eintragen
python3 -m feedback_server            # liest config.json, alternativ --config <pfad>
```

Das Passwort (mindestens 3 Zeichen) kann auch über die Umgebungsvariable `FEEDBACK_TOKEN` gesetzt werden (hat Vorrang). Unter 16 Zeichen warnt der Server beim Start: dann nur über VPN erreichbar machen. Beim Start werden alle LAN-Adressen protokolliert (`Reachable at http://…`).

## Auto-Discovery (wie beim Commander)

`GET /status` antwortet ohne Anmeldung immer mit `204` und leerem Inhalt. Damit findet derselbe Subnetz-Scan wie in der Commander-App den Server: alle Adressen des eigenen /24-Netzes parallel abfragen, die erste mit `204` gewinnt. Von einem anderen Rechner im LAN:

```sh
python3 -m feedback_server.discovery              # Port 8787, alle eigenen LAN-Netze
python3 -m feedback_server.discovery --port 8787 --ip 192.168.178.20
```

Ausgabe: `http://<ip>:<port>`. Docker-, VM- und Loopback-Schnittstellen werden ignoriert.

### Als Dienst (startet mit dem Rechner)

```sh
mkdir -p ~/.config/systemd/user
cp feedback-server.service ~/.config/systemd/user/
systemctl --user daemon-reload
systemctl --user enable --now feedback-server
loginctl enable-linger "$USER"        # läuft auch ohne angemeldete Sitzung
journalctl --user -u feedback-server -f
```

## Von unterwegs erreichen

Der Server spricht nur HTTP. Das Token darf nicht unverschlüsselt durchs Internet gehen, daher **kein** einfaches Port-Forwarding.

- **WireGuard über die FRITZ!Box** (empfohlen, schon vorhanden): In der FRITZ!Box unter *Internet → Freigaben → VPN (WireGuard)* das Handy einrichten. Dann von unterwegs `http://192.168.178.55:8787` öffnen.
- **Tailscale**: auf Rechner und Handy installieren, dann `http://<tailscale-name>:8787`.
- **Cloudflare Tunnel / Reverse-Proxy mit HTTPS**: dann in `config.json` `"secure_cookie": true` und, falls der Proxy lokal läuft, `"trust_forwarded_for": true` setzen.

## API

Alle Endpunkte außer `/api/health` und `/status` brauchen entweder das Session-Cookie (Weboberfläche) oder `Authorization: Bearer <passwort>`. POST-Anfragen erwarten `Content-Type: application/json`.

| Methode | Pfad | Zweck |
|---|---|---|
| GET | `/api/health` | Lebenszeichen (ohne Anmeldung) |
| GET | `/status` | Discovery-Probe, immer `204` leer (ohne Anmeldung) |
| GET | `/api/status` | Zustand: `idle`/`busy`, laufender Auftrag, Warteschlange, neueste APK, Laufzeit, Router- und Modellwahl |
| POST | `/api/feedback` | `{"feedback": "...", "resume": false}` → neuer Auftrag |
| POST | `/api/build` | Nur APK bauen |
| GET | `/api/jobs` | Letzte 50 Aufträge + `latest_apk` |
| GET | `/api/jobs/<id>` | Auftrag + Protokoll-Ende |
| POST | `/api/jobs/<id>/cancel` | Wartenden oder laufenden Auftrag abbrechen |
| GET | `/apk/latest`, `/apk/<id>` | APK herunterladen |

Beispiel (z. B. aus einer Kurzbefehle-/Tasker-Automation):

```sh
curl -X POST http://192.168.178.55:8787/api/feedback \
  -H "Authorization: Bearer 123" -H "Content-Type: application/json" \
  -d '{"feedback": "Der Kaffee-Button soll größer sein"}'
```

## Konfiguration (`config.json`)

| Schlüssel | Standard | Bedeutung |
|---|---|---|
| `token` | – (Pflicht, ≥ 3 Zeichen) | Passwort |
| `host` / `port` | `0.0.0.0` / `8787` | Adresse |
| `project_dir` | Elternordner von `feedback-server` | Projekt, in dem Claude arbeitet |
| `data_dir` | `feedback-server/data` | Datenbank, Protokolle, APKs |
| `claude_bin` | `claude` aus dem PATH | Claude-CLI |
| `claude_args` | `--permission-mode acceptEdits` | Zusätzliche CLI-Argumente (ohne `--model`/`--effort`) |
| `allowed_tools` | Read, Edit, Write, Glob, Grep, TodoWrite, git status/diff/log, Godot | Ohne Rückfrage erlaubte Werkzeuge |
| `prompt_template` | siehe `config.py` | Muss `{feedback}` enthalten |
| `router_model` / `router_effort` | `sonnet` / `low` | Modell der Komplexitäts-Analyse |
| `router_prompt` | siehe `config.py` | Muss `{feedback}` enthalten, optional `{models}`, `{efforts}` |
| `router_timeout` | 300 s | Zeitlimit der Analyse |
| `model_choices` | `haiku`, `sonnet`, `opus` | Wählbare Modelle, aufsteigend nach Stärke (z. B. `fable` ergänzen) |
| `effort_choices` | `low` … `max` | Wählbare Effort-Stufen |
| `fallback_model` / `fallback_effort` | `opus` / `high` | Wahl, wenn die Analyse scheitert |
| `godot_bin`, `export_preset`, `apk_path`, `apk_name` | Godot 4.7.2, `Android`, `build/idle-germany.apk`, `idle-germany` | Build |
| `agent_timeout` / `build_timeout` | 3600 / 1800 s | Zeitlimits |
| `keep_apks` | 10 | Aufbewahrte APKs |
| `max_feedback_length` | 20000 | Zeichen |
| `session_days` | 30 | Gültigkeit des Login-Cookies |
| `secure_cookie` | `false` | Cookie nur über HTTPS |
| `trust_forwarded_for` | `false` | `X-Forwarded-For` für die Login-Sperre auswerten |

Werkzeuge außerhalb von `allowed_tools` werden im nicht-interaktiven Modus abgelehnt. Wer Claude freie Hand geben will, setzt `claude_args` auf `["--permission-mode", "bypassPermissions"]` – dann aber nur über VPN erreichbar machen.

## Sicherheit

- Passwort-Vergleich zeitkonstant, Login-Cookie HMAC-signiert, `HttpOnly`, `SameSite=Strict`.
- Nach 5 Fehlversuchen pro IP 15 Minuten Sperre (Login und Bearer).
- Strikte Content-Security-Policy, keine Inline-Skripte, alle Texte per `textContent` bzw. HTML-escaped.
- Anfragekörper max. 256 KB, APK-Downloads nur aus `data/apks`.

## Tests

```sh
python3 -m unittest discover -s tests -t .
```
