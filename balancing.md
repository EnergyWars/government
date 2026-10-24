# Balancing – Review und Todos

Stand: 24.10.2026. Grundlage: Code-Review von `game_config.gd`, `formulas.gd`, `simulation.gd`, `progression.gd`, `goal_tracker.gd`, `offline_calculator.gd`, dazu Simulationen mit `tests/tools/balance_bot.gd` (8 h, 30 min bzw. 480 min aktiv) und einem Diagnose-Bot (Stationen alle 5 min, Varianten „ohne Krankheit“ / „ohne Ansehensverlust“).

Ziele des Balancings (Vorgabe):
1. Bei jeder neuen Abteilung muss der Spieler erst viel selbst machen.
2. Es gibt durchgängig kleine Dinge zu verbessern (kein Leerlauf zwischen großen Käufen).
3. Lange Spielerbindung, Spiel soll süchtig machen (kurze Belohnungsschleifen, klare nächste Ziele, nie Stillstand, nie Rückschritt ohne Gegenmittel).

Legende: **[K]** kritisch (blockiert Fortschritt), **[H]** hoch, **[M]** mittel, **[N]** niedrig. `[ ]` offen, `[x]` umgesetzt, `[~]` bewusst verworfen.

Zusätzliches Designziel: **Engpässe entstehen häufig und bewusst.** Der Spieler muss oft selbst eingreifen, regelmäßig einzelne Stationen ausbauen und kann einen Engpass mit Boosts oder Werbung überbrücken. Ansehen sinkt höchstens minimal.

Bewusst **nicht** umgesetzt, weil es Engpässe abbauen würde: größere Fächer und Rückfluss bei Stau (4.5a), Andrang an die Kapazität koppeln (3.5), längere Geduld und größerer Sitzbereich (3.5), höhere Personal-Obergrenzen (3.1), Störungs-Budget bei Ereignissen (4.7).

### Umgesetzte Engpass-Mechaniken
| Mechanik | Wirkung |
|---|---|
| Einweihungs-Euphorie | 45 s ×1,5 nach jedem Ausbau, die nächste Station läuft voll |
| Meilensteine | ×1,5 alle 10 Stufen, das Tempo springt sprunghaft |
| Land unter | ab 75 % vollem Eingang: rote Plakette, ×1,5 Müdigkeit, bevorzugt krank |
| Mehrfachanträge | bis zu 2 Zusatzanträge, die parallel in andere Abteilungen strömen |
| Fehlende Unterlagen | 5 % der Akten erzeugen einen Nachreich-Brief |
| Poststelle | zweiter Eingang, füllt Sachbearbeitungen bis zur Hälfte, nur 50 % Gebühr |
| Einarbeitung | 5 Handfälle je neuer Abteilung vor dem ersten Einstellen |
| Boosts | 14 Boosts gegen Siegel oder Werbung (Attrappe) |

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
**Befund.** Summe aller Technik-Kosten außer Rohrpost/Röhren/Portal/KI: ~0,9 Mio. Summe aller globalen Mitarbeiter und Bereiche (12 Boten, 3 Ablehnungs-Boten, 4 Kaffee-Praktikanten, 4 Telefonisten, 2 Wachen, 2 Praktikanten, Warte- 8/Sitzbereich 12): ~0,55 Mio. Das Bauamt kostet allein 400 000 €, das Wohnungsamt 2 Mio. Ab Kreisverwaltung ist alles Kleine gekauft; danach gibt es nur noch Tische/Stufen in teuren Abteilungen und vier Großtechniken. Zwischen Wohnungsamt (2 Mio.) und Sozialamt (12 Mio.) liegen Stunden ohne „kleines Upgrade“.
**Todos.**
- [ ] Alle globalen Mitarbeiter-/Bereichspreise an das **aktuelle Einkommen** koppeln (`max(Basis, Einkommen/min × Faktor) × Wachstum^n`) wie bereits `sick_bonus_cost`; dann bleiben Bote Nr. 9 oder Telefonist Nr. 3 in jeder Phase eine spürbare, aber kurze Investition.
- [ ] Obergrenzen anheben und an Gebäudestufe binden: Boten 12 → 4/Stufe (max. 20), Kaffee-Praktikanten 4 → 1/Stufe + 2, Telefonisten 4 → 6, Wachen 2 → 4, Praktikanten 2 → 4, Ablehnungs-Boten 3 → 5.
- [ ] Technik-Stufen verlängern mit abflachender Wirkung statt harter `max_level`: Kaffee 6 → 10, Scanner 3 → 8, Digitale Akte 3 → 8, Qualitätsschulung 3 → 6, Weckdienst 5 → 8, Röhrenkapazität 3 → 6; Wirkung je Stufe linear, Kosten ×Wachstum.
- [ ] Neue **Dauer-Senke**: „Verwaltungsreform“ (Prestige-light, s. 3.4) oder „Behördenschild / Ausstattung“ mit rein kosmetischen, aber sichtbaren Stufen (Pflanzen, Teppich, Kaffeetasse des Spielers) zu Preisen = 1–2 min Einkommen.
- [ ] Beamten-Schulungen (4 Spuren × 3 Stufen je Beamtem) als die vorgesehenen Klein-Upgrades sichtbar machen: Sammelknopf „Alle Beamten dieser Station schulen“ und Hinweis im Statistik-Report, wenn Schulungen günstiger als eine Stufe sind.

### 3.2 [H] Freischalt-Sprünge wachsen zu steil
**Befund.** Amortisation nur aus Rohertrag der neuen Abteilung (Gebühr/Intervall ÷ Freischaltkosten): Steuer 2,4 min, Gewerbe 11 min, Kfz 34 min, Bauamt 1,9 h, Wohnungsamt 3,6 h, Sozialamt 9,3 h, Zoll 19 h. Multiplikatoren (Ansehen ×2–2,8, Andrang ×3–5,5) verkürzen das später, aber die Ansehensschwellen (300/500/800/1 300) bremsen zusätzlich. Gleichzeitig steigen die Kostenfaktoren der Abteilungen ×3 je Stufe (1, 3, 9, 27, 80, 220, 650, 1 900) – ein Sachbearbeiter-Tisch im Zoll kostet 228 000 €, eine Stufe 171 000 €.
**Todos.**
- [ ] Zielkurve festlegen: jede Freischaltung (Abteilung oder Gebäudestufe) nach 15–45 min aktiver Spielzeit bzw. 1 Offline-Nacht; Kosten der nächsten Abteilung ≈ 20–30 min aktuelles Gesamteinkommen.
- [ ] `unlock_cost` neu setzen (Vorschlag): Steuer 600, Gewerbe 5 000, Kfz 30 000, Bauamt 150 000, Wohnungsamt 600 000, Sozialamt 2,5 Mio., Zoll 10 Mio.; `cost_multiplier` entsprechend abflachen (1, 2,5, 6, 15, 40, 100, 250, 600).
- [ ] Ansehensschwellen auf Ziel „erreichbar nach ~70 % der Geld-Wartezeit“ eichen: 10, 40, 100, 200, 320, 480, 700 (nach Umsetzung 2.2 neu messen).
- [ ] Gebäudestufen-Kosten in dieselbe Kurve legen (2 500 → 2 000, 50 000 → 30 000, 1,5 Mio. → 500 000, 40 Mio. → 6 Mio.).
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
**Befund.** Spätspiel endet bei Zoll + Stufe 50. Klassische Langzeitmotivation (Neustart mit dauerhaftem Bonus) fehlt.
**Todos.**
- [ ] **„Versetzung“**: ab Stadtverwaltung + Zoll kann der Spieler in eine neue Stadt versetzt werden. Neustart mit `Dienstgrad`-Punkten (aus erreichtem Ansehen/Fällen), jeder Punkt +2 % Gebühren und +1 % Tempo dauerhaft; freigeschaltete Techniken starten auf Stufe 1 (Rohrpost bleibt gesperrt, sonst fehlt der Botenabschnitt).
- [ ] Je Versetzung eine sichtbare Veränderung (neuer Stadtname aus Liste, anderes Amtsschild, Flaggenfarbe) – keine urheberrechtlich geschützten Namen.
- [ ] Speicherstand: neue Felder `prestige_level`, `prestige_points`, Migration mit Test.

### 3.5 [H] Positive Rückkopplung Ansehen → Andrang überlastet unbeaufsichtigt
**Befund.** Andrang `1 + √Ansehen/8` (bis ×8) und Nachfragewachstum (bis ×2,2) vervielfachen die Ankünfte, Eingangsfach `6 + 2·Tische`, Lobby 16–64. Jede Erhöhung des Ansehens bringt mehr Bürger, die bei ausgelasteten Stationen gehen und Ansehen abziehen. Das System schwingt um einen Gleichgewichtspunkt, bei dem ständig Bürger verloren gehen – Dauerfrust statt Flow.
**Todos.**
- [ ] Andrang an die **Kapazität** koppeln: Ankunftsrate = min(Nachfrage, 1,15 × realistische Kapazität des langsamsten Schritts). Überschuss wird nicht als „verloren“, sondern als „Terminvergabe“ gezählt (kein Malus, Hinweis „Mehr Bürger möglich, wenn du ausbaust“).
- [ ] Geduld `BASE_PATIENCE` 90 s → 150 s, Warteraum-Technik +40 % je Stufe beibehalten.
- [ ] Sitzbereich 24 Plätze blockiert den Empfang bereits bei einer Abteilung mit vollen Fächern; Basis 24 → 36 und +6 je Gebäudestufe automatisch, Ausbau bleibt zusätzlich.

---

## 4. Mittlere Priorität

### 4.1 [M] Stufen-Upgrade: linearer Nutzen, exponentieller Preis
Stufe n gibt +15 % Tempo (additiv), Preis ×1,45 je Stufe. Stufe 10 (×2,35) kostet 2 550 €, Stufe 20 (×3,85) 105 000 €, Stufe 30 (×5,35) 4,3 Mio. Ab Stufe ~15 ist jede Stufe schlechter als ein Tisch; `MAX_STATION_LEVEL = 50` wird nie erreicht.
- [x] Wachstum 1,45 → 1,25 und Bonus je Stufe 15 % → 10 % mit **Schwellen-Boni** alle 10 Stufen (×1,5 Tempo bei 10/20/30/40/50, Anzeige im Button „Nächster Meilenstein in 3 Stufen“) – das klassische Idle-Muster, das Klein-Upgrades spannend hält. **Umgesetzt:** 12 % je Stufe, ×1,5 alle 10 Stufen, Wachstum 1,35 und Anzeige auf der Stationskarte.
- [ ] Tische: `DESK_GROWTH` 2,2 → 1,8; Einstellen `HIRE_GROWTH` 1,8 → 1,5. Beide Käufe sollen nach Einarbeitung die Hauptsenke sein.

### 4.2 [M] Fachkräfte und Teamleitungen zu schwach bzw. zu teuer
Fachkraft: 5 × Einstellkosten × 2,4^n, nur komplexe Fälle (10–35 %) ohne Zeitstrafe, Fehler ×0,3. Teamleitung 1 000 € × Multiplikator × 3^n für +20 % Tempo und weniger Einnicken.
- [ ] Fachkraft zusätzlich als vollwertiger Arbeiter zählen (heute `effective_workers` zählt sie, aber `_pick` reserviert ihr nur komplexe Fälle → steht oft leer). Fachkraft nimmt einfache Fälle, wenn kein komplexer wartet.
- [ ] Teamleitung: zweite Stufe halbiert Krankheits- und Streitwahrscheinlichkeit der Abteilung; Preis ×3 → ×2,2.

### 4.3 [M] Rohrpost entwertet eine ganze Upgrade-Linie schlagartig
250 000 € einmalig → Transport unendlich, 12 Boten und 3 Stufen Aktenwagen wertlos.
- [ ] Rohrpost als Netz je Abteilungsraum verkaufen (eine Röhre je Verbindung, Preis steigend), Boten bleiben für nicht angeschlossene Strecken nötig; `tube_capacity` dann je Röhre.
- [ ] Boten nach Rohrpost automatisch in „Ablehnungs-Boten“ umschulen (Knopf im Team-Fenster), damit Investition nicht verloren ist.

### 4.4 [M] Prozess-Klage ist ab dem zweiten Versuch ein Geldautomat
Erwartungswert Geld = Chance × 2,5 − 1 ≥ 0 schon bei 40 %; Chance steigt +8 % je Klage bis 85 %, Kosten nur ×1,25. Ab Klage 2 positiver Erwartungswert, bis 20 Klagen je Bewertung.
- [x] `REVIEW_LAWSUIT_GROWTH` 1,25 → 1,6 oder Auszahlung 2,5 → 1,8. **Umgesetzt:** Wachstum 1,6; höchstens 3 Klagen je Bewertung (Chance 50/58/66 %), danach nur Werbung oder Löschen (×1,5 je gescheiterter Klage). Kein Schadenersatz mehr: Sieg erstattet nur die Klagekosten (1,0-fach), Klagen bringen also nie Gewinn.
- [x] Löschen und Krank-Bonus teurer: Bewertung löschen Grundpreis 25 s Einkommen (min. 40) statt 8 s (min. 10), 1 Stern damit ≈ 75 s Einkommen; Klage 1,2 × Grundpreis (≈ 30 s statt 12 s, bleibt günstiger als 1-Stern-Löschen, Risiko dafür). Krank-Bonus 0,3/0,6/1,0 Einkommensminuten statt 0,1/0,25/0,6, Mindesteinkommen 50/min; Obergrenze 1 Minute bleibt (Test `test_bonus_stays_cheap_compared_to_income`).
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

---

## 5. Niedrige Priorität / Feinschliff

- [ ] [N] `expected_case_value` berücksichtigt dringende Fälle (×1,5) nicht → Einnahmen/min-Anzeige und Offline-Ertrag unterschätzen Sozialamt (35 % dringend).
- [x] [N] Spieler arbeitet an **allen** unbesetzten Tischen einer Station gleichzeitig (`work()` iteriert `range(staff, desks)`): Tische kaufen ohne Personal vervielfacht die eigene Arbeitskraft. Nach 2.4 gewollt? Sonst: Spieler arbeitet nur am ersten unbesetzten Tisch, `work_ethic` erhöht Tempo. **Umgesetzt:** nur noch ein Tisch, damit Engpässe spürbar bleiben.
- [ ] [N] Beschwerde-Schreddern 4 €, Ablehnungs-Schreddern 2 € fest → ab Stufe 2 irrelevant; an Einkommen koppeln (`Einkommen/min × 0,05`).
- [ ] [N] Ziel „Ansehen 40“ (Ziel 9) ohne Ansehensbelohnung ist nach 2.2 leicht; Reihenfolge der Ziele gegen die neue Kostenkurve aus 3.2 neu prüfen.
- [x] [N] Bewertungs-Drain 0,0006/s je Gewicht = −2,2 Ansehen/h je 1-Stern-Bewertung, bis zu 5 → −11/h; nach 2.2 auf −0,5/h je Bewertung senken, dafür Andrang ×(Durchschnitt/5) koppeln (sichtbarer Effekt). **Umgesetzt:** Drain unterliegt der Dämpfung; Andrang × Bewertungsfaktor 0,85–1,25.
- [ ] [N] Einwohnerzahl (`POPULATION_PER_CASE`) wächst linear mit Fällen; Metropole erst bei 50 000 Fällen; Ränge an Meilensteine aus 3.3 binden und mit kleinem Bonus (+Lobbyplätze) versehen.
- [ ] [N] `MAX_STATION_LEVEL = 50` nach 4.1 auf 100 anheben (Schwellen alle 10).

---

## 6. Vorgehen und Messplan

1. Reihenfolge: 2.1 → 2.2 → 4.5a → 2.3 → 2.4 (Frühspiel spielbar machen), dann 3.1/3.2 (Kurve), dann 3.3/3.4 (Langzeit), dann Rest von Abschnitt 4.
2. Nach jedem Block Balance-Bot laufen lassen (`--hours=8 --active=30` und `--active=480`) und Zielwerte prüfen:
   - 30 min aktiv: Steuerstelle nach ≤ 25 min, Bürgeramt nach ≤ 20 min, verlorene Bürger < 10 % der Ankünfte.
   - 8 h aktiv: mindestens Kreisverwaltung + 4 Abteilungen, Ansehen > 150, alle 3–6 min ein Kauf (Bot-Protokoll um Kaufzähler erweitern).
3. Diagnose-Bot (Snapshot alle 5 min, Varianten `--nosick`, `--norep`) nach `tests/tools/diag_bot.gd` übernehmen, damit Verfügbarkeit und Verluste je Station sichtbar bleiben.
4. Nach Abschluss: FEATURES.md (Wirtschaft, Personal, Ziele), context.md und Tests aktualisieren; Konstanten in `game_config.gd` bleiben die einzige Quelle.
