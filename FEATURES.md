# Amts-Tycoon (Department Tycoon) – Features

Bewegungsbasiertes Verwaltungs-Tycoon für Android im Stil von „My Mini Mart“: Die Spielfigur ist anfangs die einzige Angestellte des Amts, läuft durchs Gebäude, trägt Akten zwischen Stationen und arbeitet selbst an unbesetzten Tischen. Jede Einstellung nimmt ihr eine konkrete Aufgabe ab. Konzeptquellen liegen in `docs/concept/`.

## Steuerung
- **Laufen**: Irgendwo auf die Karte drücken und ziehen (virtueller Joystick erscheint am Druckpunkt). Am Desktop zusätzlich WASD/Pfeiltasten.
- **Automatische Interaktion in der Nähe** (Radius 64): Akten aus Ablagen aufnehmen, passende Akten in Eingangsfächer legen, an markierten Arbeitsplätzen unbesetzter Tische arbeiten.
- **Kurzes Tippen** auf einen Abteilungsraum öffnet dessen Verwaltung; auf einen gesperrten Raum die Abteilungsübersicht.
- **Leit-Pfeil** zeigt stets auf die nächstgelegene sinnvolle Aufgabe (abliefern › arbeiten/aufnehmen › Abteilung eröffnen); außerhalb des Bildes als Randpfeil.
- Zurück-Taste schließt offene Panels, sonst wird gespeichert und beendet.

## Arbeitsablauf (gemeinsam für alle Abteilungen)
Empfang → Sachbearbeitung der Abteilung → (optional: Verweis/Prüfdienst) → Signatur-Station der Abteilung → Ausgabeschalter. Jede Station hat Eingangsfach, Tische/Maschinen und Ablage mit sichtbarer Kapazität; volle Fächer werden rot markiert.
- **Empfang** (geteilt): Bürger stehen in einer sichtbaren Warteschlange mit Sprechblase (Abteilungs-Icon) und Geduldsring. Ist die Geduld erschöpft, gehen sie (Ansehen −0,3). Ist die Lobby voll, werden Neuankömmlinge abgewiesen (−0,15).
- **Sachbearbeitung**: setzt je nach Arbeitsmodus Fehler (Schnell / Normal / Gründlich: Zeit ×0,7/1,0/1,5, Fehler 30/12/3 %).
- **Signatur-Station** je Abteilung mit eigenem Endprodukt: Passfoto → Ausweis, Rechenmaschine → Bescheid, Gewerbestempel → gerahmte Erlaubnis, Schilderdrucker → Kennzeichen (Auto fährt weg), Architektin → gestempelter Bauplan, Gutscheindrucker → Wohnungsgutschein, Zahlstelle → Leistungskarte. Maschinen brauchen kein Personal, Bauamt und Sozialamt sind personell besetzt.
- **Ausgabeschalter** (geteilt): Übergabe, Bezahlung, schwebender Geldbetrag, Bürger verlässt mit Endprodukt das Gebäude.
- Unbesetzte Tische arbeiten nur, solange die Spielfigur am pulsierenden Arbeitsplatz steht.

## Abteilungen (schrittweise Komplexität)
| # | Abteilung | Besonderheit |
|---|---|---|
| 1 | Bürgerservice | Start, einfache Fälle |
| 2 | Finanzamt | Steuer-Stichtag-Ereignis |
| 3 | Gewerbeamt | Prüfdienst (geteilte Station) vor der Freigabe |
| 4 | Kfz-Zulassung | Schilderdrucker, Kennzeichen als Endprodukt |
| 5 | Bauamt | Prüfdienst, viele komplexe Fälle, Architektin statt Maschine |
| 6 | Wohnungsamt | Verweis: jede Akte muss zusätzlich durch die Meldestelle des Bürgerservice (abteilungsübergreifende Abhängigkeit) |
| 7 | Sozialamt | Viele dringende Fälle; bewilligte Fälle kommen nach 150–300 s als Wiedervorlage zurück (kürzere Route, 60 % Gebühr) |
| 8 | Zollamt | Eigener Ablauf ohne Empfang (siehe unten) |

Eröffnet wird eine Abteilung durch Stehen auf dem Kreis im gesperrten Raum (1,2 s) oder per Button, sofern Platz (Gebäudestufe), Ansehen und Geld reichen.

## Zollamt
- Lkw liefern Fracht an die **Laderampe**; Frachtarten: Stückgut, Elektronik (höhere Verdachtsquote), Fahrzeuge.
- **Anmeldeprüfung** markiert verdächtige Sendungen (60 % + 12 % je Fachkraft).
- **Schnellspur**: Unmarkierte Sendungen überspringen den Frachtscanner. Schalter „Jede Sendung scannen“ erzwingt den Scanner für alle.
- **Frachtscanner** deckt Schmuggelware auf (50 % bei verdächtiger Fracht); sichergestellte Ware wird vor der Freigabe zum **Prüfdienst** umgeleitet (×3 Gebühr, +0,3 Ansehen).
- Übersehene Schmuggelware an der Freigabe kostet die Gebühr und 1 Ansehen.
- Statusetiketten an der Fracht: gelb markiert, rot festgehalten, grün freigegeben.

## Personal
- **Tische/Maschinen** pro Station (Limit je Gebäudestufe), **Personal einstellen** pro Tisch, **Ausbau** (+15 % Tempo je Stufe, max. 50).
- **Fachkräfte** (bis 3 je Sachbearbeitung): eigener Tisch nur für komplexe Fälle, keine Zeitstrafe, 70 % weniger Fehler; normale Tische nehmen dann keine komplexen Fälle mehr an.
- **Teamleitung** (bis 2 je Abteilung): +20 % Tempo für alle Stationen der Abteilung.
- **Boten** (bis 12): laufen als Figuren durchs Gebäude, reservieren Akten, tragen sie von Ablagen zum nächsten Eingangsfach und warten, wenn das Ziel voll ist.
- Team-Panel: Boten, Empfang, Ausgabeschalter und Prüfdienst.

## Beschwerdestelle und Aktenschredder
In der Eingangshalle gibt es eine Beschwerdestelle und einen Aktenschredder. Ab 5 erledigten Fällen laufen etwa alle 45 Sekunden Beschwerden ein (max. 8 im Kasten; ist er voll, kostet jede weitere Reputation). Der Spieler holt sie ab (Platz wie Aktentasche), bringt sie ungelesen zum Schredder und erhält pro Beschwerde etwas Geld und Reputation. Die Technik „Schredder-Praktikant“ (3 Stufen) schreddert automatisch alle 40/20/8 Sekunden eine Beschwerde. Die Führung zeigt den Weg zum Kasten bzw. Schredder.

## Krankmeldung, Telefon und Toiletten
Beamte melden sich regelmäßig krank (ab 3 Beschäftigten). Der Schreibtisch bleibt leer, bis jemand sie am Krankentelefon in der Küche anruft: der Spieler bleibt kurz am Telefon stehen oder angestellte Krankentelefonisten (Team, max. 4, mit steigendem Preis) rufen automatisch an. Die Telefonate sind als witzige Sprechblasen-Dialoge sichtbar. Ohne Anruf kehren Kranke nach 4 Minuten zurück. Außerdem gehen Beamte auf die Toilette (4 Kabinen im Küchenbereich) und müssen dort durch Danebenstehen (2 s) ermutigt werden; der Weckdienst verkürzt das ebenfalls.

## Layout Küche und Sanitär
Die Küche ist kleiner (Kühlschrank, Arbeitsplatte, Kaffeemaschine, Tisch). Rechts daneben liegt ein eigener Sanitärraum mit den vier Toiletten und dem Krankentelefon. Wird ein Beamter aus Küche oder Toilette geholt, läuft er sichtbar zu seinem Platz zurück (der Platz bleibt bis zur Ankunft leer). Die Krankentelefonate wählen zufällig aus 12 Dialogen.

## Beschwerde-Malus
Jede nicht geschredderte Beschwerde kostet laufend Ansehen (Anzeige am Beschwerdetresen in Ansehen/Min.).

## Küchenleben
Beamte gehen häufiger in die Küche: verquatschen (bleiben bis zum Abholen), Kaffee holen (kommen frischer zurück) oder laufen gemächlich (70 s; durch Danebenstehen neunmal schneller antreiben). Gelegentlich wird ein Kaffeekränzchen ausgerufen: mehrere Beamte gehen gleichzeitig in die Küche, der Spieler beendet es am Küchentisch. Technik: Kaffeemaschine (4 Stufen: schnelleres Holen, frischere Beamte, goldene Streifen), Küche (3 Stufen: weniger Verquatschen, mehr Selbstholer, Pflanzen).

## Küche
Über der Eingangshalle liegt eine Küche mit Kaffeemaschine (Lämpchen zeigen die Kaffeequalität). Beamte, die einnicken, gehen teils in die Küche: Selbstholer holen sich Kaffee und kehren nach 14 s erfrischt (länger wach) zurück; Tratschende bleiben, bis der Spieler sie in der Küche abholt (oder der Weckdienst sie zurückruft). Maximal 12 Gäste, danach schlafen Beamte am Platz.

## Prüfdienst
Ein Tippen auf den Prüfdienst-Raum in der Welt öffnet das Team-Menü, in dem die Prüfdienst-Station (Tische, Einstellen, Verbessern) bearbeitet wird. Dort steht sie unter „Öffentlicher Bereich“, in den Abteilungsmenüs der Abteilungen mit Prüfung unter den gemeinsamen Stationen.

## Performance
Die Weltansicht ist in Ebenen aufgeteilt (statischer Boden/Halle einmalig, Räume reihum begrenzt neu gezeichnet, Menschenmenge 30 Hz, Spieler 60 Hz), einfache Personen im Hintergrund, MSAA aus, 60 FPS-Limit.

## Flüssiges Scrollen
Sheets leiten Touch-Gesten auch von Karten und Buttons an den Scroll-Container weiter und scrollen mit Auslaufen (Fling).
Karte und Sheets scrollen ruhiger: die Kamera folgt framerate-unabhängig und pixelgerundet, statische Welt wird gedrosselt gezeichnet, Sheets starten das Scrollen schon nach 4 px und behalten die Position beim Neuaufbau.

## Faule Beamte
- **Einnicken und Kaffeepause**: Besetzte Tische (Angestellte und Fachkräfte, keine Maschinen) werden mit der Zeit müde, aber nur, solange Arbeit ansteht. Nach durchschnittlich 100 s (±30 %) nickt der Beamte ein (Zzz-Blase, geschlossene Augen) oder verschwindet in die Kaffeepause (Tasse mit Dampf). Sein Tisch steht dann still, auch neue Akten werden nicht begonnen.
- **Aufwecken**: Zum Tisch laufen und 0,7 s daneben stehen bleiben. Ein pulsierender Ring und ein Fortschrittsring zeigen den Vorgang. Der Leit-Pfeil weist auf schlafende Tische. Ohne Technik schlafen Beamte unbegrenzt weiter, Kaffeepausen enden von selbst nach 60 s.
- **Dagegen skillen** (Technik): *Kaffeequalität* (6 Stufen, je +35 % Wachzeit) und *Weckdienst* (5 Stufen: Eingenickte wachen nach 45/28/16/8/3 s von selbst auf, Kaffeepausen enden spätestens dann). *Teamleitung* verlangsamt das Einnicken je Person um 30 %. Mit voll ausgebautem Weckdienst läuft das Amt praktisch ohne Eingreifen.
- Anzeigen: Aufgaben-Panel zeigt je Abteilung „Zzz n“, Stationskarten „Pause oder Schlaf: n“, die Statistik zählt aufgeweckte Beamte; schwebende Sprüche beim Einnicken und Aufwachen.
- Offline-Ertrag bleibt unverändert bei 50 %, Schläfer bremsen ihn nicht.
- Das Abteilungsfenster zeigt auch die gemeinsamen Stationen der Route (Empfang, Ausgabe, Prüfdienst, Meldestelle), damit ein Engpass dort direkt ausgebaut werden kann.

## Ereignisse
Alle 3–6 Minuten tritt ein Ereignis auf (Banner mit Restzeit, betroffene Stationen zeigen ein Symbol). Datengetrieben in `GameConfig.EVENTS`; Dauer sinkt je nach passender Technik um 15 % pro Stufe (mindestens 40 %).
- **Stoßzeit** (×2 Bürger), **Prüfungsbesuch** (doppelte Ansehenseffekte), **Steuer-Stichtag** (×3 im Finanzamt).
- **Druckerstreik** (ab 20 Fällen): alle arbeiten mit 55 % Tempo. Gegenmittel: IT-Wartung.
- **Systemabsturz** (ab 60): eine zufällige Abteilung arbeitet mit 40 % Tempo. Gegenmittel: IT-Wartung.
- **Montag nach dem Feiertag** (ab 40): ×2,5 Bürger, nur 60 % Geduld. Gegenmittel: Bequemer Warteraum.
- **Kaffeepause eskaliert** (ab 30): dreifache Müdigkeit, wache Beamte arbeiten mit 115 % Tempo. Gegenmittel: Kaffeemaschine.
- **Der Aktenberg** (ab 80): 6 Altfälle landen im Eingang einer Sachbearbeitung. Gegenmittel: Digitale Akte.
- **Die Dienstbesprechung** (ab 50): alle arbeiten mit 45 % Tempo; Abbrechen beendet sie, kostet aber 1,5 Ansehen.
- **LKW voller Gummienten** (nur Zollamt): Zoll arbeitet mit 30 % Tempo. Gegenmittel: Dokumentenscanner.
- **Feueralarm – Fehlalarm** (ab 100): 20 s Stillstand. Gegenmittel: IT-Wartung.
- **Renovierung ohne Ausweichplan** (ab 120): eine Abteilung bekommt halb so viele Bürger und arbeitet mit 60 % Tempo.
- **Der Geräteschuppen** (nur mit Bauamt): ein riesiger Fall (×5 Gebühr, ×3 Bearbeitungszeit, komplex, braucht Fachkraft).
- **Der Prüfer wird geprüft** (ab 200, nur mit Prüfdienst-Abteilung): Prüfdienst arbeitet mit 35 % Tempo.
- **Der Behördenvergleich** (ab 150): Wahl „Präsentation vorbereiten“ (30 s lang alle mit 50 % Tempo, danach +3 Ansehen) oder „Ignorieren“; ohne Antwort verfällt er folgenlos.

## Akten-Markierungen
Kleine Marker über Akten: Lupe = muss noch zum Prüfdienst, Haus = braucht noch eine Meldung bei der Meldestelle, Kreuz = ungültiger Antrag, Punkt = Sonderfall (Geräteschuppen). Die Legende steht im Abteilungs-Menü.

## Ablehnungen
Ab 10 Fällen sind etwa 10 % der Anträge ungültig (deterministisch aus Seed und Fallnummer, keine Folgefälle, kein Zoll). Die Sachbearbeitung der eigenen Abteilung lehnt sie ab: Bürger geht (Spruch, Gebühr 15 %), die Akte landet im eigenen Ablehnungs-Ausgang neben dem Ausgangsfach (Kapazität 6, bei Voll ist die Sachbearbeitung blockiert). Der Spieler trägt sie zum Aktenschredder (+2 je Akte), der Schredder-Praktikant schreddert sie ebenfalls.

## Stau-Anzeige
Im Abteilungs-Menü zeigt eine rote Zeile „Stau: <Station> (Eingang/Ausgang/Ablehnungen voll)“, welche Fächer an der Route voll sind und die Abteilung bremsen.

## Fachkräfte (Optik)
Fachkräfte tragen einen hellen Kittel mit goldener Raute und Brille und sitzen auf einem goldenen Teppich mit Namensschild; normale Beamte bleiben dunkelblau.

## Einwohner und Nachfrage
Einwohner = 1000 + 12 je Fall − 20 je verlorenem Bürger (mindestens 1000); Ränge Dorf, Kleinstadt, Mittelstadt, Großstadt, Metropolregion (im Gebäude-Menü). Die Nachfrage wächst logarithmisch mit den bedienten Fällen (bei 2000 Fällen ca. ×1,5, bei 20000 ca. ×2), damit der Durchsatz nicht dauerhaft an zu wenigen Bürgern hängt.

## Rohrpost (Optik)
Mit Rohrpost zeigt die Welt Röhren zwischen den Fächern (Steigschacht am linken Rand, Verlauf in den Fluren). Kapseln in der Farbe der Abteilung sind nur in Fenstern der Röhre sichtbar.

## Wohnungsamt und Meldestelle
Wer einzieht, muss sich ummelden: Nach der Wohnungsprüfung geht die Akte zur Meldestelle des Bürgerservice (Haus-Marker an der Akte), erst danach in die Freigabe. Erklärt in der Abteilungsbeschreibung.

## Bürger an der Tür
Bürger betreten das Amt durch die linke Türhälfte und verlassen es durch die rechte.

## Technik (dauerhaft, global)
Größere Aktentasche (+2 Tragkapazität), Arbeitseifer (+50 % eigene Arbeit), Kaffeequalität (Beamte bleiben länger wach), Weckdienst (Beamte wachen selbst auf), Dokumentenscanner (Empfang/Rampe +30 %), Bequemer Warteraum (+40 % Geduld), Aktenwagen (+1 Botenkapazität), Digitale Akte (Sachbearbeitung/Freigabe +20 %), Qualitätsschulung (−25 % Fehler), Digitale Signatur (Ausgabe/Zollfreigabe +40 %), Rohrpost (Akten wandern automatisch zur nächsten Station, sichtbar in Röhren mit Fenstern), IT-Wartung (Ereignisse dauern pro Stufe 15 % kürzer), Online-Portal (+25 % Bürger), KI-Fallklassifizierung (halbe Fehler und halbe Mehrarbeit komplexer Fälle).

## Wirtschaft und Fortschritt
- Ziel-Belohnungen zählen nicht in „Einnahmen/Min.“ und nicht in die Gesamteinnahmen.
- Gebühr je Fall × Ansehensfaktor (1 + √Ansehen/20); komplexe Fälle ×2, dringende pünktlich ×1,5 (+0,3 Ansehen), verspätet −0,3; fehlerhafte ×0,4 (−0,5 Ansehen), korrekte +0,1.
- Ansehen erhöht den Bürgerandrang (1 + √Ansehen/8, höchstens ×8).
- **Gebäudestufen**: Service-Schalter → Bürgeramt → Kreisverwaltung → Dienstleistungszentrum → Stadtverwaltung (mehr Abteilungsräume, Tische, Lobbyplätze).
- **Ziele**: 21 aufeinander aufbauende Ziele mit Belohnung, letztes Ziel 20 000 Fälle.
- **Ereignisse**: siehe Abschnitt „Ereignisse“.
- **Offline-Ertrag**: 50 % des automatisierten Durchsatzes, max. 4 h, ab 60 s Abwesenheit.
- Engpass-Anzeige je Abteilung (Nachfrage, Transport oder Station) mit Hervorhebung in der Welt.

## Oberfläche
- Kopfzeile mit Geld, Ansehen, Einnahmen/Min. und Einstellungen; Zielkarte mit Abholen-Button; Ereignis-Banner.
- **Aufgaben-Panel** (einklappbar): je Abteilung wartende Bürger und Auslastung in %; Tippen fokussiert die Kamera auf den Raum und hebt ihn hervor, Pfeil öffnet die Verwaltung.
- Untere Navigation: Abteilungen, Team, Technik, Gebäude, Ziele.
- Gebäudebereiche: Publikumsbereich (Empfang, Warteschlange, Wartebereich, Ausgabe, Eingang), Bearbeitungsräume je Abteilung, Prüfdienst-Raum.
- Einstellungen: Sprache (System/Deutsch/Englisch), Spiel zurücksetzen mit Bestätigung.
- Offline-Dialog nach Rückkehr, Autospeichern alle 20 s und beim Pausieren.

## Tutorial
- Geführte Tour beim ersten Start (neues Spiel) durch alle Funktionen: Laufen, Kopfzeile, Leit-Pfeil, ersten Bürger bedienen, Warteschlange, Ziele, Aufgaben-Panel, Personal, Boten, Ausbau, Abteilungsverwaltung (Arbeitsmodi, Fachkräfte, Teamleitung), Technik, Gebäude, Abteilungen, Ereignisse, Offline-Ertrag, Ziele-Übersicht, Einstellungen, Abschluss mit Strategie-Tipps (26 Schritte, inklusive „Beamte aufwecken“).
- Tutorial-Karte unten über der Navigation, bei geöffnetem Fenster oben; zeigt Schrittzähler, Titel, Text und Fortschrittsbalken.
- Infoschritte werden mit „Weiter“ bestätigt; Aktionsschritte (Laufen, Bürger abschließen, Ziel abholen, einstellen, Boten, ausbauen, Fenster öffnen) schließen sich automatisch ab, sobald die Aktion erfolgt ist. Zählende Schritte messen ab Schrittbeginn.
- Das passende Bedienelement (Navigation, Zielkarte, Zahnrad) blinkt im jeweiligen Schritt.
- „Tutorial beenden“ mit Rückfrage jederzeit möglich; in den Einstellungen lässt sich die Tour wiederholen (Spielstand bleibt erhalten).
- Fortschritt wird im Spielstand gespeichert; ältere Spielstände ohne Tutorial-Fortschritt gelten als abgeschlossen.

## Humor und Optik
- **Beamtenhumor**: Alle Texte (Abteilungen, Technik, Ereignisse, Tutorial, Hinweise) nehmen deutsche Behörden liebevoll auf die Schippe: Dienstweg, Stempel, Mittagspause, „nicht zuständig“, Wiedervorlage. Arbeitsweisen heißen „Husch-husch“, „Nach Vorschrift“ und „Dreifach geprüft“.
- **Sprechblasen** in der Warteschlange mit wechselnden Bürgersprüchen („Ich habe Zeit. Viel Zeit.“, „Nur eine kurze Frage …“), 12 Sprüche.
- **Schwebende Kommentare** beim Abschluss: „Gestempelt!“, „Genehmigt!“, „Aktenzeichen vergeben“ bzw. bei Fehlern „Formfehler!“, „Bitte nachreichen“ (begrenzt, damit nichts überlädt).
- **Amtsweisheit des Tages** (12 Sprüche, wechselt täglich) oben im Ziele-Fenster.
- **Publikumsbereich** mit Amtsschild „Amt für Amtliches“, Wanduhr, Aktenschrank, Sprechzeiten-Tafel (Di 9:00–9:07 Uhr), Deutschlandflagge im Wind, Nummernautomat, Wartebänke, Pflanzen und einem Schalter „Nicht zuständig“.
- **Figuren** mit Anzug, Krawatte, Brille, Schnurrbart, wechselnden Haar- und Hautfarben, Schatten und Dienstmütze der Spielfigur.
- **Möbel und Maschinen**: Schreibtische mit Monitor, Papierstapel und Schubladen; je Abteilung eigene Maschine (Foto-Kabine, Taschenrechner, Stempel mit Stempelkissen, Schilderdrucker mit Kennzeichen, Gutscheindrucker, Frachtscanner mit Scanlinie).
- **Räume**: farbige Kopfleiste mit kontrastsicherer Schrift, gefliester Boden, Schatten, Stations-Plaketten; Fahrzeuge (Pkw, Lkw) mit Fenstern, Rädern und Schatten.
- **Lesbarkeit**: Schriftgrößen im gesamten UI angehoben (Fließtext 17, Nebentext 16, Beschriftungen 15), dunklerer Nebentext, Beschriftungen in der Spielwelt mit hellem Umriss.

## Lokalisierung
Deutsch und Englisch (Fallback) über `i18n/translations.csv`; keine UI-Strings im Code.

## Projektspezifische Ausnahmen von globalen Regeln
- **Godot 4.7.2 statt Jetpack Compose**: Die WaffleHQ-Styling-Regeln werden sinngemäß über `AppTheme` (Rollen, Radien, Abstände, Geist-Schrift, Material Icons) umgesetzt; Details in `styling-exceptions.md`.
- **Übersetzungen als CSV** (`i18n/translations.csv`, Godot-Standard) statt `strings.xml`.
- **Kein Gradle**: Export mit vorgefertigten Godot-Android-Templates (`gradle_build` aus).
- **Testabdeckung**: Für GDScript gibt es kein Coverage-Werkzeug; Abdeckung wird über vollständige Unit-Tests aller Kernklassen (GUT 9.7.1) sichergestellt.
- **Keine Monetarisierung**: Werbung/Rewarded Ads aus dem Konzept bewusst nicht umgesetzt.
- **Keine Datenbank**: Spielstand als JSON in `user://savegame.json` (Version 2, ältere Stände starten neu).
