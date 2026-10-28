# Balancing – Review und Todos

Stand: 27.10.2026 (Upgrade-Neugliederung in 4.13, Amtsstufen in 4.14, Einstieg und Unterbrechungen in 4.18). Grundlage: Code-Review von `game_config.gd`, `formulas.gd`, `simulation.gd`, `progression.gd`, `goal_tracker.gd`, `offline_calculator.gd`, dazu Simulationen mit `tests/tools/balance_bot.gd` (8 h, 30 min bzw. 480 min aktiv) und einem Diagnose-Bot (Stationen alle 5 min, Varianten „ohne Krankheit“ / „ohne Ansehensverlust“).

Ziele des Balancings (Vorgabe):
1. Bei jeder neuen Abteilung muss der Spieler erst viel selbst machen.
2. Es gibt durchgängig kleine Dinge zu verbessern (kein Leerlauf zwischen großen Käufen).
3. Lange Spielerbindung, Spiel soll süchtig machen (kurze Belohnungsschleifen, klare nächste Ziele, nie Stillstand, nie Rückschritt ohne Gegenmittel).

Legende: **[K]** kritisch (blockiert Fortschritt), **[H]** hoch, **[M]** mittel, **[N]** niedrig. `[ ]` offen, `[x]` umgesetzt, `[~]` bewusst verworfen.

Zusätzliches Designziel: **Engpässe entstehen häufig und bewusst.** Der Spieler muss oft selbst eingreifen, regelmäßig einzelne Stationen ausbauen und kann einen Engpass mit Boosts oder Werbung überbrücken. Ansehen sinkt höchstens minimal.

Bewusst **nicht** umgesetzt, weil es Engpässe abbauen würde: größere Fächer und Rückfluss bei Stau (4.5a), Andrang an die Kapazität koppeln (3.5), längere Geduld (3.5), Störungs-Budget bei Ereignissen (4.7). Personal-Obergrenzen wurden mit der Upgrade-Neugliederung (4.13) angehoben, weil jedes weitere Personal teurer wird und Engpässe nur verschiebt.

### Umgesetzte Engpass-Mechaniken
| Mechanik | Wirkung |
|---|---|
| Einweihungs-Euphorie | 45 s ×1,5 nach jedem Ausbau, die nächste Station läuft voll |
| Meilensteine | ×1,25 alle 10 Stufen (`LEVEL_MILESTONE_BONUS`), das Tempo springt sprunghaft |
| Gedämpftes Ausbau-Tempo | +6 % je Stufe (`LEVEL_SPEED_BONUS`), damit Stationen nicht sofort alles abarbeiten |
| Ablagen | +2 Plätze in Eingang/Ausgang je Stufe (`TRAY_CAPACITY_PER_LEVEL`, bis 50), Preis Tisch × Faktor × 0,6 × 1,22^Stufe |
| Land unter | ab 75 % vollem Eingang: rote Plakette, ×1,5 Müdigkeit, bevorzugt krank |
| Mehrfachanträge | bis zu 2 Zusatzanträge, die parallel in andere Abteilungen strömen |
| Fehlende Unterlagen | 5 % der Akten erzeugen einen Nachreich-Brief |
| Poststelle | zweiter Eingang, füllt Sachbearbeitungen bis zur Hälfte, nur 50 % Gebühr |
| Einarbeitung | 5 Handfälle je neuer Abteilung vor dem ersten Einstellen |
| Boosts | 14 Boosts gegen Siegel oder Werbung (Attrappe) |
| Radau am Empfang | blockiert den Empfang, bis der Spieler 2,5 s danebensteht |
| Briefe auf dem Boden | Überlauf des Briefregals bleibt liegen, bis der Spieler ihn einsortiert |
| Röhrenabschnitte | jeder Rohrpost-Abschnitt einzeln ausbaubar, schwächster Abschnitt bremst |

Bot-Messung nach Umsetzung (`--hours=3 --active=90`, Seed 2024): Aktiv steigt das Ansehen auf ≈ 110, danach fällt es in 90 min nur um ≈ 3,4. Unbesetzt bearbeitet die Poststelle wenig (49 von 990 Briefen), der Rest geht zurück. Das ist gewollt: Das Briefregal ist eine Ausbau-Senke.

---

## 1. Messergebnisse

### Balance-Bot (`balance_bot.gd`, Seed 2024)
| Lauf | Nach 8 h | Ansehen | Abteilungen | Stufe | Fälle | Verlorene Bürger |
|---|---|---|---|---|---|---|
| 30 min aktiv, danach idle | 72 € | 0,0 | 2 | 1 | ~400 | 8 731 |
| 480 min aktiv | 18 616 € | 23,2 | 1 | 0 | ~2 000 | 3 233 |

Beide Läufe erreichen in 8 Stunden nicht einmal die Steuerstelle (Ansehen 15) bzw. den Bürgeramt-Ausbau (Ansehen 10) dauerhaft. Das Ansehen pendelt zwischen 0 und ~8 und fällt immer wieder auf 0.

### Diagnose-Bot (60 min, voll aktiv)
- Minute 5–60: Empfang, Sachbearbeitung oder Ausgabe sind in **fast jedem 5-Minuten-Snapshot „krank“** (240 s Ausfall, neue Krankmeldung alle 45–100 s bei nur 3 besetzten Tischen).
- Empfangs-Warteschlange dauerhaft 11–16/16, obwohl `station_throughput` 0,5–0,65 Fälle/s gegen Bedarf 0,17 ausweist. Die Formeln ignorieren Abwesenheit, der Engpass wird als „Nachfrage“ gemeldet, der Bot (und die Statistik-Empfehlung in der App) kauft deshalb keine Kapazität.
- Nach 60 min: 220 Fälle erledigt, **367 Bürger verloren** (−0,3 Ansehen je Bürger → −110 Ansehen gegen +22 aus Fällen). Ansehen 0,0.
- Sitzbereich 23/24 belegt, Ausgabe-Eingang 8/8 voll, Spieler trägt 11 Akten ohne Ablagemöglichkeit.

### 1.1 Varianten des Diagnose-Bots (180 min, voll aktiv)
| Variante | Fälle | Verlorene Bürger | Ansehen | Ziel-Index | Befund |
|---|---|---|---|---|---|
| Original (nur 60 min gemessen) | 220 | 367 | 0 | 4 | Stillstand, s. oben |
| Krankheit entfernt (`--nosick`) | 4 503 | 644 | 29,6 | 8 | 7× mehr Fälle; Ansehen trotzdem bei ~30 gedeckelt, weil 14 % Verluste × 0,3 den Zugewinn aufzehren (Ziel „Ansehen 40“ wird nie erreicht) |
| Ansehensverlust entfernt (`--norep`) | 412 | 4 246 | 133 | 9 | Ansehen steigt, aber ab Minute 105 **kompletter Stau**: Sachbearbeitung 10/10 + 10/10, Unterschrift 8/8 + 8/8, Ausgabe 8/8, Sitzbereich 47/24, Beamte krank bzw. im Kaffeekränzchen, kein Fall mehr abgeschlossen |
| Beides entfernt | 1 151 | 8 656 | 245 | 11 | Steuerstelle + Gewerbeamt werden freigeschaltet, danach derselbe Stau ab Minute 120 |

Schlussfolgerung: Es gibt **drei unabhängige Blocker**, die jeder für sich das Spiel anhalten: Krankheitsrate, Ansehensverlust durch verlorene Bürger und Dauerpausen ohne Selbstauflösung (Kaffeekränzchen/Tratschen/Einschlafen ohne Weckdienst), die zusammen mit vollen Fächern zum Deadlock führen.

### 1.2 Werkzeug-Befund
- Sequenzielle Bot-Läufe sind reproduzierbar (Seed 2024), **parallel gestartete Läufe im selben Projektordner liefern abweichende Ergebnisse** (vermutlich geteilter `.godot`-Cache/Import). Für Regressions-Messungen Läufe nacheinander starten oder getrennte Arbeitskopien verwenden.
- `balance_bot.gd` kennt die Aktionen Vertreten (kranker Tisch), Kränzchen beenden nur über die Führung; die Führung (`Guidance`) kennt kranke Tische nicht (s. 2.3).

---

## 2. Kritische Schwachstellen

### 2.1 [K] Krankheits-Todesspirale im Frühspiel
**Befund.** `SICK_MIN_STAFF = 2`, Intervall 45–100 s (`SICK_MIN/MAX_INTERVAL`), Dauer `SICK_SECONDS = 240`. Der Krankheits-Timer ist **global** und unabhängig von der Mitarbeiterzahl. Bei 3 besetzten Tischen sind im Mittel 240/72 ≈ 3,3 Beamte gleichzeitig krank, also praktisch immer alle. Der Empfang ist die einzige Eingangsstation: ist er krank, kommt 240 s lang niemand hinein, Geduld ist 90 s, alle Wartenden gehen (−0,3 je Bürger). Später (50+ Beamte) ist dieselbe Rate dagegen bedeutungslos.
**Todos.**
- [x] Krankheits-Wahrscheinlichkeit **pro Beamtem** statt globalem Timer (z. B. 1 Krankmeldung je Beamtem alle 25–40 min Spielzeit). Frühspiel: alle ~8–10 min eine Krankmeldung bei 3 Beamten; Spätspiel: häufig genug, dass Telefonisten/Gesundheitsschulung lohnen. **Umgesetzt:** je Beamtem 20–40 min, erste Meldung nach 180 s.
- [x] `SICK_SECONDS` von 240 auf 90–120 senken, dafür Bonus-Stufen (`SICK_BONUS_SPEED`) beibehalten; Rückruf durch Telefonzentrale bleibt die Abkürzung. **Umgesetzt:** 150 s.
- [x] `SICK_MIN_STAFF` auf 4 anheben oder Krankmeldungen erst nach dem ersten Ziel „Mitarbeiter einstellen“ aktivieren, damit die ersten 10 Minuten nur Tragen/Arbeiten sind. **Umgesetzt:** Wert 3, damit Engpässe früh entstehen.
- [~] Empfang/Rampe (Eingangsstationen) von Krankmeldungen ausnehmen **oder** Spieler übernimmt den Eingang automatisch, wenn er in der Nähe ist (bereits `_cover_absent_desks`, aber ohne Führung, s. 2.3). **Verworfen:** Ausfälle am Eingang sollen Engpässe erzeugen; der Leit-Pfeil zeigt jetzt per `COVER` hin.
- [x] Test anpassen: `test_sick_and_loo.gd`, `test_phone_office.gd`, `test_sick_bonus.gd`.

### 2.2 [K] Ansehen ist eine Einbahnstraße nach unten
**Befund.** Gewinn je korrektem Fall +0,1 (`REP_CORRECT`), Verlust je verlorenem Bürger −0,3 (`REP_CITIZEN_LEFT`, `REP_WALKED_OUT`), je Fehler −0,5 (`REP_FLAWED`), bei „Husch-husch“ (30 % Fehler) ist der Erwartungswert je Fall **−0,08**. Netto bei „Nach Vorschrift“: 0,028 Ansehen/Fall. Für Zoll (1 300) sind das ~46 000 fehlerfreie Fälle. Ein einziger kranker Empfang vernichtet in 4 Minuten das Ansehen von 30 Minuten Arbeit. Ansehen kann auf 0 fallen (Boden), aber nie unter die Freischaltschwellen „zurückfallen“, die schon genutzt wurden – trotzdem fühlt sich jeder Verlust als Rückschritt an (Gegenteil von süchtig machend).
**Todos.**
- [x] `REP_CITIZEN_LEFT`/`REP_WALKED_OUT` auf −0,05 senken und zusätzlich einen **Verlust-Deckel je Minute** einführen (z. B. höchstens −1 Ansehen/min), damit ein Ausfall nie eine Spirale wird. **Umgesetzt:** alle Verluste ×0,05 und höchstens 0,05 Ansehen pro Minute.
- [x] `REP_FLAWED` auf −0,2; „Husch-husch“ darf schneller, aber nie netto negativ sein (Zielwert: fast ≈ +0,01, normal ≈ +0,06, thorough ≈ +0,09 je Fall). **Umgesetzt:** über die allgemeine Dämpfung abgedeckt.
- [x] Ansehen als **„höchster erreichter Wert“ für Freischaltungen** werten (`state.reputation_peak`), aktuelles Ansehen wirkt nur auf Multiplikator/Andrang. Damit bleibt Fortschritt dauerhaft, Fehler kosten Einkommen statt Zugang. **Umgesetzt:** `standing()`.
- [~] Alternativ/zusätzlich: Verlorene Bürger kosten Geld (Entschädigung, z. B. 50 % der Gebühr) statt Ansehen. **Verworfen:** nicht nötig, Verluste sind gedämpft.
- [x] Tests: `test_formulas`/`test_simulation` (Ansehensänderungen), Speicherstand-Version (neues Feld). **Umgesetzt:** `test_reputation_damping.gd`.

### 2.3 [K] Kapazitätsformeln ignorieren Pausen, Krankheit, Streit
**Befund.** `station_throughput`, `department_throughput`, `bottleneck`, `income_per_second` (Offline-Ertrag!) und der komplette `ThroughputReport` rechnen mit `effective_workers × Tempo`. Reale Verfügbarkeit liegt im Frühspiel bei 30–50 %. Folgen: Engpass „Nachfrage“ obwohl die Hälfte der Bürger geht; Statistik-Empfehlung „Nichts ausgelastet“; Offline-Ertrag überschätzt den Online-Ertrag (50 %-Faktor kompensiert zufällig).
**Todos.**
- [x] Verfügbarkeitsfaktor je Station einführen (`Formulas.availability(state, station)`): erwarteter Wachanteil aus `alert_duration`, `doze_weights`, `rest_limit`, Krankheitsrate, Streit-Tempo. In `station_throughput` multiplizieren.
- [x] Offline-Ertrag auf diesen realistischen Durchsatz stützen und `OFFLINE_EFFICIENCY` dann auf 0,7–0,8 anheben (Idle-Spiele belohnen Rückkehr). **Umgesetzt:** 0,7.
- [x] `Guidance.next_task` um Aktion `COVER` erweitern: kranke/abwesende Tische mit Arbeit (`station.can_cover`) als Aufgabe anbieten (heute kennt `needs_help()` den Zustand `SICK` nicht → Pfeil zeigt nie auf den kranken Empfang).
- [x] Tests: `test_throughput_report.gd`, `test_statistics.gd`, `test_offline.gd`, `test_guidance.gd`.

### 2.4 [K] Neue Abteilungen kommen fertig besetzt
**Befund.** `GameState.unlock_department`: `created.staff = 0 if first else 1`. Jede neue Abteilung startet mit besetztem Sachbearbeiter-Tisch, Unterschrift ist (außer Bauamt/Sozialamt) eine Maschine, Empfang/Ausgabe sind längst besetzt. Der Spieler arbeitet nur in den ersten ~4 Minuten des Spiels selbst. Erste Einstellung kostet `hire_cost × Multiplikator` (Steuer 240 € bei 800 € Freischaltkosten) – sofort bezahlbar.
**Todos.**
- [x] Neue Abteilungen mit `staff = 0` an allen Nicht-Maschinen-Stationen eröffnen; Spieler bearbeitet die ersten Fälle am Tisch selbst (Mechanik `work()` existiert).
- [x] **Einarbeitungsphase** je Abteilung: Einstellen erst möglich, nachdem der Spieler N Fälle dieser Abteilung selbst bearbeitet hat (N ≈ 8–12, `Department.hands_on_done`), mit sichtbarem Fortschritt im Abteilungsfenster und Belohnung beim Abschluss (einmalig Geld + Ansehen). **Umgesetzt:** N = 5, Prämie 10 Fallgebühren und +1 Ansehen.
- [ ] Erste Einstellung je Abteilung an die Freischaltkosten koppeln (z. B. 20 % der `unlock_cost`), spätere Einstellungen nach heutiger Formel.
- [ ] „Chefsache“-Bonus: selbst bearbeitete Fälle zahlen ×1,5 und geben +0,2 Ansehen, damit Selbermachen attraktiv ist, nicht nur Pflicht.
- [ ] Maschinenstationen (Unterschrift) der neuen Abteilung ebenfalls erst nach Einarbeitung „liefern“ (Maschine muss gekauft werden; bis dahin stempelt der Spieler per `work()`): `machine`-Stationen mit `desks = 0` starten lassen oder `signature_machine` erst nach Kauf aktiv.
- [ ] Startgeld 120 € und Preise Empfang 50 €/Ausgabe 60 €/Bote 90 € prüfen: aktuell ist die Hands-on-Phase im Hauptspiel nach <4 min vorbei. Vorschlag: Startgeld 40 €, Einstellen Empfang/Ausgabe erst nach Ziel „10 Fälle“.
- [x] Tests: `test_game_state.gd` (Unlock), `test_actions.gd` (Hire-Sperre), `test_goals.gd`. **Umgesetzt:** `test_bottleneck_dynamics.gd`.

---

## 3. Hohe Priorität

### 3.1 [H] Nach Stufe 3 gibt es nichts Kleines mehr zu kaufen
**Befund.** Summe aller Technik-Kosten außer Rohrpost/Röhren/Portal/KI: ~0,9 Mio. Summe aller globalen Mitarbeiter und Bereiche (12 Boten, 4 Kaffee-Praktikanten, 4 Telefonisten, 2 Wachen, 2 Praktikanten, Warte- 8/Sitzbereich 12): ~0,55 Mio. Das Bauamt kostet allein 400 000 €, das Wohnungsamt 2 Mio. Ab Kreisverwaltung ist alles Kleine gekauft; danach gibt es nur noch Tische/Stufen in teuren Abteilungen und vier Großtechniken. Zwischen Wohnungsamt (2 Mio.) und Sozialamt (12 Mio.) liegen Stunden ohne „kleines Upgrade“.
**Todos.**
- [ ] Alle globalen Mitarbeiter-/Bereichspreise an das **aktuelle Einkommen** koppeln (`max(Basis, Einkommen/min × Faktor) × Wachstum^n`) wie bereits `sick_bonus_cost`; dann bleiben Bote Nr. 9 oder Telefonist Nr. 3 in jeder Phase eine spürbare, aber kurze Investition.
- [x] Obergrenzen anheben. **Umgesetzt (4.13):** Boten 30, Kaffee-Praktikanten 8, Beschwerde-Praktikanten 5, Wachen 6, Telefonisten 4, Teamleitungen 4 je Abteilung, Fachkräfte 3; flacheres Preiswachstum (×1,5 bis ×2,2). Bindung an die Gebäudestufe bewusst nicht, die Preise begrenzen ausreichend.
- [x] Technik-Stufen verlängern mit kleinen Schritten statt harter `max_level`. **Umgesetzt (4.13):** alle Spuren 40–300 Stufen mit Wachstum ×1,04–×1,2.
- [x] Neue **Dauer-Senke**. **Umgesetzt (4.13):** Büroausstattung je Abteilung (200 Stufen), Rohrpost-Stationen und Röhrenabschnitte je Raum, Briefregal 300 Stufen, Sitzplätze 300 Stufen. Ob die Startpreise in jeder Phase bei 1–2 min Einkommen liegen, misst der Balance-Bot noch (4.13).
- [~] Beamten-Schulungen sichtbarer machen. **Entfällt:** Schulungen je Beamtem sind entfernt; Pausen, Krankheit und Einnicken laufen jetzt über die Boni der Teamleitung je Raum.

### 3.2 [H] Freischalt-Sprünge wachsen zu steil
**Befund.** Amortisation nur aus Rohertrag der neuen Abteilung (Gebühr/Intervall ÷ Freischaltkosten): Steuer 2,4 min, Gewerbe 11 min, Kfz 34 min, Bauamt 1,9 h, Wohnungsamt 3,6 h, Sozialamt 9,3 h, Zoll 19 h. Multiplikatoren (Ansehen ×2–2,8, Andrang ×3–5,5) verkürzen das später, aber die Ansehensschwellen (300/500/800/1 300) bremsen zusätzlich. Gleichzeitig steigen die Kostenfaktoren der Abteilungen ×3 je Stufe (1, 3, 9, 27, 80, 220, 650, 1 900) – ein Sachbearbeiter-Tisch im Zoll kostet 228 000 €, eine Stufe 171 000 €.
**Todos.**
- [ ] Zielkurve festlegen: jede Freischaltung (Abteilung oder Gebäudestufe) nach 15–45 min aktiver Spielzeit bzw. 1 Offline-Nacht; Kosten der nächsten Abteilung ≈ 20–30 min aktuelles Gesamteinkommen.
- [ ] `unlock_cost` neu setzen (Vorschlag): Steuer 600, Gewerbe 5 000, Kfz 30 000, Bauamt 150 000, Wohnungsamt 600 000, Sozialamt 2,5 Mio., Zoll 10 Mio.; `cost_multiplier` entsprechend abflachen (1, 2,5, 6, 15, 40, 100, 250, 600).
- [ ] Ansehensschwellen auf Ziel „erreichbar nach ~70 % der Geld-Wartezeit“ eichen: 10, 40, 100, 200, 320, 480, 700 (nach Umsetzung 2.2 neu messen).
- [~] Gebäudestufen-Kosten in dieselbe Kurve legen. **Entfallen (4.17):** Gebäudestufen sind nicht mehr kaufbar.
- [ ] Balance-Bot um Ausgabe „Minuten bis nächste Freischaltung“ erweitern und als Regressions-Check (nicht als Unit-Test) in `tests/tools` dokumentieren.

### 3.3 [H] Kein Spielziel nach Ziel 21, keine Wiederkehr-Belohnung
**Befund.** 21 Ziele, danach `has_goal() == false`. Siedlungsränge (Dorf → Metropole) sind rein kosmetisch. Kein Tages-Login, keine Serien, keine Sammel-Meilensteine, keine Erfolge. Offline-Ertrag maximal 4 h × 50 % = 2 h-Äquivalent, danach Stillstand – wer morgens und abends spielt, verliert nichts durch die Deckelung, wer alle 2 Tage spielt, wird bestraft statt zurückgeholt.
**Todos.**
- [ ] **Endlose Ziele** nach Ziel 21: generierte Ziele (Fälle ×1,5, Ansehen +100, Stufe-10-Station, 50 Schulungen …) mit skalierender Belohnung (`Einkommen/min × 10`), immer genau ein aktives Ziel + Vorschau auf das nächste.
- [ ] **Meilensteine** (dauerhaft sichtbar, mit Plakette im Gebäudefenster): 100/1 000/10 000/100 000 Fälle, jeder Siedlungsrang, jede Abteilung voll ausgebaut, erster fehlerfreier 10-Minuten-Lauf. Belohnung: kleiner permanenter Bonus (+1 % Gebühren je Meilenstein) statt Einmalgeld.
- [ ] **Tagesziel** („Dienstplan des Tages“, 3 kleine Aufgaben, wechselt mit `WISDOM`-Tag): Belohnung Geld = 15 min Einkommen + 1 Ansehen; Serie über Tage erhöht Offline-Deckel (+1 h je Serientag bis 12 h).
- [ ] Offline-Deckel 4 h → 8 h Basis, Technik „Nachtschicht“ (3 Stufen, +2 h) und Tagesserie; `OFFLINE_EFFICIENCY` 0,5 → 0,7 (nach 2.3).
- [x] Rückkehr-Dialog mit „Verdoppeln“-Option gegen eine kurze Hands-on-Aufgabe (z. B. 5 Akten selbst tragen) statt Werbung – passt zur Vorgabe „selbst machen“. **Umgesetzt:** per Werbung (3-Sekunden-Platzhalter), wie vom Nutzer gewünscht.

### 3.4 [H] Kein Prestige/Reset-Loop
**Befund.** Spätspiel endet bei Zoll + Stufe 50. Klassische Langzeitmotivation (Neustart mit dauerhaftem Bonus) fehlt. Die Amtsstufen (4.14) verlängern das Spätspiel deutlich, ersetzen aber keinen Neustart-Loop.
**Todos.**
- [ ] **„Versetzung“**: ab Stadtverwaltung + Zoll kann der Spieler in eine neue Stadt versetzt werden. Neustart mit `Dienstgrad`-Punkten (aus erreichtem Ansehen/Fällen), jeder Punkt +2 % Gebühren und +1 % Tempo dauerhaft; freigeschaltete Techniken starten auf Stufe 1 (Rohrpost bleibt gesperrt, sonst fehlt der Botenabschnitt).
- [ ] Je Versetzung eine sichtbare Veränderung (neuer Stadtname aus Liste, anderes Amtsschild, Flaggenfarbe) – keine urheberrechtlich geschützten Namen.
- [ ] Speicherstand: neue Felder `prestige_level`, `prestige_points`, Migration mit Test.

### 3.5 [H] Positive Rückkopplung Ansehen → Andrang überlastet unbeaufsichtigt
**Befund.** Andrang `1 + √Ansehen/8` (bis ×8) und Nachfragewachstum (bis ×2,2) vervielfachen die Ankünfte, Eingangsfach `6 + 2·Tische`, Lobby 16–64. Jede Erhöhung des Ansehens bringt mehr Bürger, die bei ausgelasteten Stationen gehen und Ansehen abziehen. Das System schwingt um einen Gleichgewichtspunkt, bei dem ständig Bürger verloren gehen – Dauerfrust statt Flow.
**Todos.**
- Entfallen durch 4.16: Ansehen, Nachfrage, Ereignisse und Boosts beeinflussen den Zulauf nicht mehr; Geduld und Sitzbereich sind neu geregelt.

---

## 4. Mittlere Priorität

### 4.1 [M] Stufen-Upgrade: linearer Nutzen, exponentieller Preis
Stufe n gibt +15 % Tempo (additiv), Preis ×1,45 je Stufe. Stufe 10 (×2,35) kostet 2 550 €, Stufe 20 (×3,85) 105 000 €, Stufe 30 (×5,35) 4,3 Mio. Ab Stufe ~15 ist jede Stufe schlechter als ein Tisch; `MAX_STATION_LEVEL = 50` wird nie erreicht.
- [x] Wachstum 1,45 → 1,25 und Bonus je Stufe 15 % → 10 % mit **Schwellen-Boni** alle 10 Stufen (×1,5 Tempo bei 10/20/30/40/50, Anzeige im Button „Nächster Meilenstein in 3 Stufen“) – das klassische Idle-Muster, das Klein-Upgrades spannend hält. **Umgesetzt:** 12 % je Stufe, ×1,5 alle 10 Stufen, Wachstum 1,35 und Anzeige auf der Stationskarte.
- [ ] Tische: `DESK_GROWTH` 2,2 → 1,8; Einstellen `HIRE_GROWTH` 1,8 → 1,5. Beide Käufe sollen nach Einarbeitung die Hauptsenke sein.

### 4.2 [M] Fachkräfte und Teamleitungen zu schwach bzw. zu teuer
Fachkraft: 5 × Einstellkosten × 2,4^n, nur komplexe Fälle (10–35 %) ohne Zeitstrafe, Fehler ×0,3. Teamleitung 1 000 € × Multiplikator × 3^n für +20 % Tempo und weniger Einnicken.
- [~] Fachkraft als vollwertiger Arbeiter. **Entfällt:** Fachkräfte sind entfernt (ein Beamter je Tisch).
- [x] Teamleitung neu gedacht. **Umgesetzt:** eine Teamleitung je Leitungsbereich (Annahme und Abholung getrennt, 400 × Personalfaktor) mit eigenem Büro und sechs ausbaubaren Boni (Pausen, Krankheit, Einnicken, Schlichtung, Rundgang-Tempo, Abklingzeit; je 150 Stufen ×1,04, Grundpreis 50–80) und dem aktiven Rundgang (30 s, weckt alle, Tempo ×2+, Abklingzeit 120 s). Schon die Einstellung wirkt sofort stark (Pausen und Krankheit ×0,75, Einnicken ×0,7, Schlichtung 25 %). Noch offen: Preise im Balance-Bot gegen Raumtempo prüfen.

### 4.3 [M] Rohrpost entwertet eine ganze Upgrade-Linie schlagartig
250 000 € einmalig → Transport unendlich, 12 Boten und 3 Stufen Aktenwagen wertlos.
- [x] Rohrpost als Netz je Raum verkaufen, Boten bleiben für nicht angeschlossene Strecken nötig. **Umgesetzt:** einmalige Freischaltung (250 000) plus Station je Raum (Abteilungen halber Eröffnungspreis, mindestens 20 000); komplexe Akten erst mit Großen Kapseln, Großakten nie; Kapazität global (Röhrenkapazität, 60 Stufen) und je Abschnitt (100 Stufen).
- [~] Boten nach Rohrpost umschulen. **Verworfen:** Boten behalten Arbeit durch nicht angeschlossene Räume, nicht passende Akten und den Überlauf (sie nehmen Rohrpost-Akten, sobald ein Ausgangsfach halb voll ist, `TUBE_OVERFLOW_SHARE`).

### 4.4 [M] Prozess-Klage ist ab dem zweiten Versuch ein Geldautomat
Erwartungswert Geld = Chance × 2,5 − 1 ≥ 0 schon bei 40 %; Chance steigt +8 % je Klage bis 85 %, Kosten nur ×1,25. Ab Klage 2 positiver Erwartungswert, bis 20 Klagen je Bewertung.
- [x] `REVIEW_LAWSUIT_GROWTH` 1,25 → 1,6 oder Auszahlung 2,5 → 1,8. **Umgesetzt:** Wachstum 1,6; höchstens 3 Klagen je Bewertung (Chance 50/58/66 %), danach nur Werbung oder Löschen (×1,5 je gescheiterter Klage). Kein Schadenersatz mehr: Sieg erstattet nur die Klagekosten (1,0-fach), Klagen bringen also nie Gewinn.
- [x] Löschen und Krank-Bonus teurer: Bewertung löschen Grundpreis 25 s Einkommen (min. 40) statt 8 s (min. 10), 1 Stern damit ≈ 75 s Einkommen; Klage 3,6 × Grundpreis (≈ 90 s Einkommen): Löschen ist damit immer günstiger als Klagen (höchster Löschfaktor 3,0 < 3,6, Löschen wächst ×1,5, Klage ×1,6 je gescheiterter Klage; Test `test_deleting_is_always_cheaper_than_suing`). Klagen lohnen sich nur wegen der Kostenerstattung bei Sieg und des Abschreckungseffekts. Krank-Bonus 0,3/0,6/1,0 Einkommensminuten statt 0,1/0,25/0,6, Mindesteinkommen 50/min; Obergrenze 1 Minute bleibt (Test `test_bonus_stays_cheap_compared_to_income`).
- [ ] Verlorene Klage: zusätzlich eine neue 1-Sterne-Bewertung („Amt verklagt Bürger“), damit Spam riskant bleibt.

### 4.5 [M] Permanentes Einnicken/Tratschen ohne Weckdienst
`asleep` (12 %) und `chat` (26 %) enden ohne Weckdienst nie (`rest_limit` → INF). 38 % aller Pausen sind Dauer-Ausfälle, bis der Spieler kommt. Sinnvoll als Hands-on-Inhalt, aber im Spätspiel mit 100 Beamten entsteht alle ~8 s ein Dauerschläfer.
- [ ] Natürliches Aufwachen immer nach `max(300 s, …)`; Weckdienst verkürzt. Kaffee-Praktikanten dürfen auch Schlafende wecken (heute nur Vorbeugung über `alert`).
- [ ] Ohne Weckdienst Pausenquote je Abteilung im Aufgaben-Panel anzeigen („3 schlafen“), damit der Spieler nicht suchen muss.

### 4.5a [H] Kaffeekränzchen hat keine Zeitgrenze und kann den Betrieb einfrieren
**Befund.** `_update_kranz` beendet das Kränzchen nur, wenn der Spieler die Küche besucht oder alle Tratschenden geweckt wurden; Tratschende wachen ohne Weckdienst nie auf. Mit 3–4 Beamten sitzt beim ersten Kränzchen (nach 90 s!) das gesamte Amt in der Küche. Im Diagnose-Bot entstand daraus zusammen mit vollen Fächern der Deadlock aus 1.1.
- [x] Kränzchen endet spätestens nach `KRANZ_MAX_SECONDS` (z. B. 60 s) von selbst; Spieler beendet es früher und bekommt dafür die Belohnung (Ansehen +0,2 wie Schlichten). **Umgesetzt:** 75 s, +0,2 Ansehen.
- [ ] `KRANZ_FIRST_SECONDS` 90 → 300 und Mindestteilnehmer 2 → 3, höchstens die Hälfte der Beamten einer Station gleichzeitig.
- [ ] Verstopfung lösen: Ist ein Ausgangsfach voll und das Zielfach voll, geht die Akte in den Wartebereich zurück statt die Station zu blockieren (`finish_job` gibt heute `false` zurück und der Tisch steht still). Alternativ Fächer `INBOX_BASE`/`OUTBOX_BASE` 6 → 10.
- [ ] `seated_citizens()` darf die Kapazität nicht überschreiten (47/24 gemessen): Boten und Rohrpost müssen `reception_may_admit` ebenfalls berücksichtigen oder die Sitzzählung schließt Akten in Ausgangsfächern aus.
- [ ] Tests: `test_kitchen_life.gd`, `test_simulation.gd` (Stau-Szenario mit vollen Fächern).

### 4.6 [M] Arbeitsweise „Husch-husch“ ist eine Falle
30 % Fehler → negatives Ansehen je Fall und Gebühr ×0,82. Nach 2.2 noch prüfen, sonst nie sinnvoll.
- [x] „Husch-husch“: Zeit ×0,6, Fehler 20 %; „Dreifach geprüft“: Zeit ×1,4, Fehler 2 %; Beschreibung mit Ansehen/Fall-Erwartungswert ergänzen (`i18n`).

### 4.7 [M] Ereignisse: zu häufig/lang relativ zur Hands-on-Last
Erstes Ereignis nach 240 s, dann alle 180–360 s für 45 s; Störereignisse (Druckerstau 0,55×, Dienstbesprechung 0,45×, Feueralarm 0×) parallel zu Krankheit, Streit, Kränzchen, Beschwerden.
- [ ] Ereignis-Pause auf 300–600 s; während eines Ereignisses keine neue Krankmeldung und kein Kränzchen (globale „Störungs-Budget“-Regel: höchstens zwei aktive Störquellen gleichzeitig).
- [x] Positive Ereignisse hinzufügen (z. B. „Bürgermeister-Besuch“: ×2 Gebühren 60 s, „Praktikantentag“: Beamte 2 min ohne Pausen), damit Ereignisse Vorfreude statt nur Stress erzeugen. **Umgesetzt:** Bürgermeister zu Besuch, Lob in der Zeitung; Pausen-Effekte als Boosts.

### 4.8 [M] Wiedervorlage und Verweis lohnen nicht
Sozialamt-Wiedervorlage ×0,6 Gebühr, aber voller Durchlauf Empfang/Sachbearbeitung/Ausgabe; Wohnungsamt-Verweis durchläuft zusätzlich die Meldestelle und belastet deren Kapazität ohne eigene Gebühr.
- [ ] Wiedervorlage ×0,6 → ×0,9 (sie ist „halbe Arbeit“: kein Unterschriftsschritt) und +0,1 Ansehen zusätzlich.
- [ ] Verwiesene Fälle zahlen der Meldestelle anteilig (20 % der Gebühr) und erscheinen in deren Statistik.

### 4.9 [H] Beschwerde-Praktikanten brechen zusammen, bevor sie arbeiten
**Befund (Spieler-Feedback, nachgerechnet).** Der Praktikant braucht auf Schredder-Stufe 1 je Gang 40 s am Platz, war bei vollem Briefkasten aber nach ~15 s gestresst (17 × 0,4 %/s); jeder wütende Besucher brachte +36 %, und die Schulung half gegen Geschrei gar nicht. Unter Last schaffte er 0,2–0,4 Gänge je Zusammenbruch und nur 20 % seiner Nennleistung; sobald der Kasten 8 Beschwerden erreichte, kippte das System dauerhaft.
- [x] Stress je Beschwerde über der Grenze 0,4 → 0,02 %/s, Geschrei 6 → 0,6 %/s, Erholung 1,2 → 0,4 %/s (bleibt unter dem Geschrei, damit ein Schreihals sichtbar stresst).
- [x] Praktikanten-Schulung senkt jeden Stresszuwachs (Kasten und Geschrei) um 25 % je Stufe (`INTERN_TRAINING_STRESS_FACTOR`); 3 → 8 Stufen, Wachstum ×4 → ×3 (3 000 bis 6,6 Mio.), damit es bis ins Spätspiel kleine Praktikanten-Upgrades gibt.
- [x] Test `test_intern_survives_several_shredder_trips_with_a_full_box` sichert ab, dass ein ungeschulter Praktikant auf Stufe 1 bei vollem Kasten und regelmäßigem Geschrei mehr als zwei Gänge schafft.

Modellrechnung (eigenes Python-Modell der Praktikanten-Logik, 60 min, 6 Seeds; „Last“ = 3 Beschwerden/min, die Hälfte wütend; „Stau“ = 6/min, 70 % wütend; S = Schredder-Stufe, T = Schulungsstufe):
| Szenario | Vorher: geschreddert/min | Vorher: Gänge je Zusammenbruch | Nachher: geschreddert/min | Nachher: Gänge je Zusammenbruch |
|---|---|---|---|---|
| Last S1 T0 | 0,27 | 0,2 | 1,10 | 3,1 |
| Last S1 T1 | 0,73 | 0,3 | 2,48 | 26 |
| Stau S1 T0 | 0,24 | 0,2 | 1,05 | 2,5 |
| Stau S1 T1 | 0,61 | 0,2 | 2,35 | 3,6 |
| Stau S2 T1 | 1,21 | 0,4 | 4,71 | 31 |
| Stau S2 T3 | 4,90 | 11 | 4,91 | kein Zusammenbruch |

Offen, falls es weiterhin zu wenig ist: mehr zusätzliche Praktikanten (2 → 4, Platz an der Beschwerdestelle vorher im Screenshot prüfen) oder Schreddern beruhigt („Schreddern ist Therapie“).

### 4.10 [H] Beschwerde-Flut durch gehende Bürger
**Befund (Spieler-Feedback, nachgerechnet).** Jeder Bürger, dessen feste Geduld (90 s) ablief, und jeder wegen voller Halle Abgewiesene reichte eine Beschwerde ein, Abgewiesene sogar schon vor Fall 10. Weil alle dieselbe Geduld hatten, ging bei einer Störung die ganze Schlange in einer Welle: Eine 150-s-Krankmeldung im Spätspiel erzeugte rund 18 Beschwerden/min, Überlast rund 28/min. Ohne Störung ging dagegen fast nie jemand.
- [x] Eigene Geduld je Bürger: gleichmäßig verteilt 30–170 % der Grundgeduld (Mittel unverändert), erst ab 10 erledigten Fällen (`PATIENCE_*`). Eilige gehen schon bei kürzeren Ausfällen: regelmäßige, kleine Verluste statt seltener Massenflucht.
- [x] Nur ein Teil beschwert sich: Gehende mit 30 % × Geduldsfaktor (Eilige rund 9 %, Geduldige bis 51 %), Abgewiesene mit 10 %; beides erst ab 10 Fällen.
- [x] Sammelbeschwerde: Nach einer Beschwerde von Gehenden 45 s lang keine weitere (höchstens rund 1,3/min).
- [x] Grundtakt der regelmäßigen Beschwerden 120 → 150 s (105–195 s).
- [x] Durchsatz-Analyse: Der Beschwerde-Bedarf enthält den gemessenen Zulauf durch Gehende (gedeckelt auf die Sperre).
- [x] Tests: `test_overcrowded_office_does_not_flood_the_box` (600 s ohne Bedienung: höchstens eine Beschwerde je 45 s, aber mehrere), dazu Anteils-, Sperr- und Geduldstests in `test_feedback_features.gd`, `test_hall_life.gd`, `test_simulation.gd`, `test_formulas.gd`.

Modellrechnung (eigenes Python-Warteschlangenmodell, 30 min, 12 Seeds; Beschwerden inklusive der regelmäßigen, vor Abwimmeln und Wachen; früh = 1 Bürger je 7 s, Bedienung 2 s; mittel = 1 je 2,5 s, 1,2 s; spät = 1 je 0,7 s, 0,45 s; gut/normal/schlampig = zufällige Ausfälle mit 12/45/120 s Reaktionszeit; krank = zwei Komplettausfälle à 150 s; AFK = niemand bedient; Überlast = Bedienung langsamer als der Zulauf):
| Szenario | Vorher: Beschwerden/min | Vorher: verlorene Bürger | Nachher: Beschwerden/min | Nachher: verlorene Bürger |
|---|---|---|---|---|
| früh gut | 0,49 | 0 % | 0,39 | 0 % |
| früh normal | 0,49 | 0 % | 0,39 | 0,2 % |
| früh schlampig | 0,48 | 0 % | 0,46 | 6,4 % |
| früh krank | 1,32 | 9,9 % | 0,45 | 10,9 % |
| früh AFK | 8,66 | 95,0 % | 1,21 | 94,9 % |
| mittel normal | 0,49 | 0 % | 0,39 | 0,2 % |
| mittel schlampig | 3,23 | 11,4 % | 0,56 | 13,4 % |
| mittel krank | 4,38 | 16,2 % | 0,58 | 17,2 % |
| spät krank | 18,52 | 21,0 % | 0,66 | 21,3 % |
| spät Überlast | 28,06 | 32,2 % | 1,27 | 32,2 % |

Ergebnis: Bürger gehen jetzt auch bei nachlässigem Spiel regelmäßig (früh 0 → 6 %), wer zügig bedient, verliert aber fast niemanden. Beschwerden steigen unter Last nur noch moderat (höchstens rund 1,3/min statt bis zu 28/min).

### 4.11 [M] Wartemarken als zusätzlicher Engpass ab Ausbaustufe 3
Ziel: Vor dem Empfang ein weiterer Engpass, der früh in der Regionalverwaltung spürbar wird und per Hand oder Ausbau gelöst wird.
- [x] Automat 3 s je Nummer (max. 20/Min.), Aufruf 3,5 s je Nummer (max. ≈ 17/Min.), Hand ×2,5, je Stufe −18 % (10 Stufen, Endwert ≈ 0,41 s bzw. 0,48 s). Kosten 30 000 bzw. 35 000 · 1,7^Stufe. Aufruf nur bei < 4 Anstehenden am Empfang. Konstanten `TICKET_*` in `game_config.gd`.
- Ersetzt durch 4.16 (Automaten von Anfang an, 0,4–1 Bürger/s je Automat).

### 4.12 [H] Tester-Feedback Halle, Rohrpost, Poststelle
Befund: Der Wartebereich-Ausbau änderte nichts am Durchsatz, allein der Sitzbereich begrenzte ihn (ein Platz bedient etwa 3–4 Bürger/Min.; für 1000 Anträge/Min. braucht es mindestens 250 Plätze). Rohrpost war nur global ausbaubar, und fertige Bescheide teilten sich die Röhren mit der Gegenrichtung.
- [x] Sitzbereich bis über 300 Plätze. Heute (4.13): 300 Stufen à +1 Platz (24 → 324), 500 · 1,04^Stufe.
- [x] Stehplätze als Überlauf bei vollem Sitzbereich; Gedränge senkt die Geduld der Schlange um bis zu 35 %. Heute (4.13): eigene Spur, 150 Stufen à +2 Stehplätze; Warteschlange 120 Stufen à +1 Platz.
- [x] Röhrenabschnitte einzeln ausbaubar; eigene Ausgabe-Röhre über den rechten Schacht. Heute (4.13): 100 Stufen à +1 Kapsel und +2 % Tempo, 30 000 · 1,08^Stufe.
- [x] Radau am Empfang alle 120–260 s ab 25 Fällen (Wachen +30 % Abstand).
- [x] Volles Briefregal: Briefe bleiben auf dem Boden liegen (max. 60), Spieler sortiert sie ein.
- [ ] Mit Balance-Bot prüfen, ob Stehplätze und Sitzbereich-Kosten im späten Spiel mit dem Andrang mithalten und Radau nicht zu häufig stört.

### 4.13 [H] Upgrade-Neugliederung: feine Stufen, alles auf der Karte
**Befund (Spieler-Feedback).** Je Upgrade-Art gab es nur 3–10 Stufen mit großen Sprüngen (Wachstum ×2,5 bis ×6), dazu eine unübersichtliche Aufteilung in Abteilungen, Team und Technik. Zwischen großen Käufen gab es lange nichts Kleines zu kaufen (siehe 3.1).
- [x] 54 Upgrade-Spuren in `GameConfig.UPGRADES` mit zusammen 9 334 Stufen (Spuren je Abteilung bzw. Raum mehrfach gezählt), meist 100–300 Stufen, Wachstum ×1,04–×1,2. Kurven: `linear` (Wert + Schritt), `decay` (Wert × Rate^Stufe, nähert sich asymptotisch), `unlock_decay` (Stufe 1 schaltet frei, danach Rate), `chance` (1 − (1 − Basis) × Rate^Stufe) und `unlock`. Übersicht aller Werte in FEATURES.md („Upgrades und Bereiche“).
- [x] `Formulas.track_value` begrenzt die Stufe auf 0 bis zur Höchststufe; manipulierte oder alte Spielstände ergeben so keine Werte jenseits der Tabelle.
- [x] Kaufmengen ×1, ×10 und Max über die geschlossene geometrische Summe (`geometric_sum`, `geometric_affordable`), damit Hunderte Stufen ohne Schleife bezahlt werden.
- [x] Migration v2 → v3 hält die Wirkung alter Stände ungefähr gleich: Stufen werden je Spur skaliert (`SaveMigration.LEVEL_SCALES`, Stufentabellen `LEVEL_STEPS`). Beispiel Küche: früher 0,07 von 0,26 Verquatsch-Gewicht je Stufe (≈ 26,9 %), heute −0,45 % je Stufe, daher ×60 (alte Stufe 3 → 180 = −81 %).
- [x] Transportschätzung nutzt das Lauftempo der Boten: `Formulas.runner_trip_time` = `RUNNER_TRIP_ESTIMATE` / Botenschuhe; Kapazität und Ausbau-Gewinn steigen damit mit jeder Stufe Botenschuhe.
- [x] Ausbau-Gewinn der Botenschuhe für Boten mit der Aufgabe Ablehnung exakt über `Formulas.reject_trip_time(state, speed_factor)`: Sobald die Mindestdauer von 12 s greift, bringt eine weitere Stufe rechnerisch nichts mehr.
- [x] Röhrenkapazität-Gewinn aus dem Schritt der Spur (+1 Akte je Röhre und Stufe) statt fester Annahme.
- [ ] Mit Balance-Bot (kauft bereits die günstigste Spur über `UpgradeCatalog` und `buy_entry`) prüfen, ob die feinen Spuren in jeder Phase ein „kleines Upgrade“ zu 1–2 min Einkommen bieten und die Max-Kaufmenge nicht zu schnell ganze Spuren leert.

### 4.14 [H] Amtsstufen: Aufwerten statt Eröffnen
**Befund (Spieler-Feedback).** Große Ausbauschritte gab es nur als nächste Abteilung oder Gebäudestufe; nach dem Zoll war Schluss. Gewünscht: Jedes Amt lässt sich für viel Geld aufwerten, sodass „4. Amt eröffnen“ und „1. Amt auf Stufe 2“ ähnlich viel kosten und einbringen und abgewogen werden müssen. Zweites Feedback: Stufen bis 250, jede Stufe etwas wertvoller, alle 25 Stufen ein großer Multiplikator (×1,5 bis ×3).
- [x] Jede eröffnete Abteilung hat eine Amtsstufe 1–250 (`GameConfig.MAX_DEPARTMENT_RANK`). Jede Stufe multipliziert alle Gebühren der Abteilung mit `RANK_LEVEL_FEE_FACTOR` = 1,02, jeder 25. Stufe (`RANK_MILESTONE_STEP`) zusätzlich mit `RANK_MILESTONE_FACTORS` (1,5 / 1,5 / 2 / 2 / 2 / 2,5 / 2,5 / 2,5 / 3 / 3); Stufe 250 ≈ ×350 572. Der Andrang bleibt gleich, damit keine zusätzliche Überlastung entsteht. Gegengewicht: `RANK_LEVEL_TIME_FACTOR` = 1,01 je Stufe verlängert die Bearbeitung an den eigenen Stationen der Abteilung (Stufe 100 ≈ ×2,7 Zeit bei ×64 Gebühr). Netto bleibt jede Stufe lohnend, der Durchsatz verlangt aber weitere Tische, Ausbau und Personal.
- [x] Preise: `base_cost` × 1,07^(Stufe − 1) (`RANK_LEVEL_COST_GROWTH`), die ersten 24 Stufen kosten zusammen die Eröffnung der nächsten Abteilung (`ladder_cost(i + 1)`, jenseits des Zolls ×`RANK_LADDER_GROWTH` = 5). Ansehen je 25er-Block aus der Eröffnungsleiter (`level_reputation`). Wird `unlock_cost` neu gesetzt, wandern die Preise automatisch mit.
- [x] Abwägung: Der erste Meilenstein bringt 43–101 % dessen, was die gleich teure nächste Abteilung bei voller Besetzung bringt (Test erlaubt 40–125 %). Innerhalb eines Blocks wächst die Amortisation je Stufe um ×1,07/1,02; der Kauf, der den Meilenstein erreicht, amortisiert sich schnell; je Block wächst die Amortisation um ×1,1 (Meilenstein ×3) bis ×2,2 (×1,5). Per Test abgesichert.
- [x] Mehrfachkauf ×10/Max über die geometrische Summe; endet an der nächsten Ansehensschwelle (`reachable_level`, `UpgradeEntry.cap`).
- [x] Alte Stände (Stufe 1–10, ×2,5 je Stufe) werden auf die kleinste neue Stufe mit mindestens gleichem Faktor umgerechnet (`SaveMigration.legacy_rank_level`, 10 → 179).
- [x] Ansicht „Ausbau“ sortiert Eröffnung, Amtsstufen und Gebäudestufe nach Amortisation; Karten zeigen „Bis zu +…/Min. · rechnet sich in etwa …“ und den nächsten Meilenstein.
- [ ] Mit dem Balance-Bot messen (kauft Amtsstufen nach Eröffnung und Gebäudestufe über `expansion_entries`): Abstand zwischen großen Käufen, Verhältnis Amtsstufen zu Eröffnungen, Einkommen nach 8 h; prüfen, ob 1,07 je Stufe das Spätspiel (Zoll Stufe 249 ≈ 1,3·10¹⁴) nicht zu lang macht.
- [ ] Die Mehrertrags-Anzeige rechnet mit `expected_case_value` und unterschätzt dringende Fälle (siehe Abschnitt 5); wird das dort behoben, profitiert die Ausbau-Ansicht mit.
- [ ] Prüfen, ob Amtsstufen in endlose Ziele bzw. Meilensteine (3.3) einfließen, z. B. „Erste Abteilung auf Stufe 100“.

### 4.15 [M] Wartemarken realistischer, Aufrufanzeige im Spätspiel (Kunden-Feedback)
**Befund.** „Leute ziehen sich nur eine Wartemarke, wenn sie dann auch aufgerufen werden.“ Ursache: Die Anzeige zeigte die Zahl der Aufrufe statt der Nummer des Aufgerufenen; wer mit Marke ging, hinterließ keine sichtbare Lücke. Außerdem soll die Aufrufanzeige gegen Ende etwa 10-mal so viel schaffen.
- [x] Fortlaufende Nummer je Bürger (`CaseFile.ticket`), Anzeige zeigt die Nummer des Aufgerufenen (`last_called_ticket`), Abgänge mit Marke zählen als verfallen (`tickets_lapsed`, Statistik). Wie viele Marken verfallen, ergibt sich aus Geduld und Aufruftempo; ein festes Verhältnis (z. B. 2,5-mal so viele Marken, 2/3 verfallen) ist bewusst nicht eingebaut, weil jeder Abgang Ansehen kostet.
- [x] Aufrufanzeige entfernt (Spuren *Schnellere Aufrufanzeige*/*Weitere Anzeigetafel* gestrichen): Bürger mit Nummer rücken sofort zum Empfang nach, Anstehplätze `TICKET_CALL_SLOTS` × Empfangstische.

---

### 4.16 [H] Fester Zulauf, Bürger-Timer und Bewertungen als Bremse
Vorgabe: höchstens 180 Bürger/min, nur abhängig von der Zahl eröffneter Abteilungen; harte Timer je Phase; Bewertungen senken den Zulauf.
- [x] Zulauf (ersetzt durch 4.18): 10/min mit der ersten Abteilung, +16/min je weiterer, die achte füllt auf 180/min auf. Bewertungsstufen `REVIEW_ARRIVAL_TIERS`: ≥ 4,6 → 100 %, ≥ 4,3 → 80 %, ≥ 3,5 → 65 %, darunter 40 %.
- [x] Automaten: 0,32 → 1 Bürger/s in 100 Stufen je Automat (Start 19,2/min, also knapp unter den 22,5/min der ersten Abteilung; ab Stufe 9 reicht er), höchstens 3 Automaten (3 × 60/min = 180/min), nächster erst nach Vollausbau (`requires`). 12 Plätze je Automat; volle Schlangen → wütend weg.
- [x] Timer: Schlange 30 s, Sitzplatz 60 s, Stehplatz 20 s, am Schalter 20 s. Wer geht, beschwert sich immer (Briefkasten voll → schlechte Bewertung).
- [x] Halle: zwei Warteräume (Annahme, Abholung) mit je 40 Plätzen, Start je 15 Sitz- und 25 Stehplätze, je 25 Stufen *Sitzplatz statt Stehplatz* (500 · ×1,1). Der Empfang ruft nur auf, solange die Abholung Platz hat.
- [x] Geduld abgelaufen: Akte auf den Ablehnungsstapel von Empfang bzw. Ausgabe, Bürger geht als wütender Besucher direkt zur Beschwerdestelle.
- [ ] Mit Balance-Bot prüfen, ob 40 Plätze in der Abholung reichen: Sie halten alle Bürger, deren Akte gerade durch die Abteilungen läuft. Wird sie zum Dauer-Engpass, Plätze je Raum getrennt anheben.
- [ ] Mit Balance-Bot prüfen: Bei 22,5/min je Abteilung ist der Start-Automat (24/min) knapp ausgelastet, der Empfang mit einem Beamten (≈ 18/min) nicht. Das ist gewollt (früher Engpass), aber Abgänge und die daraus folgenden Bewertungen können den Zulauf schnell auf 65 % oder 40 % drücken. Prüfen, ob das Frühspiel ohne Dauerfrust spielbar bleibt; ggf. Preise von *Druckgeschwindigkeit* und Empfangsausbau senken.
- [ ] Preise der Automaten 2/3 (100 000 bzw. 20 000 000) und ihrer Stufen gegen den Zeitpunkt der 4. bzw. 7. Abteilung abgleichen.

### 4.17 [H] Frühspiel ohne Personal, Stau-Pausen und harte Bewertungen (Kunden-Feedback)
- [x] Neues Spiel ohne Personal im Bürgerservice; Passfoto braucht Fotografen (kein Automat), die Bürger zum Foto aufrufen.
- [x] Volle Ausgangsablage oder voller Ablehnungs-Ausgang an einer Sachbearbeitung schickt das ganze Team in Mittag/Kaffeeklatsch, Arbeit dort blockiert bis beide Ablagen Platz haben. Ablehnungsstapel ausbaubar (+2 je Stufe, 10 Stufen, Start 12, Maximum 32, 0,5 × Tischpreis · ×1,22).
- [x] Jeder nicht abgewimmelte Beschwerdeführer vor vollem Briefkasten → 1–2 Sterne, keine Obergrenze, keine Abschreckung nach Klagen mehr. Lob 3–5 Sterne zufällig alle 45–120 s, unabhängig vom Spiel.
- [x] Spieler am Beschwerdetresen: alle Besucher gehen ohne Beschwerde.
- [ ] Mit Balance-Bot prüfen: Durch die harte Bewertungsregel kann der Durchschnitt schnell unter 4,3/3,5 fallen und den Zulauf auf 65 %/40 % drücken; Lob (Ø ≈ 4,5 Sterne, ≈ 0,7/min) gleicht nur teilweise aus. Ggf. Lob-Intervall oder Briefkasten-Startgröße anpassen.
- [ ] Mit Balance-Bot prüfen, wie oft Stau-Pausen im Frühspiel auftreten (Ausgang 8 Plätze bei einem Tisch) und ob Ablagen/Ablehnungsstapel früh genug bezahlbar sind.

### 4.17b [H] Gebäudeausbau entfällt, Ansehen als Langzeit-Bremse (Spieler-Feedback)
Vorgabe: Abteilungen direkt kaufen, das Gebäude wächst implizit mit; Ansehen soll weitere Stufen stark begrenzen und das Spiel strecken.
- [x] Gebäudestufe nicht mehr kaufbar: `GameState.sync_building_stage` hebt sie bei jeder Eröffnung auf `GameConfig.stage_for_departments` (1 / 2–3 / 4–5 / 6–7 / 8 Abteilungen), Poststelle ab der zweiten Abteilung. Platz-Sperre („space“), Katalogart `stage`, `expand_building` und die Stufen-Feier entfallen.
- [x] Ansehensschwellen der Eröffnungen angehoben: 15/60/150/300/500/800/1 300 → 20/120/350/700/1 200/2 000/3 500 (mindestens ×1,5 je Abteilung, Test `test_reputation_strongly_limits_department_openings`). Die Amtsstufen-Blöcke erben sie über die Eröffnungsleiter, ab dem Zoll 3 500.
- [x] Ziele „Gebäude erweitern“ durch Ansehens-Ziele ersetzt (10, 60, 250, 1 000, 3 000; Indizes unverändert, alte Spielstände behalten ihren Zielstand).
- Bot-Messung (`--hours=8 --active=480`): Finanzamt nach 22 min, Ansehen 60 nach 44 min, danach pendelt das Ansehen des Bots bei ≈ 126 (hohe Bürgerverluste, Einkommen ≈ 48/s); die Kfz-Zulassung (350) erreicht er in 8 h nicht. Der Bot spielt deutlich schlechter als ein Mensch, die Bremse greift aber spürbar.
- [ ] Mit dem Balance-Bot über längere Zeit messen, ob die Ansehensschwellen ab Kfz-Zulassung (350) nicht zu einer reinen Wartezeit ohne sinnvolle Käufe werden; ggf. Ansehensquellen (Einarbeitung, Kränzchen, Bewertungen) als aktive Beschleuniger stärken.

### 4.18 [H] Schnellerer Einstieg, weniger Unterbrechungen (Spieler-Feedback)
- [x] Zulauf `Formulas.base_arrivals_per_minute`: 10/min (`START_ARRIVALS_PER_MINUTE`) mit der ersten Abteilung, +16/min (`ARRIVALS_PER_DEPARTMENT`) je weiterer, mit allen 8 Abteilungen 180/min (10, 26, 42, 58, 74, 90, 106, 180).
- [x] Wartemarken-Automat startet mit 0,15/s (9/min), knapp unter den 10/min der ersten Abteilung; ab Stufe 2 reicht er.
- [x] Einstiegsrabatt `Formulas.early_discount`: Stufe 1 jeder Spur und jedes Kaufs (Tische ab dem zweiten, Einstellen, Personal, Stapel, Röhren, Briefregal, Botenstufen) kostet 25 %, linear bis 100 % ab Stufe 11 (`EARLY_DISCOUNT_LEVELS`, `EARLY_DISCOUNT_START`). Mehrfachkäufe summieren über `ramped_sum`; Folge-Automaten setzen die Preisstufe über `price_offset` fort.
- [x] Weniger Unterbrechungen: Wachzeit 100 → 180 s; Kränzchen erst nach 110 s, dann 220–400 s; Mittag erst nach 300 s, dann 280–480 s; Krankmeldung erst nach 360 s, dann 40–80 min je Beamtem; Streit erst nach 220 s, dann 200–400 s; Ereignisse erst nach 6 min, dann 5–10 min.
- [ ] Mit dem Balance-Bot messen, ob das Frühspiel mit 10/min nicht zu leer wirkt und ob der Rabatt die erste Abteilung zu schnell auslastet.

## 5. Niedrige Priorität / Feinschliff

- [ ] [N] `expected_case_value` berücksichtigt dringende Fälle (×1,5) nicht → Einnahmen/min-Anzeige und Offline-Ertrag unterschätzen Sozialamt (35 % dringend).
- [x] [N] Spieler arbeitet an **allen** unbesetzten Tischen einer Station gleichzeitig (`work()` iteriert `range(staff, desks)`): Tische kaufen ohne Personal vervielfacht die eigene Arbeitskraft. Nach 2.4 gewollt? Sonst: Spieler arbeitet nur am ersten unbesetzten Tisch, `work_ethic` erhöht Tempo. **Umgesetzt:** nur noch ein Tisch, damit Engpässe spürbar bleiben.
- [ ] [N] Beschwerde-Schreddern 4 €, Ablehnungs-Schreddern 2 € fest → ab Stufe 2 irrelevant; an Einkommen koppeln (`Einkommen/min × 0,05`).
- [ ] [N] Ziel „Ansehen 40“ (Ziel 9) ohne Ansehensbelohnung ist nach 2.2 leicht; Reihenfolge der Ziele gegen die neue Kostenkurve aus 3.2 neu prüfen.
- [x] [N] Bewertungs-Drain 0,0006/s je Gewicht = −2,2 Ansehen/h je 1-Stern-Bewertung, bis zu 5 → −11/h; nach 2.2 auf −0,5/h je Bewertung senken, dafür Andrang ×(Durchschnitt/5) koppeln (sichtbarer Effekt). **Umgesetzt:** Drain unterliegt der Dämpfung; Andrang × Bewertungsfaktor 0,85–1,25.
- [ ] [N] Einwohnerzahl (`POPULATION_PER_CASE`) wächst linear mit Fällen; Metropole erst bei 50 000 Fällen; Ränge an Meilensteine aus 3.3 binden und mit kleinem Bonus (+Lobbyplätze) versehen.
- [x] [N] Markendruck: `ticket_speed` 400 Stufen, 300 · ×1,035, −0,7 % je Stufe (3 s → 0,18 s); jeder Automat zieht parallel, zwei Automaten = doppelte Rate.
- [x] [N] `MAX_STATION_LEVEL = 50` nach 4.1 auf 100 anheben (Schwellen alle 10). **Umgesetzt:** 100 Stufen.

---

## 6. Vorgehen und Messplan

1. Reihenfolge: 2.1 → 2.2 → 4.5a → 2.3 → 2.4 (Frühspiel spielbar machen), dann 3.1/3.2 (Kurve), dann 3.3/3.4 (Langzeit), dann Rest von Abschnitt 4.
2. Nach jedem Block Balance-Bot laufen lassen (`--hours=8 --active=30` und `--active=480`) und Zielwerte prüfen:
   - 30 min aktiv: Steuerstelle nach ≤ 25 min, Bürgeramt nach ≤ 20 min, verlorene Bürger < 10 % der Ankünfte.
   - 8 h aktiv: mindestens Kreisverwaltung + 4 Abteilungen, Ansehen > 150, alle 3–6 min ein Kauf (Bot-Protokoll um Kaufzähler erweitern).
3. Diagnose-Bot (Snapshot alle 5 min, Varianten `--nosick`, `--norep`) nach `tests/tools/diag_bot.gd` übernehmen, damit Verfügbarkeit und Verluste je Station sichtbar bleiben.
4. Nach Abschluss: FEATURES.md (Wirtschaft, Personal, Ziele), context.md und Tests aktualisieren; Konstanten in `game_config.gd` bleiben die einzige Quelle.

- [x] Bewertungen löschen/anzeigen an die Gebäudestufe gebunden (statt Einkommen): Löschen 1 Stern / Klage Stufe 0 75 / 100, Stufe 1 (ab Finanzamt) 150 / 250, Stufe 2 500 / 800, Stufe 3 2.000 / 3.500, Stufe 4 10.000 / 18.000; je Bewertung feste Abweichung −30 % bis +30 %. Sternfaktoren beim Löschen normiert auf 1 / 0,5 / 0,2 / 0,067 / 0. Löschen bleibt immer günstiger als Klagen (Test `test_deleting_is_always_cheaper_than_suing`).


**Hinweis (Ablehnungs-Umbau):** Ablehnungs-Boten sind eine vierte Aufgabe der normalen Boten (Obergrenze 30 gemeinsam); Sammelwagen, Flinke Ablehnungs-Boten und Abteilungsschredder entfallen. Werte noch nicht neu vermessen (Balance-Bot offen).
