# Idle Germany – Features

Bewegungsbasiertes Verwaltungs-Tycoon für Android (vorerst ausschließlich Android; eine PC-Version ist eventuell später geplant) im Stil von „My Mini Mart“: Die Spielfigur ist anfangs die einzige Angestellte des Amts, läuft durchs Gebäude, trägt Akten zwischen Stationen und arbeitet selbst an unbesetzten Tischen. Jede Einstellung nimmt ihr eine konkrete Aufgabe ab. Konzeptquellen liegen in `docs/concept/`.

## Steuerung
- **Laufen**: Irgendwo auf die Karte drücken und ziehen (virtueller Joystick erscheint am Druckpunkt). Mit angeschlossener Hardware-Tastatur gehen auch WASD/Pfeiltasten.
- **Automatische Interaktion in der Nähe** (Radius 64): Akten aus Ablagen aufnehmen, passende Akten in Eingangsfächer legen, an markierten Arbeitsplätzen unbesetzter Tische arbeiten. **Mit anpacken:** Am Arbeitsplatz einer Station mit wachem Personal hilft der Spieler zusätzlich an einem besetzten Tisch mit (eigene Arbeitskraft obendrauf); ab 3 wartenden Akten zeigt der Leit-Pfeil auch dorthin. Ist ein besetzter Platz gerade verwaist (krank, Küche, Toilette), kann der Spieler sich direkt an diesen Schreibtisch stellen und dessen Akte selbst weiterbearbeiten bzw. die nächste aus dem Eingang beginnen (blauer Personen-Ring am leeren Stuhl).
- **Kurzes Tippen** auf die Namensleiste oben an einem Raum öffnet genau die Upgrades dieses Raums; ein Tippen in den Raum selbst öffnet nichts:
  - Abteilungsraum: Abteilungsverwaltung (Arbeitsweise, Stationen, Teamleitung) und darunter „Für alle Büros“ (Boten, Ablehnungs-Boten, Büro-Technik); gesperrter Raum (Name oben links): Abteilungsübersicht.
  - Prüfdienst-Raum: Prüfdienst-Station (nur wenn freigeschaltet).
  - Küche: Kaffee-Praktikanten, Kaffeequalität, Kaffeemaschine, Küche.
  - Sanitär: Weckdienst.
  - Telefonzentrale: Telefonisten.
  - Publikumshalle (hat keine Namensleiste, daher nicht per Tippen erreichbar; Upgrades über Team-, Technik- und Gebäude-Seite): Wachleute, Beschwerde-Praktikanten, Empfang, Ausgabeschalter, Warte- und Sitzbereich, Beschwerde-Sachbearbeitung, Beschwerde-Briefkasten, Warteraum, Schredder-Praktikant, Beschwerde-Rohrpost, Praktikanten-Schulung, Online-Portal. Der Beschwerdetisch selbst öffnet weiterhin die Beschwerden zum Lesen.
  - Jedes Raum-Fenster zeigt Kurzbeschreibung und die Abschnitte Personal, Stationen, Ausbau, Technik (leere Abschnitte entfallen).
- **Leit-Pfeil** zeigt stets auf die nächstgelegene sinnvolle Aufgabe (abliefern › arbeiten/aufnehmen › Abteilung eröffnen); außerhalb des Bildes als Randpfeil.
- Zurück-Taste schließt offene Panels, sonst wird gespeichert und beendet.

## Arbeitsablauf (gemeinsam für alle Abteilungen)
Alle genannten Ansehensverluste sind Nennwerte; tatsächlich wirken sie gedämpft (siehe „Ansehen sinkt kaum“).

Empfang → Sachbearbeitung der Abteilung → (optional: Verweis/Prüfdienst) → Signatur-Station der Abteilung → Ausgabeschalter. Jede Station hat Eingangsfach, Tische/Maschinen und Ablage mit sichtbarer Kapazität; volle Fächer werden rot markiert.
- **Empfang** (geteilt): Bürger stehen in einer sichtbaren Warteschlange mit Sprechblase (Abteilungs-Icon) und Geduldsring. Jeder Bürger hat seine eigene Geduld (siehe „Unmut der Bürger“); ist sie erschöpft, geht er (Ansehen −0,3). Ist die Lobby (Wartebereich) voll – auch bei vollem Sitzbereich erst dann –, hauen Neuankömmlinge wütend ab (−0,3 Ansehen); nur wenige davon beschweren sich später an der Beschwerdestelle (siehe Wartebereich). Der Empfang nimmt keine Bürger einer Abteilung an, deren Eingangsfach bereits ausgelastet ist (inklusive schon wartender Akten im Ausgang); so blockiert eine überlastete Abteilung nicht mehr alle anderen.
- **Sachbearbeitung**: setzt je nach Arbeitsmodus Fehler (Schnell / Normal / Gründlich: Zeit ×0,6/1,0/1,4, Fehler 20/12/2 %).
- **Signatur-Station** je Abteilung mit eigenem Endprodukt: Passfoto → Ausweis, Rechenmaschine → Bescheid, Gewerbestempel → gerahmte Erlaubnis, Schilderdrucker → Kennzeichen (Auto fährt weg), Architektin → gestempelter Bauplan, Gutscheindrucker → Wohnungsgutschein, Zahlstelle → Leistungskarte. Maschinen brauchen kein Personal, Bauamt und Sozialamt sind personell besetzt.
- **Ausgabeschalter** (geteilt): Übergabe, Bezahlung, schwebender Geldbetrag, Bürger verlässt mit Endprodukt das Gebäude.
- Unbesetzte Tische arbeiten nur, solange die Spielfigur am pulsierenden Arbeitsplatz steht.
- **Handarbeit-Bonus:** Jeder Handgriff des Spielers an einer Akte (selbst bearbeiteter Stationsschritt oder selbst getragene Übergabe) erhöht deren Gebühr. Anteil = Handgriffe / (Übergaben + Stationen ohne Maschine) der Route, Gebühr × (1 + 1,5 × Anteil), also bis zum 2,5-Fachen. Personal, Boten und Rohrpost zählen nicht. Der Zähler wird mit der Akte gespeichert; der Offline-Ertrag rechnet ohne Bonus.

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

Eröffnet wird eine Abteilung durch Stehen auf dem Kreis im gesperrten Raum (1,2 s) oder per Button, sofern Platz (Gebäudestufe), Ansehen und Geld reichen. Jede neue Abteilung startet ohne Personal (nur Maschinen laufen von selbst), der Spieler arbeitet dort also zunächst selbst.

## Zollamt
- Lkw liefern Fracht an die **Laderampe**; Frachtarten: Stückgut, Elektronik (höhere Verdachtsquote), Fahrzeuge.
- **Anmeldeprüfung** markiert verdächtige Sendungen (60 % + 12 % je Fachkraft).
- **Schnellspur**: Unmarkierte Sendungen überspringen den Frachtscanner. Schalter „Jede Sendung scannen“ erzwingt den Scanner für alle.
- **Frachtscanner** deckt Schmuggelware auf (50 % bei verdächtiger Fracht); sichergestellte Ware wird vor der Freigabe zum **Prüfdienst** umgeleitet (×3 Gebühr, +0,3 Ansehen).
- Übersehene Schmuggelware an der Freigabe kostet die Gebühr und 1 Ansehen.
- Statusetiketten an der Fracht: gelb markiert, rot festgehalten, grün freigegeben.

## Personal
- **Tische/Maschinen** pro Station (Limit je Gebäudestufe), **Personal einstellen** pro Tisch, **Ausbau** (+12 % Tempo je Stufe, alle 10 Stufen ein Meilenstein ×1,5, max. 50; Kosten ×1,35 je Stufe). Details unter „Engpässe durch Ausbau“.
- **Kosten (Handarbeit zuerst, langsam automatisieren):** Tische und Ausbau skalieren mit dem Kostenfaktor der Abteilung (1/3/9/27/80/220/650/1900) und bleiben günstig, weil zusätzliche unbesetzte Tische die Handarbeit vervielfachen. Personal (Einstellen, Fachkräfte, Teamleitung, Schulungen) skaliert mit dem höheren Personalfaktor der Abteilung (1/4/30/200/1200/6000/35 000/230 000), damit jede neue Abteilung eine Weile von Hand läuft. Einstellen: Grundpreis je Station (Empfang 150, Sachbearbeitung 240, Freigabe 270, Prüfdienst 330, Ausgabe 180, Rampe/Zollfreigabe 300) × Faktor × 2 je vorhandener Kraft; Fachkräfte ×5 davon (×2,4 je Fachkraft); Teamleitung 1500 × Faktor × 3 je Teamleitung. Boten 400 × 2,2 je Bote, Telefonisten 900 × 2,2, Kaffee-Praktikanten 700 × 2, Wachleute 1100 × 2,4, Beschwerde-Praktikanten 1300 × 2,5, Ablehnungs-Boten 600 × 2.
- **Spielfigur:** arbeitet 2,5-mal so schnell wie eine Kraft (Arbeitseifer +50 % je Stufe), läuft 420 px/s, trägt 6 Akten (+2 je Aktentasche) und legt alle 0,08 s eine Akte ab bzw. nimmt eine auf.
- **Fachkräfte** (bis 3 je Sachbearbeitung): eigener Tisch nur für komplexe Fälle, keine Zeitstrafe, 70 % weniger Fehler; normale Tische nehmen dann keine komplexen Fälle mehr an.
- **Teamleitung** (bis 2 je Abteilung): +20 % Tempo für alle Stationen der Abteilung.
- **Beamte einzeln schulen** (Bereich „Beamte: <Station>“, erreichbar über „Beamte schulen“ auf jeder Stationskarte ohne Maschine und auf der Statistikseite): Jeder besetzte Platz und jede Fachkraft hat vier Schulungen mit je 3 Stufen – *Tempo* (+15 % Arbeitstempo je Stufe, fließt auch in Kapazität und Engpass-Berechnung ein), *Gesundheit* (je Stufe 20 % Chance, eine Krankmeldung abzuwenden), *Ausdauer* (wird je Stufe 20 % langsamer müde, multiplikativ) und *Gelassenheit* (je Stufe 20 %, gemittelt über die Abteilung: so oft wird ein ausbrechender Streit in der Abteilung vorab vermieden). Kosten: Einstellungskosten der Station × Faktor (Tempo 1,5, Gesundheit 1,2, Ausdauer/Gelassenheit 1,0) × 2,5 je Stufe. Die Schulung bleibt am Platz (auch nach Pausen, Krankheit und beim Ausbau), wird gespeichert und je Beamten mit Zustand, Akten/Min., erledigten Akten, Krankmeldungen und Pausen angezeigt.
- **Boten** (bis 12 insgesamt): laufen als Figuren durchs Gebäude, reservieren Akten, tragen sie von Ablagen zum nächsten Eingangsfach und warten, wenn das Ziel voll ist. Am Ausgangsfach laden sie bis zur Tragkraft nach: auch Akten, die seit der Reservierung dazugekommen sind, und Akten für weitere Ziele (nächstgelegene zuerst, nur mit freiem Eingangsfach); Reservierungen anderer Boten bleiben liegen. Die Ziele beliefern sie nacheinander, das nächstgelegene zuerst. Jeder Bote hat genau eine **Aufgabe**:
  - *Empfang → Amt*: von Empfang, Poststelle und Laderampe in die Sachbearbeitung.
  - *Innerhalb des Amts*: zwischen den Stationen eines Amts, auch zu Prüfdienst und Meldestelle.
  - *Amt → Ausgabe*: fertige Akten zum Ausgabeschalter.
  - Optional ist ein Bote nur für ein bestimmtes Amt **zuständig** (sonst alle Ämter).
  - Die Botenkarte zeigt je Aufgabe Boten und wartende Akten und hat je Aufgabe einen Einstellen-Knopf (Preis richtet sich nach der Gesamtzahl der Boten). Ohne Angabe wird die Aufgabe mit dem größten Engpass besetzt.
  - Im Fenster **„Botenplan“** (Knopf „Boten einteilen“) lässt sich jeder Bote kostenlos umsetzen (Aufgabe per Segmentschalter, Zuständigkeit per Knopf). Je Aufgabe stehen wartende Akten, Kapazität und Bedarf pro Minute.
  - Die Transportkapazität richtet sich nach der schwächsten Aufgabe; Statistik, Engpass und Leit-Pfeil berücksichtigen nur passende Boten. Ältere Spielstände verteilen vorhandene Boten gleichmäßig auf die drei Aufgaben.
  - **Botenstufen** (je Bote 0–4, Knopf „Größere Tasche“ im Botenplan): jede Stufe +1 Akte pro Gang zusätzlich zum Aktenwagen. Kosten 900 × 3,5 je Stufe des Boten. Stufe wird gespeichert; Kapazität, Reservierung und Leit-Pfeil rechnen mit der Tragkraft jedes einzelnen Boten.
  - Akten von Ämtern mit Rohrpost-Anschluss tragen Boten nicht; eine Reservierung, deren Akten inzwischen per Rohr reisen oder weg sind, wird sofort aufgegeben.
- **Kaffee-Praktikanten** (bis 4, Team-Panel): brühen in der Küche eine Tasse und bringen sie direkt an den Platz des müdesten wachen Beamten mit Arbeit (Wachsamkeit unter 60 % der Basis). Der Beamte ist danach länger wach (125 % der Basis-Wachzeit) und muss nicht selbst in die Küche. Sie sind als Figuren mit Tasse und Dampf sichtbar, wählen nie dasselbe Ziel und lassen schlafende, kranke oder abwesende Beamte aus.
- Team-Panel nach Räumen gegliedert: Büros (Boten, Ablehnungs-Boten), Prüfdienst, Küche (Kaffee-Praktikanten), Telefonzentrale (Telefonisten), Publikumshalle (Wachleute, Beschwerde-Praktikanten, Empfang, Ausgabeschalter).

## Beschwerdestelle und Aktenschredder
In der Eingangshalle gibt es eine Beschwerdestelle und einen Aktenschredder. Ab 10 erledigten Fällen laufen regelmäßig Beschwerden ein (alle 105–195 s; jede Wache und jeder zusätzliche Beschwerde-Praktikant verlängert den Abstand um 30 %). Über dem **Beschwerde-Schreibtisch** hängt das Schild „Beschwerdestelle“. Von Anfang an steht dort immer ein selbstbewusster, schnippisch-herablassender Beamter (Beschwerde-Sachbearbeitung), der jede Beschwerde zuerst abzuwimmeln versucht (Spruch über dem Tisch, 12 Ausreden): Grundchance 15 %, per Ausbau „Schulen“ (5 Stufen, 500 · ×3) 30/42/52/60/67 %. Was nicht abgewimmelt wird, landet im roten **Beschwerde-Briefkasten**, der ein Stück vom Tisch entfernt steht, gleich neben den Beschwerde-Praktikanten (Füllstand und „n/max“ sichtbar, bei vollem Kasten ragen Briefe heraus). Er fasst anfangs 20 Beschwerden, per Ausbau „Vergrößern“ (4 Stufen, 900 · ×3) je +10. Liegende Beschwerden kosten kein Ansehen. Erst wenn der Briefkasten voll ist, schreibt jede weitere Beschwerde eine schlechte Online-Bewertung. Beide Ausbauten stehen auf der Gebäude-Seite und im Raum-Fenster der Publikumshalle; die Statistik empfiehlt die Schulung bei vielen Beschwerden. Der Spieler kann den Beschwerdetisch antippen und die Beschwerden lesen (Bereich „Beschwerdestelle“: bis zu 6 der neuesten Briefe; 50 ausführliche Beschwerdebriefe in beiden Sprachen, beim Einwurf steigt über dem Briefkasten nur ihr kurzer Betreff auf) oder sie abholen (Platz wie Aktentasche) und zum Schredder bringen; pro Beschwerde gibt es ein kleines Taschengeld (4) und etwas Reputation. Die Technik „Schredder-Praktikant“ (3 Stufen) schreddert alle 40/20/8 Sekunden: Der Praktikant läuft sichtbar mit den Akten zum Schredder und zurück; beim Weinen hört er nach 20 Sekunden von allein auf. „Praktikanten-Schulung“ (8 Stufen, 3000 · ×3, ab Ansehen 40, benötigt Schredder-Praktikant) je Stufe: 25 % weniger Stress durch Briefkasten und Geschrei (Stufe 8: ein Zehntel), +1 Stück pro Gang, +1 tolerierte Beschwerde, 30 % kürzeres Weinen. Im Team-Menü gibt es bis zu 2 weitere Beschwerde-Praktikanten (1300 · ×2,5), die den Stress aufteilen und selbst zum Schredder laufen. Alte Spielstände mit der früheren Technik „Größerer Beschwerdetisch“ erhalten dieselbe Zahl an Briefkasten-Stufen. „Beschwerde-Rohrpost“ (3 Stufen, benötigt Schredder-Praktikant) schickt langsam alle 60/35/20 Sekunden eine Beschwerde vom Briefkasten zum Schredder (sichtbare Röhre mit Kapsel). Dazu kommen gelegentlich Beschwerden von Bürgern, die gegangen oder abgehauen sind (siehe „Unmut der Bürger“; als Besucher am Tisch, sonst direkt; auch diese kann die Sachbearbeitung abwimmeln).

**Online-Bewertungen:** Eigene Bewertungsseite (Bereich „Online-Bewertungen“) mit Durchschnitt in Sternen, Verteilung von 5 bis 1 Stern, Filter nach Sternen, Liste (neueste zuerst, seitenweise) und Detailansicht mit Blättern zur vorigen/nächsten Bewertung. Aufruf über die Bewertungs-Plakette im Kopfbereich (Durchschnitt) oder das Banner. Jede Bewertung hat Sterne, Verfasser und Text (Textpool: 40 Texte für 1 Stern, 35 für 2, 30 für 3, 25 für 4 und 30 für 5 Sterne – also 105 schlechte/mittlere und 55 gute, alle verschieden). Bewertungen entstehen so: Jede Beschwerde, die nicht mehr in den vollen Briefkasten passt, wird eine schlechte Bewertung (1 Stern, zu 30 % 2 Sterne; max. 5 schlechte gleichzeitig); abgeschlossene Fälle bringen mit 18 % Lob (60 % 5, 30 % 4, 10 % 3 Sterne), fehlerhafte Fälle mit 30 % eine 3-Sterne-Bewertung (max. 80 gespeichert, älteste Nicht-Schlechte fallen zuerst weg). Jede Bewertung verschwindet nach 2 Stunden Spielzeit von selbst („Verschwindet von selbst in …“ in der Detailansicht, Hinweis in der Spielwelt); wer schneller Ruhe will, lässt sie löschen. Solange schlechte Bewertungen stehen, sinkt das Ansehen langsam (1 Stern voll, 2 Sterne halb; Lob kostet nichts). In der Detailansicht jeder Bewertung: „Löschen lassen“ – je weniger Sterne, desto teurer (Grundpreis = 25-Faches des Einkommens pro Sekunde, mindestens 40; 1 Stern ×3, 2 Sterne ×1,5, 3 Sterne ×0,6, 4 Sterne ×0,2, 5 Sterne und berichtigte kostenlos; jede gescheiterte Klage gegen die Bewertung macht das Löschen ×1,5 teurer; schlechte Bewertungen geben beim Löschen +0,15 Ansehen zurück). „Wegen Verleumdung anzeigen“ ist für jede nicht berichtigte Bewertung möglich und kostet unabhängig von den Sternen anfangs gleich viel (3,6-facher Grundpreis, also immer teurer als Löschen – auch nach gescheiterten Klagen, da Klagen ×1,6 und Löschen nur ×1,5 teurer werden); Erfolgschance 50 %; pro Bewertung höchstens 3 Klagen. Erfolg: Der Verfasser muss die Bewertung durch eine 5-Sterne-Bewertung ersetzen, der man das Erzwungene anmerkt (6 Texte: auf den ersten Blick freundlich, unterschwellig passiv-aggressiv, einer versteckt das Akrostichon HILFE bzw. HELP) („Berichtigt“, kostet kein Ansehen mehr), kein Schadenersatz, der Verfasser trägt nur die Kosten (Klagekosten werden 1,0-fach erstattet), +0,5 Ansehen und 7 Minuten lang nur noch ein Zehntel der schlechten Bewertungen als Abschreckung. Misserfolg: −0,2 Ansehen, die Bewertung verliert einen Stern (bis minimal 1 Stern, neuer passender Text), und jede weitere Klage gegen dieselbe Bewertung kostet ×1,6 mehr und hat +8 Prozentpunkte Erfolgschance (50/58/66 %, höchstens 70 %). Sind alle 3 Klagen gescheitert, lässt sich die Bewertung nur noch löschen (inzwischen deutlich teurer) oder per Werbung („Klage per Werbung gewinnen“) sicher berichtigen – mit Abschreckung und +0,5 Ansehen. Chance und verbleibende Versuche stehen in der Detailansicht und werden gespeichert. Die Bewertungsseite ist jederzeit erreichbar: über die immer sichtbare Bewertungs-Plakette im Kopfbereich („–“ ohne Bewertungen), das Banner und die Statistikseite. Alte Spielstände mit Zähler werden in 1-Stern-Bewertungen umgewandelt. Die Führung zeigt den Weg zum Kasten bzw. Schredder.

## Besucher an der Beschwerdestelle und der Beschwerde-Praktikant
- Beschwerden kommen nicht mehr aus dem Nichts: Jeder Beschwerdeführer läuft sichtbar durch die Tür zur Beschwerdestelle (max. 3 gleichzeitig an festen Plätzen) und trägt die Beschwerde dort vor. Während des Vortrags erscheint ein dreizeiliger, witziger Dialog in Sprechblasen (30 Dialoge für normale Besucher, 10 für wütende; Besucher – Antwort des Beamten – Besucher). Der Beamte antwortet selbstbewusst, zynisch und herablassend, auch wütenden Besuchern.
- Ablauf nach dem Vortrag: Erst jetzt versucht die Beschwerde-Sachbearbeitung abzuwimmeln. Abgewimmelte gehen zur Tür zurück. Alle anderen (auch wütende Besucher) gehen weiter zu den Beschwerde-Praktikanten und beschweren sich dort 5 Sekunden lang noch einmal (10 Sprüche, ein Praktikant antwortet nervös, 6 Sprüche); der Platz an der Beschwerdestelle ist dann schon wieder frei. Danach werfen sie die Beschwerde in den Briefkasten (erst dann wird sie gezählt) und gehen. Wütende Besucher werfen nichts ein. Ohne Schredder-Praktikant gibt es noch keine Praktikanten: Beschwerdeführer gehen dann direkt zum Briefkasten, wütende Besucher gehen nach dem Tisch. Bei aktiver Beschwerde-Amnestie gehen normale Besucher nach dem Tisch nach Hause. Sind alle Plätze belegt, wird die Beschwerde direkt eingereicht (mit Abwimmel-Versuch).
- Der **Schredder-Praktikant** (Technik) ist als Figur zwischen Beschwerdestelle und Briefkasten sichtbar. Er hat einen Stressbalken über dem Kopf: Liegen mehr als 3 Beschwerden je Praktikant im Briefkasten, steigt sein Stress laufend (je Beschwerde über der Grenze 0,02 %/s), sonst erholt er sich mit 0,4 %/s; ab 50 % Stress murmelt er nervöse Sprüche. Ungeschult hält er bei vollem Briefkasten und regelmäßigem Geschrei gut zwei Minuten durch, auf der ersten Schredder-Stufe also mehrere Gänge; die Praktikanten-Schulung senkt jeden Stresszuwachs um 25 % je Stufe.
- Ab 8 Beschwerden im Briefkasten kommen alle ~14 Sekunden **wütende Besucher** (rote Figur mit Ausrufezeichen, wackelt), die nach der Beschwerdestelle den ruhigsten Praktikanten am Platz anschreien (+0,6 % Stress/s während ihres Auftritts bei den Praktikanten; mehr als die Erholung, sodass auch ein einzelner Schreihals sichtbar stresst). Normale Beschwerdeführer stressen beim Beschweren mit +0,5 %/s.
- Erreicht der Stress 100 %, bricht der Praktikant zusammen („Ich kann nicht mehr!“ über genau diesem Praktikanten), rennt zur Toilette (Sanitärraum) und weint dort 20 Sekunden (mit Schulung kürzer) mit Tränen und Sprechblasen. Währenddessen schreddert er nichts und am Tresen hängt der Zettel „Gleich zurück – weine kurz“. Der Spieler kann ihn trösten: 2 Sekunden danebenstehen holt ihn sofort zurück (Stress danach 35 %, sonst 25 %); der Dank erscheint dort, wo getröstet wurde. Die Führung zeigt den Weg zu ihm.
- **Wachleute** (bis 2, Team-Panel unter „Publikumshalle“, Kosten 1100 · ×2,4): stehen sichtbar (dunkle Uniform, Mütze, Abzeichen) vor der Beschwerdestelle. Jeder neue Beschwerdeführer – auch wütende Besucher – wird mit 35 % Wahrscheinlichkeit (mit 2 Wachen 58 %) von einer freien Wache abgefangen: Er läuft zur Wache, es folgt ein zweizeiliger Dialog (5 Varianten, Wache – Besucher), nach 4 Sekunden geht er ohne Beschwerde wieder. Abgefangene belegen keinen Platz am Tresen und schreien den Praktikanten nicht an. Jede Wache hält nur eine Person gleichzeitig auf. Die Karte zeigt die Abfangquote und die Zahl der nach Hause Geschickten (gespeichert).

## Sitzbereich
- Bürger, deren Antrag bearbeitet wird (in Abteilungen oder unterwegs), belegen Sitzplätze in der Halle. Basis 24 Plätze, **Sitzbereich-Ausbau** im Gebäude-Panel (12 Stufen, +3 Plätze je Stufe, bis 60 Plätze, Preis 500 · 1,6^Stufe). Jeder Stuhl ist einzeln sichtbar und erscheint beim Ausbau nacheinander mit Aufpopp-Animation; nicht ausgebaute Stühle gibt es nicht. Das Stuhlraster (7 Spalten) liegt vollständig zwischen Empfang und Schalter und überlappt keinen Raum. Sind alle Plätze belegt, wartet der Empfang mit der Annahme und Neuankömmlinge bleiben im Wartebereich; erst wenn auch dieser voll ist, hauen sie ab. Ein zweites Schild „Sitzbereich belegt/Plätze“ zeigt den Stand (rot, wenn voll).

## Wartemarken (ab Ausbaustufe 3)
- Ab Ausbaustufe 3 („Regionalverwaltung“) muss jeder Bürger, der zum Empfang will, zuerst am **Wartemarkenautomaten** (rechts in der Halle, Schild „Bitte Nummer ziehen“) eine Nummer ziehen und dann im Wartebereich warten, bis seine Nummer an der **Aufrufanzeige** (über dem Empfang) aufgerufen wird. Erst dann stellt er sich am Empfang an und gibt seinen Antrag wie bisher ab. Folgeanträge brauchen ebenfalls eine Nummer; Post und Zoll nicht.
- Nummer ziehen dauert 3 s je Bürger (einer nach dem anderen, höchstens 10 in der Schlange am Automaten), Aufrufen 3,5 s je Nummer. Aufgerufen wird nur, solange am Empfang weniger als 4 Aufgerufene anstehen. Beides ist ein eigener Engpass.
- **Beschleunigen:** Stellt sich der Spieler an den Automaten bzw. an die Anzeige, läuft es 2,5-mal so schnell (Fortschrittsring, grün solange der Spieler hilft). Ausbauten im Gebäude-Panel: *Wartemarkenautomat* und *Aufrufanzeige* (je 10 Stufen, jede Stufe −18 % Zeit; Preis 30 000 · 1,7^Stufe bzw. 35 000 · 1,7^Stufe). Vor Stufe 3 zeigen die Karten „Öffnet mit Ausbaustufe 3.“
- Schlange am Automaten, Wartende mit Nummer und am Empfang Anstehende teilen sich die Plätze des Wartebereichs. Ist die Automatenschlange oder der Wartebereich voll, hauen Neuankömmlinge ab. Auch mit Nummer verlieren Bürger die Geduld und gehen (wie in der Warteschlange; „Rede des Bürgermeisters“ hält sie).
- Die Anzeige zeigt die zuletzt aufgerufene Nummer, beim Aufruf schwebt „Nummer n, bitte.“ auf. Wartende mit Nummer tragen ein Wartemarken-Symbol, Aufgerufene die Sprechblase ihrer Abteilung. Der Leit-Pfeil zeigt zum Automaten bzw. zur Anzeige, sobald dort 4 oder mehr Bürger warten.
- Statistik: eigene Bereiche „Wartemarkenautomat“ und „Aufrufanzeige“ (Kapazität, Bedarf, Auslastung, Ausbau-Wirkung, Schlange/Wartende/bisher aufgerufen) und Teil von „Was ausbauen?“. Das Aufgaben-Panel zählt Bürger mit und ohne Nummer als wartend. Alles wird gespeichert.

## Bürger und Beamte laufen sichtbar
- Jeder Bürger behält vom Betreten bis zum Verlassen dieselbe Farbe und dasselbe Aussehen und läuft sichtbar von Station zu Station: Eingang → Automat → Wartebereich → Empfangsschlange → vor den Empfangsschalter → fester Stuhl im Sitzbereich (solange sein Antrag bearbeitet oder getragen wird) → vor den Ausgabeschalter → Ausgang (mit Ergebnis in der Hand). Wer vorher geht (Geduld, Ablehnung), läuft von seiner aktuellen Position zum Ausgang. Niemand springt oder wechselt die Farbe.
- Beamte laufen sichtbar vom Platz in die Küche bzw. zur Toilette und wieder zurück (Kaffeepause, Tratsch, Kaffeekränzchen, Toilette); der Platz bleibt währenddessen leer, in der Küche erscheinen sie erst bei Ankunft. Bei einem Bürostreit gehen zwei Beamte der Abteilung von ihren Plätzen zum Streitort und nach dem Ende (geschlichtet oder versandet) wieder zurück; ihre Plätze sind solange leer. Aussehen und Farbe bleiben dabei gleich.

## Wartebereich
- Das Limit der Warteschlange ist die Zahl der Sitzplätze: Gebäudestufe (16/22/28/34/40) plus **Wartebereich-Ausbau** (Gebäude-Panel, 8 Stufen, +3 Plätze je Stufe, bis 64 Plätze, Preis 400 · 1,9^Stufe). Jeder Warteplatz ist als Bodenmarke sichtbar und erscheint beim Ausbau mit Aufpopp-Animation. Ein Schild in der Halle zeigt „Wartebereich belegt/Plätze“ (rot, wenn voll).
- Findet ein Neuankömmling keinen Platz mehr, haut er wütend ab: Ansehen −0,3 (gedämpft, „Minus-Sterne“), er zählt als verlorener Bürger. Ab 10 erledigten Fällen kommt etwa jeder Zehnte als wütender Besucher zur Beschwerdestelle und reicht dort eine Beschwerde ein (mit Sammelbeschwerde-Sperre, siehe „Unmut der Bürger“). Die Zahl der Abgehauenen steht im Ausbau-Panel.

## Bürostreits
- Ab 15 erledigten Fällen brechen alle 90–200 Sekunden Streits in Abteilungen mit mindestens 2 Beschäftigten aus (max. 2 gleichzeitig, höchstens einer je Abteilung): Fensterkrieg, Thermostat-Krieg, Radio-Streit, Joghurt-Klau, Tacker-Streit und Fischbrötchen-Gestank. Zwei streitende Beamte stehen sichtbar im Raum (Sprechblasen im Wechsel mit je 4 witzigen Sätzen), das Etikett zeigt den Tempoverlust (−10 % bis −20 % für die Sachbearbeitungs-Stationen der Abteilung; Maschinen und gemeinsame Stationen sind nicht betroffen).
- **Schlichten:** Der Spieler stellt sich 2,5 Sekunden an den Streitort (Ansehen +0,2). Ohne Eingreifen versandet der Streit nach 4 Minuten. Die Führung zeigt den Weg.
- **Verbesserungen (Technik):** *Klimaanlage* (2 Stufen: Stufe 1 verriegelt die Fenster, Stufe 2 sperrt das Thermostat – diese Streits entfallen) und *Schlichtungsstelle* (3 Stufen: Streits enden nach 120/60/25 Sekunden von selbst und brechen 25 % seltener aus je Stufe). Jede Teamleitung (alle Abteilungen zusammen) lässt Streits zusätzlich um 30 % seltener ausbrechen.

## Krankmeldung, Telefonzentrale und Toiletten
Beamte melden sich regelmäßig krank (ab 3 Beschäftigten, erste Meldung nach 180 s, danach je Beamtem alle 20–40 Minuten, also bei mehr Personal häufiger; jeder Telefonist verlängert den Abstand um 50 %; überlastete Stationen trifft es zu 60 % bevorzugt). Ihr Schreibtisch bleibt leer und in der **Telefonzentrale** klingelt es: Die Krankmeldung läuft als eingehender Anruf ein (Lampe an der Telefonanlage blinkt, „x klingelt – rangehen!“).
- **Eingehende Krankmeldungen**: Wer rangeht – der Spieler an seinem Apparat (1,5 s) oder ein freier Telefonist (4 s) –, nimmt die Krankmeldung auf („Krankmeldung notiert“). Mit 30 % Chance wird der Anrufer überredet und kommt sofort doch („Überredet – kommt doch!“). Wird ein Anruf 30 s lang nicht angenommen, ist er verpasst („Verpasst – unentschuldigt!“): Der Kranke gilt als unentschuldigt, kann nicht zurückgerufen werden und kommt erst nach 4 Minuten von selbst wieder.
- **Hinterhertelefonieren**: Gemeldete Kranke (Krankmeldung angenommen) werden angerufen, bis sie wieder zur Arbeit kommen – vom Spieler am Apparat (1,5 s) oder von Telefonisten (12 s). Wer am längsten krank ist, wird zuerst angerufen; niemand wird doppelt angerufen. Eingehende Anrufe haben immer Vorrang vor Rückrufen.
- **Telefonisten** (Team, max. 4, mit steigendem Preis) sitzen sichtbar an eigenen Plätzen in der Telefonzentrale; jeder führt ein Gespräch gleichzeitig. Geht der Spieler während eines Gesprächs weg, klingelt eine Krankmeldung weiter (Klingelzeit läuft weiter), ein Rückruf wird abgebrochen.
- Laufende Gespräche zeigen einen Fortschrittsring (orange = Krankmeldung, grün = Rückruf) und witzige Sprechblasen-Dialoge (Ausrede des Anrufers, dann Antwort; 12 Ausreden, 12 Rückruf- und 8 Annahme-Antworten).
- Die **Krankenliste** an der Wand zeigt Kranke, Gemeldete, Unentschuldigte sowie angenommene und zurückgeholte Anrufe. Das Team-Panel zeigt Kranke, Gemeldete und klingelnde Anrufe. Tippen auf die Namensleiste der Telefonzentrale öffnet ihr Raum-Fenster mit den Telefonisten.
- Die Führung zeigt zum Apparat, sobald es klingelt oder gemeldete Kranke angerufen werden können.
- **Rückkehr-Timer und Bonuszahlung**: Unter jedem kranken Schreibtisch steht „Zurück in m:ss“ – so lange dauert es ohne Eingreifen. Steht der Spieler am Platz des Kranken, erscheint oben eine Karte „Krank · zurück in m:ss“ mit drei Bonus-Stufen (klein/mittel/groß = 0,3/0,6/1,0 Minuten des aktuellen Einkommens pro Minute, mindestens 50 pro Minute gerechnet). Jeder Stufen-Button zeigt Preis und die Rückkehrzeit mit dieser Stufe („zurück in m:ss“), damit der Nutzen direkt vergleichbar ist. Der Bonus wird auf den Schreibtisch gelegt (Geldsymbol, „Bonus hinterlegt – gute Besserung!“) und beschleunigt die Genesung 2×/4×/10×. Pro Krankheit kann nur auf eine höhere Stufe aufgestockt werden, dabei wird nur die Differenz zur bereits gezahlten Stufe fällig; mit der Rückkehr verfällt der Bonus. Das Einkommen pro Minute wird im Spielkern über die letzten 30 Sekunden gemessen (auch für die Kopfzeile).
- Gespeichert werden der Meldestatus und die Bonusstufe jedes Kranken, die Anzahl gezahlter Boni sowie die Zähler angenommener/verpasster Anrufe; laufende Anrufe nicht. Kranke aus älteren Spielständen gelten als gemeldet.

Außerdem gehen Beamte auf die Toilette (4 Kabinen im Sanitärraum). Jeder Beamte kann jederzeit durch Danebenstehen (2 s) von der Toilette verjagt werden; die Führung zeigt auch dorthin. Der Weckdienst verkürzt Toilettengänge ebenfalls.

## Layout Küche und Sanitär
Die Küche ist kleiner (Kühlschrank, Arbeitsplatte, Kaffeemaschine, Tisch). Rechts daneben liegt ein eigener Sanitärraum mit den vier Toiletten. Darunter, zwischen Küche und Publikumshalle, liegt die Telefonzentrale über die ganze Breite (Telefonanlage, Apparat des Spielers, 4 Telefonistenplätze, Krankenliste). Wird ein Beamter aus Küche oder Toilette geholt, läuft er sichtbar zu seinem Platz zurück (der Platz bleibt bis zur Ankunft leer).

## Harmlose Beschwerden
Beschwerden im Briefkasten kosten kein Ansehen; Abhauen wegen voller Halle und Wartezeit bleibt ein milder Ansehensverlust.

## Unmut der Bürger
- **Eigene Geduld:** Ab 10 erledigten Fällen bringt jeder Bürger eine eigene Geduld mit: 30–170 % der Grundgeduld (90 s, +40 % je Stufe „Bequemer Warteraum“; Ereignisse wie „Montag nach dem Feiertag“ verkürzen sie), gleichmäßig verteilt, im Mittel also unverändert. Eilige gehen schon nach rund 27 s, Geduldige warten bis zu rund 150 s. Der Geduldsring zeigt die persönliche Geduld. In den ersten 10 Fällen (Tutorial) haben alle genau die Grundgeduld.
- **Teilweise verhinderbar:** Wer zügig bedient, verliert kaum jemanden. Schlafende, Kranke, Streit oder Engpässe führen dagegen regelmäßig dazu, dass zuerst die Eiligen gehen; bei längeren Störungen lässt sich das nicht ganz vermeiden.
- **Nur manche beschweren sich:** Ab 10 erledigten Fällen beschwert sich ein Bürger, dessen Geduld abgelaufen ist, mit 30 % × persönlichem Geduldsfaktor (Eilige rund 9 %, Geduldige bis rund 51 %); wer wegen voller Halle abhaut, mit 10 % (als wütender Besucher).
- **Sammelbeschwerde:** Nach einer solchen Beschwerde nimmt die Beschwerdestelle 45 s lang keine weitere Beschwerde von Gehenden an. Eine Massenflucht erzeugt also höchstens eine Beschwerde, insgesamt höchstens rund 1,3 pro Minute. Die regelmäßigen Beschwerden (alle 105–195 s) laufen unabhängig davon weiter.
- Die Durchsatz-Analyse rechnet den gemessenen Zulauf durch Gehende (höchstens eine Beschwerde je 45 s) in den Beschwerde-Bedarf ein.
- Der persönliche Geduldsfaktor wartender Bürger wird mit dem Spielstand gespeichert (alte Spielstände: 100 %); die 45-s-Sperre nicht.

## Küchenleben
Beamte gehen häufiger in die Küche: verquatschen (bleiben bis zum Abholen), Kaffee holen (kommen frischer zurück) oder laufen gemächlich (70 s; durch Danebenstehen neunmal schneller antreiben). Gelegentlich (erstes nach 90 s, danach alle 110–200 s, jeder Kaffee-Praktikant +30 % Abstand) wird ein Kaffeekränzchen ausgerufen: mehrere Beamte gehen gleichzeitig in die Küche, der Spieler beendet es am Küchentisch (+0,2 Ansehen); nach spätestens 75 s löst es sich von selbst auf. Technik: Kaffeemaschine (4 Stufen: schnelleres Holen, frischere Beamte, goldene Streifen), Küche (3 Stufen: weniger Verquatschen, mehr Selbstholer, Pflanzen).

## Küche
Über der Eingangshalle liegt eine Küche mit Kaffeemaschine (Lämpchen zeigen die Kaffeequalität). Beamte, die einnicken, gehen teils in die Küche: Selbstholer holen sich Kaffee und kehren nach 14 s erfrischt (länger wach) zurück; Tratschende bleiben, bis der Spieler sie in der Küche abholt (oder der Weckdienst sie zurückruft). Maximal 12 Gäste, danach schlafen Beamte am Platz.

## Prüfdienst
Ein Tippen auf die Namensleiste des Prüfdienst-Raums in der Welt öffnet sein Raum-Fenster mit der Prüfdienst-Station (Tische, Einstellen, Verbessern). Im Team-Menü steht sie unter „Prüfdienst“, in den Abteilungsmenüs der Abteilungen mit Prüfung unter den gemeinsamen Stationen.

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
- Schläfer bremsen den Offline-Ertrag nicht.
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
Ab 10 Fällen sind etwa 10 % der Anträge ungültig (deterministisch aus Seed und Fallnummer, keine Folgefälle, kein Zoll). Die Sachbearbeitung der eigenen Abteilung lehnt sie ab: Bürger geht (Spruch, Gebühr 15 %), die Akte landet im eigenen Ablehnungs-Ausgang neben dem Ausgangsfach (Kapazität 6, bei Voll ist die Sachbearbeitung blockiert). Der Spieler trägt sie zum Aktenschredder (+2 je Akte), der Schredder-Praktikant schreddert sie ebenfalls. **Ablehnungs-Boten** (bis 5, im Team-Menü einstellbar, Kosten 600 · ×2 je Bote) holen Ablehnungen selbstständig aus den Ablehnungs-Ausgängen (3 pro Gang, Aktenwagen +1 je Stufe; Rollschuhe verdoppeln ihr Tempo) und bringen sie zum Schredder (+2 je Akte). Sie wählen fast volle Ausgänge (ab 5 von 6) zuerst, auch weit entfernte, sonst den Ausgang mit den meisten Ablehnungen je Wegstrecke. Mit freien Händen sammeln sie weiter, solange der nächste Ausgang höchstens 420 px Umweg auf dem Weg zum Schredder kostet (fast volle immer), und gehen erst dann zum Schredder; mit Boten führt die Leitführung den Spieler nicht mehr zu den Ablehnungs-Ausgängen.

**Akten schreddern:** Der Spieler kann am Schredder auch normale Akten aus der Aktentasche vernichten (um die Hände frei zu haben). Der zugehörige Antragsteller geht wütend nach Hause (Spruch, Wutfigur zur Tür), das Ansehen sinkt um 1 und der Bürger zählt als verloren. Beschwerden und Ablehnungen werden am Schredder zuerst abgegeben.

## Stau-Anzeige
Im Abteilungs-Menü zeigt eine rote Zeile „Stau: <Station> (Eingang/Ausgang/Ablehnungen voll)“, welche Fächer an der Route voll sind und die Abteilung bremsen.

## Fachkräfte (Optik)
Fachkräfte tragen einen hellen Kittel mit goldener Raute und Brille und sitzen auf einem goldenen Teppich mit Namensschild; normale Beamte bleiben dunkelblau.

## Einwohner und Nachfrage
Einwohner = 1000 + 12 je Fall − 20 je verlorenem Bürger (mindestens 1000); Ränge Dorf, Kleinstadt, Mittelstadt, Großstadt, Metropolregion (im Gebäude-Menü). Die Nachfrage wächst logarithmisch mit den bedienten Fällen (bei 2000 Fällen ca. ×1,5, bei 20000 ca. ×2), damit der Durchsatz nicht dauerhaft an zu wenigen Bürgern hängt.

## Rohrpost je Amt
Die Technik „Rohrpost“ schließt alle zum Kaufzeitpunkt eröffneten Ämter an. Später eröffnete Ämter starten ohne Anschluss: Im Abteilungsfenster (Abschnitt Team) gibt es die Karte „Rohrpost-Anschluss“ mit Kaufknopf; Preis = halber Eröffnungspreis des Amts, mindestens 20 000. Nur Akten angeschlossener Ämter reisen per Rohr, alle anderen tragen Spieler und Boten weiter. Transportbedarf, Engpass, Statistik (Kapseln und Boten bei gemischtem Betrieb) und Leit-Pfeil zählen nur nicht angeschlossene Ämter. Der Anschluss wird je Amt gespeichert; ältere Spielstände mit Rohrpost gelten für alle eröffneten Ämter als angeschlossen.

## Rohrpost (Optik)
Die Welt zeigt Röhren zwischen den Fächern nur für angeschlossene Ämter (Steigschacht am linken Rand, Verlauf in den Fluren). Kapseln in der Farbe der Abteilung sind nur in Fenstern der Röhre sichtbar.

## Wohnungsamt und Meldestelle
Wer einzieht, muss sich ummelden: Nach der Wohnungsprüfung geht die Akte zur Meldestelle des Bürgerservice (Haus-Marker an der Akte), erst danach in die Freigabe. Erklärt in der Abteilungsbeschreibung.

## Bürger an der Tür
Bürger betreten das Amt durch die linke Türhälfte und verlassen es durch die rechte.

## Technik (dauerhaft, global)
Die Technik-Seite ist nach Räumen gegliedert (Überschrift und Kurzbeschreibung je Raum, jede Technik genau einmal): *Büros* (Aktentasche, Arbeitseifer, Scanner, Digitale Akte, Qualitätsschulung, Digitale Signatur, KI-Klassifizierung, Klimaanlage, Schlichtungsstelle, IT-Wartung, Aktenwagen, Rohrpost, Röhrenkapazität), *Küche* (Kaffeequalität, Kaffeemaschine, Küche), *Sanitär* (Weckdienst) und *Publikumshalle* (Warteraum, Schredder-Praktikant, Beschwerde-Rohrpost, Praktikanten-Schulung, Online-Portal). Dieselben Karten erscheinen im Raum-Fenster des jeweiligen Raums.
Größere Aktentasche (+2 Tragkapazität), Arbeitseifer (+50 % eigene Arbeit), Kaffeequalität (Beamte bleiben länger wach), Weckdienst (Beamte wachen selbst auf), Dokumentenscanner (Empfang/Rampe +30 %), Bequemer Warteraum (+40 % Geduld), Aktenwagen (+1 Kapazität für Boten und Ablehnungs-Boten), Digitale Akte (Sachbearbeitung/Freigabe +20 %), Qualitätsschulung (−25 % Fehler), Digitale Signatur (Ausgabe/Zollfreigabe +40 %), Rohrpost (schließt alle bisher eröffneten Ämter an, siehe „Rohrpost je Amt“; Akten wandern automatisch zur nächsten Station, sichtbar in Röhren mit Fenstern; jede Röhre fasst gleichzeitig nur 2 Akten, die Reisezeit folgt der Röhrenlänge, ist das Zielfach voll, wartet die Akte am Ende der Röhre und blockiert den Platz), Röhrenkapazität (3 Stufen, +2 Akten pro Röhre, benötigt Rohrpost), IT-Wartung (Ereignisse dauern pro Stufe 15 % kürzer), Klimaanlage (keine Fenster-/Thermostat-Streits), Schlichtungsstelle (Bürostreits enden früher und seltener), Online-Portal (+25 % Bürger), KI-Fallklassifizierung (halbe Fehler und halbe Mehrarbeit komplexer Fälle).

## Wirtschaft und Fortschritt
- Ziel-Belohnungen zählen nicht in „Einnahmen/Min.“ und nicht in die Gesamteinnahmen.
- Gebühr je Fall × Ansehensfaktor (1 + √Ansehen/20); komplexe Fälle ×2, dringende pünktlich ×1,5 (+0,3 Ansehen), verspätet −0,3; fehlerhafte ×0,4 (−0,5 Ansehen), korrekte +0,1.
- Ansehen erhöht den Bürgerandrang (1 + √Ansehen/8, höchstens ×8), dazu der Bewertungsschnitt (×0,85 bei 1 Stern bis ×1,25 bei 5 Sternen).
- **Gebäudestufen**: Service-Schalter → Bürgeramt → Kreisverwaltung → Dienstleistungszentrum → Stadtverwaltung (mehr Abteilungsräume, Tische, Lobbyplätze).
- **Ziele**: 21 aufeinander aufbauende Ziele mit Belohnung, letztes Ziel 20 000 Fälle. Die ersten führen über Handarbeit zur Automatisierung: 3 Fälle → Station ausbauen → 25 Fälle → erste Einstellung (250) → Gebäude erweitern → erster Bote (500).
- **Ereignisse**: siehe Abschnitt „Ereignisse“.
- **Offline-Ertrag**: 70 % des automatisierten Durchsatzes, max. 4 h, ab 60 s Abwesenheit; im Rückkehr-Dialog per Werbung verdoppelbar.
- Engpass-Anzeige je Abteilung (Nachfrage, Transport oder Station) mit Hervorhebung in der Welt.

## Oberfläche
- Kopfzeile mit Geld, Ansehen, Einnahmen/Min. und Einstellungen; Zielkarte mit Abholen-Button (ist das Ziel erfüllt, steht unter dem Fortschritt die Belohnung inkl. Ansehen und Dienstsiegel); Ereignis-Banner.
- **Aufgaben-Panel** (einklappbar über Titel oder Pfeil rechts oben im Panel; eingeklappt verschwindet das Panel bis auf einen kleinen Ausklapp-Knopf oben links): je Abteilung wartende Bürger und Auslastung in %; Tippen fokussiert die Kamera auf den Raum und hebt ihn hervor, Pfeil öffnet die Verwaltung.
- Untere Navigation: Abteilungen, Team, Technik, Gebäude, Statistik, Ziele.
- **Statistik-Seite** (Engpässe erkennen und gezielt ausbauen; gemessen im gleitenden 60-s-Fenster seit App-Start, nicht gespeichert):
  - **Was ausbauen?** (hervorgehobene Karte ganz oben): die bis zu 4 vollsten Bereiche mit Auslastung ≥ 85 % (Stationen, Aktentransport, Beschwerden, Ablehnungen, Telefonzentrale, Sitz- und Wartebereich, Wartemarkenautomat, Aufrufanzeige), absteigend nach Auslastung, je mit den zwei wirksamsten Ausbauten und ihrem Gewinn pro Minute; Pfeil öffnet direkt das passende Fenster (Abteilung, Team, Technik, Gebäude). Ohne ausgelasteten Bereich ein Hinweis.
  - Gesamtes Amt (Einnahmen, ankommende Bürger, erledigte Fälle, Ablehnungen, verlorene Bürger je Minute, erwartete Kapazität), Link zu den Online-Bewertungen mit Durchschnitt, Anzahl und schlechten Bewertungen.
  - Je Abteilung: Ankünfte gemessen/erwartet, Erledigt, Kapazität des langsamsten Schritts, Wartende, Deckungsbalken, **Kapazität je Schritt** (jeder Arbeitsschritt anteilig für diese Abteilung plus Aktentransport, der Engpass farbig hervorgehoben) und Engpass-Text.
  - Je Arbeitsschritt: erledigte Akten/Min. (gemessen), Kapazität, Bedarf, Auslastungsbalken (grün < 85 %, gelb, rot > 100 %), Ø Sekunden je Akte und Akten/Min. je Beamtem, Eingangs-/Ausgangsfach, arbeitende Beamte, Engpass-Markierung und **Ausbau-Wirkung** (zusätzliche Akten/Min. für +1 Beamter bzw. +1 Tisch mit Beamtem bzw. +1 Maschine, +1 Stufe, +1 Fachkraft, +1 Teamleitung und passende Technik; „Voll ausgebaut“, wenn nichts mehr geht).
  - **Weitere Bereiche** mit Kapazität, Bedarf, Auslastung und Ausbau-Wirkung: Aktentransport (gemessene Übergaben gesamt und aufgeteilt nach dir, Boten und Rohrpost; Boten und Akten je Gang bzw. Kapseln je Röhre und unterwegs; Rohrpost unbegrenzt), Beschwerden (Zulauf und Geschreddertes gemessen, aufgeteilt nach dir/Personal, Kasten-Füllstand, Praktikanten, Wachen; Wachen senken den Zulauf), Abgelehnte Anträge (Zulauf und Geschreddertes, wartende Ablehnungen, Ablehnungs-Boten; Ausbau: weiterer Ablehnungs-Bote oder Aktenwagen), Telefonzentrale (Krankmeldungen, angenommene und verpasste Anrufe je Minute, Annahmequote, Telefonisten senken die Krankmeldungen), Sitz- und Wartebereich (belegte Plätze, Ausbau +3 Plätze).
  - Kapazitäten sind Schätzungen aus den Spielwerten (Boten 7 s, Ablehnungs-Boten: nach Bedarf gewichteter Hin- und Rückweg Schredder ↔ Ablehnungs-Ausgang, mindestens 12 s, Praktikanten Schredder-Takt + 8 s je Gang; Bedarf an Krankmeldungen aus dem mittleren Intervall, an Beschwerden aus dem mittleren Intervall plus gemessenem Zulauf durch gehende Bürger, höchstens eine je 45 s).
  - Ausfälle und Streits (gerade krank, Krankmeldungen/Min., durch Gesundheit vermiedene Krankmeldungen, Nickerchen und Pausen/Min., Streits aktuell und je Minute, durch Gelassenheit vermiedene Streits, abgeschlossene Schulungen); je Station alle Beamten mit Schulungsstufen (Symbole), Zustand, Akten/Min., erledigten Akten, Krankmeldungen und Pausen sowie „Beamte schulen“.
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
- **Sprechblasen** in der Warteschlange mit wechselnden Bürgersprüchen („Ich hab Zeit. Ich bin Rentner.“, „Nur eine ganz kurze Frage … oder sieben.“), 12 Sprüche.
- **Schwebende Kommentare** beim Abschluss: „Gestempelt!“, „Genehmigt!“, „Aktenzeichen vergeben“ bzw. bei Fehlern „Formfehler!“, „Bitte nachreichen“ (begrenzt, damit nichts überlädt).
- **Amtsweisheit des Tages** (12 Sprüche, wechselt täglich) oben im Ziele-Fenster.
- **Publikumsbereich** mit Amtsschild „Amt für Amtliches“, Wanduhr, Aktenschrank, Sprechzeiten-Tafel (Di 9:00–9:07 Uhr), Deutschlandflagge im Wind, Nummernautomat, Wartebänke, Pflanzen und einem Aufsteller „Schalter 13: niemand zuständig. Bitte an Schalter 13 wenden.“
- **Figuren** mit Anzug, Krawatte, Brille, Schnurrbart, wechselnden Haar- und Hautfarben, Schatten und Dienstmütze der Spielfigur.
- **Möbel und Maschinen**: Schreibtische mit Monitor, Papierstapel und Schubladen; je Abteilung eigene Maschine (Foto-Kabine, Taschenrechner, Stempel mit Stempelkissen, Schilderdrucker mit Kennzeichen, Gutscheindrucker, Frachtscanner mit Scanlinie).
- **Räume**: farbige Kopfleiste mit kontrastsicherer Schrift, gefliester Boden, Schatten, Stations-Plaketten; Fahrzeuge (Pkw, Lkw) mit Fenstern, Rädern und Schatten.
- **Lesbarkeit**: Schriftgrößen im gesamten UI angehoben (Fließtext 17, Nebentext 16, Beschriftungen 15), dunklerer Nebentext, Beschriftungen in der Spielwelt mit hellem Umriss.

## Lokalisierung
Deutsch und Englisch (Fallback) über `i18n/translations.csv`; keine UI-Strings im Code.

## Mehr Trubel am Anfang
Krankmeldungen, Streits, Kaffeekränzchen und Beschwerden treten früh und häufig auf, damit der Spieler anfangs viel selbst erledigen muss. Personal entschärft das gezielt: Telefonisten → seltener krank, Teamleitungen → seltener Streit, Kaffee-Praktikanten → seltener Kaffeekränzchen, Wachleute und weitere Beschwerde-Praktikanten → seltener Beschwerden. Die Team-Beschreibungen nennen den jeweiligen Effekt.

## Ansehen sinkt kaum
- Gewinne zählen voll. Jeder Verlust wirkt nur zu 5 %, und insgesamt kann das Ansehen um höchstens 0,05 Punkte pro Minute sinken (also höchstens 3 Punkte pro Stunde, nie unter 0). Im schlimmsten Fall stagniert es.
- Freischaltungen, Technik, Gebäudeausbau und Ansehens-Ziele richten sich nach dem höchsten je erreichten Ansehen. Ein kurzer Einbruch sperrt also nichts wieder.
- Ansehen und Bewertungen erhöhen weiterhin den Bürgerandrang.

## Engpässe durch Ausbau
- **Einweihungs-Euphorie:** Nach jedem Ausbau arbeitet die Station 45 s lang mit 150 % Tempo. So läuft das Eingangsfach der nächsten Station sofort voll.
- **Meilensteine:** Alle 10 Stufen springt das Tempo zusätzlich um ×1,5. Die Stationskarte zeigt, wie viele Stufen bis zum nächsten Meilenstein fehlen.
- **Nachfolger-Anzeige:** Die Stationskarte zeigt den Durchsatz der nachfolgenden Stationen. Ist eine langsamer als die eigene Station, erscheint eine Warnung.
- **Land unter:** Ist das Eingangsfach einer Station zu mindestens 75 % voll, gilt sie als überlastet. Sie bekommt eine rote Plakette, ihre Beamten werden 1,5-mal schneller müde und bevorzugt krank. Der Boost-Knopf in der Kopfzeile färbt sich dann gelb.
- **Ausfälle eingerechnet:** Durchsatz, Engpass und Statistik berücksichtigen die erwartete Verfügbarkeit des Personals (Schlaf, Pausen, Krankheit).
- **Einarbeitung:** In einer neu eröffneten Abteilung muss der Spieler erst 5 Akten selbst bearbeiten, bevor dort Personal eingestellt werden kann. Danach gibt es eine Prämie (10 Fallgebühren) und +1 Ansehen. Die Stationskarte zeigt den Fortschritt. Bürgerservice und ältere Spielstände gelten als eingearbeitet.
- **Mit anpacken:** Der Spieler bearbeitet immer nur einen Tisch gleichzeitig.

## Mehrfachanträge
- Bürger bringen gelegentlich bis zu 2 weitere Anträge für andere eröffnete Abteilungen mit (12 % + 6 % je weitere Abteilung, höchstens 45 %; kein Zoll).
- Der Empfang braucht je weiteren Antrag 50 % länger und teilt das Bündel in einzelne Akten auf, die dann parallel durch die Abteilungen laufen. Ist der Ausgang dafür zu voll, wartet der Empfang.
- Die Zahl der Bündel wird gezählt und gespeichert.

## Poststelle
- Ab der zweiten Gebäudestufe öffnet zwischen Telefonzentrale und Halle die **Poststelle**, ein zweiter Eingang. Der Briefträger liefert alle 45 s einen Stapel Briefe (3 + 1 je Abteilung, mit Post-Abo +2).
- Briefe landen im **Briefregal** (Lager, Basis 12 Plätze, +8 je Ausbaustufe, 10 Stufen, Preis 600 · 1,7^Stufe). Ist das Regal voll, gehen Briefe ohne jede Strafe an den Absender zurück.
- Briefe haben keine Geduld, belegen keinen Sitzplatz und kosten nie Ansehen. Dafür bringen sie nur 50 % der Gebühr (+10 % je Stufe „Einschreiben“).
- Die Poststelle ist eine eigene Station (Tische, Personal, Ausbau). Sie überspringt den Empfang und schickt Briefe direkt in die Sachbearbeitung. Dort haben Bürgerakten Vorrang, und die Poststelle füllt fremde Eingangsfächer nur bis zur Hälfte.
- Technik der Poststelle: *Brieföffner* (3 Stufen, +40 % Tempo je Stufe), *Post-Abo* (größere Stapel) und *Einschreiben* (mehr Gebühr).
- **Fehlende Unterlagen:** Ab 20 Fällen fehlt bei 5 % der Akten in der Sachbearbeitung ein Formular. Es wird mit der nächsten Post als zusätzlicher Brief nachgereicht.
- Gesperrt zeigt das Raum-Fenster, ab welcher Gebäudestufe die Poststelle öffnet.

## Boosts, Dienstsiegel und Werbung (Attrappe)
- Boosts kosten **Dienstsiegel** oder alternativ eine Werbung. Ein neues Spiel startet mit 5 Siegeln, jedes abgeholte Ziel gibt 1 Siegel. Der **Siegel-Shop** verkauft Pakete mit 10, 30 oder 80 Siegeln als Testkauf ohne Bezahlung.
- Nach einer Werbung hat der Boost eine Abklingzeit, mit Siegeln nicht. Ein aktiver Boost kann nicht erneut gestartet werden.
- 14 Boosts:

| Boost | Wirkung | Dauer | Siegel |
|---|---|---|---|
| Überstunden | alle Stationen ×2 Tempo | 60 s | 3 |
| Leiharbeiter | besetzen alle leeren Tische | 180 s | 4 |
| Stempel-Turbo | Maschinen ×3 Tempo | 90 s | 2 |
| Eilpost | Poststelle ×4 Tempo (nur mit Poststelle) | 120 s | 2 |
| Kaffeerunde | weckt alle, niemand wird müde | 180 s | 2 |
| Betriebsarzt | macht alle Kranken sofort gesund | sofort | 2 |
| Betriebsausflug | beendet Streits und Kränzchen, keine neuen Streits, Krankmeldungen oder Kränzchen | 300 s | 3 |
| Rede des Bürgermeisters | wartende Bürger gehen nicht | 180 s | 2 |
| Rollschuhe | Spieler ×1,5, Boten und Ablehnungs-Boten ×2 | 180 s | 2 |
| Beschwerde-Amnestie | leert den Beschwerde-Briefkasten, keine neuen Beschwerden | 300 s | 2 |
| Wochenendschicht | schließt alle laufenden Vorgänge sofort ab | sofort | 3 |
| Anzeige im Amtsblatt | ×2 Bürger | 120 s | 3 |
| Gebührenerhöhung | ×2 Gebühren | 120 s | 4 |
| Haushaltsmittel | 5 Minuten Einkommen (mindestens 60 pro Minute) | sofort | 5 |

- Erreichbar über den Boost-Knopf in der Kopfzeile (mit Siegelzähler) und in den Raum-Fenstern der passenden Räume.
- **Werbe-Platzhalter:** Jede künftige Werbefläche zeigt jetzt eine 3-Sekunden-Fake-Werbung mit Behörden-Slogan, Countdown und Fortschrittsbalken. Danach gibt es die Belohnung. Werbeflächen: Boosts, Ziel-Belohnung ×2, Offline-Ertrag ×2 und „Gesundschreibung“ für einen kranken Beamten (alle 120 s).
- Siegel, laufende Boosts, Abklingzeiten, gesehene Werbungen und genutzte Boosts werden gespeichert und beim Laden geprüft.

## Neue Ereignisse
- **Bürgermeister zu Besuch** (ab 30 Fällen): ×1,5 Bürger, ×2 Gebühren.
- **Lob in der Zeitung** (ab 60 Fällen): ×2 Bürger, ×1,2 Gebühren.

## Projektspezifische Ausnahmen von globalen Regeln
- **Godot 4.7.2 statt Jetpack Compose**: Die WaffleHQ-Styling-Regeln werden sinngemäß über `AppTheme` (Rollen, Radien, Abstände, Geist-Schrift, Material Icons) umgesetzt; Details in `styling-exceptions.md`.
- **Übersetzungen als CSV** (`i18n/translations.csv`, Godot-Standard) statt `strings.xml`.
- **Kein Gradle**: Export mit vorgefertigten Godot-Android-Templates (`gradle_build` aus).
- **Testabdeckung**: Für GDScript gibt es kein Coverage-Werkzeug; Abdeckung wird über vollständige Unit-Tests aller Kernklassen (GUT 9.7.1) sichergestellt.
- **Monetarisierung nur als Attrappe**: Werbung ist ein 3-Sekunden-Platzhalter, der Siegel-Shop ein Testkauf ohne Bezahlung. Es ist kein Werbe- oder Bezahl-SDK eingebunden.
- **Keine Datenbank**: Spielstand als JSON in `user://savegame.json` (Version 2, ältere Stände starten neu).
