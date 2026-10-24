# Idle Germany – Features

Bewegungsbasiertes Verwaltungs-Tycoon für Android (vorerst ausschließlich Android; eine PC-Version ist eventuell später geplant) im Stil von „My Mini Mart“: Die Spielfigur ist anfangs die einzige Angestellte des Amts, läuft durchs Gebäude, trägt Akten zwischen Stationen und arbeitet selbst an unbesetzten Tischen. Jede Einstellung nimmt ihr eine konkrete Aufgabe ab. Konzeptquellen liegen in `docs/concept/`.

## Steuerung
- **Laufen**: Irgendwo auf die Karte drücken und ziehen (virtueller Joystick erscheint am Druckpunkt). Mit angeschlossener Hardware-Tastatur gehen auch WASD/Pfeiltasten.
- **Automatische Interaktion in der Nähe** (Radius 64): Akten aus Ablagen aufnehmen, passende Akten in Eingangsfächer legen, an markierten Arbeitsplätzen unbesetzter Tische arbeiten. Ist ein besetzter Platz gerade verwaist (krank, Küche, Toilette), kann der Spieler sich direkt an diesen Schreibtisch stellen und dessen Akte selbst weiterbearbeiten bzw. die nächste aus dem Eingang beginnen (blauer Personen-Ring am leeren Stuhl).
- **Kurzes Tippen** auf einen Abteilungsraum öffnet dessen Verwaltung; auf einen gesperrten Raum die Abteilungsübersicht.
- **Leit-Pfeil** zeigt stets auf die nächstgelegene sinnvolle Aufgabe (abliefern › arbeiten/aufnehmen › Abteilung eröffnen); außerhalb des Bildes als Randpfeil.
- Zurück-Taste schließt offene Panels, sonst wird gespeichert und beendet.

## Arbeitsablauf (gemeinsam für alle Abteilungen)
Empfang → Sachbearbeitung der Abteilung → (optional: Verweis/Prüfdienst) → Signatur-Station der Abteilung → Ausgabeschalter. Jede Station hat Eingangsfach, Tische/Maschinen und Ablage mit sichtbarer Kapazität; volle Fächer werden rot markiert.
- **Empfang** (geteilt): Bürger stehen in einer sichtbaren Warteschlange mit Sprechblase (Abteilungs-Icon) und Geduldsring. Ist die Geduld erschöpft, gehen sie (Ansehen −0,3). Ist die Lobby (Wartebereich) voll – auch bei vollem Sitzbereich erst dann –, hauen Neuankömmlinge wütend ab (−0,3 Ansehen) und beschweren sich an der Beschwerdestelle (siehe Wartebereich). Der Empfang nimmt keine Bürger einer Abteilung an, deren Eingangsfach bereits ausgelastet ist (inklusive schon wartender Akten im Ausgang); so blockiert eine überlastete Abteilung nicht mehr alle anderen.
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
- **Beamte einzeln schulen** (Bereich „Beamte: <Station>“, erreichbar über „Beamte schulen“ auf jeder Stationskarte ohne Maschine und auf der Statistikseite): Jeder besetzte Platz und jede Fachkraft hat vier Schulungen mit je 3 Stufen – *Tempo* (+15 % Arbeitstempo je Stufe, fließt auch in Kapazität und Engpass-Berechnung ein), *Gesundheit* (je Stufe 20 % Chance, eine Krankmeldung abzuwenden), *Ausdauer* (wird je Stufe 20 % langsamer müde, multiplikativ) und *Gelassenheit* (je Stufe 20 %, gemittelt über die Abteilung: so oft wird ein ausbrechender Streit in der Abteilung vorab vermieden). Kosten: Einstellungskosten der Station × Faktor (Tempo 1,5, Gesundheit 1,2, Ausdauer/Gelassenheit 1,0) × 2,5 je Stufe. Die Schulung bleibt am Platz (auch nach Pausen, Krankheit und beim Ausbau), wird gespeichert und je Beamten mit Zustand, Akten/Min., erledigten Akten, Krankmeldungen und Pausen angezeigt.
- **Boten** (bis 12): laufen als Figuren durchs Gebäude, reservieren Akten, tragen sie von Ablagen zum nächsten Eingangsfach und warten, wenn das Ziel voll ist.
- **Kaffee-Praktikanten** (bis 4, Team-Panel): brühen in der Küche eine Tasse und bringen sie direkt an den Platz des müdesten wachen Beamten mit Arbeit (Wachsamkeit unter 60 % der Basis). Der Beamte ist danach länger wach (125 % der Basis-Wachzeit) und muss nicht selbst in die Küche. Sie sind als Figuren mit Tasse und Dampf sichtbar, wählen nie dasselbe Ziel und lassen schlafende, kranke oder abwesende Beamte aus.
- Team-Panel: Boten, Ablehnungs-Boten, Kaffee-Praktikanten, Wachleute, Empfang, Ausgabeschalter und Prüfdienst.

## Beschwerdestelle und Aktenschredder
In der Eingangshalle gibt es eine Beschwerdestelle und einen Aktenschredder. Ab 5 erledigten Fällen laufen regelmäßig Beschwerden ein (alle 25–45 s; jede Wache und jeder zusätzliche Beschwerde-Praktikant verlängert den Abstand um 30 %) (max. 8 im Kasten; ist er voll, werden weitere einfach verworfen – ohne Ansehensverlust). Liegende Beschwerden haben keinerlei negative Folgen. Der Spieler kann den Beschwerdetisch antippen und die Beschwerden lesen (Bereich „Beschwerdestelle“: bis zu 8 der neuesten Briefe, 50 verschiedene lustige Texte, auch als Sprechblase beim Eingang) oder sie abholen (Platz wie Aktentasche) und zum Schredder bringen; pro Beschwerde gibt es ein kleines Taschengeld (4) und etwas Reputation. Die Technik „Schredder-Praktikant“ (3 Stufen) schreddert alle 40/20/8 Sekunden: Der Praktikant läuft sichtbar mit den Akten zum Schredder und zurück; beim Weinen hört er nach 20 Sekunden von allein auf. „Praktikanten-Schulung“ (3 Stufen): +1 Stück pro Gang, +1 tolerierte Beschwerde, 30 % kürzeres Weinen je Stufe. Im Team-Menü gibt es bis zu 2 weitere Beschwerde-Praktikanten (600 · ×2,5), die den Stress aufteilen und selbst zum Schredder laufen. „Größerer Beschwerdetisch“ (3 Stufen) fasst +4 Beschwerden je Stufe (Basis 8). „Beschwerde-Rohrpost“ (3 Stufen, benötigt Schredder-Praktikant) schickt langsam alle 60/35/20 Sekunden eine Beschwerde vom Tisch zum Schredder (sichtbare Röhre mit Kapsel). Jeder Bürger, der wegen Wartezeit geht, reicht ab 5 erledigten Fällen eine Beschwerde ein (als Besucher am Tisch, sonst direkt im Kasten).

**Online-Bewertungen:** Eigene Bewertungsseite (Bereich „Online-Bewertungen“) mit Durchschnitt in Sternen, Verteilung von 5 bis 1 Stern, Filter nach Sternen, Liste (neueste zuerst, seitenweise) und Detailansicht mit Blättern zur vorigen/nächsten Bewertung. Aufruf über die Bewertungs-Plakette im Kopfbereich (Durchschnitt) oder das Banner. Jede Bewertung hat Sterne, Verfasser und Text (Textpool: 40 Texte für 1 Stern, 35 für 2, 30 für 3, 25 für 4 und 30 für 5 Sterne – also 105 schlechte/mittlere und 55 gute, alle verschieden). Bewertungen entstehen so: Jede Beschwerde stellt mit 18 % Wahrscheinlichkeit eine schlechte Bewertung (1 Stern, zu 30 % 2 Sterne) ein (max. 5 schlechte gleichzeitig); abgeschlossene Fälle bringen mit 18 % Lob (60 % 5, 30 % 4, 10 % 3 Sterne), fehlerhafte Fälle mit 30 % eine 3-Sterne-Bewertung (max. 80 gespeichert, älteste Nicht-Schlechte fallen zuerst weg). Solange schlechte Bewertungen stehen, sinkt das Ansehen langsam (1 Stern voll, 2 Sterne halb; Lob kostet nichts). In der Detailansicht jeder Bewertung: „Löschen lassen“ – je weniger Sterne, desto teurer (Grundpreis = 45-Faches des Einkommens pro Sekunde, mindestens 30; 1 Stern ×8, 2 Sterne ×3, 3 Sterne ×1, 4 Sterne ×0,3, 5 Sterne und berichtigte kostenlos; schlechte Bewertungen geben beim Löschen +0,15 Ansehen zurück). „Wegen Verleumdung anzeigen“ ist für jede nicht berichtigte Bewertung möglich und kostet unabhängig von den Sternen anfangs gleich viel (4-facher Grundpreis); Erfolgschance 40 %. Erfolg: Der Verfasser muss die Bewertung durch eine 5-Sterne-Bewertung mit passiv-aggressivem Text ersetzen („Berichtigt“, kostet kein Ansehen mehr), 2,5-facher Schadenersatz, +0,5 Ansehen und 7 Minuten lang nur noch ein Zehntel der schlechten Bewertungen als Abschreckung. Misserfolg: −0,2 Ansehen, die Bewertung verliert einen Stern (bis minimal 1 Stern, neuer passender Text), und jede weitere Klage gegen dieselbe Bewertung kostet ×1,6 mehr und hat +8 Prozentpunkte Erfolgschance (höchstens 85 %, höchstens 20 Klagen). Chance und bisherige Klagen stehen in der Detailansicht und werden gespeichert. Die Bewertungsseite ist jederzeit erreichbar: über die immer sichtbare Bewertungs-Plakette im Kopfbereich („–“ ohne Bewertungen), das Banner und die Statistikseite. Alte Spielstände mit Zähler werden in 1-Stern-Bewertungen umgewandelt. Die Führung zeigt den Weg zum Kasten bzw. Schredder.

## Besucher an der Beschwerdestelle und der Beschwerde-Praktikant
- Beschwerden kommen nicht mehr aus dem Nichts: Jeder Beschwerdeführer läuft sichtbar durch die Tür zur Beschwerdestelle (max. 3 gleichzeitig an festen Plätzen) und trägt die Beschwerde erst beim Eintreffen vor; erst dann landet sie im Kasten. Während des Vortrags erscheint ein dreizeiliger, witziger Dialog in Sprechblasen (30 Dialoge für normale Besucher, 10 für wütende; Besucher – Antwort – Besucher). Danach gehen sie zur Tür zurück. Sind alle Plätze belegt, wird die Beschwerde direkt eingereicht.
- Der **Schredder-Praktikant** (Technik) ist als Figur am Beschwerdetresen sichtbar. Er hat einen Stressbalken über dem Kopf: Mehr als 3 Beschwerden im Kasten stressen ihn laufend (je Beschwerde 0,4 %/s, darunter erholt er sich mit 1,2 %/s) und er murmelt nervöse Sprüche.
- Ab 8 Beschwerden im Kasten kommen alle ~14 Sekunden **wütende Besucher** (rote Figur mit Ausrufezeichen, wackelt), die den Praktikanten anschreien (+6 % Stress/s während ihres Auftritts).
- Erreicht der Stress 100 %, bricht der Praktikant zusammen („Ich kann nicht mehr!“), rennt zur Toilette (Sanitärraum) und weint dort 40 Sekunden mit Tränen und Sprechblasen. Währenddessen schreddert er nichts und am Tresen hängt der Zettel „Gleich zurück – weine kurz“. Der Spieler kann ihn trösten: 2 Sekunden danebenstehen holt ihn sofort zurück (Stress danach 35 %, sonst 25 %). Die Führung zeigt den Weg zu ihm.
- **Wachleute** (bis 2, Team-Panel unter „Publikumsbereich“, Kosten 500 · ×2,4): stehen sichtbar (dunkle Uniform, Mütze, Abzeichen) vor der Beschwerdestelle. Jeder neue Beschwerdeführer – auch wütende Besucher – wird mit 35 % Wahrscheinlichkeit (mit 2 Wachen 58 %) von einer freien Wache abgefangen: Er läuft zur Wache, es folgt ein zweizeiliger Dialog (5 Varianten, Wache – Besucher), nach 4 Sekunden geht er ohne Beschwerde wieder. Abgefangene belegen keinen Platz am Tresen und schreien den Praktikanten nicht an. Jede Wache hält nur eine Person gleichzeitig auf. Die Karte zeigt die Abfangquote und die Zahl der nach Hause Geschickten (gespeichert).

## Sitzbereich
- Bürger, deren Antrag bearbeitet wird (in Abteilungen oder unterwegs), belegen Sitzplätze in der Halle. Basis 24 Plätze, **Sitzbereich-Ausbau** im Gebäude-Panel (12 Stufen, +3 Plätze je Stufe, bis 60 Plätze, Preis 500 · 1,6^Stufe). Jeder Stuhl ist einzeln sichtbar und erscheint beim Ausbau nacheinander mit Aufpopp-Animation; nicht ausgebaute Stühle gibt es nicht. Das Stuhlraster (7 Spalten) liegt vollständig zwischen Empfang und Schalter und überlappt keinen Raum. Sind alle Plätze belegt, wartet der Empfang mit der Annahme und Neuankömmlinge bleiben im Wartebereich; erst wenn auch dieser voll ist, hauen sie ab. Ein zweites Schild „Sitzbereich belegt/Plätze“ zeigt den Stand (rot, wenn voll).

## Wartebereich
- Das Limit der Warteschlange ist die Zahl der Sitzplätze: Gebäudestufe (16/22/28/34/40) plus **Wartebereich-Ausbau** (Gebäude-Panel, 8 Stufen, +3 Plätze je Stufe, bis 64 Plätze, Preis 400 · 1,9^Stufe). Jeder Warteplatz ist als Bodenmarke sichtbar und erscheint beim Ausbau mit Aufpopp-Animation. Ein Schild in der Halle zeigt „Wartebereich belegt/Plätze“ (rot, wenn voll).
- Findet ein Neuankömmling keinen Platz mehr, haut er wütend ab: Ansehen −0,6 („Minus-Sterne“), er zählt als verlorener Bürger, kommt als wütender Besucher zur Beschwerdestelle und reicht dort eine Beschwerde ein. Die Zahl der Abgehauenen steht im Ausbau-Panel.

## Bürostreits
- Ab 15 erledigten Fällen brechen alle 90–200 Sekunden Streits in Abteilungen mit mindestens 2 Beschäftigten aus (max. 2 gleichzeitig, höchstens einer je Abteilung): Fensterkrieg, Thermostat-Krieg, Radio-Streit, Joghurt-Klau, Tacker-Streit und Fischbrötchen-Gestank. Zwei streitende Beamte stehen sichtbar im Raum (Sprechblasen im Wechsel mit je 4 witzigen Sätzen), das Etikett zeigt den Tempoverlust (−10 % bis −20 % für die Sachbearbeitungs-Stationen der Abteilung; Maschinen und gemeinsame Stationen sind nicht betroffen).
- **Schlichten:** Der Spieler stellt sich 2,5 Sekunden an den Streitort (Ansehen +0,2). Ohne Eingreifen versandet der Streit nach 4 Minuten. Die Führung zeigt den Weg.
- **Verbesserungen (Technik):** *Klimaanlage* (2 Stufen: Stufe 1 verriegelt die Fenster, Stufe 2 sperrt das Thermostat – diese Streits entfallen) und *Schlichtungsstelle* (3 Stufen: Streits enden nach 120/60/25 Sekunden von selbst und brechen 25 % seltener aus je Stufe). Jede Teamleitung (alle Abteilungen zusammen) lässt Streits zusätzlich um 30 % seltener ausbrechen.

## Krankmeldung, Telefonzentrale und Toiletten
Beamte melden sich regelmäßig krank (ab 2 Beschäftigten, erste Meldung nach 90 s, danach alle 45–100 s; jeder Telefonist verlängert den Abstand um 50 %). Ihr Schreibtisch bleibt leer und in der **Telefonzentrale** klingelt es: Die Krankmeldung läuft als eingehender Anruf ein (Lampe an der Telefonanlage blinkt, „x klingelt – rangehen!“).
- **Eingehende Krankmeldungen**: Wer rangeht – der Spieler an seinem Apparat (1,5 s) oder ein freier Telefonist (4 s) –, nimmt die Krankmeldung auf („Krankmeldung notiert“). Mit 30 % Chance wird der Anrufer überredet und kommt sofort doch („Überredet – kommt doch!“). Wird ein Anruf 30 s lang nicht angenommen, ist er verpasst („Verpasst – unentschuldigt!“): Der Kranke gilt als unentschuldigt, kann nicht zurückgerufen werden und kommt erst nach 4 Minuten von selbst wieder.
- **Hinterhertelefonieren**: Gemeldete Kranke (Krankmeldung angenommen) werden angerufen, bis sie wieder zur Arbeit kommen – vom Spieler am Apparat (1,5 s) oder von Telefonisten (12 s). Wer am längsten krank ist, wird zuerst angerufen; niemand wird doppelt angerufen. Eingehende Anrufe haben immer Vorrang vor Rückrufen.
- **Telefonisten** (Team, max. 4, mit steigendem Preis) sitzen sichtbar an eigenen Plätzen in der Telefonzentrale; jeder führt ein Gespräch gleichzeitig. Geht der Spieler während eines Gesprächs weg, klingelt eine Krankmeldung weiter (Klingelzeit läuft weiter), ein Rückruf wird abgebrochen.
- Laufende Gespräche zeigen einen Fortschrittsring (orange = Krankmeldung, grün = Rückruf) und witzige Sprechblasen-Dialoge (Ausrede des Anrufers, dann Antwort; 12 Ausreden, 12 Rückruf- und 8 Annahme-Antworten).
- Die **Krankenliste** an der Wand zeigt Kranke, Gemeldete, Unentschuldigte sowie angenommene und zurückgeholte Anrufe. Das Team-Panel zeigt Kranke, Gemeldete und klingelnde Anrufe. Tippen auf die Telefonzentrale öffnet das Team-Panel.
- Die Führung zeigt zum Apparat, sobald es klingelt oder gemeldete Kranke angerufen werden können.
- **Rückkehr-Timer und Bonuszahlung**: Unter jedem kranken Schreibtisch steht „Zurück in m:ss“ – so lange dauert es ohne Eingreifen. Steht der Spieler am Platz des Kranken, erscheint oben eine Karte „Krank · zurück in m:ss“ mit drei Bonus-Stufen (klein/mittel/groß = 0,5/1,5/4 Minuten des aktuellen Einkommens pro Minute, mindestens 30 pro Minute gerechnet). Der Bonus wird auf den Schreibtisch gelegt (Geldsymbol, „Bonus hinterlegt – gute Besserung!“) und beschleunigt die Genesung 2×/4×/10×. Pro Krankheit kann nur auf eine höhere Stufe aufgestockt werden; mit der Rückkehr verfällt der Bonus. Das Einkommen pro Minute wird im Spielkern über die letzten 30 Sekunden gemessen (auch für die Kopfzeile).
- Gespeichert werden der Meldestatus und die Bonusstufe jedes Kranken, die Anzahl gezahlter Boni sowie die Zähler angenommener/verpasster Anrufe; laufende Anrufe nicht. Kranke aus älteren Spielständen gelten als gemeldet.

Außerdem gehen Beamte auf die Toilette (4 Kabinen im Sanitärraum). Jeder Beamte kann jederzeit durch Danebenstehen (2 s) von der Toilette verjagt werden; die Führung zeigt auch dorthin. Der Weckdienst verkürzt Toilettengänge ebenfalls.

## Layout Küche und Sanitär
Die Küche ist kleiner (Kühlschrank, Arbeitsplatte, Kaffeemaschine, Tisch). Rechts daneben liegt ein eigener Sanitärraum mit den vier Toiletten. Darunter, zwischen Küche und Publikumshalle, liegt die Telefonzentrale über die ganze Breite (Telefonanlage, Apparat des Spielers, 4 Telefonistenplätze, Krankenliste). Wird ein Beamter aus Küche oder Toilette geholt, läuft er sichtbar zu seinem Platz zurück (der Platz bleibt bis zur Ankunft leer).

## Harmlose Beschwerden
Beschwerden im Kasten kosten kein Ansehen; Abhauen wegen voller Halle und Wartezeit bleibt ein milder Ansehensverlust.

## Küchenleben
Beamte gehen häufiger in die Küche: verquatschen (bleiben bis zum Abholen), Kaffee holen (kommen frischer zurück) oder laufen gemächlich (70 s; durch Danebenstehen neunmal schneller antreiben). Gelegentlich (erstes nach 90 s, danach alle 110–200 s, jeder Kaffee-Praktikant +30 % Abstand) wird ein Kaffeekränzchen ausgerufen: mehrere Beamte gehen gleichzeitig in die Küche, der Spieler beendet es am Küchentisch. Technik: Kaffeemaschine (4 Stufen: schnelleres Holen, frischere Beamte, goldene Streifen), Küche (3 Stufen: weniger Verquatschen, mehr Selbstholer, Pflanzen).

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
Ab 10 Fällen sind etwa 10 % der Anträge ungültig (deterministisch aus Seed und Fallnummer, keine Folgefälle, kein Zoll). Die Sachbearbeitung der eigenen Abteilung lehnt sie ab: Bürger geht (Spruch, Gebühr 15 %), die Akte landet im eigenen Ablehnungs-Ausgang neben dem Ausgangsfach (Kapazität 6, bei Voll ist die Sachbearbeitung blockiert). Der Spieler trägt sie zum Aktenschredder (+2 je Akte), der Schredder-Praktikant schreddert sie ebenfalls. **Ablehnungs-Boten** (bis 3, im Team-Menü einstellbar, Kosten 250 · ×2 je Bote) holen Ablehnungen selbstständig aus den Ablehnungs-Ausgängen (3 pro Gang) und bringen sie zum Schredder (+2 je Akte); mit Boten führt die Leitführung den Spieler nicht mehr zu den Ablehnungs-Ausgängen.

**Akten schreddern:** Der Spieler kann am Schredder auch normale Akten aus der Aktentasche vernichten (um die Hände frei zu haben). Der zugehörige Antragsteller geht wütend nach Hause (Spruch, Wutfigur zur Tür), das Ansehen sinkt um 1 und der Bürger zählt als verloren. Beschwerden und Ablehnungen werden am Schredder zuerst abgegeben.

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
Die Technik-Seite ist in vier Gruppen mit Überschrift und Kurzbeschreibung gegliedert: *Aktenarbeit und Tempo* (Aktentasche, Arbeitseifer, Scanner, Digitale Akte, Qualitätsschulung, Digitale Signatur, KI-Klassifizierung), *Personal und Pausen* (Kaffeequalität, Kaffeemaschine, Küche, Weckdienst, Klimaanlage, Schlichtungsstelle, IT-Wartung), *Bürger und Beschwerden* (Warteraum, Schredder-Praktikant, Beschwerdetisch, Beschwerde-Rohrpost, Praktikanten-Schulung, Online-Portal) und *Transport* (Aktenwagen, Rohrpost, Röhrenkapazität).
Größere Aktentasche (+2 Tragkapazität), Arbeitseifer (+50 % eigene Arbeit), Kaffeequalität (Beamte bleiben länger wach), Weckdienst (Beamte wachen selbst auf), Dokumentenscanner (Empfang/Rampe +30 %), Bequemer Warteraum (+40 % Geduld), Aktenwagen (+1 Botenkapazität), Digitale Akte (Sachbearbeitung/Freigabe +20 %), Qualitätsschulung (−25 % Fehler), Digitale Signatur (Ausgabe/Zollfreigabe +40 %), Rohrpost (Akten wandern automatisch zur nächsten Station, sichtbar in Röhren mit Fenstern; jede Röhre fasst gleichzeitig nur 2 Akten, die Reisezeit folgt der Röhrenlänge, ist das Zielfach voll, wartet die Akte am Ende der Röhre und blockiert den Platz), Röhrenkapazität (3 Stufen, +2 Akten pro Röhre, benötigt Rohrpost), IT-Wartung (Ereignisse dauern pro Stufe 15 % kürzer), Klimaanlage (keine Fenster-/Thermostat-Streits), Schlichtungsstelle (Bürostreits enden früher und seltener), Online-Portal (+25 % Bürger), KI-Fallklassifizierung (halbe Fehler und halbe Mehrarbeit komplexer Fälle).

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
- **Aufgaben-Panel** (einklappbar über Titel oder Pfeil rechts oben im Panel): je Abteilung wartende Bürger und Auslastung in %; Tippen fokussiert die Kamera auf den Raum und hebt ihn hervor, Pfeil öffnet die Verwaltung.
- Untere Navigation: Abteilungen, Team, Technik, Gebäude, Statistik, Ziele.
- **Statistik-Seite** (Engpässe erkennen; gemessen im gleitenden 60-s-Fenster seit App-Start, nicht gespeichert): Gesamtes Amt (Einnahmen, ankommende Bürger, erledigte Fälle, Ablehnungen, verlorene Bürger je Minute, erwartete Kapazität), Link zu den Online-Bewertungen mit Durchschnitt, Anzahl und schlechten Bewertungen; je Abteilung Ankünfte gemessen/erwartet, Erledigt, Kapazität des langsamsten Schritts, Wartende, Deckungsbalken und Engpass-Text; je Arbeitsschritt erledigte Akten/Min. (gemessen), Kapazität, Bedarf, Auslastungsbalken (grün < 85 %, gelb, rot > 100 %), Eingangs-/Ausgangsfach, arbeitende Beamte und Engpass-Markierung; Ausfälle und Streits (gerade krank, Krankmeldungen/Min., durch Gesundheit vermiedene Krankmeldungen, Nickerchen und Pausen/Min., Streits aktuell und je Minute, durch Gelassenheit vermiedene Streits, abgeschlossene Schulungen); je Station alle Beamten mit Schulungsstufen (Symbole), Zustand, Akten/Min., erledigten Akten, Krankmeldungen und Pausen sowie „Beamte schulen“.
- Gebäudebereiche: Publikumsbereich (Empfang, Warteschlange, Wartebereich, Ausgabe, Eingang), Bearbeitungsräume je Abteilung, Prüfdienst-Raum.
- Einstellungen: Sprache (System/Deutsch/Englisch), Spiel zurücksetzen mit Bestätigung.
- Offline-Dialog nach Rückkehr, Autospeichern alle 20 s und beim Pausieren.

## Tutorial
- Geführte Tour beim ersten Start (neues Spiel) durch alle Funktionen: Laufen, Kopfzeile, Leit-Pfeil, ersten Bürger bedienen, Warteschlange, Ziele, Aufgaben-Panel, Personal, Boten, Ausbau, Abteilungsverwaltung (Arbeitsmodi, Fachkräfte, Teamleitung), Technik, Gebäude, Abteilungen, Ereignisse, Offline-Ertrag, Ziele-Übersicht, Einstellungen, Abschluss mit Strategie-Tipps (26 Schritte, inklusive „Beamte aufwecken“).
- Tutorial-Karte unten über der Navigation, bei geöffnetem Fenster oben; zeigt Schrittzähler, Titel, Text und Fortschrittsbalken.
- Infoschritte werden mit „Weiter“ bestätigt; Aktionsschritte (Laufen, Bürger abschließen, Ziel abholen, einstellen, Boten, ausbauen, Fenster öffnen) schließen sich automatisch ab, sobald die Aktion erfolgt ist. Zählende Schritte messen ab Schrittbeginn.
- Hängenbleiben ausgeschlossen: Aktionsschritte, die im aktuellen Spielstand nicht mehr erfüllbar sind (alle Ziele erledigt, maximale Botenzahl, alle Stationen auf Höchststufe, kein Platz für weiteres Personal), werden automatisch übersprungen. Nach 20 s in einem Aktionsschritt erscheint zusätzlich „Schritt überspringen“.
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

## Mehr Trubel am Anfang
Krankmeldungen, Streits, Kaffeekränzchen und Beschwerden treten früh und häufig auf, damit der Spieler anfangs viel selbst erledigen muss. Personal entschärft das gezielt: Telefonisten → seltener krank, Teamleitungen → seltener Streit, Kaffee-Praktikanten → seltener Kaffeekränzchen, Wachleute und weitere Beschwerde-Praktikanten → seltener Beschwerden. Die Team-Beschreibungen nennen den jeweiligen Effekt.

## Projektspezifische Ausnahmen von globalen Regeln
- **Godot 4.7.2 statt Jetpack Compose**: Die WaffleHQ-Styling-Regeln werden sinngemäß über `AppTheme` (Rollen, Radien, Abstände, Geist-Schrift, Material Icons) umgesetzt; Details in `styling-exceptions.md`.
- **Übersetzungen als CSV** (`i18n/translations.csv`, Godot-Standard) statt `strings.xml`.
- **Kein Gradle**: Export mit vorgefertigten Godot-Android-Templates (`gradle_build` aus).
- **Testabdeckung**: Für GDScript gibt es kein Coverage-Werkzeug; Abdeckung wird über vollständige Unit-Tests aller Kernklassen (GUT 9.7.1) sichergestellt.
- **Keine Monetarisierung**: Werbung/Rewarded Ads aus dem Konzept bewusst nicht umgesetzt.
- **Keine Datenbank**: Spielstand als JSON in `user://savegame.json` (Version 2, ältere Stände starten neu).
