# Idle Germany – Features

Bewegungsbasiertes Verwaltungs-Tycoon für Android (vorerst ausschließlich Android; eine PC-Version ist eventuell später geplant) im Stil von „My Mini Mart“: Die Spielfigur ist anfangs die einzige Angestellte des Amts, läuft durchs Gebäude, trägt Akten zwischen Stationen und arbeitet selbst an unbesetzten Tischen. Jede Einstellung nimmt ihr eine konkrete Aufgabe ab. Konzeptquellen liegen in `docs/concept/`.

## Steuerung
- **Laufen**: Irgendwo auf die Karte drücken und ziehen (virtueller Joystick erscheint am Druckpunkt). Mit angeschlossener Hardware-Tastatur gehen auch WASD/Pfeiltasten.
- **Automatische Interaktion in der Nähe** (Radius 64): Akten aus Ablagen aufnehmen und passende Akten in Eingangsfächer legen. **Selbst arbeiten nur am Schreibtisch:** Das Arbeitsfeld des Spielers liegt immer direkt am Platz eines Tisches (blauer Personen-Ring am Stuhl), nie mehr unten im Raum. Der Spieler kann an jedem Tisch arbeiten, egal ob er leer ist, der Beamte gerade arbeitet, schläft oder verwaist ist (krank, Kantine, Toilette): Er übernimmt die Akte bzw. addiert seine Arbeitskraft obendrauf. Das gilt auch für den Passfoto-Platz. Nur besetzte Maschinen lassen sich nicht unterstützen. Der Leit-Pfeil zeigt auf den freien Tisch bzw. ab 3 wartenden Akten auf den Platz eines arbeitenden Kollegen.
- **Tippen nur ohne Ziehen:** Ein Bereich öffnet sich nur, wenn der Finger zwischen Drücken und Loslassen gar nicht bewegt wurde (und kürzer als die Tipp-Zeit). Jede noch so kleine Bewegung zählt als Steuern und bewegt die Spielfigur (Joystick-Totzone 4 px).
- **Doppeltippen** (zwei kurze Tipps ohne Ziehen innerhalb von 450 ms und 48 px) öffnet immer den kleinsten getroffenen Bereich (siehe „Upgrades und Bereiche“), so kleinschrittig wie möglich:
  - Spielfigur: eigene Upgrades („Du“) und der Boost Rollschuhe; das eigene Büro bietet den Boost Überstunden.
  - Einzelne Bereiche öffnen ihr Bereichsfenster mit nur ihren Upgrades: z. B. Wartebereich Annahme bzw. Abholung (Stühle, Stehplätze und ihre Schilder; je eigener Sitzplatz-Ausbau), Wartemarkenautomaten, Empfang bzw. Ausgabe (Überschrift oder Fläche: Tische, Personal und Raumtempo), jede Abteilungsstation (nur deren Tische, Personal und Raumtempo, z. B. Meldestelle oder Passfoto), die **Ablagen** jeder Station (Eingangs-, Ausgangsfach und Ablehnungsstapel: nur Ablehnungsstapel und Ablagen-Ausbau des Raums), jedes Büro einer Teamleitung (nur deren Upgrades und Rundgang), der Botenpausenraum in der Eingangshalle, der Aktenschredder, Rohrpost-Plätze, Geräte und Möbel (Kaffeemaschine, Serverschrank, Klimagerät, Kantine, Telefon …), jedes schwarze Brett im Personalraum, Archiv, Beschwerdetisch, Briefregal, Postkasten, Eingang.
  - Tipp in einen Raum außerhalb aller Bereiche: Raum-Übersicht bzw. Abteilungsverwaltung; Tipp irgendwo in eine gesperrte Abteilung: deren Eröffnung. Flure und Außenflächen öffnen nichts.
  - **Jedes Upgrade ist auch ohne Namensleiste erreichbar:** Raumtempo über jede Station des Raums, Ablagen über jede Ablage des Raums; nur Eröffnung und Amtsstufe einer Abteilung hängen allein an ihrer Namensleiste.
  - Namensleiste eines Raums (Publikumshalle: Hallenschild oben): Raum-Übersicht mit allen Upgrades des Raums, gegliedert nach Bereichen (Kopfzeile, Statuszeilen und Pfeil zum Bereichsfenster je Bereich), dazu die Boosts des Raums.
  - Namensleiste einer Abteilung: Abteilungsverwaltung (Kennzahlen, Engpass, Stau, Arbeitsweise, Route) und alle Upgrades der Abteilung, gegliedert nach Amt, Stationen und Rohrpost; gesperrte Abteilung: Hinweis und „Abteilung eröffnen“.
  - Beschwerde-Briefkasten: öffnet die Beschwerdestelle zum Lesen der Briefe im Kasten.
  - Gesperrte Räume (Poststelle vor der zweiten Abteilung, Prüfdienst ohne Prüf-Abteilung) zeigen, wann sie öffnen.
- **Leit-Pfeil** zeigt stets auf die nächstgelegene sinnvolle Aufgabe (abliefern › arbeiten/aufnehmen › Abteilung eröffnen); außerhalb des Bildes als Randpfeil.
- Zurück-Taste schließt offene Panels, sonst wird gespeichert und beendet.

## Arbeitsablauf (gemeinsam für alle Abteilungen)
Alle genannten Ansehensverluste sind Nennwerte; tatsächlich wirken sie gedämpft (siehe „Ansehen sinkt kaum“).

Empfang → Sachbearbeitung der Abteilung → (optional: Verweis/Prüfdienst) → Signatur-Station der Abteilung → Ausgabeschalter. Jede Station hat Eingangsfach, Tische/Maschinen und Ablage mit sichtbarer Kapazität; volle Fächer werden rot markiert.
- **Empfang** (geteilt): Eine Warteschlange vor dem Empfang gibt es nicht. Jeder freie Empfangsschalter ruft automatisch die niedrigste wartende Nummer auf, wenn er besetzt ist (Beamter am Platz, Aushilfe oder Spielfigur am Tisch). Die aufgerufene Nummer leuchtet als Anzeige über dem Schalter. Der Bürger geht hin und wartet dort bis zu 20 s. Erst nach seiner Ankunft beginnt die Bearbeitung, und erst danach liegt die Akte in der Ablage. Bürger einer Abteilung, deren Eingangsfach ausgelastet ist (inklusive Akten in Ablage, Arbeit und schon Aufgerufener), ruft der Empfang nicht auf. So blockiert eine überlastete Abteilung die anderen nicht (siehe „Wartemarken und Wartehalle“).
- **Sachbearbeitung**: setzt je nach Arbeitsweise der Abteilung Fehler (Husch-husch / Nach Vorschrift / Dreifach geprüft: Zeit ×0,45/1,0/2,0, Fehler 30/12/2 %, Gebühr ×1,0/1,0/2,6). Der Zeitfaktor gilt an allen besetzten Stationen der eigenen Abteilung (nicht an Maschinen, Empfang und Ausgabe), der Gebührenfaktor für jeden erledigten Fall der Abteilung (auch Offline-Ertrag und Statistik). Die Abteilungsverwaltung zeigt „Bearbeitungszeit · Fehlerquote · Gebühr“.
- **Signatur-Station** je Abteilung mit eigenem Endprodukt: Passfoto → Ausweis, Rechenmaschine → Bescheid, Gewerbestempel → gerahmte Erlaubnis, Schilderdrucker → Kennzeichen (Auto fährt weg), Architektin → gestempelter Bauplan, Gutscheindrucker → Wohnungsgutschein, Zahlstelle → Leistungskarte. Maschinen brauchen kein Personal; Bürgerservice (Passfoto), Bauamt und Sozialamt sind personell besetzt.
- **Passfoto mit Fotograf** (Bürgerservice, `GameConfig.PHOTO_STATION`): kein Automat, sondern eine Fotokabine mit Vorhang, neben der der Fotograf steht (Personal einstellen wie an jedem Tisch, ohne Einarbeitung). Liegt eine Akte im Eingang, ruft ein besetzter Fotoplatz (Fotograf, Aushilfe oder Spielfigur am Tisch) den wartenden Bürger aus der Abholung auf (Nummer leuchtet über dem Platz). Er geht hin, erst nach seiner Ankunft beginnt das Foto, danach geht er an denselben Platz zurück. Sein Sitz- oder Stehplatz bleibt in der Zwischenzeit für ihn reserviert (niemand anderes setzt sich hin, neue Stühle holen ihn nicht um), und sein Geduld-Timer wird weder zurückgesetzt noch läuft er während des Fotos weiter. Akten ohne Bürger (Post, Begleitanträge) werden ohne Aufruf fotografiert.
- **Start ohne Personal:** Jedes Büro mit Schreibtischen beginnt mit genau einem leeren Tisch (auch Empfang, Ausgabe, Poststelle, Prüfdienst und jede neu eröffnete Abteilung). Weitere Tische kauft man dazu, je Tisch genau eine angestellte Kraft; alles läuft zunächst über Handarbeit.
- **Ausgabeschalter** (geteilt): Liegt das fertige Dokument im Eingang, ruft ein freier, besetzter Schalter die Nummer des Bürgers auf (Anzeige über dem Schalter). Der Bürger steht auf, geht hin und wartet bis zu 20 s. Dann folgen Übergabe, Bezahlung, schwebender Geldbetrag, Bürger verlässt mit Endprodukt das Gebäude.
- Unbesetzte Tische arbeiten nur, solange die Spielfigur am pulsierenden Arbeitsplatz steht.
- **Handarbeit-Bonus:** Jeder Handgriff des Spielers an einer Akte (selbst bearbeiteter Stationsschritt oder selbst getragene Übergabe) erhöht deren Gebühr. Anteil = Handgriffe / (Übergaben + Stationen ohne Maschine) der Route, Gebühr × (1 + 1,5 × Anteil), also bis zum 2,5-Fachen. Personal, Boten und Rohrpost zählen nicht. Der Zähler wird mit der Akte gespeichert; der Offline-Ertrag rechnet ohne Bonus.

## Abteilungen (schrittweise Komplexität)
| # | Abteilung | Besonderheit |
|---|---|---|
| 1 | Bürgerservice | Start, einfache Fälle |
| 2 | Finanzamt | Rechenmaschine als Signatur-Station |
| 3 | Gewerbeamt | Prüfdienst (geteilte Station) vor der Freigabe |
| 4 | Kfz-Zulassung | Schilderdrucker, Kennzeichen als Endprodukt |
| 5 | Bauamt | Prüfdienst, viele komplexe Fälle, Architektin statt Maschine |
| 6 | Wohnungsamt | Verweis: jede Akte muss zusätzlich durch die Meldestelle des Bürgerservice (abteilungsübergreifende Abhängigkeit) |
| 7 | Sozialamt | Viele dringende Fälle; bewilligte Fälle kommen nach 150–300 s als Wiedervorlage zurück (kürzere Route, 60 % Gebühr) |
| 8 | Zollamt | Eigener Ablauf ohne Empfang (siehe unten) |

Eröffnet wird eine Abteilung durch Stehen auf dem Kreis im gesperrten Raum (1,2 s) oder per Tipp auf seine Namensleiste („Abteilung eröffnen“; auch in der Upgrade-Übersicht), sofern Ansehen und Geld reichen; einen eigenen Gebäudeausbau gibt es nicht, das Gebäude wächst mit jeder Eröffnung von selbst (siehe „Gebäudestufen“). Ansehen ist dabei der eigentliche Bremsklotz: Finanzamt 20, Gewerbeamt 120, Kfz-Zulassung 350, Bauamt 700, Wohnungsamt 1 200, Sozialamt 2 000, Zollamt 3 500 (jede Schwelle mindestens ×1,5 der vorigen, `UNLOCK_REPUTATION_MIN_GROWTH`). Jede neue Abteilung startet ohne Personal (nur Maschinen laufen von selbst), der Spieler arbeitet dort also zunächst selbst.

## Amtsstufen
- Jede eröffnete Abteilung lässt sich über ihre Namensleiste (Eintrag „Amtsstufe: …“, Thema „Gebäude und Ausbau“) von Stufe 1 bis 250 aufwerten. Alle 25 Stufen ist ein **Meilenstein** mit neuer Amtsbezeichnung: Provisorium (1–24) → Außenstelle (25) → Dienststelle (50) → Amt (75) → Kreisamt (100) → Oberamt (125) → Hauptamt (150) → Landesamt (175) → Bundesamt (200) → Oberste Bundesbehörde (225) → Behörde der Behörden (250).
- **Wirkung:** Jede Stufe macht alle Gebühren der Abteilung um 2 % wertvoller (`RANK_LEVEL_FEE_FACTOR`), jeder Meilenstein multipliziert sie zusätzlich (`RANK_MILESTONE_FACTORS`: ×1,5 / ×1,5 / ×2 / ×2 / ×2 / ×2,5 / ×2,5 / ×2,5 / ×3 / ×3). Gesamtfaktor: Stufe 25 ×2,41, Stufe 50 ×5,94, Stufe 100 ×64, Stufe 150 ×860, Stufe 200 ×14 472, Stufe 250 ×350 572. Das gilt für erledigte Fälle, Post-Antworten, die Ablehnungsgebühr und die Einarbeitungsprämie und damit auch für Einnahmen/Min., Offline-Ertrag und Statistik. Andrang, Tische und Personal bleiben gleich: Eine Aufwertung braucht weder Platz in der Gebäudestufe noch neues Personal.
- **Gegengewicht:** Höhere Ämter bearbeiten gründlicher. Jede Stufe über 1 macht die Bearbeitungszeit an den eigenen Stationen der Abteilung um 1 % länger (`RANK_LEVEL_TIME_FACTOR`, ×1,28 bei Stufe 25, ×1,63 bei Stufe 50, ×2,7 bei Stufe 100); Empfang und Ausgabe bleiben unberührt. Da die Gebühren je Stufe stärker steigen (+2 % plus Meilensteine), lohnt sich jede Stufe weiterhin, verlangt aber neue Tische, Ausbau und Personal, um den Durchsatz zu halten. Die Upgrade-Karte zeigt zusätzlich „Bearbeitungszeit ×a → ×b“.
- **Preis:** geometrisch ×1,07 je Stufe (`RANK_LEVEL_COST_GROWTH`). Die ersten 24 Stufen bis zum ersten Meilenstein kosten zusammen so viel wie die Eröffnung der nächsten Abteilung (Bürgerservice: Stufe 1 → 2 kostet 13,75 €, Stufe 1 → 25 zusammen 800 € = Finanzamt; beim Zollamt ist die Bezugsgröße 80 Mio. × 5).
- **Ansehen:** je Meilenstein-Block eine Schwelle aus der Eröffnungsleiter: Abteilung Nr. i braucht bis Stufe 25 das Ansehen der Abteilung Nr. i+1, bis Stufe 50 das der Nr. i+2 usw.; ab dem Zollamt bleibt es bei 3 500. Damit bremst Ansehen auch die Amtsstufen stark.
- **Kaufen:** Kaufmenge ×1, ×10 oder Max wie bei allen Spuren (Summe der Einzelpreise). Mehrfachkäufe enden an der nächsten Ansehensschwelle.
- **Abwägen:** Der erste Meilenstein bringt etwa 43–101 % dessen, was die gleich teure nächste Abteilung bei voller Besetzung einbringt, wirkt aber sofort und ohne neues Personal. Innerhalb eines Blocks rechnet sich jede Stufe langsamer als die vorige; der Kauf, der einen Meilenstein erreicht, rechnet sich besonders schnell, und jeder neue Block rechnet sich langsamer als der vorige.
- Die Upgrade-Karte zeigt „Stufe n → n+1 · Gebühren ×a → ×b“, den nächsten Meilenstein („Meilenstein bei Stufe 25: Außenstelle, Gebühren ×1,5“) und „Bis zu +…/Min. · rechnet sich in etwa …“; die Eröffnungskarte einer Abteilung zeigt entsprechend „Bis zu +…/Min. bei voller Besetzung · rechnet sich in etwa …“.
- Auf der Karte trägt die Namensleiste ab Stufe 2 ein goldenes Stufen-Abzeichen mit der Stufenzahl (Pille, wächst mit der Ziffernzahl); nur beim Erreichen eines Meilensteins erscheint „Neue Amtsstufe: … · Gebühren ×…“ über dem Raum. Die Statistik zeigt je Abteilung Amtsbezeichnung, Stufe und Gebührenfaktor.
- Gespeichert als `rank_level` (fehlend = 1, auf 1–250 begrenzt, gesperrte Abteilungen immer 1). Alte Stände mit `rank` 1–10 (früher ×2,5 je Stufe) werden beim Laden auf die kleinste Stufe mit mindestens gleichem Gebührenfaktor umgerechnet (1 → 1, 2 → 27, 3 → 53, 4 → 75, 5 → 100, 6 → 122, 7 → 133, 8 → 150, 9 → 175, 10 → 179).

## Zollamt
- Lkw liefern Fracht an die **Laderampe**; Frachtarten: Stückgut, Elektronik (höhere Verdachtsquote), Fahrzeuge.
- **Anmeldeprüfung** markiert verdächtige Sendungen (60 %).
- **Schnellspur**: Unmarkierte Sendungen überspringen den Frachtscanner. Schalter „Jede Sendung scannen“ erzwingt den Scanner für alle.
- **Frachtscanner** deckt Schmuggelware auf (50 % bei verdächtiger Fracht); sichergestellte Ware wird vor der Freigabe zum **Prüfdienst** umgeleitet (×3 Gebühr, +0,3 Ansehen).
- Übersehene Schmuggelware an der Freigabe kostet die Gebühr und 1 Ansehen.
- Statusetiketten an der Fracht: gelb markiert, rot festgehalten, grün freigegeben.

## Personal
- **Tische/Maschinen** pro Station (Start mit einem leeren Tisch, Limit je Gebäudestufe: 2/3/4/5/6) und **Personal einstellen** pro Tisch (eine Kraft je Tisch) kauft man per Tipp auf die Station (Überschrift oder Fläche) oder über das Schild der Abteilung bzw. des Raums im Abschnitt der Station.
- **Upgrades je Raum statt je Station oder Beamtem** (Halle, Poststelle, Prüfdienst und jede Abteilung, am Raumschild): *Raumtempo* (+6 % Tempo je Stufe für alle Tische und Maschinen des Raums, alle 10 Stufen ein Meilenstein ×1,25, 100 Stufen, 150 × Kostenfaktor × 1,35 je Stufe; ein Kauf gibt den Stationen des Raums kurz Rückenwind) und *Ablagen* (Eingangs- und Ausgangsfach jedes Tisches im Raum 6 → +1 je Stufe → höchstens 25 Akten, 19 Stufen, 60 × Kostenfaktor × 1,3; mehr Tische vergrößern die Ablagen nicht). Details unter „Engpässe durch Ausbau“.
- **Kosten (Handarbeit zuerst, langsam automatisieren):** Tische und Ausbau skalieren mit dem Kostenfaktor der Abteilung (1/3/9/27/80/220/650/1900) und bleiben günstig, weil zusätzliche unbesetzte Tische die Handarbeit vervielfachen. Personal (Einstellen und Teamleitung) skaliert mit dem höheren Personalfaktor der Abteilung (1/4/30/200/1200/6000/35 000/230 000), damit jede neue Abteilung eine Weile von Hand läuft. Einstellen: Grundpreis je Station (Empfang 150, Sachbearbeitung 240, Freigabe 270, Prüfdienst 330, Ausgabe 180, Rampe/Zollfreigabe 300) × Faktor × 2 je vorhandener Kraft; Teamleitung 400 × Faktor. Gebäudeweites Personal (Einstellen am jeweiligen schwarzen Brett im Personalraum, Boten im Botenpausenraum der Halle): Boten 400 × 1,5 je Bote (bis 30), Ablehnungs-Boten 600 × 1,7 (bis 12), Kaffee-Praktikanten 700 × 1,9 (bis 8), Beschwerde-Praktikanten 1300 × 2,2 (bis 2 zusätzlich), Wachleute 1100 × 2 (bis 6), Telefonist 900 (genau einer).
- **Einstiegsrabatt:** Die ersten 10 Stufen jedes Upgrades sind deutlich günstiger: Stufe 1 kostet 25 % des Listenpreises, danach steigt der Anteil gleichmäßig bis zum vollen Preis ab Stufe 11. Das gilt für alle Spuren (bei weiteren Wartemarkenautomaten zählt die Preisstufe weiter), Tische (ab dem zweiten), Einstellen, Ablehnungsstapel, Röhrenabschnitte, Briefregal, gebäudeweites Personal und Botenstufen.
- **Spielfigur:** arbeitet 2,5-mal so schnell wie eine Kraft (*Arbeitseifer* +2,5 % je Stufe, 200 Stufen), läuft 420 px/s (*Bequeme Turnschuhe* +0,5 % je Stufe, 100 Stufen), trägt 6 Akten (*Größere Aktentasche* +1 je Stufe, 100 Stufen) und legt alle 0,08 s eine Akte ab bzw. nimmt eine auf. Alle drei Upgrades öffnen sich per Tipp auf die Spielfigur.
- **Teamleitung** (eine je Leitungsbereich: Annahme (Empfang) und Abholung (Ausgabe) in der Halle getrennt, Poststelle, Prüfdienst, jede Abteilung): sitzt sichtbar in einem eigenen kleinen Büro, das als Raum gezeichnet ist (Wände, offene Tür mit Türflügel, Fenster, Aktenschrank, Pflanze, Teppich, Namensschild „Teamleitung“); in der Halle liegt das Büro direkt unter dem Empfang bzw. der Ausgabe. Ohne Teamleitung zeigt ein blasser Platz, wo sie hinkommt. Tipp auf das Büro öffnet nur „Teamleitung: <Bereich>“. Einstellen 400 × Personalfaktor. Schon ohne Ausbau wirkt sie sofort stark; danach folgen kleinschrittige, günstige Boni (je 150 Stufen, Preis × Personalfaktor × 1,04 je Stufe, erste 10 Stufen mit Einstiegsrabatt):
  - *Kurze Pausen*: Kaffee-, Mittags-, Toiletten- und Kaffeeholpausen sofort ×0,75, je Stufe ×0,995 kürzer (60).
  - *Rückkehrgespräche*: Krankheit sofort ×0,75, je Stufe ×0,995 kürzer (60).
  - *Strenger Blick*: Einnicken sofort ×0,7, je Stufe ×0,995 langsamer (80).
  - *Schlichtung* (nur Abteilungen): sofort 25 % Chance, einen Streit vorab zu verhindern, je Stufe +0,5 Prozentpunkte (50).
  - *Rundgang-Tempo*: Tempo im Rundgang ×3,0, je Stufe +0,01 (80).
  - *Rundgang-Routine*: Abklingzeit 180 s, je Stufe ×0,995 kürzer (60).
  - Alte Spielstände: Eine Hallen-Teamleitung samt Stufen wird auf Annahme und Abholung übertragen.
- **Aktive Fähigkeit „Auf Rundgang schicken“** (Knopf im Bereich der Teamleitung): Die Teamleitung läuft 90 s sichtbar von Tisch zu Tisch (5 Runden, also deutlich flotter als zuvor); die Abklingzeit von 180 s läuft ab Start des Rundgangs. Sofort wachen alle Schlafenden, Verquatschten und Kaffeepausierenden des Raums auf, während des Rundgangs arbeitet der Raum mit dem Rundgang-Tempo und niemand nickt ein. Danach läuft die Abklingzeit (Ring über der Teamleitung, Knopf zeigt Restzeit). Rundgänge und dabei geweckte Beamte zählt die Statistik.
- **Boten** (bis 30 insgesamt, eingestellt und ausgebaut im **Botenpausenraum** der Eingangshalle): laufen als Figuren durchs Gebäude, reservieren Akten, tragen sie von Ablagen zum nächsten Eingangsfach und warten, wenn das Ziel voll ist. **Möglichst immer in Bewegung:** Ohne Auftrag laufen sie zur Station, an der als Nächstes die meisten Akten für ihre Aufgabe fertig werden (in Arbeit oder im Eingangsfach; bei Gleichstand die nächstgelegene), und gehen dort neben dem Ausgangsfach auf und ab. Nur wenn es für sie wirklich nichts zu tun gibt, ruhen sie im Pausenraum (Sofa, Tisch, Wasserspender, Schild „Botenpause n/30“). In den Technikraum laufen sie nicht. Am Ausgangsfach laden sie bis zur Tragkraft nach: auch Akten, die seit der Reservierung dazugekommen sind, und Akten für weitere Ziele (nächstgelegene zuerst, nur mit freiem Eingangsfach); Reservierungen anderer Boten bleiben liegen. Die Ziele beliefern sie nacheinander, das nächstgelegene zuerst. Jeder Bote hat genau eine **Aufgabe**:
  - *Empfang → Amt*: von Empfang, Poststelle und Laderampe in die Sachbearbeitung.
  - *Innerhalb des Amts*: zwischen den Stationen eines Amts, auch zu Prüfdienst und Meldestelle.
  - *Amt → Ausgabe*: fertige Akten zum Ausgabeschalter.
  - *Ablehnung*: holt abgelehnte Anträge aus den Ablehnungs-Ausgängen (fast volle Stapel zuerst; mit Ladung nur Umwege bis 420 px, bei fast vollem Stapel immer; zwei Boten wählen nie denselben Stapel) und schreddert sie im Aktenschredder des Schredderraums (+2 je Ablehnung, Statistik „durch Personal“). Er trägt bis zur Tragkraft seiner Botenstufe, läuft mit Botentempo (*Botenschuhe*, Rollschuhe), ruht ohne Auftrag im Pausenraum und fasst keine Akten an; Boten mit den anderen Aufgaben fassen keine Ablehnungen an. Wird er umgesetzt, bringt er seine Ladung noch zum Schredder.
  - Optional ist ein Bote nur für ein bestimmtes Amt **zuständig** (sonst alle Ämter).
  - Eingestellt wird im **Botenpausenraum** (Eingangshalle); der Preis richtet sich nach der Gesamtzahl der Boten, besetzt wird die Aktenaufgabe mit dem größten Engpass (Ablehnung wählst du selbst im Segmentschalter).
  - Im Botenpausenraum lässt sich jeder Bote kostenlos umsetzen (Aufgabe per Segmentschalter, Zuständigkeit per Knopf). Je Aufgabe stehen wartende Akten (bei Ablehnung: wartende Ablehnungen), Kapazität und Bedarf pro Minute, je Bote Zustand (unterwegs/frei) und Tragkraft.
  - Die Transportkapazität richtet sich nach der schwächsten Aktenaufgabe (Boten mit der Aufgabe Ablehnung zählen nicht dazu) und dem Lauftempo (*Botenschuhe* +1 % je Stufe, 200 Stufen); Statistik, Engpass und Leit-Pfeil berücksichtigen nur passende Boten. Ältere Spielstände verteilen vorhandene Boten gleichmäßig auf die drei Aktenaufgaben.
  - **Tragkraft:** 2 Akten (bzw. Ablehnungen) pro Gang, *Aktenwagen* +1 für alle Boten (40 Stufen). Dazu **Botenstufen** je Bote (0–30, Knopf im Botenpausenraum): jede Stufe +1 Akte pro Gang. Kosten 900 × 1,25 je Stufe des Boten. Stufe wird gespeichert; Kapazität, Reservierung und Leit-Pfeil rechnen mit der Tragkraft jedes einzelnen Boten.
  - **Boten neben der Rohrpost:** Boten tragen alle Akten, die nicht per Rohr reisen können (Raum ohne Rohrpost-Station, übergroße Akten, komplexe Fälle ohne „Große Kapseln“). Ist ein Ausgangsfach mindestens halb voll, nehmen sie dort auch Rohrpost-Akten mit und entlasten so die Röhren. Eine Reservierung, deren Akten inzwischen per Rohr reisen oder weg sind, wird sofort aufgegeben.
- **Kaffee-Praktikanten** (bis 8, Kaffeedienst-Plan im Personalraum): brühen in der Kantine eine Tasse und bringen sie direkt an den Platz des müdesten wachen Beamten mit Arbeit (Wachsamkeit unter 60 % der Basis). Der Beamte ist danach länger wach (125 % der Basis-Wachzeit) und muss nicht selbst in die Kantine. Sie sind als Figuren mit Tasse und Dampf sichtbar, wählen nie dasselbe Ziel und lassen schlafende, kranke oder abwesende Beamte aus. Jeder Kaffee-Praktikant lässt sich im Plan einer Abteilung zuteilen (sonst alle); *Flinke Kaffee-Praktikanten* (+1 % Lauftempo je Stufe, 200 Stufen).

## Schwarze Bretter (Schichtpläne)
Gebäudeweites Personal hat kein eigenes Menü mehr, sondern je Gruppe ein schwarzes Brett. Alle Bretter hängen gesammelt im **Personalraum** (rechte Raumspalte, direkt unter dem Büro des Spielers und nahe der Halle, 4 Bretter mit Live-Werten); die Boten haben stattdessen ihren Pausenraum in der Eingangshalle. Das Raumschild des Personalraums öffnet alle übrigen Personal-Upgrades (Kaffeedienst, Telefonist, Schulungen, Betriebsrat) gruppiert nach Brett. In der Raum-Übersicht öffnet der Pfeil neben dem Brett den **Schichtplan**: Einleitung, jede Kraft mit Name, Zustand und Einteilung, dazu Einstellen und alle Upgrades der Gruppe. Ohne Personal steht ein zweizeiliger Hinweis da.

| Brett | Ort | Inhalt |
|---|---|---|
| Botenpausenraum | Eingangshalle | Boten nach Aufgabe (Annahme, Intern, Ausgabe, Ablehnung), Aufgabe/Zuständigkeit umsetzen, Botenstufe je Bote, Aktenwagen, Botenschuhe; Hinweis, wenn die Rohrpost schon einen Teil übernimmt |
| Kaffeedienst | Personalraum | Aufgabe je Kaffee-Praktikant, Zuständigkeit, Flinke Kaffee-Praktikanten |
| Krankenliste | Personalraum | Telefonist (frei/belegt); Kranke, Gemeldete, Unentschuldigte, Anrufe |
| Schulungsbrett | Personalraum | Qualitätsschulung |
| Betriebsrat | Personalraum | Schlichtung, laufende und geschlichtete Streits |

## Beschwerdebüro, Briefkasten und Schredderraum
Beschwerdebüro und Schredderraum liegen in der rechten Raumspalte (siehe „Gebäudeplan“), das Beschwerdebüro ganz unten direkt neben der Publikumshalle. Im Beschwerdebüro gibt es keinen Sitzplatz, nur den hölzernen **Beschwerdetresen** und direkt daneben den roten **Beschwerde-Briefkasten**; am Eingang kann eine **Security** stehen. Ab 10 erledigten Fällen laufen regelmäßig Beschwerden ein (alle 105–195 s).
- **Beschwerdebriefe ohne Anlass:** Ab 10 erledigten Fällen kommt außerdem alle 4–9 Minuten (zufällig) ein Brief per Post, ganz ohne Grund. Er landet direkt im Briefkasten; Security und Praktikanten halten ihn nicht auf, nur die Beschwerde-Amnestie. Ist der Kasten voll, wird er eine schlechte Bewertung.
- **Tresen unbesetzt** (Anfang, Zettel „Tresen unbesetzt“, verkleinert die Schrift bei Bedarf, damit er in den Rahmen passt; verschwindet, solange der Spieler am Tresen steht): Jede Beschwerde geht direkt in den Briefkasten.
- **Spieler am Tresen:** Der Spieler hat am linken Tresenende einen eigenen, mit blauem Personen-Ring markierten Platz (`WorldLayout.complaint_player_point`, Radius 64). Steht die Spielfigur dort, haben alle Bürger Respekt: Beschwerdeführer und wütende Besucher kommen in den Raum, tragen ihr Anliegen vor, bekommen Respekt („Respekt. Geht wortlos.“) und gehen ohne Beschwerde. Praktikanten werden dabei nicht belastet, auch Beschwerden ohne freien Platz vor dem Tresen entfallen. Geht der Spieler vor Ende des Gesprächs weg, gilt wieder Praktikant bzw. Briefkasten. Gezählt in `visitors_respected` (gespeichert). Briefe per Post sind nicht betroffen.
- **Praktikanten am Tresen** (*Praktikant am Tresen*, 3 Stufen, 600 · ×2,5): bis zu 3 Praktikanten stehen hinter dem Tresen. Jede Beschwerde geht an den Praktikanten mit den wenigsten bisher abgewimmelten Beschwerden; er wimmelt sie ab, sie landet nicht im Kasten. Nach 2 Beschwerden geht er heulen (*Standhafte Praktikanten*, 6 Stufen, 1500 · ×1,8: +1 je Stufe, bis 8). Ist kein Praktikant am Tresen, geht die Beschwerde in den Briefkasten.
- **Heulen und Trösten:** Ein überforderter Praktikant rennt zur Toilette und heult dort, bis der Spieler ihn tröstet (2 Sekunden danebenstehen). Er kommt dann mit frischen Nerven zurück (Zähler 0). Die Führung zeigt den Weg zu ihm.
- **Briefkasten:** fasst 6 Beschwerden (Füllstand „n/max“ sichtbar), *Größerer Beschwerdebriefkasten* +4 je Stufe (6 Stufen, bis 30, 900 · ×2). Liegende Beschwerden kosten kein Ansehen; ist der Kasten voll, hinterlässt jeder Beschwerdeführer, der nicht abgewimmelt wurde, ausnahmslos eine Bewertung mit 1–2 Sternen.
- **Briefkasten leeren** (*Briefkasten leeren*, 6 Stufen, 2500 · ×1,9, ab 2 Praktikanten): Praktikanten holen Beschwerden aus dem Kasten und bringen sie in den Schredderraum, Stufe 1 eine Beschwerde pro Gang, bis 6 pro Gang. Ein Praktikant bleibt immer am Tresen; es laufen nur so viele los, wie Beschwerden im Kasten liegen. Geschredderte Beschwerden bringen dasselbe Taschengeld wie beim Spieler.
- **Lauftempo** (*Praktikanten-Turnschuhe*, 100 Stufen, 400 · ×1,07): Praktikanten laufen langsam (90), jede Stufe +2 % (bis +200 %).
- **Security** (*Security*, Freischaltung 3000) steht im Beschwerdebüro direkt am Eingang. Jeder neue Beschwerdeführer (auch wütende Besucher) wird mit 10 % abgefangen (*Security-Schulung*, 100 Stufen, 800 · ×1,06, bis 80 %): Er bleibt vor der Tür in der Halle stehen, es folgt ein zweizeiliger Dialog (5 Varianten), nach 4 Sekunden geht er ohne Beschwerde, ohne den Raum zu betreten. Die Security macht Radau am Empfang seltener (+30 % Abstand). Der Bereich zeigt Abfangquote und Zahl der nach Hause Geschickten (gespeichert).
- **Erreichbarkeit:** Ein Tipp auf die Überschrift des Beschwerdebüros zeigt alle diese Upgrades (gegliedert nach Tresen, Briefkasten, Security); im Upgrade-Menü stehen sie verschachtelt unter Räume → Beschwerdebüro → Bereich.
- Ein Tipp auf den Beschwerde-Briefkasten öffnet die Beschwerdestelle zum Lesen (bis zu 6 der neuesten Briefe im Kasten; 50 ausführliche Beschwerdebriefe in beiden Sprachen). Im Bereichsfenster des Tresens gibt es dafür zusätzlich „Beschwerden lesen“.
- **Schreddern:** Der Spieler holt Beschwerden am Kasten ab (Platz wie Aktentasche) und bringt sie zu einem Schredder; pro Beschwerde gibt es ein kleines Taschengeld (4) und etwas Reputation. *Schärfere Schneidwerke* (100 Stufen) lassen den Spieler schneller einwerfen (−1,5 % Zeit je Stufe).
- Dazu beschwert sich jeder Bürger, der geht oder abhaut (siehe „Wartemarken und Wartehalle“; als Besucher am Tresen, sonst direkt per Zettel).

**Online-Bewertungen:** Eigene Bewertungsseite (Bereich „Online-Bewertungen“) mit Durchschnitt in Sternen, Verteilung von 5 bis 1 Stern, Filter nach Sternen, Liste (neueste zuerst, seitenweise) und Detailansicht mit Blättern zur vorigen/nächsten Bewertung. Aufruf über die Bewertungs-Plakette im Kopfbereich (Durchschnitt) oder das Banner. Jede Bewertung hat Sterne, Verfasser und Text (Textpool: 40 Texte für 1 Stern, 35 für 2, 30 für 3, 25 für 4 und 30 für 5 Sterne – also 105 schlechte/mittlere und 55 gute, alle verschieden). Bewertungen entstehen so: Jede Beschwerde, die nicht mehr in den vollen Briefkasten passt, wird ausnahmslos eine schlechte Bewertung (1 Stern, zu 30 % 2 Sterne; keine Obergrenze außer dem Speicher). Gute Bewertungen (3–5 Sterne: 10 % 3, 30 % 4, 60 % 5 Sterne) kommen völlig unabhängig vom übrigen Spiel zufällig alle 45–120 Sekunden (`praise_timer`, gespeichert); abgeschlossene oder fehlerhafte Fälle lösen keine Bewertung aus (max. 80 gespeichert, älteste Nicht-Schlechte fallen zuerst weg). Jede Bewertung verschwindet nach 2 Stunden Spielzeit von selbst („Verschwindet von selbst in …“ in der Detailansicht, Hinweis in der Spielwelt); wer schneller Ruhe will, lässt sie löschen. Solange schlechte Bewertungen stehen, sinkt das Ansehen langsam (1 Stern voll, 2 Sterne halb; Lob kostet nichts). In der Detailansicht jeder Bewertung: „Löschen lassen“ – je weniger Sterne, desto teurer. Der Preis hängt von der Gebäudestufe ab (Löschen einer 1-Stern-Bewertung / Klage: Stufe 0 Schalterhalle 75 / 100, Stufe 1 ab Finanzamt 150 / 250, Stufe 2 500 / 800, Stufe 3 2.000 / 3.500, Stufe 4 10.000 / 18.000) und jede Bewertung trägt eine feste Zufallsabweichung von −30 % bis +30 % (`Review.price_factor`, gespeichert). Löschen: 1 Stern ×1, 2 Sterne ×0,5, 3 Sterne ×0,2, 4 Sterne ×0,067, 5 Sterne und berichtigte kostenlos; jede gescheiterte Klage gegen die Bewertung macht das Löschen ×1,5 teurer; schlechte Bewertungen geben beim Löschen +0,15 Ansehen zurück). „Wegen Verleumdung anzeigen“ ist für jede nicht berichtigte Bewertung möglich und kostet unabhängig von den Sternen anfangs gleich viel (Klagepreis der Gebäudestufe, also immer teurer als Löschen – auch nach gescheiterten Klagen, da Klagen ×1,6 und Löschen nur ×1,5 teurer werden); Erfolgschance 50 %; pro Bewertung höchstens 3 Klagen. Erfolg: Der Verfasser muss die Bewertung durch eine 5-Sterne-Bewertung ersetzen, der man das Erzwungene anmerkt (6 Texte: auf den ersten Blick freundlich, unterschwellig passiv-aggressiv, einer versteckt das Akrostichon HILFE bzw. HELP) („Berichtigt“, kostet kein Ansehen mehr), kein Schadenersatz, der Verfasser trägt nur die Kosten (Klagekosten werden 1,0-fach erstattet), +0,5 Ansehen. Misserfolg: −0,2 Ansehen, die Bewertung verliert einen Stern (bis minimal 1 Stern, neuer passender Text), und jede weitere Klage gegen dieselbe Bewertung kostet ×1,6 mehr und hat +8 Prozentpunkte Erfolgschance (50/58/66 %, höchstens 70 %). Die Option „Klage per Werbung gewinnen“ ist für jede nicht berichtigte Bewertung immer da, auch vor und zwischen den Klagen: Nach einer Werbung wird sie sicher berichtigt (+0,5 Ansehen, kein Geld). Sind alle 3 Klagen gescheitert, bleibt nur noch Löschen (inzwischen deutlich teurer) oder die Werbung. Chance und verbleibende Versuche stehen in der Detailansicht und werden gespeichert. Die Bewertungsseite ist jederzeit erreichbar: über die immer sichtbare Bewertungs-Plakette im Kopfbereich („–“ ohne Bewertungen), das Banner und die Statistikseite. Alte Spielstände mit Zähler werden in 1-Stern-Bewertungen umgewandelt. Die Führung zeigt den Weg zum Kasten bzw. Schredder.

## Besucher an der Beschwerdestelle und die Praktikanten
- Beschwerdeführer laufen sichtbar ins Beschwerdebüro zum Tresen (max. 3 gleichzeitig an festen Plätzen davor); von der Security Abgefangene betreten den Raum nicht.
- **Ohne Praktikant am Tresen** gehen sie direkt zum Briefkasten und werfen die Beschwerde ein; wütende Besucher ohne Beschwerde gehen wieder.
- **Mit Praktikant** tragen sie die Beschwerde in einem dreizeiligen, witzigen Dialog vor (30 Dialoge für normale Besucher, 10 für wütende). Danach wimmelt der Praktikant sie ab (auch wütende Schreihälse zählen als Beschwerde) und sie gehen. Heult er inzwischen und ist kein anderer da, wirft der Besucher die Beschwerde in den Briefkasten. Bei aktiver Beschwerde-Amnestie gehen Besucher nach dem Tresen nach Hause. Sind alle Plätze belegt, wird die Beschwerde direkt eingereicht.
- Jeder Praktikant steht sichtbar hinter dem Tresen und hat einen Belastungsbalken (abgewimmelt / Standhaftigkeit); mit Belastung murmelt er nervöse Sprüche, Läufer tragen sichtbar ihren Stapel.
- Ab 8 Beschwerden im Briefkasten kommen alle ~14 Sekunden **wütende Besucher** (rote Figur mit Ausrufezeichen, wackelt).

## Zulauf der Bürger
- **Zulauf wächst mit dem Ausbau:** Mit der ersten Abteilung kommen 10 Bürger pro Minute, jede weitere eröffnete Abteilung bringt 16 pro Minute mehr (10, 26, 42, 58, 74, 90, 106). Die letzte Abteilung füllt den Rest bis 180 auf: Mit allen 8 Abteilungen kommen 180 Bürger pro Minute. Ansehen, Einwohner, Ereignisse und Boosts ändern den Zulauf nicht.
- Zoll-Fracht kommt ohne Wartemarke direkt an die Laderampe. Fällige Folgeanträge des Sozialamts ersetzen eine reguläre Ankunft ihrer Abteilung.
- **Online-Bewertungen steuern den Zulauf:**

  | Durchschnitt | Zulauf |
  |---|---|
  | genau 5,0 Sterne | 125 % (nie über 180 pro Minute) |
  | 4,6 bis unter 5,0 (oder keine Bewertung) | 100 % |
  | unter 4,6 bis 4,3 | 80 % |
  | unter 4,3 bis 3,5 | 65 % |
  | unter 3,5 | 40 % |

  Schlechte Bewertungen löschen zu lassen oder erfolgreich anzuzeigen hebt den Zulauf wieder.

## Wartemarken und Wartehalle
- Es gibt bis zu 3 **Wartemarkenautomaten** mit je 12 Plätzen davor. Die Plätze sind als Bodenmarken sichtbar, die Schlange steht in zwei Spalten. Ein neuer Bürger stellt sich an die kürzeste Schlange. Sind alle Plätze an allen Automaten belegt, haut er wütend ab.
- Das Ziehen beginnt erst, wenn der Vorderste vor dem Automaten steht. Jeder Automat hat einen eigenen Fortschrittsring. Steht die Spielfigur am Automaten, läuft das Ziehen 2,5-mal so schnell.
- **Ausbau Schritt für Schritt:** Ein Automat schafft anfangs 0,15 Bürger pro Sekunde (9 pro Minute), kommt also mit den 10 Bürgern pro Minute der ersten Abteilung nicht ganz hinterher; ab Stufe 2 reicht er. Je Automat gibt es 100 Stufen *Druckgeschwindigkeit* bis 1 Bürger pro Sekunde. Den nächsten Automaten kann man kaufen, sobald der jeweils letzte Automat Stufe 50 erreicht hat (`TICKET_UNLOCK_LEVEL`). Der zweite Automat und jede seiner Stufen kosten so viel wie die Stufen 50–99 des ersten (Grundpreis 5 526 = 300 · 1,06^50), der dritte entsprechend wie die Stufen 50–99 des zweiten (101 791). Drei voll ausgebaute Automaten schaffen genau 180 Bürger pro Minute.
- Jede gezogene Nummer ist fortlaufend; sie erscheint nur auf den Aufruf-Anzeigen über den Schaltern, nicht am Bürger.
- **Zwei Warteräume in der Halle:** Links der Raum **Annahme** (Empfang), rechts der Raum **Abholung** (Ausgabe), dazwischen und drumherum die große Eingangshalle mit Eingang, Wartemarkenautomaten, Sprechzeiten-Tafel, Aufsteller und Flagge. Jeder Raum hat oben einen Titelstreifen mit Wanduhr, darunter je Schaltertisch ein eigenes Mini-Büro (6 Kabinen, unbebaute blass), in das die Bürger aufgerufen werden, darunter die Ablagen. Die Stühle stehen jeweils zur Hallenmitte hin (Annahme rechts, Abholung links), die Stehplätze in derselben Spalte direkt unter den Stühlen. Türen: zur Hallenmitte hin und zum Eingang.
- **Sitz- und Stehplätze je Raum:** Jeder Warteraum hat 70 Plätze in 10 Spalten × 7 Reihen, anfangs 15 Sitzplätze und 55 Stehplätze. Die Ausbauten sind getrennt: *Annahme: Sitzplatz statt Stehplatz* (Wartebereich Annahme) und *Abholung: Sitzplatz statt Stehplatz* (Wartebereich Abholung), je 55 Stufen, 500 · ×1,1. Mit Nummer setzt sich der Bürger in der Annahme bevorzugt auf einen Stuhl, sonst auf einen Stehplatz; ist beides voll, geht er und seine Nummer verfällt. Neue Stühle holen wartende Stehende sofort auf einen Stuhl, die übrigen rücken nach. Je Raum zeigen zwei Schilder Sitz- und Stehplätze (belegt/gesamt).
- Beim Aufruf gibt der Bürger seinen Platz in der Annahme frei. Nach dem Empfang geht er in den Raum Abholung und wartet dort (Stuhl bevorzugt) auf sein Dokument. Ist der Raum Abholung voll (inklusive der gerade Aufgerufenen und Bedienten), ruft der Empfang niemanden mehr auf.
- **Wartezeiten:** Jede Phase startet ihren Timer neu, und Laufwege zählen nicht. Die Rede des Bürgermeisters hält alle Timer an.

  | Phase | Wartet bis zu |
  |---|---|
  | Schlange am Automaten | 30 s |
  | Mit Nummer auf einem Sitzplatz | höchstens 5 min (siehe unten) |
  | Mit Nummer auf einem Stehplatz | 90 s |
  | Am aufrufenden Empfangs- oder Ausgabeschalter | 20 s |
  | Nach dem Empfang auf das Dokument (Sitzplatz / Stehplatz) | höchstens 5 min / 90 s |

- **Sitzende werden ungeduldig (beide Warteräume):** Ab 2 Minuten Wartezeit würfelt jeder Sitzende alle 20 s, ob er wütend geht: ab 2 min 10 %, ab 3 min 15 %, ab 4 min 20 % (`SEAT_LEAVE_CHANCES`); nach 5 min geht er sicher. Stehende würfeln nicht und gehen nach 90 s.
- **Keine Timer-Anzeige, aber Warnung:** Über den Bürgern stehen weder Nummer noch Restzeit. Ein **rotes Ausrufezeichen** über dem Kopf tragen Sitzende ab 4 Minuten Wartezeit (`SEAT_LEAVE_WARNING_SECONDS` 60 s Restgeduld) und alle anderen (Stehende, Wartemarken-Schlange, Schalter) mit weniger als 30 s Restgeduld (`STAND_LEAVE_WARNING_SECONDS`); Sitzende können per Zufall auch früher gehen. Wer wütend aufsteht, zeigt es durch Spruch und Weg zur Beschwerdestelle.
- **Wer die Geduld verliert, stürmt zur Beschwerdestelle.** Läuft der Timer ab (egal in welcher Phase), steht der Bürger auf, schimpft typisch deutsch (10 Sprüche, z. B. „Unerhört! Ich beschwere mich!“, „Ich zahle hier Steuern!“, „So ein Saftladen!“; mehrere kurz nacheinander werden gebündelt), bleibt 2,5 s wütend stehen und geht dann als wütender Besucher auf direktem Weg zum Beschwerdetresen statt erst nach draußen. Ansehen −0,3 und ein verlorener Bürger. Seine Akte landet auf dem Ablehnungsstapel der Station, an der er gerade wartet: Automatenschlange, Annahme und Empfangsschalter → Stapel am **Empfang**; Abholung und Ausgabeschalter → Stapel an der **Ausgabe** (je 6 Plätze, ist der Stapel voll, verfällt sie). Lief sein Antrag schon, wird die Akte im Ablauf verworfen. Ist am Tresen kein Platz frei, geht die Beschwerde direkt per Zettel ein; ist der Briefkasten voll, entsteht stattdessen eine schlechte Online-Bewertung. Wer abhaut, weil alle Automaten-Plätze voll sind, kommt weiterhin als wütender Besucher durch die Tür.
- Abgelehnte oder unvollständige Anträge schicken den Bürger direkt nach Hause.
- **Statistik:** Bereiche „Sitzplätze Annahme“, „Stehplätze Annahme“, „Sitzplätze Abholung“, „Stehplätze Abholung“ und „Wartemarkenautomat“ mit Kapazität, Bedarf, Auslastung und nächstem Ausbauschritt. Der Leit-Pfeil zeigt zum Automaten mit der längsten Schlange, sobald dort 4 oder mehr stehen.
- **Speichern:** Bürger in der Halle werden nicht gespeichert. Ältere Spielstände mit mehr Sitzplatz-Stufen als die Annahme fasst übertragen den Rest auf die Abholung (`SaveMigration.split_seating`, höchstens bis zu deren Maximum). Geladene Akten laufen ohne Bürger weiter, der Ausgabeschalter bearbeitet sie ohne Aufruf. Die Zähler (gezogen, aufgerufen, verfallen) bleiben erhalten. Alte Schlangen werden ignoriert, entfernte Upgrades ohne Erstattung gelöscht.

## Bürger und Beamte laufen sichtbar
- Jeder Bürger behält vom Betreten bis zum Verlassen dieselbe Farbe und dasselbe Aussehen und läuft sichtbar von Station zu Station: Eingang → Automatenschlange → Sitz- oder Stehplatz in der Annahme → ins Mini-Büro des aufrufenden Empfangsschalters → Sitz- oder Stehplatz in der Abholung → ins Mini-Büro des aufrufenden Ausgabeschalters → Ausgang (mit Ergebnis in der Hand). Wer abgelehnt wird, läuft von seiner aktuellen Position zum Ausgang; wer die Geduld verliert, geht von seiner Position direkt zur Beschwerdestelle. Niemand springt oder wechselt die Farbe.
- Beamte laufen sichtbar vom Platz in die Kantine bzw. zur Toilette und wieder zurück (Kaffeepause, Tratsch, Kaffeekränzchen, Mittagessen, Toilette); der Platz bleibt währenddessen leer, in der Kantine erscheinen sie erst bei Ankunft. Bei einem Bürostreit gehen bis zu zwei wache Beamte der Abteilung von ihren Plätzen zum Streitort und nach dem Ende (geschlichtet oder versandet) wieder zurück. Abwesenheit, Streit und Rückweg sind echte Zustände im Spielkern: Solange ein Beamter weg, im Streit oder auf dem Rückweg ist, arbeitet sein Platz nicht (kein leerer Tisch mit laufender Arbeit), und erst bei Ankunft am Platz geht es weiter (Rückweg 200 px/s, 0,4–8 s).
- **Wo ist wer?** Unter jedem verwaisten Platz steht, wo der Beamte gerade ist (Kaffeepause, Tratsch, Kaffeekränzchen, Mittagessen, Toilette, Streit in der Abteilung, Auf dem Rückweg; Krankheit mit Rückkehr-Timer). Die Sprechblase passt dazu: Besteck beim Essen, Streit-Symbol beim Streit, Laufsymbol auf dem Rückweg, „Zzz“ nur beim Schlafen.
- **Zurückrufen:** Steht der Spieler 1,5 s am Platz eines abwesenden Beamten (Kantine, Toilette, Kränzchen, Mittagessen), ruft er ihn von überall zurück (Fortschrittsring am Platz, Floater „Zurück an den Platz“); der Beamte läuft dann sichtbar zurück. Kranke und Streitende lassen sich so nicht zurückrufen. Zurückrufe werden gezählt und gespeichert. Aussehen und Farbe bleiben dabei gleich.

## Radau am Empfang
- Ab 25 erledigten Fällen findet ab und zu ein Bürger am Empfang sein Formular nicht und macht Radau (alle 120–260 s, die Security verlängert den Abstand um 30 %; nur wenn gerade ein Bürger am Empfangsschalter bedient wird). Solange blockiert der ganze Empfang: keine Annahme, kein Fortschritt, auch nicht durch Handarbeit.
- Der Spieler muss hingehen und den Bürger beruhigen: 2,5 s danebenstehen (grüner Fortschrittsring, setzt beim Weggehen zurück). Am Schalter pulsiert ein roter Ring mit Formular-Symbol, Schriftzug „Empfang blockiert“ und wechselnden Sprüchen (8 Stück); Floater beim Beginn und „Beruhigt“ am Ende. **Warnsignal:** Beim Beginn vibriert das Gerät (400 ms), und solange der Radau dauert, steht oben ein rotes Banner „Radau am Empfang“ („Ein Bürger hält den Empfang auf – die ganze Behörde steht still …“) (ohne Ortungsknopf, man findet den Empfang selbst). Der Leit-Pfeil zeigt dann immer zuerst dorthin, vor allen anderen Aufgaben. Zustand, Timer und Zahl der beruhigten Fälle werden gespeichert.

## Bürostreits
- Ab 15 erledigten Fällen brechen (erstmals nach 220 s, danach alle 200–400 Sekunden) Streits in Abteilungen mit mindestens 2 Beschäftigten aus (max. 2 gleichzeitig, höchstens einer je Abteilung): Fensterkrieg, Thermostat-Krieg, Radio-Streit, Joghurt-Klau, Tacker-Streit und Fischbrötchen-Gestank. Zwei streitende Beamte stehen sichtbar im Raum (Sprechblasen im Wechsel mit je 4 witzigen Sätzen), das Etikett zeigt den Tempoverlust (−10 % bis −20 % für die Sachbearbeitungs-Stationen der Abteilung; Maschinen und gemeinsame Stationen sind nicht betroffen).
- **Schlichten:** Der Spieler stellt sich 2,5 Sekunden an den Streitort (Ansehen +0,2). Ohne Eingreifen versandet der Streit nach 4 Minuten. Die Führung zeigt den Weg.
- **Upgrades:** *Klimaanlage* am Klimagerät im Technikraum (100 Stufen: Streits brechen je Stufe 1 % seltener aus; ab Stufe 25 bleiben die Fenster zu, ab Stufe 60 ist das Thermostat gesperrt – diese Streits entfallen) und *Schlichtung* am Brett des Betriebsrats im Personalraum (150 Stufen: ab Stufe 1 endet jeder Streit nach 120 s von selbst, jede weitere Stufe −1,5 %, bis 12,6 s). Jede Teamleitung (alle Abteilungen zusammen) lässt Streits zusätzlich um 30 % seltener ausbrechen.

## Krankmeldung, Telefonzentrale und Toiletten
Beamte melden sich regelmäßig krank (ab 3 Beschäftigten, erste Meldung nach 360 s, danach je Beamtem alle 40–80 Minuten, also bei mehr Personal häufiger; jeder Telefonist verlängert den Abstand um 50 %; überlastete Stationen trifft es zu 60 % bevorzugt). Ihr Schreibtisch bleibt leer und es klingelt – in der kleinen **Telefonzentrale** (ein Schreibtisch mit Telefonanlage) und am Apparat im eigenen Büro des Spielers: Die Krankmeldung läuft als eingehender Anruf ein (Lampe an der Telefonanlage blinkt, „x klingelt – rangehen!“).
- **Eingehende Krankmeldungen**: Wer rangeht – der Spieler an seinem Apparat (1,5 s) oder ein freier Telefonist (4 s) –, nimmt die Krankmeldung auf („Krankmeldung notiert“). Mit 30 % Chance wird der Anrufer überredet und kommt sofort doch („Überredet – kommt doch!“). Wird ein Anruf 30 s lang nicht angenommen, ist er verpasst („Verpasst – unentschuldigt!“): Der Kranke gilt als unentschuldigt, kann nicht zurückgerufen werden und kommt erst nach 4 Minuten von selbst wieder.
- **Hinterhertelefonieren**: Gemeldete Kranke (Krankmeldung angenommen) werden angerufen, bis sie wieder zur Arbeit kommen – vom Spieler am Apparat in seinem Büro (1,5 s) oder vom Telefonisten (12 s). Wer am längsten krank ist, wird zuerst angerufen; niemand wird doppelt angerufen. Eingehende Anrufe haben immer Vorrang vor Rückrufen.
- **Telefonist** (genau einer, 900, eingestellt an der Krankenliste) sitzt sichtbar am einzigen Schreibtisch der Telefonzentrale und führt ein Gespräch gleichzeitig. *Telefonschulung* an der Telefonanlage (100 Stufen) verkürzt seine Gespräche um 1 % je Stufe (multiplikativ, bis −63 %). Der Spieler telefoniert an seinem Apparat im eigenen Büro. Geht er während eines Gesprächs weg, klingelt eine Krankmeldung weiter, ein Rückruf wird abgebrochen.
- Laufende Gespräche zeigen einen Fortschrittsring (orange = Krankmeldung, grün = Rückruf) und witzige Sprechblasen-Dialoge (Ausrede des Anrufers, dann Antwort; 12 Ausreden, 12 Rückruf- und 8 Annahme-Antworten).
- Die **Krankenliste** im Personalraum zeigt Kranke, Gemeldete, Unentschuldigte sowie angenommene und zurückgeholte Anrufe. In der Übersicht der Telefonzentrale öffnet der Pfeil neben dem Telefonistenplatz den Schichtplan des Telefonisten, der neben der Telefonanlage die Telefonschulung; beide zeigen Kranke, Gemeldete und klingelnde Anrufe.
- Die Führung zeigt zum Apparat, sobald es klingelt oder gemeldete Kranke angerufen werden können.
- **Rückkehr-Timer und Bonuszahlung**: Unter jedem kranken Schreibtisch steht „Zurück in m:ss“ – so lange dauert es ohne Eingreifen. Steht der Spieler am Platz des Kranken, erscheint oben eine Karte „Krank · zurück in m:ss“ mit drei Bonus-Stufen (klein/mittel/groß = 0,3/0,6/1,0 Minuten des aktuellen Einkommens pro Minute, mindestens 50 pro Minute gerechnet). Jeder Stufen-Button zeigt Preis und die Rückkehrzeit mit dieser Stufe („zurück in m:ss“), damit der Nutzen direkt vergleichbar ist. Der Bonus wird auf den Schreibtisch gelegt (Geldsymbol, „Bonus hinterlegt – gute Besserung!“) und beschleunigt die Genesung 2×/4×/10×. Pro Krankheit kann nur auf eine höhere Stufe aufgestockt werden, dabei wird nur die Differenz zur bereits gezahlten Stufe fällig; mit der Rückkehr verfällt der Bonus. Das Einkommen pro Minute wird im Spielkern über die letzten 30 Sekunden gemessen (auch für die Kopfzeile).
- Gespeichert werden der Meldestatus und die Bonusstufe jedes Kranken, die Anzahl gezahlter Boni sowie die Zähler angenommener/verpasster Anrufe; laufende Anrufe nicht. Kranke aus älteren Spielständen gelten als gemeldet.

## Toiletten
Beamte gehen auf die Toilette (Sanitärraum über der Kantine, anfangs 4 Kabinen). Jeder Beamte kann jederzeit durch Danebenstehen (2 s) von der Toilette verjagt werden; die Führung zeigt auch dorthin. Das Raumschild der Toiletten öffnet ihre Upgrades:
- *Weitere Toilettenkabine* (8 Stufen, bis 12 Kabinen in zwei Reihen, 1500 · ×2,2), damit seltener jemand warten muss.
- *Schnellere Spülung* (150 Stufen): ein Toilettengang dauert 150 s, je Stufe 1 % kürzer (bis 33 s).
- *Toilettenhygiene* (100 Stufen, ab Ansehen 20): Krankmeldungen kommen je Stufe 1 % seltener (bis halb so oft).
- *Weckdienst* (150 Stufen, ab Ansehen 20): siehe „Faule Beamte“; er begrenzt auch Toilettengänge und Kaffeepausen auf seine Weckzeit.

## Gebäudeplan
Links liegen von oben nach unten die Abteilungsräume (Zoll über die ganze Breite, darunter je zwei Abteilungen bzw. Gewerbeamt und Prüfdienst nebeneinander) und unten die große Publikumshalle: eine Eingangshalle, die die beiden Warteräume Annahme (links, mit Empfang und Archiv) und Abholung (rechts, mit Ausgabe und Rohrpost-Platz) umschließt, unten Eingang und Wartemarkenautomaten. Alle Service-Räume stehen rechts daneben in einer Spalte, damit man nicht mehr durch alles hindurchlaufen muss; von oben nach unten: Technikraum, Toiletten, Kantine, Telefonzentrale (klein), Poststelle (klein, Hintereingang nach rechts), das eigene Büro des Spielers, der Personalraum mit allen schwarzen Brettern, Schredderraum und ganz unten, bündig mit der Halle, das Beschwerdebüro. Jeder Raum der Spalte hat seine Tür zur linken Seite. Jeder Abteilungsraum hat unter seinen Stationen einen Versorgungsstreifen mit Schredder-Platz und Rohrpost-Platz (leere, gestrichelte Plätze, bis dort etwas gebaut ist). Wird ein Beamter aus Kantine oder Toilette geholt, läuft er sichtbar zu seinem Platz zurück.

## Harmlose Beschwerden
Beschwerden im Briefkasten kosten kein Ansehen; Abhauen wegen voller Halle und Wartezeit bleibt ein milder Ansehensverlust.

## Unmut der Bürger
- Jeder Bürger, der geht, beschwert sich (siehe „Wartemarken und Wartehalle“). Die Durchsatz-Analyse rechnet die gemessene Rate gehender Bürger vollständig in den Beschwerde-Bedarf ein.
- Zoll-Fracht, die länger als 90 s an der Laderampe wartet, verfällt. Dann kommt mit 30 % eine Beschwerde, danach 45 s lang keine weitere.

## Küchenleben
Beamte gehen häufiger in die Kantine: verquatschen (bleiben bis zum Abholen), Kaffee holen (kommen frischer zurück) oder laufen gemächlich (70 s; durch Danebenstehen neunmal schneller antreiben). Gelegentlich (erstes nach 110 s, danach alle 220–400 s, jeder Kaffee-Praktikant +30 % Abstand) wird ein Kaffeekränzchen ausgerufen: mehrere Beamte gehen gleichzeitig in die Kantine, der Spieler beendet es am Kränzchentisch (+0,2 Ansehen); nach spätestens 75 s löst es sich von selbst auf.

## Kantine
Die Kantine (rechte Raumspalte) hat eine Essensausgabe mit Koch und wechselndem Tagesgericht (6 Schilder), Kühlschrank, einen langen Mittagstisch, die Kaffeemaschine und den Kränzchentisch. Maximal 18 Gäste (6 an der Kaffeemaschine, 6 am Kränzchentisch, 6 am Mittagstisch), danach schlafen Beamte am Platz.
- **Mittagessen:** Regelmäßig (erstes nach 300 s, danach alle 280–480 s; ohne genug Personal neuer Versuch nach 30 s; nicht während des Betriebsausflugs) gehen bis zu 6 wache Beamte gemeinsam essen, sofern mindestens 3 wach sind; mindestens einer bleibt immer am Platz. Sie laufen sichtbar zum Mittagstisch, essen von Tellern und plaudern (6 Sprüche). Nach 25 s kehren sie von selbst zurück und sind danach länger wach (×1,2 der normalen Wachzeit).
- **Essensausgabe:** *Besseres Kantinenessen* (200 Stufen, ab Ansehen 12: Wachzeit nach dem Essen +1 Prozentpunkt je Stufe, bis ×3,2) und *Schnellere Essensausgabe* (150 Stufen: Mittagspause je Stufe 1 % kürzer). Die Statuszeile zeigt servierte Mittagessen, Pausenlänge und Wachheits-Faktor.
- **Kaffeemaschine:** *Kaffeequalität* (300 Stufen, +1 % Wachzeit je Stufe, gilt auch für selbst geholten Kaffee), *Schnellere Kaffeemaschine* (150 Stufen, Kaffeeholen je Stufe 1 % kürzer) und *Espresso-Modul* (200 Stufen: Selbstholer kommen mit 150 % statt Basis-Wachzeit zurück, +0,5 Prozentpunkte je Stufe, bis 250 %). Selbstholer kehren nach 14 s erfrischt zurück; Tratschende bleiben, bis der Spieler sie abholt (oder der Weckdienst sie zurückruft).
- **Kränzchentisch:** *Aufgeräumte Küche* (200 Stufen: je Stufe 0,45 % weniger Verquatschen zugunsten des Kaffeeholens, bis −90 %).
- **Kaffeedienst** (schwarzes Brett im Personalraum): Kaffee-Praktikanten und *Flinke Kaffee-Praktikanten*.
- **Betriebsrat** (Aushang): *Schlichtung* von Bürostreits.
- Die Raum-Übersicht (Namensleiste) zeigt zusätzlich die Boosts Kaffeerunde und Betriebsausflug.
- Mittagszähler und -timer werden gespeichert.

## Eigenes Büro, Geschenke und Briefe
- Der Spieler hat ein eigenes Büro (rechte Raumspalte) mit Schreibtisch („Dein Schreibtisch“) und seinem Telefon, an dem Krankmeldungen eingehen und Rückrufe geführt werden (Klingeln, Fortschrittsring, Gesprächsblasen).
- Witzige Ausstattung: gerahmtes Bild „Mitarbeiter des Monats“ (mit dem Spieler, natürlich jeden Monat), eine wechselnde Urkunde (4 Texte, z. B. „100 % Stempelgenauigkeit“), ein Pokalregal mit 4 Pokalen, deren Titel nacheinander angezeigt werden (z. B. „Schnellster Stempel“), und eine Zimmerpflanze.
- **Geschenke:** Ab und zu (erstes nach 120 s, danach alle 180–420 s) liegt ein kleines Geschenk auf dem Schreibtisch (6 Sorten, z. B. Pralinen oder ein Gutschein). Es ist so viel wert wie 20 Sekunden Einkommen, mindestens 25. Es bleibt liegen, bis es abgeholt wird; solange kommt kein neues.
- **Briefe:** Ist das aktuelle Ziel erfüllt, liegt ein Brief mit der Ziel-Belohnung auf dem Schreibtisch. Er kann wie bisher oben an der Zielkarte oder direkt am Schreibtisch abgeholt werden.
- **Abholen am Schreibtisch:** Steht der Spieler an seinem Schreibtisch, erscheint oben eine Karte mit Brief und/oder Geschenk, jeweils mit „Abholen“ oder „×2 mit Werbung“.
- Geschenk-Sorte, Wert, Timer und Zahl geöffneter Geschenke werden gespeichert. Die Raum-Übersicht des Büros zeigt den Boost Überstunden.

## Prüfdienst
Das Raumschild des Prüfdiensts öffnet seine Station (Tische, Einstellen), die Raum-Upgrades (Raumtempo, Ablagen), die Teamleitung und den Rohrpost-Platz des Raums. Solange keine eröffnete Abteilung Vor-Ort-Prüfungen braucht, zeigt der Raum nur, wann er öffnet.

## Performance
Die Weltansicht ist in Ebenen aufgeteilt (statischer Boden/Halle samt Möblierung einmalig, Räume reihum höchstens alle 0,4 s neu gezeichnet, Bearbeitungsbalken und Fortschrittsringe trotzdem live, stehende Bürger auf einer eigenen, seltener gezeichneten Ebene, gehende Bürger und Spieler flüssig), einfache Personen im Hintergrund, Kreise über vorberechnete Texturen, MSAA aus, 60 FPS-Limit, Renderer GL Compatibility.
Höchstens 24 schwebende Texte gleichzeitig (ältester verschwindet zuerst). Die Simulation holt pro Frame höchstens 8 Schritte nach, damit ein kurzer Ruckler nicht zu weiteren Rucklern führt; längere Pausen verrechnet der Offline-Fortschritt. Die Anzeige oben aktualisiert sich 5-mal pro Sekunde, das Geld zählt flüssig weiter. Häufig gebrauchte Spielwerte (Upgrade-Wirkungen, Rohrpost-Verbindungen, Schredder, Routen) werden zwischengespeichert, sodass auch voll ausgebaute Ämter flüssig laufen.

## Flüssiges Scrollen
Sheets leiten Touch-Gesten auch von Karten und Buttons an den Scroll-Container weiter und scrollen mit Auslaufen (Fling).
Karte und Sheets scrollen ruhiger: die Kamera folgt framerate-unabhängig und pixelgerundet, statische Welt wird gedrosselt gezeichnet, Sheets starten das Scrollen schon nach 4 px und behalten die Position beim Neuaufbau.

## Faule Beamte
- **Einnicken und Kaffeepause**: Besetzte Tische (Angestellte, keine Maschinen) werden mit der Zeit müde, aber nur, solange Arbeit ansteht. Nach durchschnittlich 180 s (±30 %) nickt der Beamte ein (Zzz-Blase, geschlossene Augen) oder verschwindet in die Kaffeepause (Tasse mit Dampf). Sein Tisch steht dann still, auch neue Akten werden nicht begonnen.
- **Aufwecken**: Zum Tisch laufen und 0,7 s daneben stehen bleiben. Ein pulsierender Ring und ein Fortschrittsring zeigen den Vorgang. Der Leit-Pfeil weist auf schlafende Tische. Ohne Weckdienst schlafen Beamte unbegrenzt weiter, Kaffeepausen enden von selbst nach 60 s.
- **Dagegen skillen:** *Kaffeequalität* an der Kaffeemaschine (300 Stufen, +1 % Wachzeit je Stufe) und *Weckdienst* an den Toiletten (150 Stufen: ab Stufe 1 wachen Eingenickte nach 45 s von selbst auf, jede weitere Stufe −2 %, bis 2,2 s; Kaffeepausen und Toilettengänge enden spätestens dann, Tratschende kehren zurück). *Teamleitung* verlangsamt das Einnicken im Raum sofort um 30 % (siehe „Personal“). Mit weit ausgebautem Weckdienst läuft das Amt praktisch ohne Eingreifen.
- Anzeigen: Aufgaben-Panel zeigt je Abteilung „Zzz n“, Stationskarten „Pause oder Schlaf: n“, die Statistik zählt aufgeweckte Beamte; schwebende Sprüche beim Einnicken und Aufwachen.
- Schläfer bremsen den Offline-Ertrag nicht.
- Die Abteilungsverwaltung zeigt die ganze Route einschließlich gemeinsamer Stationen (Empfang, Ausgabe, Prüfdienst, Meldestelle); deren Raum-Upgrades liegen am Schild von Halle, Prüfdienst bzw. Bürgerservice, die Stau-Zeile und „Was ausbauen?“ führen direkt dorthin.

## Ereignisse
Erstmals nach 6 Minuten, danach alle 5–10 Minuten tritt ein Ereignis auf (Banner mit Restzeit, betroffene Stationen zeigen ein Symbol). Datengetrieben in `GameConfig.EVENTS`; die Dauer sinkt anteilig zur erreichten Stufe des passenden Upgrades (Gegenmittel), bei voller Stufe auf 40 %.
- **Prüfungsbesuch** (doppelte Ansehenseffekte).
- **Druckerstreik** (ab 20 Fällen): alle arbeiten mit 55 % Tempo. Gegenmittel: IT-Wartung.
- **Systemabsturz** (ab 60): eine zufällige Abteilung arbeitet mit 40 % Tempo. Gegenmittel: IT-Wartung.
- **Kaffeepause eskaliert** (ab 30): dreifache Müdigkeit, wache Beamte arbeiten mit 115 % Tempo. Gegenmittel: Schnellere Kaffeemaschine.
- **Der Aktenberg** (ab 80): 6 Altfälle landen im Eingang einer Sachbearbeitung. Gegenmittel: IT-Wartung.
- **Die Dienstbesprechung** (ab 50): alle arbeiten mit 45 % Tempo; Abbrechen beendet sie, kostet aber 1,5 Ansehen.
- **LKW voller Gummienten** (nur Zollamt): Zoll arbeitet mit 30 % Tempo. Gegenmittel: IT-Wartung.
- **Feueralarm – Fehlalarm** (ab 100): 20 s Stillstand. Gegenmittel: IT-Wartung.
- **Renovierung ohne Ausweichplan** (ab 120): eine Abteilung bekommt halb so viele Bürger und arbeitet mit 60 % Tempo.
- **Der Geräteschuppen** (nur mit Bauamt): ein riesiger Fall (×5 Gebühr, ×3 Bearbeitungszeit, komplex).
- **Der Prüfer wird geprüft** (ab 200, nur mit Prüfdienst-Abteilung): Prüfdienst arbeitet mit 35 % Tempo.
- **Der Behördenvergleich** (ab 150): Wahl „Präsentation vorbereiten“ (30 s lang alle mit 50 % Tempo, danach +3 Ansehen) oder „Ignorieren“; ohne Antwort verfällt er folgenlos.

## Akten-Markierungen
Kleine Marker über Akten: Lupe = muss noch zum Prüfdienst, Haus = braucht noch eine Meldung bei der Meldestelle, Kreuz = ungültiger Antrag, Punkt = Sonderfall (Geräteschuppen). Die Legende steht in der Abteilungsverwaltung.

## Ablehnungen
Ab 10 Fällen sind etwa 10 % der Anträge ungültig (deterministisch aus Seed und Fallnummer, keine Folgefälle, kein Zoll). Die Sachbearbeitung der eigenen Abteilung lehnt sie ab: Bürger geht (Spruch, Gebühr 15 %), die Akte landet im eigenen Ablehnungs-Ausgang neben dem Ausgangsfach (Kapazität 6, *Ablehnungsstapel für …* +2 je Stufe, 50 Stufen, Tischpreis × Kostenfaktor × 0,5 × 1,22 je Stufe, gespeichert als `reject_level`).
- **Ablage voll → Pause:** Ist an einer Sachbearbeitung das Ausgangsfach oder der Ablehnungs-Ausgang voll (sodass eins von beiden nicht mehr bearbeitet werden könnte), gehen sofort alle anwesenden Mitarbeiter dieses Platzes in die Pause: je zur Hälfte zufällig Mittagessen in der Kantine oder Kaffeeklatsch am Küchentisch (ist die Küche voll, Kaffeepause am Platz). Floater „Ablage voll, Pause!“, die Bereichsübersicht zeigt den Stau. Solange nicht in beiden Ablagen mindestens ein Platz frei ist, wird dort generell nicht gearbeitet – auch nicht von zurückgeholten Mitarbeitern, Aushilfen oder der Spielfigur. Erst ein erneuter Stau schickt das Team wieder in die Pause. Der Spieler trägt sie zum nächstgelegenen Schredder (+2 je Akte), der Schredder-Praktikant schreddert mit freier Kapazität ebenfalls welche. **Ablehnungs-Boten** (bis 12, Plan im Personalraum, Kosten 600 · ×1,7 je Bote) holen Ablehnungen selbstständig aus den Ablehnungs-Ausgängen (3 pro Gang, *Sammelwagen* +1 je Stufe, 40 Stufen; *Flinke Ablehnungs-Boten* +1 % Tempo je Stufe, 200 Stufen; Rollschuhe verdoppeln ihr Tempo) und bringen sie zum nächstgelegenen Schredder (+2 je Akte). Jeder lässt sich einer Abteilung zuteilen (sonst alle). Sie wählen fast volle Ausgänge (ab 5 von 6) zuerst, auch weit entfernte, sonst den Ausgang mit den meisten Ablehnungen je Wegstrecke. Mit freien Händen sammeln sie weiter, solange der nächste Ausgang höchstens 420 px Umweg auf dem Weg zum Schredder kostet (fast volle immer), und gehen erst dann zum Schredder; mit Boten führt die Leitführung den Spieler nicht mehr zu den Ablehnungs-Ausgängen.

**Ablehnungsstapel in der Halle:** Empfang und Ausgabe haben ebenfalls einen Ablehnungsstapel (12 Plätze, unter den Mini-Büros), auf dem die Akten von Bürgern landen, die dort die Geduld verloren haben. Er blockiert nichts (keine Pause), lässt sich aber ebenfalls mit *Ablehnungsstapel für …* vergrößern; Spieler und Boten mit der Aufgabe Ablehnung (für alle Abteilungen) leeren ihn wie jeden anderen Stapel. Er zählt nicht als Stau einer Abteilung.

**Aktenschredder:** Es gibt nur den zentralen Aktenschredder im Schredderraum (es gibt keine Abteilungsschredder). Spieler und Boten mit der Aufgabe Ablehnung bringen Ablehnungen dorthin; Leit-Pfeil und Statistik rechnen mit diesem einen Schredder.

**Akten schreddern:** Der Spieler kann am Schredder auch normale Akten aus der Aktentasche vernichten (um die Hände frei zu haben). Der zugehörige Antragsteller geht wütend nach Hause (Spruch, Wutfigur zur Tür), das Ansehen sinkt um 1 und der Bürger zählt als verloren. Beschwerden und Ablehnungen werden am Schredder zuerst abgegeben.

## Stau-Anzeige
In der Abteilungsverwaltung zeigt eine rote Zeile „Stau: <Station> (Eingang/Ausgang/Ablehnungen voll)“, welche Fächer an der Route voll sind und die Abteilung bremsen (höchstens drei, weitere als „…“).

## Teamleitung (Optik)
Die Teamleitung trägt einen hellen Kittel mit goldener Raute und Brille und sitzt in ihrem Büro (Wände, Tür, Fenster, Aktenschrank, Pflanze, Namensschild) an einem Schreibtisch; normale Beamte bleiben dunkelblau. Auf dem Rundgang läuft sie sichtbar von Tisch zu Tisch.

## Einwohner und Nachfrage
Einwohner = 1000 + 12 je Fall − 20 je verlorenem Bürger (mindestens 1000); Ränge Dorf, Kleinstadt, Mittelstadt, Großstadt, Metropolregion (im Bereich Eingang und auf der Statistikseite). Der Zulauf hängt nicht von den Einwohnern ab (siehe „Zulauf der Bürger“).

## Rohrpost je Raum
- **Einmal freischalten:** *Rohrpost* an der Rohrpost-Zentrale im Technikraum (250 000, ab Ansehen 250). Erst danach erscheinen in den Räumen die leeren Rohrpost-Plätze.
- **Je Raum einbauen:** Jeder Raum braucht eine eigene *Rohrpost-Station* (Rohrpost-Platz im Raum): Publikumshalle (Empfang und Ausgabe), Poststelle, Prüfdienst und jede Abteilung. Preis: Abteilungen halber Eröffnungspreis (mindestens 20 000), Halle und Poststelle 20 000, Prüfdienst 60 000. Die Rohrpost-Zentrale listet zusätzlich alle Rohrpost-Stationen und Röhrenabschnitte des Hauses.
- **Was reist per Rohr:** Eine Übergabe läuft per Rohr, wenn Start- und Zielraum eine Station haben und die Akte in die Kapsel passt: übergroße Akten (Geräteschuppen) nie, komplexe Fälle erst mit *Große Kapseln* (600 000, ab Ansehen 400). Übergaben innerhalb eines Raums mit Station laufen ebenfalls per Rohr.
- **Durchsatz skillen:** *Röhrenkapazität* (60 Stufen, je Stufe +1 Akte gleichzeitig in jeder Röhre, 120 000 · ×1,15), *Stärkeres Gebläse* (200 Stufen, +1 % Kapseltempo je Stufe, 80 000 · ×1,06). Dazu hat jeder **Röhrenabschnitt** (Station → nächste Station, auch Poststelle → Amt und Folgeantrag → Ausgabe) eine eigene Stufe am Rohrpost-Platz seiner Abteilung (100 Stufen, je Stufe +1 Kapsel und +2 % Tempo, 30 000 · ×1,08). Ist das Zielfach voll, wartet die Akte am Ende der Röhre und blockiert den Platz.
- **Boten bleiben gefragt:** Sie tragen alles, was nicht per Rohr geht, und nehmen bei Überlast (Ausgangsfach mindestens halb voll) auch Rohrpost-Akten mit (siehe „Personal“). Transportbedarf, Engpass, Statistik (Kapseln und Boten bei gemischtem Betrieb) und Leit-Pfeil zählen nur Übergaben ohne Rohr.
- Stationen und Abschnittsstufen werden je Raum bzw. Abschnitt gespeichert; ungültige Einträge werden beim Laden verworfen. Ältere Spielstände mit Rohrpost-Anschluss erhalten Stationen in den angeschlossenen Abteilungen sowie in Halle, Poststelle und (bei Bedarf) Prüfdienst, dazu die Großen Kapseln, damit wie bisher alle Akten reisen.

## Rohrpost (Optik)
Die Welt zeigt Röhren nur zwischen Stationen, deren Räume beide angeschlossen sind; jede Rohrpost-Station ist als Gerät mit Kapsel sichtbar, die Rohrpost-Zentrale im Technikraum zeigt ein Schloss, solange die Rohrpost nicht freigeschaltet ist. Zuleitungen und interne Wege laufen über den Steigschacht am linken Rand, fertige Bescheide zur Ausgabe über eine eigene **Ausgabe-Röhre** mit Schacht am rechten Rand und leicht versetzter Spur in den Fluren; so bewegt sich die Post in jeder Röhre nur in eine Richtung. Kapseln in der Farbe der Abteilung sind nur in Fenstern der Röhre sichtbar und fahren so schnell wie ihr Abschnitt.

## Wohnungsamt und Meldestelle
Wer einzieht, muss sich ummelden: Nach der Wohnungsprüfung geht die Akte zur Meldestelle des Bürgerservice (Haus-Marker an der Akte), erst danach in die Freigabe. Erklärt in der Abteilungsbeschreibung.

## Bürger an der Tür
Bürger betreten das Amt durch die linke Türhälfte und verlassen es durch die rechte.

## Upgrades und Bereiche
Alle Verbesserungen hängen an **Bereichen** auf der Karte (Schild, Möbelstück, Gerät, Aushang oder Platz). Geöffnet werden sie per **Doppeltipp** (zweiter Tipp innerhalb von 450 ms und 48 px Abstand; ein einzelner Tipp bewirkt nichts, `WorldView.register_tap`) auf den Bereich selbst (Bereichsfenster) oder über das Namensschild des Raums bzw. der Abteilung: Die Übersicht zeigt alle Upgrades des Raums gegliedert nach Bereichen, je Bereich mit Kopfzeile, Statuszeilen (z. B. Füllstand, Takt, Kapazität, Belegung) und Pfeil zum Bereichsfenster (Kurzbeschreibung, Statuszeilen, Upgrades, Schichtplan bzw. Stationskarte), dazu die passenden Boosts. Kein Upgrade ist ohne Ort; zusammen sind es 54 Upgrade-Spuren mit 16 126 Stufen (Spuren je Raum mehrfach gezählt), dazu Stationen, Personal, Botenstufen, Röhrenabschnitte, Briefregal, Abteilungen und Amtsstufen.

**Räume und ihre Bereiche**
| Raum | Bereiche |
|---|---|
| Du (Spielfigur) | Du |
| Publikumshalle | Eingang (Gebäude, Einwohner), Wartebereich Annahme, Wartebereich Abholung, Wartemarkenautomaten, Archiv, Schulungsbrett, Botenpausenraum, Empfang, Ausgabeschalter, Ablagen von Empfang und Ausgabe, Büro der Teamleitung Annahme bzw. Abholung, Rohrpost-Platz |
| Beschwerdebüro | Beschwerdetresen, Beschwerdebriefkasten, Security |
| Schredderraum | Aktenschredder |
| Technikraum | Rohrpost-Zentrale, Serverschrank, Klimagerät |
| Kantine | Kaffeemaschine, Kränzchentisch, Essensausgabe, Kaffeedienst, Betriebsrat |
| Dein Büro | (Raum-Übersicht mit Boost Überstunden; Schreibtisch mit Telefon, Geschenken und Briefen) |
| Sanitär | Toiletten |
| Telefonzentrale | Telefonanlage, Krankenliste |
| Poststelle | Briefregal, Postkasten, Poststelle, Rohrpost-Platz |
| Prüfdienst | Prüfdienst-Station, Rohrpost-Platz |
| Jede Abteilung | Namensleiste (Verwaltung, Amtsstufe als erster Eintrag, Raumtempo, Ablagen, Eröffnen), Büro der Teamleitung (Einstellen, Boni, Rundgang), jede Station (Tische/Maschinen, Personal, Raumtempo), Ablagen jeder Station (Ablehnungsstapel, Ablagen), Rohrpost-Platz (Station und Röhrenabschnitte) |

**Hauptpunkt „Upgrades“** (untere Navigation): Kopf mit gekauften Stufen, Zahl der Upgrade-Linien und jetzt kaufbaren Einträgen, darunter ein Segmentschalter mit fünf Ansichten (Ansicht und aufgeklappte Gruppen bleiben erhalten):
- *Räume*: aufklappbare Gruppen je Raum, darin je Bereich eine Kopfzeile mit „Auf der Karte zeigen“ (Fenster schließt, Kamera fährt hin, Bereich pulsiert) und „Bereich öffnen“.
- *Themen*: nach Wirkung gruppiert (Du selbst, Bürger und Warten, Arbeitstempo, Personal, Transport und Rohrpost, Pausen und Wohlbefinden, Beschwerden, Post, Qualität und IT, Gebäude und Ausbau), jeder Eintrag mit Ort.
- *Kaufbar*: alles, was gerade bezahlbar ist, das Günstigste zuerst (höchstens 40, Hinweis auf weitere).
- *Empfohlen*: die Vorschläge der Statistik, die die aktuellen Engpässe am meisten entlasten.
- *Ausbau*: die großen Schritte im Vergleich – nächste Abteilung und alle noch offenen Amtsstufen –, sortiert nach Amortisation (Preis ÷ möglicher Mehrertrag pro Sekunde). Der Kaufmengen-Schalter gilt auch hier (für Amtsstufen; die Eröffnung ist ein Einzelschritt). Ist alles erreicht, erscheint ein zweizeiliger Leerzustand.

**Kaufen:** Jede Karte zeigt Symbol, Titel, Beschreibung, Stufe (Plakette und Fortschrittsbalken), aktuelle und nächste Wirkung und den Kaufknopf mit Preis bzw. Sperrgrund (Höchststufe, Raum geschlossen, mehr Tische erst mit weiteren Abteilungen, Voraussetzung, Ansehen – zählt das höchste je erreichte –, Geld, Personal braucht Tische, neue Abteilungen erst Einarbeitung). Die Kaufmenge ×1, ×10 oder Max (alle bezahlbaren Stufen) gilt für alle Karten; mehrere Stufen kosten die Summe der Einzelpreise. Preise wachsen je Spur geometrisch (meist ×1,04 bis ×1,2 je Stufe; wenige große Schritte wie Toilettenkabinen ×2,2). Die Listenpreise unten gelten ab Stufe 11; die ersten 10 Stufen haben den Einstiegsrabatt (Stufe 1 kostet 25 %, linear steigend bis 100 %).

**Upgrade-Spuren** (Wert ohne Upgrade → mit Stufe 1 → bei Höchststufe; „je Abteilung“/„je Raum“ einzeln pro Raum zu kaufen, Preis mal Kostenfaktor der Abteilung):

| Raum | Bereich | Upgrade | Stufen | Wert: ohne → Stufe 1 → Maximum | Preis · je Stufe | Voraussetzung |
|---|---|---|---|---|---|---|
| Du | Du | Größere Aktentasche | 100 | 6 → 7 → 106 | 150 · ×1,15 | – |
| Du | Du | Arbeitseifer | 200 | 0 % → +2,5 % → +500 % | 200 · ×1,08 | – |
| Du | Du | Bequeme Turnschuhe | 100 | 0 % → +0,5 % → +50 % | 300 · ×1,12 | – |
| je Raum (Halle, Poststelle, Prüfdienst, Abteilungen) | Raumschild | Raumtempo | 100 | ×1 → ×1,06 → ×65,2 (Meilenstein ×1,25 alle 10) | 150 · ×1,35 | – |
| je Raum | Raumschild | Ablagen | 19 | 6 → 7 → 25 Akten je Fach | 60 · ×1,3 | – |
| je Leitungsbereich (Annahme, Abholung, Poststelle, Prüfdienst, Abteilungen) | Büro der Teamleitung | Teamleitung | 1 | aus → an | 400 (Personalfaktor) | – |
| je Leitungsbereich | Büro der Teamleitung | Kurze Pausen | 150 | ×1 → ×0,75 (sofort) → ×0,746 → ×0,354 Pausendauer | 60 · ×1,04 (Personalfaktor) | Teamleitung |
| je Leitungsbereich | Büro der Teamleitung | Rückkehrgespräche | 150 | ×1 → ×0,75 (sofort) → ×0,746 → ×0,354 Krankheitsdauer | 60 · ×1,04 (Personalfaktor) | Teamleitung |
| je Leitungsbereich | Büro der Teamleitung | Strenger Blick | 150 | ×1 → ×0,7 (sofort) → ×0,697 → ×0,331 Einnicken | 80 · ×1,04 (Personalfaktor) | Teamleitung |
| je Abteilung | Büro der Teamleitung | Schlichtung | 150 | 0 % → 25 % (sofort) → 25,5 % → 100 % Streit verhindert | 50 · ×1,04 (Personalfaktor) | Teamleitung |
| je Leitungsbereich | Büro der Teamleitung | Rundgang-Tempo | 150 | ×1 → ×3,0 (sofort) → ×3,01 → ×4,5 | 80 · ×1,04 (Personalfaktor) | Teamleitung |
| je Leitungsbereich | Büro der Teamleitung | Rundgang-Routine | 150 | 180 s (sofort) → 179,1 s → 84,9 s Abklingzeit | 60 · ×1,04 (Personalfaktor) | Teamleitung |
| Publikumshalle | Wartebereich Annahme | Annahme: Sitzplatz statt Stehplatz | 55 | 15 → 16 → 70 Sitzplätze | 500 · ×1,1 | – |
| Publikumshalle | Wartebereich Abholung | Abholung: Sitzplatz statt Stehplatz | 55 | 15 → 16 → 70 Sitzplätze | 500 · ×1,1 | – |
| Publikumshalle | Wartemarkenautomaten | Automat 1: Druckgeschwindigkeit | 100 | 0,15/s → 0,159/s → 1/s | 300 · ×1,06 | – |
| Publikumshalle | Wartemarkenautomaten | Zweiter Wartemarkenautomat | 1 | aus → an | 100.000 | Automat 1 auf Stufe 100 |
| Publikumshalle | Wartemarkenautomaten | Automat 2: Druckgeschwindigkeit | 100 | 0,15/s → 0,159/s → 1/s | 20.000 · ×1,06 | Zweiter Automat |
| Publikumshalle | Wartemarkenautomaten | Dritter Wartemarkenautomat | 1 | aus → an | 20.000.000 | Automat 2 auf Stufe 100 |
| Publikumshalle | Wartemarkenautomaten | Automat 3: Druckgeschwindigkeit | 100 | 0,15/s → 0,159/s → 1/s | 4.000.000 · ×1,06 | Dritter Automat |
| Beschwerdebüro | Beschwerdetresen | Praktikant am Tresen | 3 | 0 → 1 → 3 | 600 · ×2,5 | – |
| Beschwerdebüro | Beschwerdetresen | Standhafte Praktikanten | 6 | 2 → 3 → 8 Beschwerden | 1.500 · ×1,8 | 1 Praktikant |
| Beschwerdebüro | Beschwerdetresen | Praktikanten-Turnschuhe | 100 | 0 % → +2 % → +200 % | 400 · ×1,07 | 1 Praktikant |
| Beschwerdebüro | Beschwerdebriefkasten | Größerer Beschwerdebriefkasten | 6 | 6 → 10 → 30 | 900 · ×2 | – |
| Beschwerdebüro | Beschwerdebriefkasten | Briefkasten leeren | 6 | aus → 1 → 6 je Gang | 2.500 · ×1,9 | 2 Praktikanten |
| Beschwerdebüro | Security | Security | 1 | aus → an → an | 3.000 · ×1 | – |
| Beschwerdebüro | Security | Security-Schulung | 100 | 10 % → 10,7 % → 80 % | 800 · ×1,06 | Security |
| Schredderraum | Aktenschredder | Schärfere Schneidwerke | 100 | 0 % → −1,5 % → −77,9 % | 1.000 · ×1,1 | – |
| Publikumshalle | Botenpausenraum | Aktenwagen | 40 | 2 → 3 → 42 | 1.200 · ×1,18 | Ansehen 15 |
| Publikumshalle | Botenpausenraum | Botenschuhe | 200 | 0 % → +1 % → +200 % | 900 · ×1,07 | – |
| Technikraum | Rohrpost-Zentrale | Rohrpost | 1 | aus → an → an | 250.000 · ×1 | Ansehen 250 |
| Technikraum | Rohrpost-Zentrale | Röhrenkapazität | 60 | 2 → 3 → 62 | 120.000 · ×1,15 | Rohrpost |
| Technikraum | Rohrpost-Zentrale | Stärkeres Gebläse | 200 | 0 % → +1 % → +200 % | 80.000 · ×1,06 | Rohrpost |
| Technikraum | Rohrpost-Zentrale | Große Kapseln | 1 | aus → an → an | 600.000 · ×1 | Ansehen 400, Rohrpost |
| je Raum (Halle, Poststelle, Prüfdienst, Abteilungen) | Rohrpost-Platz | Rohrpost-Station | 1 | aus → an → an | 20.000 · ×1 | Rohrpost |
| Technikraum | Serverschrank | IT-Wartung | 100 | 0 % → −0,6 % → −60 % | 2.000 · ×1,1 | Ansehen 20 |
| Technikraum | Serverschrank | KI-Fallklassifizierung | 100 | 0 % → −0,7 % → −50,5 % | 20.000.000 · ×1,1 | Ansehen 1.000 |
| Publikumshalle | Schulungsbrett | Qualitätsschulung | 150 | 0 % → −1 % → −77,9 % | 3.000 · ×1,08 | Ansehen 25 |
| Technikraum | Klimagerät | Klimaanlage | 100 | 0 % → +1 % → +100 % | 900 · ×1,1 | Ansehen 12 |
| Kantine | Betriebsrat | Schlichtung | 150 | aus → 120 s → 12,6 s | 1.500 · ×1,08 | Ansehen 18 |
| Kantine | Kaffeemaschine | Kaffeequalität | 300 | 0 % → +1 % → +300 % | 500 · ×1,045 | Ansehen 5 |
| Kantine | Kaffeemaschine | Schnellere Kaffeemaschine | 150 | 0 % → −1 % → −77,9 % | 700 · ×1,08 | Ansehen 8 |
| Kantine | Kaffeemaschine | Espresso-Modul | 200 | +50 % → +50,5 % → +150 % | 900 · ×1,06 | Ansehen 8 |
| Kantine | Kränzchentisch | Aufgeräumte Küche | 200 | 0 % → −0,45 % → −90 % | 1.200 · ×1,06 | Ansehen 15 |
| Kantine | Kaffeedienst | Flinke Kaffee-Praktikanten | 200 | 0 % → +1 % → +200 % | 700 · ×1,07 | – |
| Kantine | Essensausgabe | Besseres Kantinenessen | 200 | ×1,2 → ×1,21 → ×3,2 Wachzeit nach dem Essen | 1.400 · ×1,06 | Ansehen 12 |
| Kantine | Essensausgabe | Schnellere Essensausgabe | 150 | 25 s → 24,75 s → 5,5 s | 1.100 · ×1,08 | – |
| Sanitär | Toiletten | Weitere Toilettenkabine | 8 | 4 → 5 → 12 | 1.500 · ×2,2 | – |
| Sanitär | Toiletten | Schnellere Spülung | 150 | 150 s → 148,5 s → 33,2 s | 1.000 · ×1,08 | – |
| Sanitär | Toiletten | Toilettenhygiene | 100 | 0 % → +1 % → +100 % | 2.000 · ×1,1 | Ansehen 20 |
| Sanitär | Toiletten | Weckdienst | 150 | aus → 45 s → 2,22 s | 1.500 · ×1,08 | Ansehen 20 |
| Publikumshalle | Wachplan | Wachschulung | 150 | 35 % → 35,3 % → 80 % | 2.000 · ×1,08 | – |
| Telefonzentrale | Telefonanlage | Telefonschulung | 100 | 0 % → −1 % → −63,4 % | 1.500 · ×1,1 | – |
| Poststelle | Postkasten | Amtsblatt-Abo | 100 | 0 → 1 → 100 | 1.500 · ×1,1 | Ansehen 15 |
| Poststelle | Postkasten | Häufigere Zustellung | 150 | 45 s → 44,5 s → 9,97 s | 1.200 · ×1,08 | – |
| Poststelle | Poststelle | Einschreibegebühr | 200 | 50 % → 50,5 % → 150 % | 2.500 · ×1,06 | Ansehen 25 |

**Weitere Upgrade-Arten**
| Art | Bereich | Umfang | Preis |
|---|---|---|---|
| Tisch bzw. Maschine | Station | bis 2/3/4/5/6 je Gebäudestufe | Grundpreis × Kostenfaktor × 2,2 je Tisch |
| Personal einstellen | Station | bis Tischzahl, in neuen Abteilungen erst nach 5 Akten Einarbeitung | Grundpreis × Personalfaktor × 2 je Kraft |
| Boten (auch mit der Aufgabe Ablehnung), Kaffee-Praktikanten, Telefonist | Botenpausenraum bzw. schwarzes Brett | 30/8/1 | siehe „Personal“ |
| Botenstufe | Botenpausenraum (je Bote) | 0–30, +1 Akte je Gang | 900 × 1,25 je Stufe |
| Röhrenabschnitt | Rohrpost-Platz der Abteilung | 0–100, +1 Kapsel, +2 % Tempo | 30 000 × 1,08 je Stufe |
| Ablagen | Station | 0–50, +2 Plätze in Eingangsfach (nicht beim Empfang) und Ausgangsfach | Tischpreis × Kostenfaktor × 0,6 × 1,22 je Stufe |
| Ablehnungsstapel | Station mit Ablehnungsstapel (Empfang, Ausgabe, Sachbearbeitung außer Zoll) | 0–10, 12 → +2 je Stufe → 32 Plätze | Tischpreis × Kostenfaktor × 0,5 × 1,22 je Stufe |
| Briefregal | Briefregal | 0–300, +1 Platz (Basis 12) | 600 × 1,04 je Stufe |
| Abteilung eröffnen | Namensleiste der gesperrten Abteilung | in fester Reihenfolge, hebt die Gebäudestufe automatisch | Eröffnungspreis, Ansehen |
| Amtsstufe | Namensleiste der Abteilung | Stufe 1–250, Gebühren +2 % je Stufe, alle 25 Stufen ×1,5 bis ×3, eigene Bearbeitungszeit +1 % je Stufe | erste 24 Stufen zusammen = Eröffnung der nächsten Abteilung, ×1,07 je Stufe; Ansehen je Meilenstein-Block |

## Wirtschaft und Fortschritt
- Ziel-Belohnungen zählen nicht in „Einnahmen/Min.“ und nicht in die Gesamteinnahmen. Offline-Ertrag und seine Werbe-Verdopplung zählen in die Gesamteinnahmen, aber nicht in „Einnahmen/Min.“ (Durchschnitt der letzten 10 Minuten, alle 30 s neu berechnet).
- Gebühr je Fall × Amtsstufen-Faktor (siehe „Amtsstufen“) × Ansehensfaktor (1 + √Ansehen/20); komplexe Fälle ×2, dringende pünktlich ×1,5 (+0,3 Ansehen), verspätet −0,3; fehlerhafte ×0,4 (−0,5 Ansehen), korrekte +0,1.
- Ansehen erhöht den Bürgerandrang (1 + √Ansehen/8, höchstens ×8), dazu der Bewertungsschnitt (×0,85 bei 1 Stern bis ×1,25 bei 5 Sternen).
- **Gebäudestufen**: Service-Schalter → Bürgeramt → Kreisverwaltung → Dienstleistungszentrum → Stadtverwaltung (mehr Tische je Station 2/3/4/5/6, Lobbyplätze 16/22/28/34/40). Nicht kaufbar: Die Stufe steigt automatisch mit der Zahl eröffneter Abteilungen (1 → Service-Schalter, 2–3 → Bürgeramt, 4–5 → Kreisverwaltung, 6–7 → Dienstleistungszentrum, 8 → Stadtverwaltung; `GameConfig.stage_for_departments`). Ältere Spielstände behalten eine früher gekaufte höhere Stufe. Der Eingang der Halle zeigt Gebäude, eröffnete Abteilungen und Einwohner.
- **Ziele**: 21 aufeinander aufbauende Ziele mit Belohnung, letztes Ziel 20 000 Fälle. Die ersten führen über Handarbeit zur Automatisierung: 3 Fälle → Raumtempo ausbauen → 25 Fälle → erste Einstellung (250) → Ansehen 10 → erster Bote (500). Statt Gebäudeausbau-Zielen gibt es Ansehens-Ziele (10, 60, 250, 1 000, 3 000), jeweils knapp unter der Schwelle der nächsten Abteilung.
- **Ereignisse**: siehe Abschnitt „Ereignisse“.
- **Offline-Ertrag**: 70 % des automatisierten Durchsatzes, max. 4 h, ab 60 s Abwesenheit; im Rückkehr-Dialog per Werbung verdoppelbar.
- Engpass-Anzeige je Abteilung (Nachfrage, Transport oder Station) mit Hervorhebung in der Welt.

## Oberfläche
- Kopfzeile mit Geld, Ansehen, Einnahmen/Min. (alle 30 s neu berechnet, rückwirkend über die letzten 10 Minuten; zu Spielbeginn über die bisher vorhandene Zeit) und Einstellungen; Zielkarte mit Abholen-Button (ist das Ziel erfüllt, steht unter dem Fortschritt die Belohnung inkl. Ansehen und Dienstsiegel; alternativ als Brief am eigenen Schreibtisch abholbar); Ereignis-Banner.
- **Aufgaben-Panel** (einklappbar über Titel oder Pfeil rechts oben im Panel; eingeklappt verschwindet das Panel bis auf einen kleinen Ausklapp-Knopf oben links): je Abteilung wartende Bürger und Auslastung in %; Tippen fokussiert die Kamera auf den Raum und hebt ihn hervor, Pfeil öffnet die Abteilungsverwaltung.
- Untere Navigation: Upgrades, Statistik, Ziele. Alle übrigen Fenster öffnen sich über die Karte (Bereiche, schwarze Bretter, Namensleisten), Boosts über den Boost-Knopf, Einstellungen über das Zahnrad.
- **Statistik-Seite** (Engpässe erkennen und gezielt ausbauen; gemessen im gleitenden 60-s-Fenster seit App-Start, nicht gespeichert):
  - **Was ausbauen?** (hervorgehobene Karte ganz oben): die bis zu 4 vollsten Bereiche mit Auslastung ≥ 85 % (Stationen, Aktentransport, Beschwerden, Ablehnungen, Telefonzentrale, Sitz- und Wartebereich, Wartemarkenautomat), absteigend nach Auslastung, je mit den zwei wirksamsten Ausbauten und ihrem Gewinn pro Minute; Pfeil öffnet direkt den Bereich mit dem besten Ausbau (sonst den der Station bzw. die Upgrade-Übersicht). Ohne ausgelasteten Bereich ein Hinweis.
  - **Statistik** (Gesamtwerte, gespeichert): erledigte Fälle, Trefferquote, verlorene Bürger, aufgeweckte Beamte, Personal, Gesamteinnahmen, Spielzeit und Einwohner.
  - Gesamtes Amt (Einnahmen, ankommende Bürger, erledigte Fälle, Ablehnungen, verlorene Bürger je Minute, erwartete Kapazität), Link zu den Online-Bewertungen mit Durchschnitt, Anzahl und schlechten Bewertungen.
  - Je Abteilung: Amtsstufe mit Gebührenfaktor, Ankünfte gemessen/erwartet, Erledigt, Kapazität des langsamsten Schritts, Wartende, Deckungsbalken, **Kapazität je Schritt** (jeder Arbeitsschritt anteilig für diese Abteilung plus Aktentransport, der Engpass farbig hervorgehoben) und Engpass-Text.
  - Je Arbeitsschritt: erledigte Akten/Min. (gemessen), Kapazität, Bedarf, Auslastungsbalken (grün < 85 %, gelb, rot > 100 %), Ø Sekunden je Akte und Akten/Min. je Beamtem, Eingangs-/Ausgangsfach, arbeitende Beamte, Engpass-Markierung und **Ausbau-Wirkung** (zusätzliche Akten/Min. für +1 Beamter bzw. +1 Tisch mit Beamtem bzw. +1 Maschine, +1 Stufe Raumtempo, Teamleitung bzw. +1 Stufe Strenger Blick; „Voll ausgebaut“, wenn nichts mehr geht).
  - **Weitere Bereiche** mit Kapazität, Bedarf, Auslastung und Ausbau-Wirkung: Aktentransport (gemessene Übergaben gesamt und aufgeteilt nach dir, Boten und Rohrpost; Boten und Akten je Gang bzw. Kapseln je Röhre und unterwegs; Rohrpost unbegrenzt), Beschwerden (Zulauf und Geschreddertes gemessen, aufgeteilt nach dir/Personal, Kasten-Füllstand, Praktikanten am Tresen, Security; die Security senkt den Zulauf, Kapazität aus den Leer-Läufen der Praktikanten), Abgelehnte Anträge (Zulauf und Geschreddertes, wartende Ablehnungen, Boten mit der Aufgabe Ablehnung; Ausbau: weiterer Bote, Aktenwagen oder Botenschuhe), Telefonzentrale (Krankmeldungen, angenommene und verpasste Anrufe je Minute, Annahmequote, Telefonisten senken die Krankmeldungen), Sitzbereich und Stehplätze (belegte Plätze; Ausbau +1 Sitzplatz statt Stehplatz), Wartemarkenautomat (Ziehrate aller Automaten, nächste Stufe bzw. nächster Automat).
  - Kapazitäten sind Schätzungen aus den Spielwerten (Boten 7 s je Gang, mit Botenschuhen entsprechend kürzer; Boten mit der Aufgabe Ablehnung: nach Bedarf gewichteter Hin- und Rückweg zum Aktenschredder mit ihrem Lauftempo, mindestens 12 s; Praktikanten Schredder-Takt + 8 s je Gang; Aktentransport-Ausbau: weiterer Bote, Aktenwagen, Botenschuhe, Röhrenkapazität; Bedarf an Krankmeldungen aus dem mittleren Intervall, an Beschwerden aus dem mittleren Intervall plus gemessenem Zulauf durch gehende Bürger, höchstens eine je 45 s).
  - Ausfälle und Streits (gerade krank, Krankmeldungen/Min., durch Rundgänge geweckte Beamte, Nickerchen und Pausen/Min., Streits aktuell und je Minute, geschlichtete Streits, Rundgänge der Teamleitung); je Station alle Beamten mit Zustand, Akten/Min., erledigten Akten, Krankmeldungen und Pausen sowie „Beamte“ (Detailansicht).
- Räume und Bereiche: siehe „Gebäudeplan“ und „Upgrades und Bereiche“.
- Einstellungen: Sprache (System/Deutsch/Englisch), Ton und Vibration (Schalter „Soundeffekte“ und „Vibration“, gespeichert in `user://settings.cfg`), Spiel zurücksetzen mit Bestätigung. Unter „Über“ steht die App-Version mit Build-Zeitpunkt in Ortszeit („Version 1.0.0 · Build vom 26.10.2026, 20:51 Uhr“, englisch „built 2026-10-26 20:51“); ohne Export (Editor) nur „Version 1.0.0“.
- Offline-Dialog nach Rückkehr, Autospeichern alle 20 s und beim Pausieren.

## Erfolgserlebnisse (Pop-ups, Sounds, Vibration)
- **Sounds**: Alle Klänge werden beim Start aus eigenen Notenfolgen synthetisiert (keine fremden Audiodateien, damit frei von Rechten Dritter): Klick, Münze, Plopp, Kasse, Glockenspiel, Level-up-Arpeggio, Fanfare, Funkeln, Whoosh, Freischalt-Glissando, Münzregen. Jeder Klang hat eine Mindestpause, damit Dauerfeuer nicht nervt; 8 Stimmen gleichzeitig.
- **Jeder Knopf klickt** leise beim Antippen.
- **Erledigte Anträge** klingeln mit einer Münze; folgen sie dicht aufeinander (≤ 1,6 s), steigt die Tonhöhe stufenweise eine Dur-Pentatonik hinauf und beginnt danach von vorn. Bei 10, 20, 30 … Anträgen am Stück erscheint „Fließband ×n!“ über der Ausgabe. Beantwortete Post zählt mit.
- **Eigene Taten** (Beamte wecken, Streit schlichten, Praktikanten trösten, Beschwerden selbst schreddern, Anrufe annehmen, Krankmeldung abwenden, Radau beruhigen, Post aufheben, Krankheits-Bonus) ploppen mit steigender Tonhöhe und kurzer Vibration; innerhalb von 6 s bilden sie eine Serie mit Jubel über der Spielfigur: „Doppelt!“, „Dreifach!“, „Unaufhaltsam!“, danach „Dienstserie ×n!“ (bei 3, 5, 10, 20 … zusätzlich Funkeln).
- **Käufe** klingeln wie eine Kasse (Tonhöhe steigt bei schnellen Folgekäufen), vibrieren kurz und lassen an der Tipp-Stelle Funken und „Gekauft“ bzw. „Gekauft ×n“ aufsteigen. Bei 3, 5, 10, 20 … Käufen innerhalb von je 4 s erscheint ein Hinweis „Kaufrausch – n Käufe am Stück“.
- **Große Feiern** (zentrierte Karte, die aufploppt, mit Konfetti, Fanfare und langer Vibration; bis zu 3 warten in einer Schlange): neue Abteilung eröffnet, Amtsstufen-Meilenstein (Titel und neuer Gebührenfaktor), Ziel erreicht (Geld, Ansehen, Siegel), Einnahmen-Meilensteine (1 000, 5 000, 10 000, 50 000 … € insgesamt eingenommen) und Antrags-Meilensteine (10, 25, 50, 100, 250 … erledigt). Bereits erreichte Meilensteine werden beim Start nicht erneut gefeiert.
- **Münzregen**: Beim Abholen eines Ziels (8 Münzen), eines Geschenks (5) und des Offline-Ertrags (8, auch verdoppelt) fliegen Münzen im Bogen zum Geld-Zähler; jede Landung klingelt aufsteigend und lässt den Zähler hüpfen.
- **Geld-Zähler** zählt Zuwächse in 0,6 s hoch; Ausgaben springen sofort.
- **Ziel erfüllt**: Glockenspiel, die Zielkarte hüpft, der Abholen-Knopf „atmet“, bis abgeholt wird.
- Kleinere Klänge: Einarbeitung abgeschlossen und gewonnene/gelöschte Bewertung (Glockenspiel), Geschenk liegt bereit (Funkeln), Boost (Whoosh), normale Amtsstufe (Level-up), Tutorial-Schritt geschafft (Glockenspiel).
- Alle Floater der Spielwelt ploppen beim Erscheinen kurz auf (Skalierung 0,45 → 1,25 → 1).
- Ton und Vibration lassen sich getrennt abschalten; die Radau-Vibration folgt ebenfalls dem Vibrations-Schalter.

## Einstellungsbescheid (Intro)
- Beim ersten Start eines neuen Spiels (auch nach „Spiel zurücksetzen“) erscheint vor dem Tutorial ein Vollbild-Intro im Stil eines Behördenschreibens („Einstellungsbescheid · Az. 08/15“, Sie-Form): Nach längerer Arbeitslosigkeit endlich verbeamtet, doch alles bleibt an einem hängen, niemand will arbeiten, die Bürokratie hat die Oberhand – Aufgabe: den Laden zum Laufen bringen und den Staat am Laufen halten.
- Knopf „Dienst antreten“ schließt das Intro, merkt es im Spielstand (`intro_seen`) und speichert sofort. Solange das Intro offen ist, läuft die Simulation nicht.
- Ältere Spielstände ohne den Eintrag zeigen das Intro nicht; wird das Spiel ohne Bestätigen beendet, erscheint es beim nächsten Start erneut.

## Tutorial
- Geführte Tour beim ersten Start (neues Spiel) durch alle Funktionen in 24 Schritten: Willkommen, Laufen, Geld und Ansehen, Leit-Pfeil, erster Bürger, Wartemarken und Geduld, Ziele, Aufgaben-Panel, Upgrades öffnen, die fünf Ansichten, Personal einstellen, Boten einstellen, Station ausbauen, ein Raumschild antippen, Raumschilder öffnen die Upgrades, Arbeitsmodus und Teamleitung, schwarze Bretter, Ausbauwege (Gebäude, neue Abteilung oder Amtsstufe), Beamte aufwecken, Ereignisse, Offline-Ertrag, alle Ziele, Einstellungen, Abschluss mit Strategie-Tipps.
- Tutorial-Karte unten über der Navigation, bei geöffnetem Fenster oben; zeigt Schrittzähler, Titel, Text und Fortschrittsbalken.
- Infoschritte werden mit „Weiter“ bestätigt; Aktionsschritte (Laufen, Bürger abschließen, Ziel abholen, Upgrades öffnen, einstellen, Bote, ausbauen, Bereich auf der Karte öffnen, Ziele und Einstellungen öffnen) schließen sich automatisch ab, sobald die Aktion erfolgt ist. Zählende Schritte messen ab Schrittbeginn.
- Hängenbleiben ausgeschlossen: Aktionsschritte, die im aktuellen Spielstand nicht mehr erfüllbar sind (alle Ziele erledigt, maximale Botenzahl, alle Stationen auf Höchststufe, kein Platz für weiteres Personal), werden automatisch übersprungen. Nach 20 s in einem Aktionsschritt erscheint zusätzlich „Schritt überspringen“.
- Das passende Bedienelement (Navigation, Zielkarte, Zahnrad) blinkt im jeweiligen Schritt.
- „Tutorial beenden“ mit Rückfrage jederzeit möglich; in den Einstellungen lässt sich die Tour wiederholen (Spielstand bleibt erhalten).
- Fortschritt wird im Spielstand gespeichert; ältere Spielstände ohne Tutorial-Fortschritt gelten als abgeschlossen.

## Humor und Optik
- **Beamtenhumor**: Alle Texte (Abteilungen, Upgrades, Bereiche, Ereignisse, Tutorial, Hinweise) nehmen deutsche Behörden liebevoll auf die Schippe: Dienstweg, Stempel, Mittagspause, „nicht zuständig“, Wiedervorlage. Arbeitsweisen heißen „Husch-husch“, „Nach Vorschrift“ und „Dreifach geprüft“.
- **Schwebende Kommentare** beim Abschluss: „Gestempelt!“, „Genehmigt!“, „Aktenzeichen vergeben“ bzw. bei Fehlern „Formfehler!“, „Bitte nachreichen“ (begrenzt, damit nichts überlädt).
- **Amtsweisheit des Tages** (12 Sprüche, wechselt täglich) oben im Ziele-Fenster.
- **Publikumsbereich** mit Amtsschild „Amt für Amtliches“, je einer Wanduhr in Annahme und Abholung, Aktenschrank in der Annahme, kleiner Sprechzeiten-Tafel neben dem Eingang (Di 9:00–9:07 Uhr), Deutschlandflagge im Wind, Nummernautomat, Wartebänke, Pflanzen und einem Aufsteller „Schalter 13: niemand zuständig. Bitte an Schalter 13 wenden.“
- **Figuren** mit Anzug, Krawatte, Brille, Schnurrbart, wechselnden Haar- und Hautfarben, Schatten und Dienstmütze der Spielfigur.
- **Möbel und Maschinen**: Schreibtische mit Monitor, Papierstapel und Schubladen; je Abteilung eigene Maschine (Foto-Kabine, Taschenrechner, Stempel mit Stempelkissen, Schilderdrucker mit Kennzeichen, Gutscheindrucker, Frachtscanner mit Scanlinie).
- **Räume**: farbige Kopfleiste mit kontrastsicherer Schrift, gefliester Boden, Schatten, Stations-Plaketten; Fahrzeuge (Pkw, Lkw) mit Fenstern, Rädern und Schatten.
- **Lesbarkeit**: Schriftgrößen im gesamten UI angehoben (Fließtext 17, Nebentext 16, Beschriftungen 15), dunklerer Nebentext, Beschriftungen in der Spielwelt mit hellem Umriss.

## Lokalisierung
Deutsch und Englisch (Fallback) über `i18n/translations.csv`; keine UI-Strings im Code.

## Mehr Trubel am Anfang
Krankmeldungen, Streits, Kaffeekränzchen und Beschwerden treten früh und häufig auf, damit der Spieler anfangs viel selbst erledigen muss. Personal entschärft das gezielt: Telefonisten → seltener krank, Teamleitungen und Klimagerät → seltener Streit, Kaffee-Praktikanten → seltener Kaffeekränzchen, Security → weniger Beschwerden. Die Beschreibungen an den schwarzen Brettern und Bereichen nennen den jeweiligen Effekt.

## Ansehen sinkt kaum
- Gewinne zählen voll. Jeder Verlust wirkt nur zu 5 %, und insgesamt kann das Ansehen um höchstens 0,05 Punkte pro Minute sinken (also höchstens 3 Punkte pro Stunde, nie unter 0). Im schlimmsten Fall stagniert es.
- Freischaltungen, Upgrade-Voraussetzungen, Amtsstufen und Ansehens-Ziele richten sich nach dem höchsten je erreichten Ansehen. Ein kurzer Einbruch sperrt also nichts wieder.
- Ansehen und Bewertungen erhöhen weiterhin den Bürgerandrang.

## Engpässe durch Ausbau
- **Einweihungs-Euphorie:** Nach jedem Kauf von Raumtempo arbeiten alle Stationen des Raums 45 s lang mit 150 % Tempo. So läuft das Eingangsfach der nächsten Station sofort voll.
- **Gedämpftes Tempo:** Jede Stufe Raumtempo bringt nur +6 % Tempo, damit nicht sofort alles abgearbeitet ist.
- **Meilensteine:** Alle 10 Stufen springt das Tempo zusätzlich um ×1,25.
- **Ablagen ausbauen:** Jeder Raum hat am Raumschild den Eintrag „Ablagen“ (Thema „Gebäude und Ausbau“, 19 Stufen): Eingangsfach (außer Empfang/Rampe) und Ausgangsfach jedes Tisches im Raum fassen 6 Akten, je Stufe +1, höchstens 25. Zusätzliche Tische ändern daran nichts. Die Stationskarte zeigt die Raumtempo-Stufe und wie viele Stufen bis zum nächsten Meilenstein fehlen.
- **Nachfolger-Anzeige:** Die Stationskarte zeigt den Durchsatz der nachfolgenden Stationen. Ist eine langsamer als die eigene Station, erscheint eine Warnung.
- **Land unter:** Ist das Eingangsfach einer Station zu mindestens 75 % voll, gilt sie als überlastet. Sie bekommt eine rote Plakette, ihre Beamten werden 1,5-mal schneller müde und bevorzugt krank. Der Boost-Knopf in der Kopfzeile färbt sich dann gelb.
- **Ausfälle eingerechnet:** Durchsatz, Engpass und Statistik berücksichtigen die erwartete Verfügbarkeit des Personals (Schlaf, Pausen, Krankheit).
- **Einarbeitung:** In einer neu eröffneten Abteilung muss der Spieler erst 5 Akten selbst bearbeiten, bevor dort Personal eingestellt werden kann. Danach gibt es eine Prämie (10 Fallgebühren) und +1 Ansehen. Die Stationskarte zeigt den Fortschritt. Bürgerservice und ältere Spielstände gelten als eingearbeitet.
- **Mit anpacken:** Der Spieler bearbeitet immer nur einen Tisch gleichzeitig.

## Mehrfachanträge
- Bürger bringen gelegentlich bis zu 2 weitere Anträge für andere eröffnete Abteilungen mit (12 % + 6 % je weitere Abteilung, höchstens 45 %; kein Zoll).
- Der Empfang braucht je weiteren Antrag 50 % länger und teilt das Bündel in einzelne Akten auf, die dann parallel durch die Abteilungen laufen. Ist der Ausgang dafür zu voll, wartet der Empfang.
- Die Zahl der Bündel wird gezählt und gespeichert.
- Der Floater „n Anträge auf einmal“ erscheint je Bündelgröße höchstens einmal pro Sekunde; weitere Bündel in dieser Sekunde werden danach gesammelt angezeigt („2 Anträge auf einmal ×7“). Ebenso der Floater „Reicht mir!“ gehender Bürger („Reicht mir! ×5“).

## Poststelle
- Mit der zweiten Abteilung (zweite Gebäudestufe) öffnet die kleine **Poststelle** in der rechten Raumspalte (Briefregal links, Station in der Mitte, Postkasten am Hintereingang rechts), ein zweiter Eingang. Der Briefträger liefert alle 45 s einen Stapel Briefe (3 + 1 je Abteilung). Am **Postkasten**: *Amtsblatt-Abo* (+1 Brief je Stapel und Stufe, 100 Stufen) und *Häufigere Zustellung* (−1 % Zustellabstand je Stufe, 150 Stufen, bis etwa 10 s).
- Briefe landen im **Briefregal** (Lager, Basis 12 Plätze, +1 je Ausbaustufe, 300 Stufen, Preis 600 · 1,04^Stufe). Ist das Regal voll, legt der Briefträger die übrigen Briefe **auf den Boden** neben dem Regal (sichtbarer Haufen mit „n auf dem Boden“, Floater beim Ablegen, höchstens 60). Sie werden erst weiterverarbeitet, wenn der Spieler hingeht und sie aufsammelt: Neben dem Haufen sortiert er je Übergabe-Takt einen Brief ins Regal, sofern dort Platz ist (auch mit vollen Händen). Der Leit-Pfeil zeigt zum Haufen, sobald im Regal Platz ist. Erst wenn auch der Boden voll ist, gehen Briefe ohne Strafe an den Absender zurück. Bodenbriefe und ihre Zahl werden gespeichert; das Ausbau-Panel zeigt sie.
- Briefe haben keine Geduld, belegen keinen Sitzplatz und kosten nie Ansehen. Dafür bringen sie nur 50 % der Gebühr (*Einschreibegebühr*: +0,5 Prozentpunkte je Stufe, 200 Stufen, bis 150 %).
- Die Poststelle ist eine eigene Station (Tische, Personal; Raumtempo, Ablagen und Teamleitung am Raumschild). Sie überspringt den Empfang und schickt Briefe direkt in die Sachbearbeitung. Dort haben Bürgerakten Vorrang, und das Personal der Poststelle füllt fremde Eingangsfächer nur bis zur Hälfte; die Spielfigur am Posttisch arbeitet immer, auch wenn das Eingangsfach des Amts schon halb voll ist.
- An der Poststellen-Station: *Einschreibegebühr*; dazu Tische und Personal wie bei jeder Station. Alte Spielstände werden umgerechnet (Briefregal ×8, Post-Abo ×2, Einschreiben ×20 Stufen).
- **Fehlende Unterlagen:** Ab 20 Fällen fehlt bei 5 % der Akten in der Sachbearbeitung ein Formular. Es wird mit der nächsten Post als zusätzlicher Brief nachgereicht.
- Gesperrt zeigt die Raum-Übersicht der Poststelle, ab wie vielen Abteilungen sie öffnet.

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
| Rollschuhe | Spieler ×1,5, Boten (alle Aufgaben) ×2 | 180 s | 2 |
| Beschwerde-Amnestie | leert den Beschwerde-Briefkasten, keine neuen Beschwerden | 300 s | 2 |
| Wochenendschicht | schließt alle laufenden Vorgänge sofort ab | sofort | 3 |
| Gebührenerhöhung | ×2 Gebühren | 120 s | 4 |
| Haushaltsmittel | 5 Minuten Einkommen (mindestens 60 pro Minute) | sofort | 5 |

- Erreichbar über den Boost-Knopf in der Kopfzeile (mit Siegelzähler), in den Raum-Übersichten der passenden Räume (Tipp auf die Raum-Kopfleiste) und im Bereich „Du“ (Tipp auf die Spielfigur).
- **Werbe-Platzhalter:** Jede künftige Werbefläche zeigt jetzt eine 3-Sekunden-Fake-Werbung mit Behörden-Slogan, Countdown und Fortschrittsbalken. Danach gibt es die Belohnung. Werbeflächen: Boosts, Ziel-Belohnung ×2, Offline-Ertrag ×2 und „Gesundschreibung“ für einen kranken Beamten (alle 120 s).
- Siegel, laufende Boosts, Abklingzeiten, gesehene Werbungen und genutzte Boosts werden gespeichert und beim Laden geprüft.

## Neue Ereignisse
- **Bürgermeister zu Besuch** (ab 30 Fällen): ×2 Gebühren.
- **Lob in der Zeitung** (ab 60 Fällen): ×1,2 Gebühren.

## Feedback-Server (Entwicklungswerkzeug, nicht Teil der App)
- Unterordner `feedback-server/`: Weboberfläche und API, um von unterwegs Feedback zu senden. Claude Code (`claude -p`) setzt es im Projekt um, danach baut der Server per Godot die Debug-APK und bietet sie zum Download an.
- Jedes Feedback analysiert zuerst ein Router-Agent (Sonnet, Effort low) auf Komplexität und wählt Modell (Haiku/Sonnet/Opus) und Effort; anschließend setzt ein neuer Agent mit dieser Wahl das Feedback um. Wahl und Begründung stehen am Auftrag; scheitert die Analyse, gilt Opus/high.
- Anmeldung per Passwort (aktuell `123`, signiertes Session-Cookie oder `Authorization: Bearer`), Sperre nach 5 Fehlversuchen.
- Status-Endpunkt `GET /api/status` (Zustand, laufender Auftrag, Warteschlange, neueste APK) und Auto-Discovery wie beim Commander: `GET /status` antwortet ohne Anmeldung mit 204, `python3 -m feedback_server.discovery` scannt das /24-Netz.
- Warteschlange mit Status (wartet, analysiert, KI arbeitet, baut APK, fertig, fehlgeschlagen, abgebrochen), Live-Protokoll, Zusammenfassung von Claude, Abbrechen, „Nur APK bauen“, „Im letzten Gespräch fortsetzen“.
- Die letzten 10 APKs bleiben zum Download erhalten; Entwurf des Feedback-Textes bleibt im Browser gespeichert.
- Oberfläche Deutsch mit Englisch als Fallback (`feedback_server/i18n/*.json`), hell/dunkel nach Systemeinstellung.
- Einrichtung, Fernzugriff (WireGuard/Tailscale) und API in `feedback-server/README.md`.
- Android-App „Feedback Commander“ (`feedback-server/android/`, minimaler Klon des Commanders, eigenständig):
  - Server verbinden: zuletzt genutzte Adressen als Chips (max. 8), neue Adresse, Port Standard 8787 oder eigener, „Automatisch suchen“ durchsucht das WLAN-/24-Netz nach `/status` (204).
  - Anmelden mit dem Server-Passwort; es wird mit dem Android-Keystore (AES-GCM) verschlüsselt gespeichert. Abgelehnte Passwörter führen zurück zur Anmeldung. „Verbindung wechseln“ und „Abmelden“.
  - Startseite: Serverstatus (bereit/arbeitet, laufender Auftrag, Warteschlange, Analyse-Modell), neueste APK laden und direkt installieren (Fortschritt in MB, Cache der letzten 3 APKs, bereits geladene werden sofort installiert), Feedback-Text (max. 20.000 Zeichen) mit Schalter „Sitzung fortsetzen“, „Senden“, „Nur APK bauen“, Auftragsliste mit Status, gewähltem Modell und Effort, APK je Auftrag, Abbrechen mit Rückfrage. Aktualisierung alle 3 Sekunden, solange die App sichtbar ist.
  - Auftragsdetail: Status, Feedback, Dauer, Fehler, Modellwahl mit Begründung, Ergebnis von Claude, Protokoll; laufende Aufträge abbrechen.
  - Deutsch mit Englisch als Fallback, hell/dunkel nach System, WaffleHQ-Design.

## Projektspezifische Ausnahmen von globalen Regeln
- **Godot 4.7.2 statt Jetpack Compose**: Die WaffleHQ-Styling-Regeln werden sinngemäß über `AppTheme` (Rollen, Radien, Abstände, Geist-Schrift, Material Icons) umgesetzt; Details in `styling-exceptions.md`.
- **Übersetzungen als CSV** (`i18n/translations.csv`, Godot-Standard) statt `strings.xml`.
- **Kein Gradle**: Export mit vorgefertigten Godot-Android-Templates (`gradle_build` aus).
- **Testabdeckung**: Für GDScript gibt es kein Coverage-Werkzeug; Abdeckung wird über vollständige Unit-Tests aller Kernklassen (GUT 9.7.1) sichergestellt.
- **Monetarisierung nur als Attrappe**: Werbung ist ein 3-Sekunden-Platzhalter, der Siegel-Shop ein Testkauf ohne Bezahlung. Es ist kein Werbe- oder Bezahl-SDK eingebunden.
- **Keine Datenbank**: Spielstand als JSON in `user://savegame.json` (Version 6). Version-2-Stände werden beim Laden umgerechnet (Upgrade-Stufen auf die feineren Spuren skaliert, frühere Forschung in Spuren überführt, Briefregal und Schulungen hochgerechnet, Rohrpost-Anschlüsse in Stationen je Raum), danach wie Version 3 auf das Beschwerdebüro mit Tresen umgestellt (Tisch-Praktikant und Helfer → Praktikanten am Tresen, Resilienz → Standhaftigkeit, Praktikanten-Schulung → Briefkasten leeren, Briefkasten-Stufen neu skaliert, Wachleute samt Schulung → Security mit gleichwertiger Abfangchance); Version-4-Stände verlieren beim Laden alle früheren Stations- und Mitarbeiter-Upgrades ohne Erstattung (Stationsstufen, Fachkräfte – ihre angefangenen Akten wandern zurück ins Eingangsfach –, Ablagenstufen je Station, Teamleitungen alter Art, Schulungen, Dokumentenscanner, Digitale Akte, Digitale Signatur, Elektrischer Brieföffner, Büroausstattung); Rohrpost, Tische, Personal, Ablehnungsstapel und Briefregal bleiben. Version-5-Stände verwandeln gespeicherte Ablehnungs-Boten in Boten mit der Aufgabe Ablehnung (Zuständigkeit und Ladung bleiben, Botenstufe 0; über die Obergrenze von 30 Boten hinaus entfallen sie samt Ladung), Sammelwagen, Flinke Ablehnungs-Boten und alle Abteilungsschredder verschwinden ohne Erstattung. Noch ältere Stände starten neu.
- **Feedback-Server in Python**: Werkzeug ohne Fremdpakete (nur Standardbibliothek), Texte als JSON statt `strings.xml`, Tests mit `unittest`. Godot ignoriert den Ordner über `.gdignore`.
- **Feedback-Commander-App**: einziger Kotlin/Compose-Teil des Projekts mit eigenem Gradle-Build in `feedback-server/android/`; hält die WaffleHQ-Styling-Regeln direkt ein (Ausnahmen in `feedback-server/android/styling-exceptions.md`).
