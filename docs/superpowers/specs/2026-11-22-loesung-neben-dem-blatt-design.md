# Lösung neben dem Blatt — Design

Stand 2026-11-22. Entwurf von Andreas am 2026-11-22 bestätigt („passt“); Einzelentscheidungen von Andreas delegiert.

## Absicht

Die Klasse sieht am Smartboard ein Arbeitsblatt. Die Lehrkraft will dabei am iPad die Lösung dazu sehen, ohne dass die
Klasse sie sieht – nebeneinander in einer geteilten Anzeige. Die Anzeige (FR-6) öffnet heute genau ein Material, und der
Zweitbildschirm zeigt dieses Material (FR-6.2). Die Lösung hängt also an der Zuordnung des Blatts.

- **Ziele:** (1) eine Lösung an ein Material hängen, mit automatischem Vorschlag aus dem Ordner; (2) in der Anzeige
  neben dem Blatt zeigen; (3) die Lösung erscheint nie auf dem Zweitbildschirm.
- **Nicht-Ziele:** Stiftnotizen auf der Lösung; Lösung für Material, das in einer anderen App öffnet (PowerPoint, Word –
  dort bestimmt die andere App den Bildschirm, RISK-5); mehrere Lösungen je Material; Lösung auf der Tafel.
- **Anti-Ziel:** Die Klasse sieht die Lösung. Weder über den Zweitbildschirm noch über dessen Vorschaubild noch über
  reine Bildschirmspiegelung ohne Hinweis.

## Ansätze

- **Gewählt: Lösung als zweiter Verweis an der Zuordnung, geteilte Anzeige im vorhandenen `ViewerView`.** Die Lösung
  ist eine Eigenschaft der Zuordnung (wie die Stiftnotizen, FR-6.1): Schieben nimmt sie mit, ohne dass Code dafür nötig
  ist, „Für Klasse übernehmen“ kopiert sie mit. Die Anzeige bekommt eine zweite, nur lesende Spalte.
- Verworfen: **Lösung nur über den Dateinamen finden** (keine Daten, „<Name> – Lösung.pdf“ daneben). Das kostet keine
  Datenänderung, aber jede Lehrkraft benennt anders, und ohne Treffer gibt es keinen Weg. Bleibt als Vorschlag erhalten.
- Verworfen: **Zwei Materialien derselben Stunde nebeneinander öffnen** (eines als „nur für mich“ markiert). Allgemeiner,
  aber die Lösung stünde als eigenes Material in Tagesansicht und Vorbereiten, ließe sich versehentlich aufs Smartboard
  bringen und würde beim Schieben vom Blatt getrennt.
- Verworfen: **Zweites Fenster bzw. Split View des Systems** (Lösung in Dateien/Vorschau daneben). Funktioniert ohne
  uns, aber die App im Vordergrund bestimmt den Zweitbildschirm; das Blatt verschwindet dort beim Wechsel.

## Verhalten

### Lösung verknüpfen

- An jeder Material-Kachel (Tagesansicht, Vorbereiten) im Kontextmenü „Lösung hinzufügen …“, nur für PDF und Bild.
  Hat das Material schon eine, stattdessen „Lösung ersetzen …“ und „Lösung entfernen“.
- In der Anzeige: Hat das Material keine Lösung, bietet die Leiste „Lösung hinzufügen“ an (gleicher Ablauf), damit es
  auch im Unterricht ohne Umweg geht.
- **Vorschlag:** Vor der Dateiauswahl sucht die App im Ordner des Blatts eine Datei, deren Name ohne Lösungswort und
  Trennzeichen dem Blatt gleicht (siehe Regel unten). Gibt es genau einen besten Treffer, fragt ein Dialog „<Name> als
  Lösung verwenden?“ mit „Verwenden“ und „Andere Datei wählen …“. Sonst öffnet direkt die Dateiauswahl (`.pdf`,
  `.image`). Die gewählte Datei muss in einem freigegebenen Ordner liegen – sonst derselbe Hinweis wie beim Zuordnen.
- **Namensregel (Kern, testbar):** Lösungswörter `Lösung`, `Lösungen`, `Loesung`, `Loesungen`, `Lsg`, `Solution`,
  `Solutions`, `Key`, ohne Groß-/Kleinschreibung und Akzente, als eigenes Wort am Anfang oder Ende des Dateinamens
  (ohne Endung); Trennzeichen dazwischen ` `, `-`, `–`, `_`, `.`, `(`, `)`. Kandidat, wenn der Rest dem Blattnamen
  (ohne Endung, gleich normalisiert) gleicht, die Endung PDF oder Bild ist und es nicht das Blatt selbst ist. Mehrere
  Kandidaten: PDF vor Bild, dann kürzester Name, dann alphabetisch. Beispiel: „AB Bruchrechnen.pdf“ → „AB Bruchrechnen –
  Lösung.pdf“, „AB Bruchrechnen_Loesung.pdf“, „Lösung AB Bruchrechnen.pdf“.
- Die Kachel zeigt im Fuß „PDF · mit Lösung“ (VoiceOver: „mit Lösung“), damit man vorab sieht, dass eine dran hängt.

### Geteilte Anzeige

- Hat die Zuordnung eine Lösung, zeigt die Anzeige links das Blatt (wie heute, mit Stift) und rechts die Lösung, nur
  lesend (`PDFDisplayView`), jeweils halbe Breite mit Trennlinie. Bei schmaler Breite (iPad hochkant, Split View; also
  `horizontalSizeClass == .compact` oder Breite < 700 pt) übereinander: Blatt oben, Lösung unten.
- Die Lösungsspalte hat eine Kopfzeile: „Lösung“, Seite „2 von 3“ mit eigenen Pfeilen, Schalter „Seiten koppeln“
  (Symbol `link`, an als Vorgabe) und „Ausblenden“. Gekoppelt springt die Lösung beim Blättern im Blatt auf dieselbe
  Seite (bei weniger Seiten auf die letzte). Eigene Pfeile lösen die Kopplung.
- Ein Knopf „Lösung“ (Symbol `sidebar.right`) in der Leiste blendet die Spalte ein und aus. Der Zustand ist flüchtig und
  gilt app-weit für die laufende Sitzung (wer sie einmal ausblendet, hat sie beim nächsten Blatt ebenfalls aus).
- Lösung nicht verfügbar (Datei fehlt, nicht geladen): Die Spalte zeigt „Lösung nicht verfügbar“ mit „Andere Datei
  wählen …“; das Blatt bleibt voll nutzbar.
- Mac: gleich, ohne Stift (die Mac-Anzeige ist heute schon nur lesend).

### Was die Klasse sieht

- Der Zweitbildschirm zeigt unverändert nur das Blatt. Die Lösungsdaten gelangen nie in `SecondScreenState` bzw.
  `MaterialPresentation`; das Vorschaubild (FR-11.5) ist dieselbe Ansicht und zeigt sie damit ebenfalls nicht.
- **Reine Bildschirmspiegelung** (Bildschirm verbunden, aber keine eigene Szene – etwa bei einem Gerät, das nur spiegelt):
  Erkennt die App, dass das Tablet-Bild aufgenommen bzw. gespiegelt wird (`sceneCaptureState == .active`, UIKit ab
  iOS 17) und gleichzeitig kein Zweitbildschirm verbunden ist, blendet sie die Lösung aus und zeigt in der Spalte „Dein
  Bildschirm wird gespiegelt – die Klasse würde die Lösung sehen“ mit „Trotzdem zeigen“. Betrifft Q-19.

### Daten

- `MaterialLinkRecord` bekommt sechs optionale Felder mit Präfix `solution` (Freigabe, Pfad, Name, Dateiart,
  OneDrive-Kennungen), Vorgabe `nil` (iCloud-Regeln ADR-0002), und eine berechnete Eigenschaft `solution:
  MaterialReference?`. Grund für flache Felder statt eines JSON-Blobs: gleiche Form wie der Verweis des Materials, keine
  Kodierung in der Spiegelung, lesbar im Datenordner.
- `MaterialLinkPayload` (Datenordner OneDrive) bekommt `solution: MaterialReference?`; fehlt der Schlüssel (alte Datei),
  ist er `nil`. Alte App-Stände ignorieren den unbekannten Schlüssel.
- Schieben (FR-3.3, FR-7, FR-8) ändert nur den Schlüssel → Lösung wandert mit. „Für Klasse übernehmen“ (FR-3.2) kopiert
  die Lösung mit. „Neu verknüpfen“ ersetzt auch Lösungen am alten Ort. Bereithalten (Prefetch) und Verfügbarkeit
  beziehen Lösungen ein. Führt der Abgleich zwei Zuordnungen derselben Datei zusammen, bleibt eine vorhandene Lösung
  erhalten (die der behaltenen Zuordnung, sonst die der anderen).
- Kostenlos, als Teil der Anzeige (FR-6, FR-13).

## Was beim Bau zu entscheiden bleibt

- Genaue Breitengrenze für übereinander/nebeneinander; ob die Trennlinie verschiebbar ist (Vorgabe: nein, fest 1:1).
- Wortlaut der Texte nach UI-15; Schlüssel englisch in `Localizable.xcstrings`.
- Wie die Spiegelungserkennung auf dem Mac aussieht (Vorgabe: auf dem Mac keine Erkennung, dort gibt es keine Szene für
  externe Bildschirme in diesem Sinn).
