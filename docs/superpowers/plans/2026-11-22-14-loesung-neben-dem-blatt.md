# Lösung neben dem Blatt — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** An ein PDF/Bild lässt sich eine Lösung hängen; die Anzeige zeigt sie am Tablet neben dem Blatt, der Zweitbildschirm nie (FR-6.3, UI-17).

**Architecture:** Die Lösung ist ein zweiter, optionaler `MaterialReference` an der Zuordnung (`MaterialLinkRecord`, Felder mit Präfix `solution`). Reine Logik (Namensregel für den Vorschlag, gekoppeltes Blättern, Zusammenführen) liegt im Kern-Paket und ist unter Windows testbar. Die Anzeige bekommt eine zweite, nur lesende Spalte (`SolutionPane`), deren Daten nie in `SecondScreenState` gelangen.

**Tech Stack:** Swift 6, SwiftUI, SwiftData, PDFKit, Swift Testing (`@Test`, `#expect`), XcodeGen.

**Spec:** `docs/superpowers/specs/2026-11-22-loesung-neben-dem-blatt-design.md` (bindend: Verhalten, Namensregel, Texte). Dazu PRD FR-6.3/AK-69, DESIGN.md UI-17, ARCHITECTURE.md „Lösung neben dem Blatt“.

## Global Constraints

- iCloud-Regeln (ADR-0002): keine Eindeutigkeit, jede neue Eigenschaft optional bzw. mit Vorgabewert.
- Code-Sprache (ADR-0009): Bezeichner englisch, Kommentare/`///` deutsch, Glossar „Lösung“ → `solution`, Spalte `SolutionPane`.
- Oberflächentexte deutsch in `Frontstage/Resources/Localizable.xcstrings`, Schlüssel englisch; Wortlaut nach UI-15 (du, Verb zuerst).
- Swift-Idiome für den Entwickler kurz als `Swift-Hinweis:` kommentieren, wie im übrigen Code.
- Kern lokal: `.\scripts\swift-test.ps1` (`-Filter <Name>`). App-Code vor dem CI-Lauf: `.\scripts\swift-parse.ps1`. **Genau ein** CI-Lauf (`workflow_dispatch` auf `ci.yml`) am Ende (Task 7).
- Datenhygiene: Beispielnamen nur erfunden („AB Bruchrechnen“, Klassen `8b`, `9c`).
- Nur PDF und Bild (`MaterialFileKind.pdf`, `.image`) bekommen eine Lösung; alles andere bietet den Menüpunkt nicht an.
- Die Lösung erscheint nie auf dem Zweitbildschirm und nie in dessen Vorschaubild.

## Entscheidungen & Begründung (aus dem Gespräch, Andreas am 2026-11-22: „passt“; Details delegiert)

- Lösung als Verweis an der **Zuordnung** (nicht an der Datei, nicht als eigenes Material): Schieben nimmt sie automatisch mit; sie kann nie als Material aufs Smartboard kommen. Verworfen: nur Dateiname (kein Weg ohne Treffer), zwei Materialien nebeneinander (Lösung wäre Material der Stunde), Split View des Systems (Vordergrund-App bestimmt den Zweitbildschirm).
- Flache optionale Felder statt JSON-Blob: gleiche Form wie der Materialverweis, lesbar im Datenordner.
- Vorschlag aus dem Ordner per Namensregel, danach immer Dateiauswahl als Ausweg.
- Spalte 1:1 nebeneinander, schmal übereinander; Kopplung der Seiten an als Vorgabe; Ein-/Ausblenden app-weit flüchtig.
- Bei Spiegelung ohne Zweitbildschirm: Lösung ausblenden, Warnung, „Trotzdem zeigen“.
- Kostenlos (Teil von FR-6), kein Kauf-Check.
- Keine Stiftnotizen auf der Lösung.

## Review Focus

1. **Spiegelung statt Zweitbildschirm** — Tablet-Bild wird aufgenommen/gespiegelt, keine externe Szene: Lösung muss ausgeblendet sein (Task 6, Test über `SolutionVisibility`).
2. **Lösungsdatei fehlt oder ist nicht geladen** — Blatt bleibt voll nutzbar, Spalte zeigt „Lösung nicht verfügbar“ (Task 6, `SolutionPaneModel`-Test mit werfendem Leser).
3. **Lösung hat weniger/mehr Seiten als das Blatt** — gekoppelt auf letzte Seite begrenzt (Task 1, `SolutionPaging`-Tests).
4. **Abgleich zweier Geräte führt Zuordnungen zusammen, nur eine hat eine Lösung** — Lösung bleibt (Task 2 Kern-Test, Task 3 App-Test).
5. **Alter Datenordner ohne `solution`-Schlüssel / Blatt-Datei wird umbenannt (Neu verknüpfen)** — dekodiert als `nil`; Lösung am alten Ort wird mit ersetzt (Task 2, Task 3).

---

### Task 1: Kern – Namensregel und gekoppeltes Blättern

**Files:**
- Create: `Packages/FrontstageCore/Sources/FrontstageCore/Storage/SolutionMatching.swift`
- Create: `Packages/FrontstageCore/Sources/FrontstageCore/Storage/SolutionPaging.swift`
- Test: `Packages/FrontstageCore/Tests/FrontstageCoreTests/Storage/SolutionMatchingTests.swift`, `.../Storage/SolutionPagingTests.swift`

**Interfaces:**
- Produces: `public enum SolutionMatching { public static func bestCandidate(forSheetNamed sheet: String, among names: [String]) -> String? }` (Namen mit Endung, ohne Pfad; liefert den Dateinamen des besten Kandidaten).
- Produces: `public enum SolutionPaging { public static func coupledPage(sheetPage: Int, solutionPageCount: Int) -> Int }` (0-basiert; `solutionPageCount <= 0` → 0).

- [ ] **Step 1: Tests schreiben** (`@Test`-Funktionen, Swift Testing wie in `StoragePathTests.swift`)

```swift
@Test func findsDashSuffix() {
  #expect(SolutionMatching.bestCandidate(forSheetNamed: "AB Bruchrechnen.pdf",
    among: ["AB Bruchrechnen.pdf", "AB Bruchrechnen – Lösung.pdf", "Andere.pdf"]) == "AB Bruchrechnen – Lösung.pdf")
}
@Test func findsUnderscoreLoesungAndPrefix() {
  #expect(SolutionMatching.bestCandidate(forSheetNamed: "AB Bruchrechnen.pdf", among: ["AB Bruchrechnen_Loesung.pdf"]) == "AB Bruchrechnen_Loesung.pdf")
  #expect(SolutionMatching.bestCandidate(forSheetNamed: "AB Bruchrechnen.pdf", among: ["Lösung AB Bruchrechnen.pdf"]) == "Lösung AB Bruchrechnen.pdf")
}
@Test func ignoresCaseAccentsAndLsg() {
  #expect(SolutionMatching.bestCandidate(forSheetNamed: "ab bruchrechnen.PDF", among: ["AB Bruchrechnen (LSG).png"]) == "AB Bruchrechnen (LSG).png")
}
@Test func prefersPdfThenShorterThenAlphabetical() {
  #expect(SolutionMatching.bestCandidate(forSheetNamed: "Test.pdf",
    among: ["Test Lösungen.png", "Test Lösungen.pdf", "Test Lösung.pdf"]) == "Test Lösung.pdf")
}
@Test func rejectsOtherStemsNonDocumentsAndSheetItself() {
  #expect(SolutionMatching.bestCandidate(forSheetNamed: "AB Bruchrechnen.pdf",
    among: ["AB Bruchrechnen 2 – Lösung.pdf", "AB Bruchrechnen – Lösung.docx", "AB Bruchrechnen.pdf", "Lösungsweg AB Bruchrechnen.pdf"]) == nil)
}
@Test func coupledPageClamps() {
  #expect(SolutionPaging.coupledPage(sheetPage: 1, solutionPageCount: 2) == 1)
  #expect(SolutionPaging.coupledPage(sheetPage: 2, solutionPageCount: 2) == 1)
  #expect(SolutionPaging.coupledPage(sheetPage: 3, solutionPageCount: 0) == 0)
}
```

- [ ] **Step 2:** `.\scripts\swift-test.ps1 -Filter Solution` → FAIL (Typen fehlen).
- [ ] **Step 3: Implementieren.** Regel exakt nach Spec, Abschnitt „Namensregel“: Lösungswörter `lösung, lösungen, loesung, loesungen, lsg, solution, solutions, key`; Normalisierung über `folding(options: [.caseInsensitive, .diacriticInsensitive], locale: nil)` auf Dateinamen **und** Wortliste (aus „lösung“ wird „losung“, „loesung“ bleibt eigenes Wort); Trennzeichen ` - – _ . ( )` als Wortgrenzen; Wort nur am Anfang oder Ende; Rest (Wörter mit einem Leerzeichen verbunden) == normalisierter Blattstamm. Endungen: PDF bzw. Bild wie `MaterialFileKind` sie erkennt (vorhandene Zuordnung von Endung → Art im Kern nutzen; per `grep -rn "enum MaterialFileKind" Packages` finden). Sortierung: PDF vor Bild, kürzerer Name, dann `localizedStandardCompare`.
- [ ] **Step 4:** `.\scripts\swift-test.ps1 -Filter Solution` → PASS.
- [ ] **Step 5:** Commit `feat(core): Namensregel und Seitenkopplung für die Lösung (FR-6.3)`.

### Task 2: Kern – Datenordner-Payload und Zusammenführen

**Files:**
- Modify: `Packages/FrontstageCore/Sources/FrontstageCore/DataFolder/RecordPayload.swift` (`MaterialLinkPayload`)
- Modify: `Packages/FrontstageCore/Sources/FrontstageCore/Merge/SyncSnapshot.swift` (`MaterialLinkSnapshot`)
- Modify: `Packages/FrontstageCore/Sources/FrontstageCore/Merge/SyncMerger.swift` (`MergePlan`, `plan(for:)`)
- Test: bestehende Tests unter `Packages/FrontstageCore/Tests/FrontstageCoreTests/DataFolder/` bzw. `SyncMergerTests.swift` erweitern

**Interfaces:**
- Produces: `MaterialLinkPayload.solution: MaterialReference?`, Init-Parameter `solution: MaterialReference? = nil` (letzter Parameter).
- Produces: `MaterialLinkSnapshot.hasSolution: Bool`, Init-Parameter `hasSolution: Bool = false`.
- Produces: `MergePlan.linkSolutionSources: [UUID: UUID]` (behaltene Zuordnung → aufgegebene mit Lösung); in `isEmpty` berücksichtigen.

- [ ] **Step 1: Tests:**
  - `materialLinkPayloadDecodesWithoutSolution`: JSON eines Payloads ohne Schlüssel `solution` dekodiert, `solution == nil`.
  - `materialLinkPayloadRoundTripsSolution`: mit Lösung kodieren/dekodieren → gleich.
  - `mergeKeepsSolutionOfDroppedLink`: zwei Snapshots gleicher Stunde/Datei, behaltene `hasSolution: false`, aufgegebene `true` → `plan.linkSolutionSources == [keeper: dropped]`.
  - `mergeKeepsKeeperSolution`: beide `true` → `linkSolutionSources` leer.
- [ ] **Step 2:** `.\scripts\swift-test.ps1 -Filter "Payload|SyncMerger"` → FAIL.
- [ ] **Step 3:** Implementieren. Synthetisiertes `Codable` dekodiert optionale Eigenschaften mit `decodeIfPresent` – kein eigener Decoder nötig. In `SyncMerger` aus `linkMap` (aufgegeben → behalten) ableiten; bei mehreren aufgegebenen mit Lösung die jüngste (`createdAt`) nehmen.
- [ ] **Step 4:** Ganze Kern-Suite `.\scripts\swift-test.ps1` → PASS.
- [ ] **Step 5:** Commit `feat(core): Lösung im Datenordner und beim Zusammenführen (FR-6.3)`.

### Task 3: App-Daten – Felder, Abgleich, Kopieren, Neu verknüpfen, Bereithalten

**Files:**
- Modify: `Frontstage/Data/Records/MaterialLinkRecord.swift` – neue Felder `solutionFolderGrantName: String?`, `solutionRelativePath: String?`, `solutionDisplayName: String?`, `solutionFileKindRaw: String?`, `solutionOneDriveItemID: String?`, `solutionOneDriveDriveID: String?` (alle `= nil`).
- Modify: `Frontstage/Data/RecordConversion.swift` (Erweiterung um `var reference`/`setReference`, ab ca. `var reference: MaterialReference`) – `var solution: MaterialReference?` (nil, wenn Pfad leer/nil) und `func setSolution(_ reference: MaterialReference?)`; `snapshot()` setzt `hasSolution`.
- Modify: `Frontstage/Data/Folder/RecordCodec.swift` – `export(_ record: MaterialLinkRecord)` und `case .materialLink(let value)` übertragen `solution`.
- Modify: `Frontstage/Data/DataStore+MaterialLinks.swift` – neu `func setSolution(_ reference: MaterialReference?, forLinkID id: UUID) throws` (unbekannte id → nichts; speichert per `saveAndBump()`); `copyMaterialLinks` kopiert `copy.setSolution(link.solution)`; `replaceReferences(atLocation:with:)` ersetzt zusätzlich Lösungen mit `solution.locationKey == locationKey` und zählt sie mit; `linkedReferences(for:)` liefert je Zuordnung mit Lösung einen zweiten Eintrag `(key, solution)`.
- Modify: `Frontstage/Data/DataStore+Merge.swift` – vor dem Löschen: für `plan.linkSolutionSources` `keeper.setSolution(source.solution)`.
- Modify: `Frontstage/UI/Preparation/PreparationStore.swift` – `MaterialLinkItem.solution: MaterialReference?` (Init aus Record setzt sie); Protokoll `PreparationStore` + `DataStore`-Erweiterung: `func setSolution(_ reference: MaterialReference?, forLinkID id: UUID) throws`.
- Test: `FrontstageTests/Data/DataStoreMaterialLinkTests.swift`, `DataStoreMergeTests.swift`, `Folder/`-Codec-Tests, ggf. `RecordSchemaTests.swift` (prüft Feldlisten – an neue Felder anpassen).

**Interfaces:**
- Consumes: Task 2 (`MaterialLinkPayload.solution`, `hasSolution`, `linkSolutionSources`).
- Produces: `MaterialLinkRecord.solution`, `setSolution(_:)`, `DataStore.setSolution(_:forLinkID:)`, `MaterialLinkItem.solution`.

- [ ] **Step 1: Tests** (Muster und Hilfen `reference("…")` aus `DataStoreMaterialLinkTests.swift`):
  - `setSolutionStoresAndClears`: setzen → `link.solution == ref`; `nil` → `nil`.
  - `moveToNextLessonKeepsSolution`; `copyMaterialLinksCopiesSolution`.
  - `replaceReferencesReplacesSolutionAtLocation`: Lösung „AB – Lösung.pdf“ an zwei Zuordnungen, umbenannt → beide ersetzt, Rückgabe zählt sie.
  - `linkedReferencesIncludesSolution`.
  - `mergeMovesSolutionToKeeper` (in `DataStoreMergeTests`).
  - Codec-Rundweg mit Lösung.
- [ ] **Step 2:** Tests laufen nur auf macOS: `.\scripts\swift-parse.ps1` → keine Syntaxfehler (Test-Ausführung im CI-Lauf, Task 7).
- [ ] **Step 3:** Implementieren wie in Files beschrieben.
- [ ] **Step 4:** `.\scripts\swift-parse.ps1` → OK; Diff gegen bestehende Aufrufer von `MaterialLinkItem(id:lessonKey:position:reference:)` prüfen (`grep -rn "MaterialLinkItem(" Frontstage FrontstageTests`), neuen Parameter `solution: MaterialReference? = nil` mit Vorgabe anhängen.
- [ ] **Step 5:** Commit `feat(daten): Lösung an der Zuordnung (FR-6.3)`.

### Task 4: Ablage – Vorschlag suchen und Lösung wählen

**Files:**
- Modify: `Frontstage/Storage/MaterialResolver.swift` – `func siblingFileNames(of reference: MaterialReference) -> [String]` (über `resolveFolder(of:)`, Ordner der Datei, `contentsOfDirectory`, Zugriffsfenster wie in `lookup`).
- Modify: `Frontstage/Storage/StorageService.swift` – `func suggestedSolution(for sheet: MaterialReference) -> MaterialReference?` (Namen von `resolver.siblingFileNames`, `SolutionMatching.bestCandidate`, Verweis mit gleichem `folderGrantName` und Pfad im selben Ordner, `fileKind` nach Endung); zusätzlich `refreshAvailability` wird von Aufrufern mit Lösungen gefüttert (Task 5/6).
- Modify: `Frontstage/UI/Shared/MaterialStorage.swift` (Protokoll) um `suggestedSolution(for:)`, damit Ansichtsmodelle testbar bleiben; Fakes in `FrontstageTests/TestSupport` nachziehen (`grep -rn "MaterialStorage" FrontstageTests`).
- Create: `Frontstage/UI/Shared/SolutionPicking.swift` – `struct SolutionPicking: ViewModifier`: nimmt `@Binding var target: MaterialLinkItem?`; wenn gesetzt: `suggestedSolution` → `confirmationDialog` „„<Name>“ als Lösung verwenden?“ mit „Verwenden“ / „Andere Datei wählen …“; sonst direkt `.fileImporter(allowedContentTypes: [.pdf, .image])`; gewählte URL über `storage.reference(forPickedFile:)` (nil → vorhandener Hinweis „außerhalb der freigegebenen Ordner“, gleicher Schlüssel wie beim Zuordnen); speichert über `PreparationStore.setSolution(_:forLinkID:)`.

**Interfaces:**
- Consumes: Task 1 `SolutionMatching`, Task 3 `setSolution(_:forLinkID:)`.
- Produces: `View.solutionPicking(target: Binding<MaterialLinkItem?>, store: any PreparationStore) -> some View`.

- [ ] **Step 1:** Test in `FrontstageTests/Storage/` (vorhandene Ordner-Fixtures mit temporärem Verzeichnis nutzen): Ordner mit „AB Bruchrechnen.pdf“ und „AB Bruchrechnen – Lösung.pdf“ → `suggestedSolution` liefert Pfad `…/AB Bruchrechnen – Lösung.pdf`, `fileKind == .pdf`; ohne Kandidat → `nil`.
- [ ] **Step 2–4:** implementieren, `.\scripts\swift-parse.ps1` → OK.
- [ ] **Step 5:** Commit `feat(ablage): Lösung vorschlagen und wählen (FR-6.3)`.

### Task 5: Kachel und Vorbereiten – Menüpunkte und „mit Lösung“

**Files:**
- Modify: `Frontstage/UI/DayView/DayLessonDetail.swift` – `DayRowActions` um `var editSolution: (MaterialRow) -> Void` und `var removeSolution: (MaterialRow) -> Void`.
- Modify: `Frontstage/UI/DayView/MaterialTile.swift` – im `.contextMenu`: nur bei `fileKind` `.pdf`/`.image`: ohne Lösung „Lösung hinzufügen …“ (`doc.badge.plus`), mit Lösung „Lösung ersetzen …“ (`arrow.triangle.2.circlepath`) und „Lösung entfernen“ (`trash`, `role: .destructive`); Fuß: Dateityp + „ · mit Lösung“; `accessibilityValue` ergänzt „mit Lösung“.
- Modify: `Frontstage/UI/DayView/DayView.swift` – Zustand `@State var solutionTarget: MaterialLinkItem?`, Closures verdrahten, `.solutionPicking(target:store:)` anhängen; nach Änderung neu laden wie bei anderen Aktionen.
- Modify: `Frontstage/UI/Preparation/LessonDetailView.swift` – im `Menu` von `materialSection` dieselben Punkte; Zeile zeigt bei Lösung ein Symbol `checkmark.seal` mit Bedienhilfe „mit Lösung“.
- Modify: `Frontstage/UI/DayView/DayViewModel.swift` – `refreshAvailability` erhält zusätzlich die Lösungsverweise.
- Modify: `Frontstage/Resources/Localizable.xcstrings` – Schlüssel `solution.add` „Lösung hinzufügen …“, `solution.replace` „Lösung ersetzen …“, `solution.remove` „Lösung entfernen“, `solution.withSolution` „mit Lösung“, `solution.suggestion.title %@` „„%@“ als Lösung verwenden?“, `solution.suggestion.use` „Verwenden“, `solution.suggestion.other` „Andere Datei wählen …“.

- [ ] **Step 1:** Ansichtsmodell-Test (falls `DayViewModel`-Tests unter `FrontstageTests/UI/` existieren): Zeile mit Lösung → Verfügbarkeit wird für beide Verweise angefragt (Fake-`MaterialStorage` zählt Aufrufe).
- [ ] **Step 2–4:** implementieren, `.\scripts\swift-parse.ps1` → OK.
- [ ] **Step 5:** Commit `feat(ui): Lösung an der Kachel hinzufügen, ersetzen, entfernen (FR-6.3)`.

### Task 6: Anzeige – Lösungsspalte, Kopplung, Spiegelungsschutz

**Files:**
- Create: `Frontstage/Viewer/SolutionPaneModel.swift` – `@MainActor @Observable final class SolutionPaneModel` mit `init(reference: MaterialReference, fileReader: any MaterialFileReading)`, `phase: Phase` (`.loading/.ready/.unavailable`), `documentData: Data?`, `pageCount: Int`, `pageIndex: Int`, `isCoupled: Bool = true`, `func load() async`, `func sheetPageChanged(to sheetPage: Int)` (nur gekoppelt, über `SolutionPaging.coupledPage`), `func goToPage(_ index: Int)` (setzt `isCoupled = false`, begrenzt), `func toggleCoupling(sheetPage: Int)`.
- Create: `Frontstage/Viewer/SolutionVisibility.swift` – `@MainActor @Observable final class SolutionVisibility { static let shared; var isShownByUser = true; var overrideMirroring = false; func isVisible(isMirrored: Bool) -> Bool }` (sichtbar = `isShownByUser && (!isMirrored || overrideMirroring)`; `overrideMirroring` wird beim Schließen der Anzeige zurückgesetzt).
- Create: `Frontstage/Viewer/ScreenCaptureReader.swift` – nur iOS: `UIViewRepresentable`, das `traitCollection.sceneCaptureState == .active` meldet (`registerForTraitChanges([UITraitSceneCaptureState.self])`, iOS 17+; vor dem Bau per Context7/Apple-Doku bestätigen) als `Binding<Bool>`. Gespiegelt = aufgenommen **und** `SecondScreenState.shared.isConnected == false`. Mac: immer `false`.
- Create: `Frontstage/Viewer/SolutionPane.swift` – Kopfzeile nach UI-17 („Lösung“, „Seite x von y“, Pfeile, `link`-Schalter, „Ausblenden“), Inhalt `PDFDisplayView(documentData:pageIndex:drawing: nil, visibleRect: nil)`; Zustände „Lösung nicht verfügbar“ + „Andere Datei wählen …“ und Spiegelungswarnung + „Trotzdem zeigen“ als ruhige Aussage (`ContentUnavailableView`, UI-13).
- Modify: `Frontstage/Viewer/ViewerView.swift` – in `start()` `link.solution` lesen und ggf. `SolutionPaneModel` bauen (gleicher `ScopedFileReader`); `ready(_:)` legt Blatt und Spalte in `ViewThatFits`/`GeometryReader` nebeneinander (Breite ≥ 700 pt und nicht `.compact`) bzw. übereinander, Trennlinie `Divider()`; Seitenwechsel des Blatts (`go(to:)` und Wechsel aus `PDFCanvasView`, beobachtet über `model.pageIndex` mit `.onChange`) ruft `sheetPageChanged`; Leistenknopf „Lösung“ (`sidebar.right`, Schlüssel `viewer.solution`) schaltet `SolutionVisibility.shared.isShownByUser`; ohne Lösung bei PDF/Bild stattdessen „Lösung hinzufügen“ (öffnet `solutionPicking`, danach Spalte neu laden).
- **Nicht ändern:** `Frontstage/SecondScreen/*`, `MaterialPresentation`. `ViewerModel` bleibt ohne Wissen über die Lösung.
- Modify: `Frontstage/Resources/Localizable.xcstrings` – `viewer.solution` „Lösung“, `solution.title` „Lösung“, `solution.couple` „Seiten koppeln“, `solution.hide` „Ausblenden“, `solution.unavailable` „Lösung nicht verfügbar“, `solution.mirrored.title` „Dein Bildschirm wird gespiegelt“, `solution.mirrored.body` „Die Klasse würde die Lösung sehen.“, `solution.mirrored.showAnyway` „Trotzdem zeigen“; Hilfeartikel `help.penNotes.body` um einen Absatz zur Lösung ergänzen, `help.penNotes.keywords` um „Lösung, Lösungsblatt“.
- Test: `FrontstageTests/Viewer/SolutionPaneModelTests.swift`, `FrontstageTests/Viewer/SolutionVisibilityTests.swift`, `FrontstageTests/Viewer/ViewerModelTests.swift` (erweitern).

**Interfaces:**
- Consumes: Task 1 `SolutionPaging`, Task 3 `MaterialLinkRecord.solution`, Task 4 `solutionPicking`.

- [ ] **Step 1: Tests** (Fake-Leser wie in `ViewerModelTests.swift`):
  - `loadsSolutionAndCouplesPages`: Lösung mit 2 Seiten; `sheetPageChanged(to: 1)` → 1; `(to: 2)` → 1.
  - `ownPagingDecouples`: `goToPage(0)` → `isCoupled == false`; `sheetPageChanged(to: 1)` → bleibt 0.
  - `unreadableSolutionIsUnavailable`: Leser wirft → `phase == .unavailable`.
  - `mirroringHidesUnlessOverridden`: `isVisible(isMirrored: true) == false`; nach `overrideMirroring = true` → `true`; `isShownByUser = false` → immer `false`.
  - `secondScreenNeverGetsSolution` (in `ViewerModelTests`): Zuordnung mit Lösung öffnen → `SecondScreenState.material?.documentData` gleich den Blatt-Daten.
- [ ] **Step 2–4:** implementieren, `.\scripts\swift-parse.ps1` → OK.
- [ ] **Step 5:** Commit `feat(anzeige): Lösung neben dem Blatt, nie am Zweitbildschirm (FR-6.3, UI-17)`.

### Task 7: Prüfen, CI, Sitzungsnotiz, PR

- [ ] **Step 1:** `.\scripts\swift-test.ps1` (Kern komplett) → PASS; `.\scripts\swift-parse.ps1` → OK.
- [ ] **Step 2:** Diff gegen `main` auf Compilerfehler durchsehen (Typen, fehlende Parameter, `#if os(iOS)` um UIKit-Code).
- [ ] **Step 3:** Push, **ein** CI-Lauf: `gh workflow run ci.yml --ref feature/loesung-neben-dem-blatt`; warten; bei Fehler `TestResults.xcresult` und Log lesen, Ursache beheben, ein neuer Lauf.
- [ ] **Step 4:** Design-Prüfung der Anzeige mit dem projektlokalen Skill `apple-design` (2 UI-Dateien und mehr → Befunde einarbeiten oder als Q-n festhalten).
- [ ] **Step 5:** Sitzungsnotiz `docs/sessions/2026-11-22.md` (Entscheidungen, Verworfenes, Kosten: halbe Breite beim Schreiben, Spiegelungserkennung nur iOS).
- [ ] **Step 6:** PR nach `main`, nach grünem CI selbst mergen (Gedächtnis: Merge ohne Rückfrage).
