# Frontstage — Projektregeln

Tagesbegleiter für Lehrkräfte (iPad und Mac). Überblick: `README.md`. Es gibt noch keinen Code; der
Stand jeder Ebene steht im Frontmatter des jeweiligen Dokuments.

## Bauen und Testen

- **Swift für Windows ist installiert (6.4.2), aber nur für das Kern-Paket.** `Packages/FrontstageCore`
  (nur `Foundation`) lokal testen mit `.\scripts\swift-test.ps1` (lädt Swift- und Visual-Studio-Umgebung;
  `-Filter <Test>` für einzelne Tests). Die App (SwiftUI, SwiftData, UIKit) lässt sich auf Windows nicht
  bauen: Gebaut und getestet wird sie nur per GitHub Actions auf macOS oder auf einem Mac. Maßgeblich
  bleibt der CI-Lauf auf macOS – Foundation unter Windows weicht in Einzelheiten ab.
- **App-Code lässt sich auf Windows nicht typprüfen, aber Syntaxfehler findet `.\scripts\swift-parse.ps1`**
  (`swiftc -frontend -parse` über `Frontstage` und `FrontstageTests`, `-Paths` für andere Ordner). Vor jedem
  CI-Lauf ausführen.
- **CI kostet Geld, die macOS-Minuten sind begrenzt:** nur bei Tags oder manuell (`workflow_dispatch`),
  nie bei jedem Push. Änderungen sammeln, Diff sorgfältig auf Compilerfehler durchsehen, dann ein Lauf.
  Sparregeln:
  - Höchstens **ein** CI-Lauf je Teilplan, am Ende; kein zweiter Lauf nur zur Bestätigung.
  - Änderungen, die nur `Packages/FrontstageCore` berühren, brauchen keinen CI-Lauf – lokal mit
    `scripts/swift-test.ps1` prüfen; der nächste fällige Lauf bestätigt sie auf macOS mit.
  - Reine Dokument- oder Plan-PRs: kein CI-Lauf.
  - Wenn möglich mehrere Teilpläne gemeinsam in einem Lauf prüfen, statt je einen.
  - Schlägt ein Lauf fehl: erst das hochgeladene `TestResults.xcresult` und das Log lesen, Ursache
    beheben und den Diff prüfen, dann **ein** neuer Lauf – nie „noch mal probieren“.
- Swift/SwiftUI ist für den Entwickler Neuland: nicht offensichtliche Idiome und Framework-Eigenheiten
  kurz mit erklären.
- Regeln der iCloud-Spiegelung (ADR-0002): kein `@Attribute(.unique)`/`#Unique`, alle Eigenschaften
  optional oder mit Vorgabewert, alle Beziehungen optional.
- **Code-Sprache (ADR-0009):** Bezeichner, Dateien, Ordner und Paketnamen englisch; Fachbegriffe exakt
  nach der Spalte „Im Code“ des Glossars im PRD (neuer Begriff: erst Glossarzeile, dann Code).
  Kommentare und `///`-Doku deutsch. Oberflächentexte deutsch in `Localizable.xcstrings`, Schlüssel
  englisch.

## Skills in diesem Projekt

- **Design-Prüfung:** Für Reviews der Oberfläche gilt hier der projektlokale Skill `apple-design`
  (Apple Human Interface Guidelines) — nicht `web-design-guidelines` und nicht `impeccable critique`,
  die auf Web-Oberflächen zielen. Benannte Ausnahme zur globalen Design-Orchestrierung.
- `apple-design` ist nicht im Repo (Inhalt ohne Lizenz, Apple-Texte). Fehlt er:
  `npx skills add dickwu/apple-design-skill --skill apple-design -y`.
- Gestaltungsbeschlüsse trifft kein Skill; sie entstehen über `/design:design-runde` und stehen in
  `DESIGN.md`.

## Datenhygiene

Keine echten Namen von Lehrkräften, Schülern, Klassenlisten oder Dateinamen realer Personen in Code,
Tests, Doku oder Beispielen. Beispiele nutzen neutrale Klassen (`8b`, `9c`) und erfundene Materialnamen.
Zugangsdaten zu Schulmanager oder Microsoft nie ins Repo.

## Dokumenten-Landkarte — wer besitzt welche Entscheidung

Jedes Dokument hat genau eine Zuständigkeit. **Eine Entscheidung im falschen Dokument ist eine
Entscheidung, der später widersprochen wird.** Den Stand jedes Dokuments trägt sein Frontmatter
(`status: draft | clarifying | ready | not-needed`), nicht diese Tabelle.

| Dokument | Datei | Besitzt |
|---|---|---|
| PRD | `docs/PRD.md` | Zweck, Nutzerschaft, Anforderungen, Risiken, offene Fragen. **Das Glossar darin ist bindend für jedes spätere Dokument und für den Code.** |
| ADRs | `docs/adr/NNNN-titel.md`, Ebenenkopf `docs/adr/README.md` | Je Datei eine architekturrelevante Entscheidung im MADR-Format, mit `reversibility: one-way \| two-way` und `area: <bereich>`. |
| Architecture Doc | `docs/ARCHITECTURE.md` | Wie gebaut wird, je Bereich (`## Area: <bereich>`) — beschreibend, mit Verweisen „gemäß ADR-NNNN“. Entscheidet nichts selbst. |
| UI Spec | `DESIGN.md` | Wie sich das Produkt zeigt und verhält: Gestaltungsbeschlüsse `UI-n`. |

`docs/adr/` statt des MADR-Standardpfads `docs/decisions/` ist eine bewusste Wahl: ADR-Werkzeuge
wie adr-tools und log4brains erwarten diesen Pfad.

**Nie einen Begriff einführen, der dem Glossar widerspricht.** Ist das Glossar falsch, wird das
Glossar geändert — nicht in einem tieferen Dokument umgangen.

`docs/research/` hält Prüfnotizen (etwa zu einer inoffiziellen Schnittstelle): Befunde mit Quelle, keine Entscheidungen. Eine Entscheidung daraus gehört in ein Dokument der Landkarte.

`wiki/` und `README.md` sind **abgeleitete Darstellungen**: Sie entscheiden nichts und werden beim
Rückfluss mit aktualisiert.

## Nummern — append-only

- Präfixe: `FR-n` Anforderungen, `NFR-n` nichtfunktionale Anforderungen, `RISK-n` Risiken, `CON-n` Vorgaben
  (im PRD unter `## Constraints`), `Q-n` offene Fragen (eindeutig über alle Dokumente), `ADR-NNNN` Architekturentscheidungen (= Nummer
  der Datei), `UI-n` Gestaltungsbeschlüsse, `AK-n` Abnahmekriterien (im PRD).
- **Überschriftenformat** (Anker und Werkzeuge hängen daran): `### FR-7 — <Titel> [MVP]`,
  `### FR-7.4 — <Titel> [Later]`, `### NFR-2 — <Titel> [MVP]`, `### RISK-3 — <Titel>`,
  `### UI-3 — <Titel>`, `### CON-1 — <Titel>`, in der ADR-Datei `# ADR-0003 — <Titel>`. Offene Fragen sind Zeilen
  `- Q-n: <Frage>` unter `## Open Questions`, keine Überschriften.
- **Nummern werden nie wiederverwendet und nie umnummeriert.** Sie werden aus Code, Tests und
  anderen Dokumenten heraus referenziert. Neues wird angehängt, auch wenn die Reihenfolge dadurch
  unsortiert aussieht — **das ist korrekt, kein Defekt zum Aufräumen.** Gehört das Neue unter einen
  bestehenden Eintrag, bekommt es eine **Unter-Nummer** (`FR-7.4` statt `FR-31`) und liegt damit
  neben seinen Geschwistern, statt die Reihenfolge zu zerreißen. ADRs haben keine Unter-Nummern.
- **Eine geänderte Anforderung oder ein geänderter Gestaltungsbeschluss behält seine Nummer**; die
  Änderung steht als Zeile im Abschnitt `## Changes` des Dokuments
  (`- JJJJ-MM-TT: <Nummer> new|changed|removed — <Grund>`), der überholte Wortlaut bleibt stehen.
  Er ist das, was verhindert, dass dieselbe verworfene Alternative erneut vorgeschlagen wird.
- **Eine ADR wird nicht umgeschrieben, sondern abgelöst:** neue ADR mit `- Supersedes: ADR-NNNN`,
  die alte erhält `status: superseded by ADR-NNNN` — im selben Durchgang. Eine Ergänzung ohne
  Ersatz ist eine neue ADR mit `- Amends: ADR-NNNN`.
- **Eine beantwortete Frage wird durchgestrichen, mit ihrer Antwort daneben** — nie gelöscht:
  `- ~~Q-n~~: <Frage> → answered JJJJ-MM-TT: <Antwort>`. Der Weg zur Antwort ist der Wert.
- Jede Anforderung trägt eine **Lieferstufe**: `[MVP]` oder `[Later]`. Nicht „Reifemarkierung“ —
  *Reife* bezeichnet oft den Zustand eines einzelnen Gegenstands, und zwei Achsen unter einem Wort
  werden im Code ein Feld mit zwei Bedeutungen.
- **Jede Anforderung steht unter einer eigenen Überschrift**, nicht als Aufzählungszeile. Sie wird
  aus Code, Tests und anderen Dokumenten heraus referenziert und braucht dafür einen Anker; eine
  Aufzählungszeile erzeugt nur eine Nummer, die man suchen muss.
- **Vor der Vergabe einer neuen Nummer den aktuellen Hauptstand prüfen.** Zwei parallele
  Sitzungen vergeben unabhängig dieselbe nächste Nummer, und die Versionsverwaltung meldet
  nichts, weil es verschiedene Zeilen sind. Nächste freie `Q-n`: Suche über `docs/` und `DESIGN.md`.

## Rückfluss — im selben Durchgang

Eine Entscheidung aus einer Prüfrunde, einer Planung oder einem Review **aktualisiert die
Dokumente sofort** — nicht später, nicht am Ende der Sitzung.

Der Gesprächsverlauf ist der einzige andere Ort, an dem die Entscheidung existiert, und er ist
nach der Sitzung weg. **Eine Runde mit zehn Einsichten und ohne Dokumentänderung hat nichts
hervorgebracht.**

Jede erledigte Frage aktualisiert **alle** Stellen, die sie berührt:

- den Text der Anforderung — und jede andere, der sie jetzt widerspricht
- das Glossar, wenn ein Begriff neu ist oder sich verschiebt
- die Lieferstufe, wenn Arbeit sich verschiebt
- die Risikoliste, wenn die Entscheidung Kosten mit sich bringt
- die offenen Fragen, mit Durchstreichung des Erledigten
- **jede abgeleitete Darstellung** — Zusammenfassungen, Diagramme, Präsentationen; hier: `wiki/` und `README.md`

**Eine Liste offener Nachzüge ist kein Rückfluss, sondern der Aufschub in ordentlicher Form.**

## Pflege

Die Dokumente werden **im selben Durchgang** wie die Entscheidung aktualisiert, die sie berührt —
nicht in einem späteren Aufräumschritt. Änderungen an `docs/PRD.md`, `docs/adr/`,
`docs/ARCHITECTURE.md` und `DESIGN.md` laufen über einen Pull Request mit Review, wie Code.
`status: ready` setzt nur ein Mensch, nach Vorlage der offenen Fragen.

## Sitzungsnotizen

Eine Sitzung endet mit einer Notiz unter `docs/sessions/JJJJ-MM-TT.md`: Entscheidungen mit ihrer
Begründung, was verworfen wurde und warum, die benannten Kosten, und wo weitergearbeitet wird.

**Verworfene Alternativen gehören hinein.** Manche Entscheidungen sind nur deshalb vertretbar,
weil die Alternative geprüft und schlechter befunden wurde. Ohne diese Notiz wird dieselbe
Alternative in drei Wochen erneut vorgeschlagen.
