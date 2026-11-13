# Mockups

**Veranschaulichung, kein Gestaltungsbeschluss.** Die Dateien hier zeigen, wie sich die Anforderungen
aus `docs/PRD.md` auf einem Bildschirm anfühlen könnten. Sie entscheiden nichts: Gestaltungsbeschlüsse
entstehen über `/design:design-runde` und stehen in `DESIGN.md` — dort sind alle Kategorien offen.
Die Mockups sind HTML, weil auf dem Entwicklungsrechner kein Swift gebaut werden kann; sie sind nicht
der Code der App.

| Datei | Zeigt | Anforderungen |
|---|---|---|
| `index.html` | Einstieg, verlinkt die drei Bildschirme | — |
| `tagesansicht.html` | iPad im Unterricht: ein Tag, Material mit einem Tipp | FR-4, FR-5, FR-2.2, FR-3.3, FR-8, FR-9 |
| `vorbereiten.html` | Mac: Material den Unterrichtsstunden der Woche zuordnen | FR-3, FR-3.1 bis FR-3.4, FR-7, FR-8, FR-9 |
| `einrichten.html` | iPad: Stundenplan anlegen, Import-Abgleich, Ordnerfreigaben | FR-1, FR-1.1, FR-2, FR-7, NFR-4 |
| `smartboard.html` | Zweitbildschirm: Klassenbildschirm im Verlauf der Stunde, Timer, Arbeitsform, Dunkel | FR-6.2, FR-11, FR-11.1 bis FR-11.4 |
| `tafel.html` | iPad: an die Tafel schreiben, Seiten, Hintergründe, letztes Tafelbild | FR-12, FR-12.1 bis FR-12.4 |
| `anzeige.html` | iPad: PDF mit Stiftnotizen, daneben was die Klasse sieht | FR-6, FR-6.1, FR-6.2 |

## Smartboard-Leiste (FR-11.5) — in allen iPad-Mockups gleich

Platzhalter, kein Beschluss: eine Leiste am unteren Rand des iPad-Bildschirms, volle Breite, 76 pt hoch,
über dem Home-Indikator, mit Trennlinie nach oben. Von links nach rechts:

1. **Vorschaubild** 16:9, 120 × 68 pt, zeigt verkleinert genau das, was der Zweitbildschirm zeigt;
   darüber klein „Das sieht die Klasse“.
2. **Umschalter** als segmentierte Auswahl mit vier Feldern, je Symbol und Wort:
   `Klassenbildschirm` · `Material` · `Tafel` · `Dunkel`. `Material` ist ausgegraut, wenn keines offen ist.
3. **Timer:** Knopf „Timer“; läuft einer, steht dort die Restzeit (z. B. `4:12`) mit Anhalten und Beenden.
4. **Arbeitsform:** Menüknopf, zeigt die gewählte (Einzelarbeit, Partnerarbeit, Gruppenarbeit) oder „Arbeitsform“.
5. Ganz rechts der **Verbindungsstatus:** „Apple TV Raum 204“ mit Symbol, oder „Kein Bildschirm verbunden“ –
   dann ist das Vorschaubild schraffiert, der Umschalter bleibt bedienbar, und daneben steht der Knopf
   „So verbinden“ (FR-11.6): ein Popover mit den Schritten zur Bildschirmsynchronisierung im
   Kontrollzentrum und dem Hinweis auf die Kabelverbindung.

## Zweitbildschirm in den Mockups

Der Zweitbildschirm ist ein Rahmen im Format 16:9 (1920 × 1080, skaliert), ohne jedes Bedienelement,
für Lesbarkeit aus sechs Metern: wenige, sehr große Angaben. Der Timer liegt als eigene Schicht in
einer Ecke über Klassenbildschirm, Material und Tafel (FR-11.2), nicht über Dunkel.

Zusätzliche Beispieldaten für Di 2. Stunde 8b Englisch (8:35–9:20): Thema „Unit 4 – Wortschatz“,
Bereitlegen „Buch, Heft, Vokabelheft“, Hausaufgabe „Workbook S. 34, Nr. 2 und 3“, Timer 5:00,
Arbeitsform Partnerarbeit. Voriges Tafelbild der 8b Englisch: Mo 16.11. gab es keine 8b – nimm
Do 12.11., 3. Stunde, zwei Seiten. Raum des Apple TV: „Raum 204“.

Vorschläge, die in den Mockups gezeigt, aber **nicht beschlossen** sind (Q-24, Q-25 im PRD), tragen
außerhalb des Geräterahmens den Vermerk „Vorschlag“.

## Gemeinsamer Rahmen für alle Mockups

- **Aussehen = unveränderter Systemstandard von Apple**, ausdrücklich als Platzhalter: Systemschrift
  (`-apple-system, "SF Pro Text", system-ui, sans-serif`), Systemfarben, Standard-Bausteine (Listen,
  Seitenleiste, Symbolleiste, Popover, Sheet). Keine eigene Palette, keine Marke, kein Logo, keine
  Zierschrift. Hell und Dunkel über `prefers-color-scheme`.
- **Begriffe nur aus dem Glossar des PRD:** Stundenplan, Stundenplan-Eintrag, Unterrichtsstunde,
  Material, Zuordnung, Ablage, Vorbereiten, Tagesansicht, Wochenvariante (A-Woche/B-Woche),
  unterrichtsfreier Tag, Ausfall, Vertretungsstunde, Stundenplan-Quelle.
- **Vier Aussagen dürfen nie gleich aussehen** und nie nur am Farbton hängen: „keine Unterrichtsstunde“,
  „Unterrichtsstunde ohne Material“, „Material nicht verfügbar“, „Ausfall“.
- **Nur erfundene Daten.** Keine Namen von Personen, keine Schule.
- Eine Datei je Bildschirm, in sich geschlossen (kein CDN, keine externen Schriften oder Bilder,
  Symbole als Inline-SVG), Gerät als schlichter Rahmen, der sich in das Browserfenster einpasst.

## Was die Mockups offen gelassen haben

Stellen, an denen beim Bauen mangels Beschluss eine Annahme nötig war — Kandidaten für
`/design:design-runde`, hier nur gesammelt, nicht entschieden:

- **Anrede und Wortlaut:** Die drei Mockups reden verschieden (unpersönlich, „du“, „Sie“). Ebenso
  offen: „Weiterreichen“ gegenüber „Schieben“, „laut Schulmanager“, „Ohne Stunde“.
- **Bedeutung der Akzentfarbe:** Blau steht zugleich für „bedienbar“, „ausgewählt“, „jetzt/heute“ und
  „Ablageziel“ — die Falle „eine Farbe, zwei Bedeutungen“ aus `DESIGN.md`.
- **Zustandsdarstellung:** Form und Symbol für Ausfall, Vertretungsstunde, ohne Material, nicht
  verfügbar, unterrichtsfreier Tag sind je Mockup frei gewählt und nicht einheitlich.
- **Dichte und Überlauf:** Was passiert bei mehr als drei Materialien je Unterrichtsstunde oder langen
  Dateinamen? Werden leere Stunden immer gezeigt oder zusammengefasst?
- **Aufbau Vorbereiten:** Wochenraster mit Detailbereich ist eine von mehreren Möglichkeiten (Liste je
  Tag, Ablage-Browser in der App). Wo „Material ohne Stunde“ steht, ist offen.
- **Aufbau der App insgesamt:** Wie man zwischen Tagesansicht, Vorbereiten und Einrichten wechselt, ist
  nur angedeutet. Darf in der Tagesansicht zugeordnet werden?
- **Status „auf dem Gerät“:** immer zeigen oder nur die Abweichung? Was tut ein Tipp auf Material, das
  noch lädt?
- **Stand der Stundenplan-Quelle:** Ort, und wie ein veralteter Stand aussieht.
- **Q-19** (was bei Bildschirmspiegelung sichtbar sein darf) ist in keinem Mockup berücksichtigt.
- Ort und Form der Smartboard-Leiste (FR-11.5) sind für alle Mockups einheitlich gesetzt, aber frei
  gewählt.

## Gemeinsame Beispieldaten

Woche 47, A-Woche. Heute: **Dienstag, 17.11.2026**. Stand der Stundenplan-Quelle: Schulmanager Online,
heute 7:28 Uhr. Ablage: Ordnerfreigabe „Unterricht“.

| Stunde | Zeit | Dienstag 17.11. | Material (in Reihenfolge) |
|---|---|---|---|
| 1 | 7:45 | 7a Deutsch | Arbeitsblatt 3 – Satzglieder (PDF, auf dem Gerät) |
| 2 | 8:35 | 8b Englisch | Unit 4 – Präsentation (PowerPoint, auf dem Gerät) · Arbeitsblatt Vokabeln (Word, auf dem Gerät) · Lösung Vokabeln (PDF, wird geladen) |
| 3 | 9:40 | keine Unterrichtsstunde | — |
| 4 | 10:30 | 9c Englisch — **Ausfall** (aus der Stundenplan-Quelle) | Unit 2 – Hörverstehen (PowerPoint) → „in die nächste Stunde der 9c“ (Do 19.11., 2. Stunde) |
| 5 | 11:35 | 6c Mathe — **Vertretungsstunde** (aus der Stundenplan-Quelle) | ohne Material |
| 6 | 12:25 | 8a Englisch | Unit 4 – Präsentation (PowerPoint, **nicht verfügbar**: Verweis löst nicht auf → neu verknüpfen) |

Weitere Tage der Woche: Mo 16.11. 1. Std 7a Deutsch, 2. Std 9c Englisch, 5. Std 8a Englisch ·
Mi 18.11. 3. Std 8b Englisch, 4. Std 7a Deutsch · Do 19.11. 2. Std 9c Englisch, 3. Std 8a Englisch ·
Fr 20.11. unterrichtsfreier Tag („Pädagogischer Tag“), darauf liegt noch ein Material „ohne Stunde“:
Lesetext Kapitel 5 (PDF, war 7a Deutsch). B-Woche weicht ab: Mo 1. Std 9c statt 7a.
