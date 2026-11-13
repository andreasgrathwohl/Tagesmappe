# Teilplan 04 — Oberfläche Kern: Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.
> Rahmen: `docs/superpowers/plans/2026-11-13-00-uebersicht.md` — gilt vollständig. **Aufgabe 18 (Design-Runden) läuft nie unbeaufsichtigt; Aufgabe 17 braucht einen Menschen mit Geräten.**

**Goal:** Die drei Bildschirme des Kerns bauen – Tagesansicht, Vorbereiten, Einrichten – samt App-Gerüst und Navigation auf iPad und Mac, sodass eine Lehrkraft einen Stundenplan anlegt, Material zuordnet, Ausfall und Vertretung pflegt und im Unterricht den Tag sieht; danach der erste TestFlight-Bau und die Design-Runden 1–10.

**Architecture:** Jede Ansicht hat ein `@MainActor @Observable`-View-Modell ohne SwiftUI-Import, das nur über drei Protokolle spricht: `FrontstageStore` (Daten, Teilplan 02), `StorageService` (Ablage, Teilplan 03), `TimetableSourceStatusProviding` (Stand der Quelle, hier festgelegt, Teilplan 05 erfüllt es). Alle Rechnung über Unterrichtsstunden läuft über `TimetableCalculator` (Teilplan 01) und zwei kleine Kern-Ergänzungen aus Aufgabe 1. Die Tests prüfen die View-Modelle gegen Fakes dieser Protokolle; die Views selbst sind dünn und ohne Logik.

**Tech Stack:** SwiftUI (`TabView` mit `.sidebarAdaptable`, `NavigationSplitView`, `.fileImporter`, `.dropDestination(for:isEnabled:action:)`), Observation (`@Observable`), Swift Testing, GitHub Actions (`xcodebuild archive` / `-exportArchive`).

**Spec:** `docs/PRD.md` (FR-1, FR-1.1, FR-1.2, FR-3 bis FR-3.4, FR-4, FR-7, FR-8, FR-9, FR-11.1 als Eingabe; AK-1, AK-4 bis AK-8, AK-10, AK-14 bis AK-16, AK-42 Tagesansichts-Teil), `docs/ARCHITECTURE.md` (Area plattform, daten, ablage, stundenplan-quellen), ADR-0002, ADR-0003, ADR-0005, ADR-0008, ADR-0009, `DESIGN.md` (Wiederkehrende Fallen), `mockup/tagesansicht.html`, `mockup/vorbereiten.html`, `mockup/einrichten.html`, `mockup/LIESMICH.md` (Beispieldaten, offene Gestaltungsfragen).

## Global Constraints

Alle Zeilen aus „Global Constraints“ und „Gestaltung in den Aufgaben“ der Übersicht gelten. Zusätzlich für diesen Teilplan:

- **Quellen der verwendeten Apple-APIs** (gelesen 2026-11-13 über `developer.apple.com/tutorials/data/documentation/…json`):
  - `dropDestination(for:isEnabled:action:)` mit `action: ([T], DropSession) -> Void` – **iOS/macOS 26.0**; die ältere Form `dropDestination(for:action:isTargeted:)` ist ab 27.3 als veraltet markiert → nur die neue Form nutzen. `DropSession.location: CGPoint` ab 26.0.
  - `fileImporter(isPresented:allowedContentTypes:allowsMultipleSelection:onCompletion:)` – ab iOS 14 / macOS 11, liefert `Result<[URL], any Error>`.
  - `TabViewStyle.sidebarAdaptable` – ab iOS 18 / macOS 15. `NavigationSplitView` ab iOS 16 / macOS 13. `ViewThatFits` ab iOS 16 / macOS 13.
- **View-Modelle importieren kein SwiftUI** (nur `Foundation`, `Observation`, `FrontstageCore`), damit sie im Testziel ohne Ansicht prüfbar sind. Ausnahme: keine.
- **Heute ist ein Parameter:** Jedes View-Modell bekommt `today: @escaping @MainActor () -> CalendarDay`; nie `Date()` im View-Modell. Tests fixieren **Dienstag, 2026-11-17** (Woche 47, A-Woche, Bezugswoche A = Montag 2026-11-16).
- **Neue Ordner:** `Frontstage/UI/Shared/` (gemeinsame Zeilen-Modelle und Aktionen der drei Bildschirme), `FrontstageTests/Support/`, `FrontstageTests/UI/`. Ergänzt die Ordnerliste der Übersicht, widerspricht ihr nicht.
- **Oberflächentexte:** Jede Aufgabe trägt ihre Schlüssel in `Frontstage/Resources/Localizable.xcstrings` ein, Präfix je Bildschirm (`app.`, `dayView.`, `preparation.`, `setup.`, `lesson.`). Werte deutsch, unpersönlich, als Platzhalter.
- **Material wird nie kopiert:** Kein View-Modell ruft etwas anderes als `StorageService.makeReference(for:)` mit einer Datei-URL auf; Übernehmen und Schieben verwenden vorhandene `MaterialReference`-Werte weiter (FR-3.4).
- **Offene Gestaltung:** Jede Aufgabe mit Oberfläche nimmt den SwiftUI-Systemstandard und nennt im Abschlussbericht je berührter offener Kategorie eine Zeile (Sammelstelle: Aufgabe 18).

## Review Focus

Was die Spec voraussetzt, aber kein AK prüft – wahrscheinlichstes zuerst; jede Zeile hat ihren Test in der genannten Aufgabe:

1. **Zeitraster leer oder lückenhaft** (Stunde ohne Zeit, typisch nach dem ersten Anlegen): Tagesansicht zeigt die Unterrichtsstunden trotzdem in Stundenreihenfolge, ohne Zeit, ohne Absturz – Aufgabe 6 (`dayRowsWithoutBellScheduleKeepPeriodOrder`).
2. **Keine nächste Unterrichtsstunde innerhalb von 28 Tagen** (Schuljahresende, lange Ferien) beim Schieben/Weiterreichen/Übernehmen: Aktion meldet `nil`, Material bleibt unverändert an der alten Stunde – Aufgabe 4 (`moveToNextLessonWithoutTargetKeepsLink`).
3. **Datei außerhalb jeder Ordnerfreigabe** oder Nicht-Datei-URL wird gezogen/gewählt: kein Datensatz entsteht, Fehler wird gemeldet mit Angebot, den Ordner freizugeben – Aufgabe 3 (`assignOutsideGrantedFolderStoresNothing`).
4. **Ausfall doppelt markieren / Ausfall aus der Quelle von Hand aufheben:** zweite Markierung erzeugt keine zweite Abweichung; eine Abweichung mit Herkunft `source` lässt sich nicht von Hand entfernen – Aufgabe 5 (`markCancelledTwiceStoresOneChange`, `unmarkSourceCancellationIsRejected`).
5. **Wechsel von zwei Wochenvarianten zurück auf eine**, während A/B-spezifische Einträge existieren: nichts geht still verloren; Wechsel verlangt Bestätigung und nennt die Zahl der B-Einträge – Aufgabe 11 (`reducingToOneVariantRequiresConfirmation`).

---

## Interfaces

### Konsumiert aus der Übersicht (Teilplan 01)

`CalendarDay`, `Weekday`, `WeekVariant`, `SchoolClass`, `Subject`, `TimeOfDay`, `BellSchedule`, `TimetableEntry`, `Timetable`, `NonTeachingPeriod`, `LessonKey`, `Origin`, `ScheduleChange`, `Lesson`, `TimetableCalculator` – exakt wie in der Übersicht.

### Erwartet von Teilplan 01 (nicht in der Übersicht)

```swift
// öffentliche Initialisierer, die die Übersicht nicht ausschreibt
public init(year: Int, month: Int, day: Int)                                          // CalendarDay
public init(hour: Int, minute: Int)                                                    // TimeOfDay
public init(date: CalendarDay, schoolClass: SchoolClass, subject: Subject, ordinal: Int) // LessonKey
public init(weekVariant: WeekVariant?, weekday: Weekday, period: Int, schoolClass: SchoolClass, subject: Subject) // TimetableEntry
// Semantik: TimetableEntry.weekVariant == nil heißt „gilt in A- und B-Woche“.
```

### Erwartet von Teilplan 02 (Daten)

```swift
/// Wertabbild einer Zuordnung (MaterialLinkRecord) für die Oberfläche.
public struct MaterialLinkItem: Identifiable, Hashable, Sendable {
    public let id: UUID
    public var lessonKey: LessonKey
    public var position: Int
    public var reference: MaterialReference
}
/// Stundenangaben (LessonInfoRecord) als Wert; nil heißt „Feld leer“.
public struct LessonInfo: Hashable, Sendable { public var topic: String?; public var toPrepare: String?; public var homework: String? }

@MainActor public protocol FrontstageStore: AnyObject {
    /// Steigt bei jeder lokalen Änderung und nach jedem Zusammenführen eines Abgleichs (Klasse ist @Observable).
    var revision: Int { get }
    func timetable() -> Timetable?
    func saveTimetableSettings(weekVariantCount: Int, referenceWeekA: CalendarDay)
    func saveBellSchedule(_ schedule: BellSchedule)
    /// Legt an oder ersetzt `old`; markiert den Eintrag als „von Hand geändert“ (für ImportDiffer, AK-3).
    func upsertEntry(_ entry: TimetableEntry, replacing old: TimetableEntry?)
    func deleteEntry(_ entry: TimetableEntry)
    func nonTeachingPeriods() -> [NonTeachingPeriod]
    func addNonTeachingPeriod(_ period: NonTeachingPeriod)
    func removeNonTeachingPeriod(_ period: NonTeachingPeriod)
    func scheduleChanges() -> [ScheduleChange]
    func addScheduleChange(_ change: ScheduleChange)
    func removeScheduleChange(_ change: ScheduleChange)
    func materialLinks(for key: LessonKey) -> [MaterialLinkItem]              // nach position sortiert
    func materialLinks(from: CalendarDay, through: CalendarDay) -> [MaterialLinkItem]
    @discardableResult func addMaterialLink(_ reference: MaterialReference, to key: LessonKey) -> MaterialLinkItem // hinten anhängen
    func setOrder(of key: LessonKey, linkIDs: [UUID])                          // positions 0…n-1
    /// Ändert nur den Schlüssel; Stiftnotizen bleiben an der Zuordnung (FR-6.1).
    func moveMaterialLink(id: UUID, to key: LessonKey)
    /// Neue Zuordnungen ohne Stiftnotizen (FR-6.1); gleiche Referenz am Ziel wird übersprungen.
    func copyMaterialLinks(from: LessonKey, to: LessonKey)
    func replaceReference(linkID: UUID, with reference: MaterialReference)
    func removeMaterialLink(id: UUID)
    func lessonInfo(for key: LessonKey) -> LessonInfo?
    func saveLessonInfo(_ info: LessonInfo, for key: LessonKey)               // alle Felder nil → Datensatz löschen
}
public final class SwiftDataStore: FrontstageStore { public init(container: ModelContainer) }
public enum FrontstageModelContainer { public static func make() throws -> ModelContainer }
```

### Erwartet von Teilplan 03 (Ablage)

```swift
public enum MaterialFileKind: String, Codable, Sendable { case presentation, document, spreadsheet, pdf, image, other }
public struct MaterialReference: Hashable, Codable, Sendable {
    public var grantName: String; public var relativePath: String; public var displayName: String
    public var fileKind: MaterialFileKind; public var oneDriveItemID: String?
}
public enum MaterialAvailability: Hashable, Sendable { case onDevice, downloading, notDownloaded, unavailable }
public struct FolderGrantStatus: Hashable, Sendable { public let name: String; public let isAvailableOnThisDevice: Bool }
public enum StorageError: Error, Equatable { case outsideGrantedFolders, notAFile, grantNotResolvable }

@MainActor public protocol StorageService: AnyObject {
    func folderGrants() -> [FolderGrantStatus]          // lokal erteilte plus nur gespiegelt bekannte Namen
    func addFolderGrant(url: URL) throws -> FolderGrantStatus
    func removeFolderGrant(name: String)
    func makeReference(for fileURL: URL) throws(StorageError) -> MaterialReference
    func availability(of reference: MaterialReference) -> MaterialAvailability
    func prefetch(_ references: [MaterialReference])
    func open(_ reference: MaterialReference) async throws
}
public final class FileStorageService: StorageService { public init() }
```

### Festgelegt in 04, erfüllt von Teilplan 05 (Schulmanager)

```swift
public enum TimetableSourceKind: String, Sendable { case manual, schulmanager }
public struct TimetableSourceStatus: Hashable, Sendable {
    public var kind: TimetableSourceKind; public var lastSuccessfulUpdate: Date?; public var consecutiveFailures: Int
}
@MainActor public protocol TimetableSourceStatusProviding: AnyObject {
    var status: TimetableSourceStatus { get }
    func refreshNow() async
}
/// Vorgabe, solange Teilplan 05 nicht eingebaut ist.
public final class ManualTimetableSourceStatus: TimetableSourceStatusProviding   // status.kind == .manual, refreshNow() tut nichts
```

### Festgelegt in 04, genutzt von Teilplan 06 (Anzeige)

```swift
@MainActor @Observable final class AppEnvironment {
    let store: any FrontstageStore; let storage: any StorageService; var sourceStatus: any TimetableSourceStatusProviding
    /// Setzt Teilplan 06; false (Vorgabe) → PDF und Bild werden wie jedes Material übergeben.
    var viewerAvailable: Bool
    var today: @MainActor () -> CalendarDay
}
enum MaterialOpenAction: Equatable { case handOff(MaterialReference); case viewer(MaterialLinkItem); case unavailable }
```

---

## Dateien

| Datei | Verantwortung | Aufgabe |
|---|---|---|
| `Packages/FrontstageCore/Sources/FrontstageCore/CalendarDay+Navigation.swift` | Tag addieren, Wochentag, Montag der Woche, aus `Date` | 1 |
| `Packages/FrontstageCore/Sources/FrontstageCore/LessonMatching.swift` | Parallelklasse finden, Schlüssel ohne Unterrichtsstunde | 1 |
| `FrontstageTests/Support/FakeStore.swift`, `FakeStorage.swift`, `Fixtures.swift` | Fakes der drei Protokolle, Beispieldaten Woche 47 | 2 |
| `Frontstage/UI/Shared/LessonActions.swift` | Zuordnen, Reihenfolge, Übernehmen, Schieben, Ausfall, Vertretung, Neuverknüpfen | 3–5 |
| `Frontstage/UI/Shared/LessonRow.swift`, `DayStatement.swift`, `TimetableSourceStatus.swift`, `MaterialOpenAction.swift` | gemeinsame Zeilen-Modelle | 6 |
| `Frontstage/App/AppEnvironment.swift` | Abhängigkeitsbündel | 6 |
| `Frontstage/App/AppSection.swift`, `RootView.swift`; `FrontstageApp.swift` (ändern) | Gerüst, Navigation | 7 |
| `Frontstage/UI/DayView/DayViewModel.swift`, `DayViewLayout.swift` | Tagesansicht-Logik | 6 |
| `Frontstage/UI/DayView/DayView.swift`, `DayRowView.swift`, `SourceStatusView.swift` | Tagesansicht | 8 |
| `Frontstage/UI/Preparation/PreparationViewModel.swift`, `LessonInfoEditor.swift` | Vorbereiten-Logik | 9 |
| `Frontstage/UI/Preparation/PreparationView.swift`, `LessonDetailView.swift`, `MaterialDropTarget.swift`, `SubstituteLessonSheet.swift` | Vorbereiten | 10 |
| `Frontstage/UI/Setup/TimetableEditorViewModel.swift`, `TimetableEditorView.swift`, `TimetableEntrySheet.swift`, `SetupView.swift` | Stundenplan von Hand, A/B, Bezugswoche | 11 |
| `Frontstage/UI/Setup/BellScheduleEditorViewModel.swift`, `BellScheduleEditorView.swift` | Zeitraster | 12 |
| `Frontstage/UI/Setup/NonTeachingPeriodsViewModel.swift`, `NonTeachingPeriodsView.swift` | unterrichtsfreie Zeiträume, Material ohne Stunde | 13 |
| `Frontstage/UI/Setup/StorageSettingsViewModel.swift`, `StorageSettingsView.swift` | Ordnerfreigaben, Platz für Quelle | 14 |
| `.github/workflows/testflight.yml`, `ci/ExportOptions-TestFlight.plist`, `project.yml` (ändern) | TestFlight-Bau | 16 |

Tests: je View-Modell `FrontstageTests/UI/<Name>Tests.swift`; Kern-Tests unter `Packages/FrontstageCore/Tests/FrontstageCoreTests/`.

---

### Task 1: Kern-Ergänzungen – Tagesrechnung und Zuordnungsabgleich

Design-Takt: keiner

**Files:**
- Create: `Packages/FrontstageCore/Sources/FrontstageCore/CalendarDay+Navigation.swift`
- Create: `Packages/FrontstageCore/Sources/FrontstageCore/LessonMatching.swift`
- Test: `Packages/FrontstageCore/Tests/FrontstageCoreTests/CalendarDayNavigationTests.swift`, `LessonMatchingTests.swift`

**Interfaces:**
- Consumes: Kern-Typen der Übersicht, `TimetableCalculator.lessons(on:timetable:nonTeachingPeriods:changes:)`.
- Produces:
```swift
extension CalendarDay {
    public func addingDays(_ days: Int) -> CalendarDay
    public var weekday: Weekday { get }
    public var mondayOfWeek: CalendarDay { get }
    public init(_ date: Date, calendar: Calendar)
}
public enum LessonMatching {
    /// FR-3.2: erste nicht ausgefallene Unterrichtsstunde der Zielklasse im selben Fach am selben Tag oder danach.
    public static func parallelLesson(for source: LessonKey, targetClass: SchoolClass, timetable: Timetable, nonTeachingPeriods: [NonTeachingPeriod], changes: [ScheduleChange], maxDays: Int = 28) -> LessonKey?
    /// Klassen mit Einträgen im selben Fach, ohne die Quellklasse, sortiert nach `normalized`.
    public static func parallelClasses(for subject: Subject, excluding: SchoolClass, timetable: Timetable) -> [SchoolClass]
    /// FR-7, ADR-0005: Schlüssel, zu denen an ihrem Datum keine berechnete Unterrichtsstunde (auch keine ausgefallene) existiert.
    public static func keysWithoutLesson(_ keys: Set<LessonKey>, timetable: Timetable, nonTeachingPeriods: [NonTeachingPeriod], changes: [ScheduleChange]) -> Set<LessonKey>
}
```

- [ ] **Step 1: Tests schreiben**

```swift
@Test("Montag der Woche und Wochentag") func mondayAndWeekday() {
    let tue = CalendarDay(year: 2026, month: 11, day: 17)
    #expect(tue.weekday == .tuesday)
    #expect(tue.mondayOfWeek == CalendarDay(year: 2026, month: 11, day: 16))
    #expect(CalendarDay(year: 2026, month: 11, day: 30).addingDays(1) == CalendarDay(year: 2026, month: 12, day: 1))
}
@Test("AK-7: Parallelstunde der 8b am Mittwoch") func parallelLessonFindsWednesday() {
    // Di 2. Std 8a Englisch, Mi 3. Std 8b Englisch, eine Wochenvariante
    let key = LessonKey(date: .init(year: 2026, month: 11, day: 17), schoolClass: .init("8a"), subject: .init("Englisch"), ordinal: 1)
    #expect(LessonMatching.parallelLesson(for: key, targetClass: .init("8b"), timetable: t, nonTeachingPeriods: [], changes: [])
            == LessonKey(date: .init(year: 2026, month: 11, day: 18), schoolClass: .init("8b"), subject: .init("Englisch"), ordinal: 1))
    #expect(LessonMatching.parallelClasses(for: .init("Englisch"), excluding: .init("8a"), timetable: t) == [.init("8b")])
}
@Test("Parallelstunde überspringt Ausfall") func parallelLessonSkipsCancellation()          // Mi 8b ausgefallen → Mi 25.11.
@Test("AK-14: Schlüssel in den Herbstferien hat keine Stunde") func keyInHolidayHasNoLesson() {
    // Ferien 2.–6.11.2026, Di 2. Std 8b; Schlüssel 3.11. und 10.11.
    #expect(LessonMatching.keysWithoutLesson([nov3, nov10], …) == [nov3])
}
@Test("Ausgefallene Stunde zählt als vorhanden") func cancelledLessonIsNotOrphaned()
```

- [ ] **Step 2: Implementieren.** `init(_ date:calendar:)` über `calendar.dateComponents([.year,.month,.day], from:)`; `addingDays`/`weekday` über einen festen gregorianischen Kalender mit Zeitzone UTC (kein Bezug zur Gerätezone). `parallelLesson` läuft Tag für Tag bis `maxDays`, ruft `TimetableCalculator.lessons` und nimmt den ersten Treffer mit `!isCancelled`.
- [ ] **Step 3: Diff durchsehen:** nur `import Foundation`; alles `public`; keine Kollision mit Helfern aus Teilplan 01 (gleichnamige vorhanden → diese nutzen, Datei streichen, im Abschlussbericht nennen).
- [ ] **Step 4: Commit** `feat(core): calendar day navigation and lesson matching`

---

### Task 2: Test-Fakes und Beispieldaten

Design-Takt: keiner

**Files:**
- Create: `FrontstageTests/Support/FakeStore.swift`, `FrontstageTests/Support/FakeStorage.swift`, `FrontstageTests/Support/Fixtures.swift`

**Interfaces:**
- Consumes: `FrontstageStore`, `StorageService`, `TimetableSourceStatusProviding` (oben).
- Produces:
```swift
@MainActor final class FakeStore: FrontstageStore { var timetableValue: Timetable?; var periods: [NonTeachingPeriod]; var changes: [ScheduleChange]; var links: [MaterialLinkItem]; var infos: [LessonKey: LessonInfo]; var manuallyEdited: Set<TimetableEntry>; private(set) var revision: Int }
@MainActor final class FakeStorage: StorageService { var grants: [FolderGrantStatus]; var availabilityByPath: [String: MaterialAvailability]; var rejectURLs: Set<URL>; private(set) var makeReferenceCalls: Int; private(set) var opened: [MaterialReference]; private(set) var prefetched: [[MaterialReference]] }
enum Fixtures {
    static let tue17 = CalendarDay(year: 2026, month: 11, day: 17)   // + wed18, thu19, tue24, nov3
    static let bellSchedule: BellSchedule   // 1: 7:45–8:30, 2: 8:35–9:20, 3: 9:40–10:25, 4: 10:30–11:15, 5: 11:35–12:20, 6: 12:25–13:10
    static func timetable(_ entries: [TimetableEntry], variants: Int = 1, bell: BellSchedule = bellSchedule) -> Timetable  // referenceWeekA 2026-11-16
    static func entry(_ weekday: Weekday, _ period: Int, _ cls: String, _ subject: String, _ variant: WeekVariant? = nil) -> TimetableEntry
    static func reference(_ name: String, _ kind: MaterialFileKind) -> MaterialReference   // grantName "Unterricht", relativePath = name
    static func key(_ day: CalendarDay, _ cls: String, _ subject: String, _ ordinal: Int = 1) -> LessonKey
}
```

- [ ] **Step 1: Fakes schreiben.** `FakeStorage.makeReference` liefert `Fixtures.reference(url.lastPathComponent, …)` nach Dateiendung (`pptx`→presentation, `pdf`→pdf, `docx`→document) und wirft `.outsideGrantedFolders` für URLs in `rejectURLs`, `.notAFile` für Nicht-`file:`-URLs. `FakeStore` setzt Semantik des Protokolls exakt um (anhängen, `setOrder`, `copyMaterialLinks` überspringt gleiche Referenz) und erhöht `revision` bei jeder Änderung.
- [ ] **Step 2: Diff durchsehen:** nur erfundene Materialnamen („Unit 4 – Präsentation“, „Arbeitsblatt Vokabeln“, „Lösung Vokabeln“), Klassen `7a 8a 8b 9c 6c`.
- [ ] **Step 3: Commit** `test: fakes and fixtures for UI view models`

---

### Task 3: Zuordnen, Reihenfolge, Neuverknüpfen (FR-3, FR-3.1, FR-3.4)

Design-Takt: keiner

**Files:**
- Create: `Frontstage/UI/Shared/LessonActions.swift`
- Test: `FrontstageTests/UI/LessonActionsAssignTests.swift`

**Interfaces:**
- Consumes: `FrontstageStore`, `StorageService`.
- Produces:
```swift
@MainActor struct LessonActions {
    init(store: any FrontstageStore, storage: any StorageService)
    /// Je URL ein Verweis, hinten angehängt; bricht bei der ersten ungültigen URL ab, ohne vorher Angelegtes zurückzunehmen.
    @discardableResult func assign(fileURLs: [URL], to key: LessonKey) throws(StorageError) -> [MaterialLinkItem]
    func reorder(_ key: LessonKey, fromOffsets: IndexSet, toOffset: Int)   // Semantik wie Array.move(fromOffsets:toOffset:)
    func relink(linkID: UUID, fileURL: URL) throws(StorageError)
    func remove(linkID: UUID)
}
```

- [ ] **Step 1: Tests schreiben**

```swift
@Test("AK-4: zugeordnete Präsentation steht an der Unterrichtsstunde") func assignAddsLink() throws {
    let items = try actions.assign(fileURLs: [URL(filePath: "/Unterricht/Unit 4 – Präsentation.pptx")], to: Fixtures.key(.tue17, "8b", "Englisch"))
    #expect(store.materialLinks(for: key).map(\.reference.displayName) == ["Unit 4 – Präsentation.pptx"])
    #expect(items.count == 1)
}
@Test("AK-6: Lösung an Position 1") func reorderMovesSolutionFirst() {
    // Präsentation, Arbeitsblatt, Lösung
    actions.reorder(key, fromOffsets: [2], toOffset: 0)
    #expect(store.materialLinks(for: key).map(\.reference.displayName) == ["Lösung Vokabeln", "Unit 4 – Präsentation", "Arbeitsblatt Vokabeln"])
}
@Test("Datei außerhalb der Freigaben legt nichts an") func assignOutsideGrantedFolderStoresNothing() {
    #expect(throws: StorageError.outsideGrantedFolders) { try actions.assign(fileURLs: [rejected], to: key) }
    #expect(store.links.isEmpty)
}
@Test("Neuverknüpfen ersetzt nur den Verweis") func relinkKeepsIDAndPosition()   // id und position unverändert, reference neu
```

- [ ] **Step 2: Implementieren** gemäß Signaturen; `reorder` baut die neue ID-Reihenfolge und ruft `setOrder`.
- [ ] **Step 3: Diff durchsehen:** kein `FileManager`, kein Schreiben in die Ablage; `throws(StorageError)` (typisierte Fehler, Swift 6).
- [ ] **Step 4: Commit** `feat(ui): assign, reorder and relink material`

---

### Task 4: Übernehmen und Schieben (FR-3.2, FR-3.3, FR-8 Weiterreichen)

Design-Takt: keiner

**Files:**
- Modify: `Frontstage/UI/Shared/LessonActions.swift`
- Test: `FrontstageTests/UI/LessonActionsMoveTests.swift`

**Interfaces:**
- Consumes: `LessonMatching` (Aufgabe 1), `TimetableCalculator.nextLesson(after:…)`.
- Produces:
```swift
extension LessonActions {
    func parallelClasses(for key: LessonKey) -> [SchoolClass]
    /// FR-3.2; nil → keine passende Stunde, nichts geändert.
    @discardableResult func copyLinks(from key: LessonKey, toClass: SchoolClass) -> LessonKey?
    /// FR-3.3 für ein Material; nil → keine nächste Stunde, nichts geändert.
    @discardableResult func moveToNextLesson(linkID: UUID, from key: LessonKey) -> LessonKey?
    /// FR-8: alles Material der Stunde; Reihenfolge bleibt, hinten an das Ziel angehängt.
    @discardableResult func passOnAll(from key: LessonKey) -> LessonKey?
    /// Material ohne Stunde einer gewählten Unterrichtsstunde zuordnen (FR-7).
    func move(linkID: UUID, to key: LessonKey)
}
```

- [ ] **Step 1: Tests schreiben**

```swift
@Test("AK-7: Für 8b übernehmen kopiert zwei Zuordnungen, keine Dateien") func copyToParallelClass() {
    // Di 2. Std 8a Englisch mit 2 Materialien, Mi 3. Std 8b Englisch ohne
    #expect(actions.copyLinks(from: tue8a, toClass: .init("8b")) == wed8b)
    #expect(store.materialLinks(for: wed8b).map(\.reference) == store.materialLinks(for: tue8a).map(\.reference))
    #expect(store.materialLinks(for: tue8a).count == 2)
    #expect(storage.makeReferenceCalls == 0)
}
@Test("AK-8: X steht am Donnerstag, nicht mehr am Dienstag") func moveToNextLesson() {
    #expect(actions.moveToNextLesson(linkID: x.id, from: tue8b) == thu8b)
    #expect(store.materialLinks(for: thu8b).map(\.id) == [x.id])     // dieselbe Zuordnung → Stiftnotizen wandern mit
    #expect(store.materialLinks(for: tue8b).isEmpty)
}
@Test("AK-15: Weiterreichen nach Ausfall") func passOnAfterCancellation() {
    store.changes = [.cancellation(tue8b, .manual)]
    #expect(actions.passOnAll(from: tue8b) == thu8b)
    #expect(store.materialLinks(for: thu8b).count == 1)
}
@Test("Ohne nächste Stunde bleibt das Material") func moveToNextLessonWithoutTargetKeepsLink() {
    // Ferien vom 18.11. bis 31.12. → keine 8b-Stunde in 28 Tagen
    #expect(actions.moveToNextLesson(linkID: x.id, from: tue8b) == nil)
    #expect(store.materialLinks(for: tue8b).map(\.id) == [x.id])
}
```

- [ ] **Step 2: Implementieren.** Ziel immer über `TimetableCalculator.nextLesson` bzw. `LessonMatching.parallelLesson` mit `store.timetable()`, `store.nonTeachingPeriods()`, `store.scheduleChanges()`; bei `timetable() == nil` → `nil`.
- [ ] **Step 3: Diff durchsehen:** Schieben ruft `moveMaterialLink` (nie `copy` + `remove`), Übernehmen ruft `copyMaterialLinks`.
- [ ] **Step 4: Commit** `feat(ui): copy to parallel class, move to next lesson, pass on`

---

### Task 5: Ausfall und Vertretungsstunde (FR-8, FR-9)

Design-Takt: keiner

**Files:**
- Modify: `Frontstage/UI/Shared/LessonActions.swift`
- Test: `FrontstageTests/UI/LessonActionsChangesTests.swift`

**Interfaces:**
- Produces:
```swift
enum CancellationResult: Equatable { case changed, unchanged, blockedBySource }
extension LessonActions {
    func setCancelled(_ cancelled: Bool, key: LessonKey) -> CancellationResult
    func addSubstituteLesson(date: CalendarDay, period: Int, schoolClass: SchoolClass, subject: Subject)   // Origin .manual
    /// Nur Herkunft .manual; liefert false bei .source.
    func removeSubstituteLesson(date: CalendarDay, period: Int, schoolClass: SchoolClass, subject: Subject) -> Bool
}
```

- [ ] **Step 1: Tests schreiben**

```swift
@Test("AK-15: Ausfall markieren") func markCancelled() {
    #expect(actions.setCancelled(true, key: tue8b) == .changed)
    #expect(store.changes == [.cancellation(tue8b, .manual)])
}
@Test("Doppelt markiert ergibt eine Abweichung") func markCancelledTwiceStoresOneChange()   // zweites Mal .unchanged, count == 1
@Test("Ausfall aus der Quelle lässt sich nicht von Hand aufheben") func unmarkSourceCancellationIsRejected() {
    store.changes = [.cancellation(tue8b, .source)]
    #expect(actions.setCancelled(false, key: tue8b) == .blockedBySource)
    #expect(store.changes.count == 1)
}
@Test("AK-16: Vertretungsstunde Mi 4. Stunde 6c Mathe") func addSubstituteLesson() {
    actions.addSubstituteLesson(date: .wed18, period: 4, schoolClass: .init("6c"), subject: .init("Mathe"))
    #expect(store.changes == [.substituteLesson(date: .wed18, period: 4, schoolClass: .init("6c"), subject: .init("Mathe"), .manual)])
}
```

- [ ] **Step 2: Implementieren**; Ausfall bereits mit beliebiger Herkunft vorhanden → `setCancelled(true)` liefert `.unchanged`.
- [ ] **Step 3: Diff durchsehen.**
- [ ] **Step 4: Commit** `feat(ui): cancellation and substitute lesson actions`

---

### Task 6: Tagesansicht-Logik (FR-4, FR-7, FR-8, FR-9, Stand der Quelle)

Design-Takt: keiner

**Files:**
- Create: `Frontstage/UI/Shared/LessonRow.swift`, `DayStatement.swift`, `TimetableSourceStatus.swift`, `MaterialOpenAction.swift`
- Create: `Frontstage/App/AppEnvironment.swift` (Abhängigkeitsbündel; Tests bauen es aus `FakeStore`, `FakeStorage`, `ManualTimetableSourceStatus`, `today: { Fixtures.tue17 }`)
- Create: `Frontstage/UI/DayView/DayViewModel.swift`, `Frontstage/UI/DayView/DayViewLayout.swift`
- Test: `FrontstageTests/UI/DayViewModelTests.swift`, `DayViewLayoutTests.swift`

**Interfaces:**
- Consumes: `LessonActions` (3–5), `LessonMatching.keysWithoutLesson`, Protokolle oben.
- Produces:
```swift
enum LessonStatus: Hashable { case regular, substitute, cancelled(Origin) }
struct MaterialRow: Identifiable, Hashable { let item: MaterialLinkItem; let availability: MaterialAvailability; var id: UUID { item.id } }
struct LessonRow: Identifiable, Hashable { let lesson: Lesson; let status: LessonStatus; let materials: [MaterialRow]; let info: LessonInfo?; var id: String { lesson.key.storageText } }
enum DayRow: Identifiable, Hashable { case noLesson(period: Int, time: ClosedRange<TimeOfDay>?); case lesson(LessonRow) }
enum DayContent: Hashable { case nonTeachingDay(title: String); case noLessons; case rows([DayRow]) }
/// Die vier Aussagen aus DESIGN.md – je eigenes Symbol und eigener Text, nie nur Farbe.
enum DayStatement: CaseIterable { case noLesson, lessonWithoutMaterial, materialUnavailable, cancellation
    var symbolName: String { get }; var labelKey: String { get } }
enum SourceStatusPresentation { static func make(_ status: TimetableSourceStatus, now: Date) -> (labelKey: String, date: Date?, isWarning: Bool) }
enum DayViewLayout {
    static let minRowHeight: CGFloat = 44; static let maxRowHeight: CGFloat = 96
    static func rowHeight(availableHeight: CGFloat, rowCount: Int, spacing: CGFloat = 8) -> CGFloat?   // nil → Rückfall auf Scrollen
}
@MainActor @Observable final class DayViewModel {
    init(environment: AppEnvironment)
    var day: CalendarDay
    private(set) var content: DayContent
    private(set) var materialsWithoutLesson: [MaterialLinkItem]
    private(set) var sourceStatus: TimetableSourceStatus
    let actions: LessonActions
    func reload()
    func showPreviousDay(); func showNextDay(); func showToday()
    func openAction(for row: MaterialRow) -> MaterialOpenAction
    func open(_ row: MaterialRow) async
    func refreshSource() async
}
```

Platzhalter-Symbole (SF Symbols, Systemstandard bis zur Design-Runde): `noLesson` → `minus`, `lessonWithoutMaterial` → `tray`, `materialUnavailable` → `exclamationmark.triangle`, `cancellation` → `xmark.circle`.

Zeilenbau (Signatur legt ihn nicht fest):
1. Liegt `day` in einem `NonTeachingPeriod` (`from ≤ day ≤ to`) → `.nonTeachingDay(title:)` des ersten Treffers.
2. Sonst `TimetableCalculator.lessons(on:…)`; leer → `.noLessons`.
3. Sonst für jede Stunde von der kleinsten bis zur größten `period` der Liste: alle Unterrichtsstunden dieser Stunde in Kern-Reihenfolge als `.lesson`, keine → `.noLesson(period:time:)` mit Zeit aus `bellSchedule.periods[period]`.
4. `materialsWithoutLesson` = Zuordnungen des Tages, deren Schlüssel `LessonMatching.keysWithoutLesson` liefert.
5. `reload()` ruft `storage.prefetch` mit dem Material des Tages (Bereithalten selbst gehört Teilplan 03).

- [ ] **Step 1: Tests schreiben**

```swift
@Test("AK-1: jeder Dienstag zeigt 2. Stunde 8b Englisch") func everyTuesdayShowsEntry() {
    // Stundenplan: nur Fixtures.entry(.tuesday, 2, "8b", "Englisch")
    for day in [Fixtures.tue17, Fixtures.tue24] { vm.day = day; vm.reload()
        #expect(lessonRows(vm).map { ($0.lesson.period, $0.lesson.key.schoolClass.normalized, $0.lesson.key.subject.display) } == [(2, "8b", "Englisch")]) }
    vm.day = Fixtures.wed18; vm.reload(); #expect(vm.content == .noLessons)
}
@Test("AK-42: Tagesansicht zeigt die Zeit an der 2. Stunde") func showsBellScheduleTime()   // time == 8:35...9:20
@Test("AK-10: fünf Unterrichtsstunden in zeitlicher Reihenfolge, drei mit Material") func fiveLessonsInOrder() {
    // Di 1–5: 7a Deutsch, 8b Englisch, 9c Englisch, 6c Mathe, 8a Englisch; Material an 1, 2, 5
    #expect(lessonRows(vm).map(\.lesson.period) == [1, 2, 3, 4, 5])
    #expect(lessonRows(vm).map { $0.materials.count } == [1, 3, 0, 0, 1])
}
@Test("AK-10: acht Zeilen passen ohne Scrollen auf 11 Zoll quer") func eightRowsFitElevenInch() {
    // 834 pt Höhe − 24 Status − 50 Leiste − 64 Kopf − 76 Smartboard-Leiste (Teilplan 06) − 100 Ränder = 520
    #expect(DayViewLayout.rowHeight(availableHeight: 520, rowCount: 8)! >= 44)
    #expect(DayViewLayout.rowHeight(availableHeight: 600, rowCount: 5) == 96)
    #expect(DayViewLayout.rowHeight(availableHeight: 600, rowCount: 12) == nil)
}
@Test("Vier Aussagen unterscheiden sich in Symbol und Text") func fourStatementsDistinct() {
    #expect(Set(DayStatement.allCases.map(\.symbolName)).count == 4)
    #expect(Set(DayStatement.allCases.map(\.labelKey)).count == 4)
}
@Test("Lücke, ohne Material, nicht verfügbar, Ausfall erscheinen als verschiedene Zustände") func fourStatementsInRows() {
    // Mockup-Dienstag: 3. Std frei, 4. Std 9c Ausfall (.source), 5. Std 6c Vertretung ohne Material, 6. Std 8a mit unavailable
    #expect(vm.rows[2] == .noLesson(period: 3, time: …))
    #expect(lessonRow(4).status == .cancelled(.source))
    #expect(lessonRow(5).status == .substitute && lessonRow(5).materials.isEmpty)
    #expect(lessonRow(6).materials.first?.availability == .unavailable)
}
@Test("AK-14: Herbstferien – keine Stunden, Material bleibt") func holidayKeepsMaterial() {
    // Ferien 2.–6.11. "Herbstferien", Material am 3.11. an 8b Englisch
    #expect(vm.content == .nonTeachingDay(title: "Herbstferien"))
    #expect(vm.materialsWithoutLesson.map(\.reference.displayName) == ["Arbeitsblatt Vokabeln"])
}
@Test("AK-15: Ausfall erkennbar, Material weiter sichtbar") func cancelledRowKeepsMaterial()
@Test("AK-16: Vertretungsstunde nur am Mittwoch 18.11.") func substituteOnlyOnItsDate() {
    // wed18 → Zeile 4, 6c Mathe, .substitute; wed25 → keine
}
@Test("Ohne Zeitraster bleibt die Stundenreihenfolge") func dayRowsWithoutBellScheduleKeepPeriodOrder()   // periods == [:], time == nil, Reihenfolge 1,2,4
@Test("PDF geht ohne Anzeige an die Übergabe") func openActionWithoutViewer() {
    // viewerAvailable == false, pdf → .handOff; viewerAvailable == true → .viewer; unavailable → .unavailable
}
@Test("Stand der Quelle: drei Fehlschläge warnen") func sourceStatusWarnsAfterThreeFailures() {
    #expect(SourceStatusPresentation.make(.init(kind: .schulmanager, lastSuccessfulUpdate: d, consecutiveFailures: 3), now: n).isWarning)
    #expect(SourceStatusPresentation.make(.init(kind: .manual, lastSuccessfulUpdate: nil, consecutiveFailures: 0), now: n).labelKey == "dayView.source.manual")
}
```

- [ ] **Step 2: Implementieren** nach dem Zeilenbau oben; `rowHeight` = `min(maxRowHeight, (availableHeight − spacing·(n−1)) / n)`, `nil` wenn kleiner `minRowHeight`. Die beiden Grenzwerte sind Platzhalter der offenen Kategorie Dichte.
- [ ] **Step 3: Diff durchsehen:** kein `import SwiftUI` in View-Modell und Zeilen-Modellen (`CGFloat` aus `Foundation`); `Lesson` ist `Hashable`, also genügen die `Hashable`-Ableitungen.
- [ ] **Step 4: Commit** `feat(ui): day view model with four distinct statements`

---

### Task 7: App-Gerüst und Navigation

Design-Takt: Hauptstufe

**Files:**
- Create: `Frontstage/App/AppSection.swift`, `Frontstage/App/RootView.swift`
- Modify: `Frontstage/App/FrontstageApp.swift` (aus Teilplan 01) – erzeugt `AppEnvironment` (Aufgabe 6) mit den echten Diensten
- Test: `FrontstageTests/UI/AppSectionTests.swift`

**Interfaces:**
- Consumes: `FrontstageModelContainer.make()`, `SwiftDataStore`, `FileStorageService`, `ManualTimetableSourceStatus`.
- Produces: `enum AppSection: String, CaseIterable, Hashable { case dayView, preparation, setup; static func initial(isMac: Bool, hasTimetable: Bool) -> AppSection }`; `struct RootView: View`.

- [ ] **Step 1: Test schreiben**

```swift
@Test("Startbereich: ohne Stundenplan Einrichten, sonst iPad Tagesansicht, Mac Vorbereiten") func initialSection() {
    #expect(AppSection.initial(isMac: false, hasTimetable: false) == .setup)
    #expect(AppSection.initial(isMac: false, hasTimetable: true) == .dayView)
    #expect(AppSection.initial(isMac: true, hasTimetable: true) == .preparation)
}
```

- [ ] **Step 2: Implementieren.** `RootView`: `TabView(selection:)` mit drei `Tab`s und `.tabViewStyle(.sidebarAdaptable)` (iPad: Leiste oder Seitenleiste nach Wahl der Lehrkraft, Mac: Seitenleiste). `FrontstageApp` erzeugt `AppEnvironment` einmal und reicht es per `.environment(_:)` weiter; `today` = `CalendarDay(Date(), calendar: .current)`. Szenen-Zubehör für den Zweitbildschirm meldet Teilplan 06 an `RootView` an – hier nur ein Kommentar an der Stelle.
- [ ] **Step 3: Strings:** `app.section.dayView` „Heute“, `app.section.preparation` „Vorbereiten“, `app.section.setup` „Einrichten“ (Platzhalter, Kategorie Wortlaut offen).
- [ ] **Step 4: Diff durchsehen:** `@MainActor` an `AppEnvironment`; `ModelContainer`-Fehler beim Start führt zu einer Fehleransicht, nicht zu `fatalError`.
- [ ] **Step 5: Commit** `feat(app): root navigation between day view, preparation and setup`

---

### Task 8: Tagesansicht (Oberfläche)

Design-Takt: voll

**Files:**
- Create: `Frontstage/UI/DayView/DayView.swift`, `DayRowView.swift`, `SourceStatusView.swift`

**Interfaces:**
- Consumes: `DayViewModel`, `DayViewLayout`, `DayStatement`, `SourceStatusPresentation` (Aufgabe 6).
- Produces: `struct DayView: View { init(model: DayViewModel) }` – Teilplan 06 legt die Smartboard-Leiste per `.safeAreaInset(edge: .bottom)` darunter; die Höhe kommt damit automatisch aus dem `GeometryReader`.

- [ ] **Step 1: Bauen.** Kopf: Datum groß, Vor/Zurück/Heute in der Symbolleiste, rechts `SourceStatusView` (Text aus `SourceStatusPresentation`, bei `.schulmanager` Knopf „Aktualisieren“ → `refreshSource()`). Inhalt: `GeometryReader` → `DayViewLayout.rowHeight`; Wert vorhanden → `VStack` fester Zeilenhöhe, `nil` → `ScrollView`. Je Zeile: Stunde, Zeit, Klasse, Fach, Material als Knöpfe in Reihenfolge (`ViewThatFits`: alle Namen → gekürzte Namen → erster Name plus Anzahl). Jede der vier Aussagen zeigt `DayStatement.symbolName` **und** Text, nie nur Farbe. Ausgefallene Stunde: Kontextmenü „Ausfall aufheben“ (nur `.manual`), „Material weiterreichen“; Material: „In die nächste Stunde“, nicht verfügbar → „Neu verknüpfen“ über `.fileImporter`. Unter der Liste „Material ohne Stunde“ mit „Zuordnen …“ (Auswahl einer Unterrichtsstunde der nächsten 14 Tage). `.onChange(of: environment.store.revision) { model.reload() }`.
- [ ] **Step 2: Strings** unter `dayView.*` (u. a. `dayView.noLesson`, `dayView.withoutMaterial`, `dayView.unavailable`, `dayView.cancelled`, `dayView.substitute`, `dayView.withoutLesson`, `dayView.source.manual`, `dayView.source.schulmanager`, `dayView.source.stale`).
- [ ] **Step 3: Diff durchsehen:** VoiceOver-Text je Zeile nennt Aussage in Worten (`accessibilityLabel`); Zielgröße der Knöpfe ≥ 44 pt.
- [ ] **Step 4: Prüfung `apple-design`** (Design-Takt voll) auf den Diff; Befunde gegen offene Kategorien nur benennen, nicht entscheiden.
- [ ] **Step 5: Commit** `feat(ui): day view`

---

### Task 9: Vorbereiten-Logik (Woche, Stundenangaben)

Design-Takt: keiner

**Files:**
- Create: `Frontstage/UI/Preparation/PreparationViewModel.swift`, `Frontstage/UI/Preparation/LessonInfoEditor.swift`
- Test: `FrontstageTests/UI/PreparationViewModelTests.swift`, `LessonInfoEditorTests.swift`

**Interfaces:**
- Consumes: Zeilenbau aus `DayViewModel` – dafür die Zeilenbildung aus Aufgabe 6 als `static func DayViewModel.content(for day: CalendarDay, store:, storage:) -> (DayContent, [MaterialLinkItem])` herausziehen und hier wiederverwenden.
- Produces:
```swift
struct PreparationDay: Identifiable, Hashable { let date: CalendarDay; let content: DayContent; let materialsWithoutLesson: [MaterialLinkItem]; var id: CalendarDay { date } }
@MainActor @Observable final class PreparationViewModel {
    init(environment: AppEnvironment)
    private(set) var weekStart: CalendarDay          // immer ein Montag
    private(set) var days: [PreparationDay]          // Mo–Fr, Sa/So nur bei Einträgen an diesen Tagen
    var selection: LessonKey?
    let actions: LessonActions
    func reload(); func showPreviousWeek(); func showNextWeek(); func showThisWeek()
    func upcomingLessons(days: Int) -> [Lesson]      // Ziele für „Material ohne Stunde zuordnen“, ab heute
}
@MainActor @Observable final class LessonInfoEditor {
    init(key: LessonKey, store: any FrontstageStore)
    var topic: String; var toPrepare: String; var homework: String
    func save()   // getrimmt; leer → nil (FR-11.1: leere Felder zeigt der Klassenbildschirm nicht)
}
```

- [ ] **Step 1: Tests schreiben**

```swift
@Test("AK-4: zugeordnet im Vorbereiten, sichtbar in der Tagesansicht") func preparationAssignShowsInDayView() throws {
    // heute Mo 16.11., Stundenplan Di 2. Std 8b; Zuordnung über prep.actions an den Schlüssel aus prep.days[1]
    dayVM.day = Fixtures.tue17; dayVM.reload()
    #expect(lessonRows(dayVM).first { $0.lesson.period == 2 }?.materials.map(\.item.reference.displayName) == ["Unit 4 – Präsentation.pptx"])
}
@Test("Woche beginnt am Montag") func weekStartsMonday()   // today tue17 → weekStart 16.11., days.map(\.date) == 16.–20.11.
@Test("AK-14: Ferientag mit Material ohne Stunde in der Woche") func weekShowsMaterialWithoutLesson()   // Woche 2.11., days[1].content == .nonTeachingDay
@Test("Leere Felder werden nil") func emptyFieldsBecomeNil() {
    editor.topic = "Unit 4 – Wortschatz"; editor.toPrepare = "  "; editor.save()
    #expect(store.lessonInfo(for: key) == LessonInfo(topic: "Unit 4 – Wortschatz", toPrepare: nil, homework: nil))
}
```

- [ ] **Step 2: Implementieren.** `weekStart = today().mondayOfWeek`; Wochenwechsel ±7 Tage.
- [ ] **Step 3: Diff durchsehen:** `DayViewModel` nutzt danach dieselbe statische Funktion (kein doppelter Zeilenbau).
- [ ] **Step 4: Commit** `feat(ui): preparation week model and lesson info editor`

---

### Task 10: Vorbereiten (Oberfläche) – Woche, Zuordnen per Ziehen und Dateiauswahl

Design-Takt: voll

**Files:**
- Create: `Frontstage/UI/Preparation/PreparationView.swift`, `LessonDetailView.swift`, `MaterialDropTarget.swift`, `SubstituteLessonSheet.swift`

**Interfaces:**
- Consumes: `PreparationViewModel`, `LessonInfoEditor`, `LessonActions`.
- Produces: `struct PreparationView: View { init(model: PreparationViewModel) }`; `struct MaterialDropTarget: ViewModifier { init(key: LessonKey, actions: LessonActions, onError: @escaping (StorageError) -> Void) }`.

- [ ] **Step 1: Woche bauen.** `NavigationSplitView`: Inhalt = Woche (je Tag eine Spalte am Mac und auf dem iPad quer, sonst Liste je Tag – Systemstandard, Aufbau ist offene Kategorie), Detail = `LessonDetailView` der `selection`. Wochenwechsel in der Symbolleiste, „Vertretungsstunde“ öffnet `SubstituteLessonSheet` (Datum, Stunde aus Zeitraster oder 1–10, Klasse, Fach; Herkunft `.manual`).
- [ ] **Step 2: Zuordnen.** `MaterialDropTarget` an jeder Unterrichtsstunde und am Detail: `.dropDestination(for: URL.self, isEnabled: true) { urls, session in … }` (iOS/macOS 26, siehe Quellen) → `actions.assign(fileURLs:to:)`; am Mac zieht die Lehrkraft aus dem Finder, am iPad aus der Dateien-App in Split View. Zusätzlich Knopf „Material hinzufügen“ → `.fileImporter(isPresented:allowedContentTypes: [.item], allowsMultipleSelection: true)`. Fehler `.outsideGrantedFolders` → Hinweis mit Knopf „Ordner freigeben“ (springt zu Einrichten › Ablage).
- [ ] **Step 3: Detail.** Materialliste mit `ForEach(...).onMove { actions.reorder(key, fromOffsets:toOffset:) }` (Mac: Ziehen in der Liste; iPad: Bearbeiten-Modus), Entfernen; Aktionen „Für <Klasse> übernehmen“ (Menü aus `parallelClasses`, `nil` → Hinweis „keine passende Unterrichtsstunde“), „In die nächste Stunde“, „Ausfall“ (Umschalter; `.blockedBySource` → Hinweis „laut Stundenplan-Quelle“), „Material weiterreichen“; Felder Thema, Bereitlegen, Hausaufgabe (`LessonInfoEditor`, Speichern bei `onSubmit` und `onDisappear`). Material ohne Stunde je Tag mit „Zuordnen …“ (`upcomingLessons(days: 14)`).
- [ ] **Step 4: Strings** unter `preparation.*` und `lesson.*` (`lesson.copyTo`, `lesson.moveToNext`, `lesson.passOn`, `lesson.cancel`, `lesson.topic`, `lesson.toPrepare`, `lesson.homework`, `preparation.addMaterial`, `preparation.grantFolder`, `preparation.substitute`).
- [ ] **Step 5: Diff durchsehen:** nur `dropDestination(for:isEnabled:action:)`, nicht die veraltete Form; `UTType` per `import UniformTypeIdentifiers`.
- [ ] **Step 6: Prüfung `apple-design`** (Design-Takt voll).
- [ ] **Step 7: Commit** `feat(ui): preparation week with drag, file picker and lesson detail`

---

### Task 11: Einrichten – Stundenplan von Hand, A/B-Woche, Bezugswoche (FR-1, FR-1.1)

Design-Takt: Hauptstufe

**Files:**
- Create: `Frontstage/UI/Setup/SetupView.swift`, `TimetableEditorViewModel.swift`, `TimetableEditorView.swift`, `TimetableEntrySheet.swift`
- Test: `FrontstageTests/UI/TimetableEditorViewModelTests.swift`

**Interfaces:**
- Produces:
```swift
enum TimetableEditError: Error, Equatable { case emptyClass, emptySubject, invalidPeriod, duplicate }
@MainActor @Observable final class TimetableEditorViewModel {
    init(environment: AppEnvironment)
    private(set) var weekVariantCount: Int         // 1 oder 2; ohne Stundenplan 1
    private(set) var referenceWeekA: CalendarDay   // immer ein Montag
    var shownVariant: WeekVariant                  // Ansicht bei 2 Varianten
    func entries(weekday: Weekday, period: Int) -> [TimetableEntry]   // shownVariant oder nil
    func save(_ entry: TimetableEntry, replacing old: TimetableEntry?) throws(TimetableEditError)
    func delete(_ entry: TimetableEntry)
    func setReferenceWeek(containing day: CalendarDay)
    /// 2 → 1 mit variantenspezifischen Einträgen: liefert die Zahl der B-Einträge und ändert nichts, bis confirmed == true.
    func setWeekVariantCount(_ count: Int, confirmed: Bool) -> Int?
    var periodChoices: [Int] { get }               // Schlüssel des Zeitrasters, leer → 1…10
}
struct SetupView: View   // Liste: Stundenplan, Zeitraster, Unterrichtsfrei, Ablage, Stundenplan-Quelle (Platz für Teilplan 05)
```

- [ ] **Step 1: Tests schreiben**

```swift
@Test("AK-1: Eintrag Di 2. Std 8b Englisch anlegen") func addEntryFromEmpty() throws {
    try vm.save(Fixtures.entry(.tuesday, 2, "8b", "Englisch"), replacing: nil)
    #expect(store.timetableValue?.entries == [Fixtures.entry(.tuesday, 2, "8b", "Englisch")])
    #expect(store.manuallyEdited.contains(Fixtures.entry(.tuesday, 2, "8b", "Englisch")))
}
@Test("AK-2 Logik: A-Woche 7a, B-Woche 9c") func abWeeksResolve() throws {
    _ = vm.setWeekVariantCount(2, confirmed: false); vm.setReferenceWeek(containing: .init(year: 2026, month: 11, day: 18))
    #expect(vm.referenceWeekA == .init(year: 2026, month: 11, day: 16))
    // Mo 1. Std 7a (.a), Mo 1. Std 9c (.b) → DayViewModel 16.11. zeigt 7a, 23.11. zeigt 9c
}
@Test("Leere Klasse wird abgelehnt") func emptyClassRejected()        // "  " → .emptyClass
@Test("Doppelter Eintrag wird abgelehnt") func duplicateRejected()   // .duplicate
@Test("Zurück auf eine Variante verlangt Bestätigung") func reducingToOneVariantRequiresConfirmation() {
    // 2 Varianten, ein .b-Eintrag
    #expect(vm.setWeekVariantCount(1, confirmed: false) == 1)
    #expect(vm.weekVariantCount == 2)
    // confirmed: true → .b-Einträge gelöscht, .a-Einträge werden nil
}
```

- [ ] **Step 2: Implementieren.** Bezugswoche = `day.mondayOfWeek`; Klasse/Fach über `SchoolClass(_:)`/`Subject(_:)`, leer nach `normalized` → Fehler. Ansicht: Raster Wochentag × Stunde (Systemstandard `Grid`), Tipp auf Feld → `TimetableEntrySheet` (Klasse, Fach, bei 2 Varianten „gilt für: beide / A / B“).
- [ ] **Step 3: Strings** unter `setup.timetable.*`.
- [ ] **Step 4: Diff durchsehen.**
- [ ] **Step 5: Commit** `feat(ui): manual timetable editor with A/B weeks`

---

### Task 12: Einrichten – Zeitraster (FR-1.2)

Design-Takt: Hauptstufe

**Files:**
- Create: `Frontstage/UI/Setup/BellScheduleEditorViewModel.swift`, `BellScheduleEditorView.swift`
- Test: `FrontstageTests/UI/BellScheduleEditorViewModelTests.swift`

**Interfaces:**
- Produces:
```swift
enum BellScheduleError: Error, Equatable { case endNotAfterStart, overlaps(period: Int) }
@MainActor @Observable final class BellScheduleEditorViewModel {
    init(environment: AppEnvironment)
    private(set) var schedule: BellSchedule
    func set(period: Int, start: TimeOfDay, end: TimeOfDay) throws(BellScheduleError)
    func addPeriod()        // nächste Nummer; Beginn = Ende der vorigen + 5 min, Dauer 45 min; leer → 1: 8:00–8:45
    func removeLastPeriod()
}
```

- [ ] **Step 1: Tests schreiben**

```swift
@Test("AK-42: 2. Stunde auf 8:35–9:20") func setSecondPeriod() throws {
    try vm.set(period: 2, start: .init(hour: 8, minute: 35), end: .init(hour: 9, minute: 20))
    #expect(store.timetableValue?.bellSchedule.periods[2] == TimeOfDay(hour: 8, minute: 35)...TimeOfDay(hour: 9, minute: 20))
}
@Test("Ende vor Beginn wird abgelehnt") func endBeforeStartRejected()          // .endNotAfterStart
@Test("Überschneidung mit der 1. Stunde wird abgelehnt") func overlapRejected() // 1: 7:45–8:30, 2: 8:20–9:05 → .overlaps(period: 1)
```

- [ ] **Step 2: Implementieren**; Ansicht: Liste je Stunde mit zwei `DatePicker(displayedComponents: .hourAndMinute)`.
- [ ] **Step 3: Diff durchsehen;** `Date` ↔ `TimeOfDay` nur in der View.
- [ ] **Step 4: Commit** `feat(ui): bell schedule editor`

---

### Task 13: Einrichten – unterrichtsfreie Zeiträume und Material ohne Stunde (FR-7)

Design-Takt: Hauptstufe

**Files:**
- Create: `Frontstage/UI/Setup/NonTeachingPeriodsViewModel.swift`, `NonTeachingPeriodsView.swift`
- Test: `FrontstageTests/UI/NonTeachingPeriodsViewModelTests.swift`

**Interfaces:**
- Produces:
```swift
enum NonTeachingPeriodError: Error, Equatable { case fromAfterTo }
@MainActor @Observable final class NonTeachingPeriodsViewModel {
    init(environment: AppEnvironment)
    private(set) var periods: [NonTeachingPeriod]                       // nach from sortiert
    func add(from: CalendarDay, to: CalendarDay, title: String) throws(NonTeachingPeriodError)   // leerer Titel → Text aus setup.nonTeaching.defaultTitle
    func remove(_ period: NonTeachingPeriod)
    func materialsWithoutLesson(in period: NonTeachingPeriod) -> [MaterialLinkItem]
    let actions: LessonActions                                          // move(linkID:to:)
}
```

- [ ] **Step 1: Tests schreiben**

```swift
@Test("AK-14: Material in den Herbstferien bleibt und lässt sich verschieben") func holidayMaterialCanBeMoved() throws {
    try vm.add(from: .init(year: 2026, month: 11, day: 2), to: .init(year: 2026, month: 11, day: 6), title: "Herbstferien")
    let orphan = vm.materialsWithoutLesson(in: vm.periods[0])
    #expect(orphan.map(\.reference.displayName) == ["Arbeitsblatt Vokabeln"])
    vm.actions.move(linkID: orphan[0].id, to: Fixtures.key(.init(year: 2026, month: 11, day: 10), "8b", "Englisch"))
    #expect(vm.materialsWithoutLesson(in: vm.periods[0]).isEmpty)
}
@Test("Von nach Bis wird abgelehnt") func fromAfterToRejected()
@Test("Zeitraum entfernen löscht kein Material") func removeKeepsLinks()   // store.links.count unverändert
```

- [ ] **Step 2: Implementieren;** Ansicht: Liste der Zeiträume, je Zeitraum Zahl des Materials ohne Stunde und Aufklappliste mit „Zuordnen …“.
- [ ] **Step 3: Diff durchsehen.**
- [ ] **Step 4: Commit** `feat(ui): non-teaching periods with orphaned material`

---

### Task 14: Einrichten – Ablage-Freigaben und Platz für die Stundenplan-Quelle

Design-Takt: Hauptstufe

**Files:**
- Create: `Frontstage/UI/Setup/StorageSettingsViewModel.swift`, `StorageSettingsView.swift`
- Modify: `Frontstage/UI/Setup/SetupView.swift`
- Test: `FrontstageTests/UI/StorageSettingsViewModelTests.swift`

**Interfaces:**
- Produces:
```swift
@MainActor @Observable final class StorageSettingsViewModel {
    init(environment: AppEnvironment)
    private(set) var grants: [FolderGrantStatus]
    var missingOnThisDevice: [FolderGrantStatus] { get }   // isAvailableOnThisDevice == false
    func add(folderURL: URL) throws
    func remove(name: String)
}
```
`SetupView` zeigt unter „Stundenplan-Quelle“ für 05 den Platzhalter `TimetableSourceSettingsSlot` (bis 05: Text „Von Hand“).

- [ ] **Step 1: Tests schreiben**

```swift
@Test("Fehlende Freigabe auf diesem Gerät wird gemeldet") func missingGrantListed()   // grants "Unterricht" (true), "Klausuren" (false) → missing == ["Klausuren"]
@Test("Freigabe entfernen löscht keine Zuordnung") func removeGrantKeepsLinks()
```

- [ ] **Step 2: Implementieren;** Ansicht: Liste, „Ordner freigeben“ → `.fileImporter(allowedContentTypes: [.folder], allowsMultipleSelection: false)`, fehlende Freigaben mit Knopf „Hier freigeben“.
- [ ] **Step 3: Diff durchsehen.**
- [ ] **Step 4: Commit** `feat(ui): storage folder grants in setup`

---

### Task 15: CI-Lauf (workflow_dispatch) und Ergebnis prüfen

Design-Takt: keiner

- [ ] **Step 1: Diff des ganzen Teilplans durchsehen** gegen die Global Constraints (ADR-0002-Regeln unberührt, kein `import SwiftUI` in View-Modellen, englische Bezeichner, deutsche Kommentare, Strings nur in `Localizable.xcstrings`).
- [ ] **Step 2: Lauf anstoßen**

```bash
gh workflow run ci.yml --ref feature/<branch-dieses-teilplans>
gh run watch
```
Erwartet: Job grün; `swift test` mit `LessonMatchingTests`, `CalendarDayNavigationTests`; `xcodebuild test` mit allen `FrontstageTests/UI/*`-Tests grün, beide Ziele (iPadOS, macOS) bauen.
- [ ] **Step 3: Bei Rot** `superpowers:systematic-debugging`, alle Fehler im Log sammeln, gesammelt beheben, **ein** neuer Lauf.

---

### Task 16: Erster TestFlight-Bau

Design-Takt: keiner

**Files:**
- Create: `.github/workflows/testflight.yml`, `ci/ExportOptions-TestFlight.plist`
- Modify: `project.yml` (`ITSAppUsesNonExemptEncryption: NO` in den Info.plist-Eigenschaften beider Ziele; `CURRENT_PROJECT_VERSION` aus Umgebung)

**Voraussetzungen (Mensch, einmalig):** Apple-Entwicklerkonto (RISK-4); App-Eintrag in App Store Connect; CloudKit-Container aus Teilplan 02 angelegt; App-Store-Connect-API-Schlüssel (Rolle „App Manager“). Secrets im Repo: `APPLE_TEAM_ID`, `BUNDLE_ID_PREFIX`, `ASC_KEY_ID`, `ASC_ISSUER_ID`, `ASC_KEY_P8_BASE64`. Nur interne Tester, solange Q-31 offen ist.

- [ ] **Step 1: Workflow schreiben.** Auslöser nur `workflow_dispatch`. Schritte: Checkout → `brew install xcodegen` → `xcodegen generate` → API-Schlüssel aus `ASC_KEY_P8_BASE64` nach `$RUNNER_TEMP/AuthKey.p8` → 
```bash
xcodebuild archive -project Frontstage.xcodeproj -scheme Frontstage-iOS -destination 'generic/platform=iOS' \
  -archivePath build/Frontstage-iOS.xcarchive DEVELOPMENT_TEAM="$APPLE_TEAM_ID" \
  PRODUCT_BUNDLE_IDENTIFIER="$BUNDLE_ID_PREFIX.frontstage" CURRENT_PROJECT_VERSION="$GITHUB_RUN_NUMBER" \
  -allowProvisioningUpdates -authenticationKeyPath "$RUNNER_TEMP/AuthKey.p8" \
  -authenticationKeyID "$ASC_KEY_ID" -authenticationKeyIssuerID "$ASC_ISSUER_ID"
xcodebuild -exportArchive -archivePath build/Frontstage-iOS.xcarchive -exportOptionsPlist ci/ExportOptions-TestFlight.plist \
  -exportPath build/export -allowProvisioningUpdates -authenticationKeyPath "$RUNNER_TEMP/AuthKey.p8" \
  -authenticationKeyID "$ASC_KEY_ID" -authenticationKeyIssuerID "$ASC_ISSUER_ID"
```
  Schlüsseldatei am Ende löschen (`if: always()`). Zweiter Job gleich für `Frontstage-macOS` mit `-destination 'generic/platform=macOS'`. Schema-Namen aus Teilplan 01 übernehmen, falls sie abweichen.
- [ ] **Step 2: `ExportOptions-TestFlight.plist`:** `method` = `app-store-connect`, `destination` = `upload`, `signingStyle` = `automatic`, `teamID` als Platzhalter `$(APPLE_TEAM_ID)` – im Workflow vor dem Export per `plutil -replace teamID -string "$APPLE_TEAM_ID"` gesetzt. Quelle: `xcodebuild -help` (Abschnitt „Available keys for -exportOptionsPlist“) am Runner – Step 3 gibt ihn ins Log aus, um die Schlüssel zu belegen.
- [ ] **Step 3: Diff durchsehen:** keine echte Team-ID, Bundle-ID oder Schlüssel im Repo; `xcodebuild -help | sed -n '/exportOptionsPlist/,/^$/p'` als erster Schritt im Workflow.
- [ ] **Step 4: Lauf** `gh workflow run testflight.yml --ref <branch>`, `gh run watch`. Erwartet: beide Jobs grün; in App Store Connect › TestFlight erscheint Build `$GITHUB_RUN_NUMBER` für iPadOS und macOS.
- [ ] **Step 5: Commit** `ci: archive and upload to TestFlight`

---

### Task 17: Geräte-Checkliste AK-5 (und Sichtprüfungen)

Design-Takt: keiner – Mensch mit iPad (11 Zoll) und Mac, gleiche Apple-ID, TestFlight-Bau aus Aufgabe 16.

| # | Schritte | Erwartet | ✓ |
|---|---|---|---|
| AK-5 | Am iPad: Einrichten › Ablage Ordner freigeben; Stundenplan „Di 2. Std 8b Englisch“; Vorbereiten › kommender Dienstag › Material hinzufügen (Dateiauswahl) → Präsentation | Am Mac (Ordner dort einmal freigegeben) zeigt Vorbereiten und Tagesansicht dieses Dienstags die Präsentation in der 2. Stunde, ohne Zutun, binnen etwa einer Minute | ☐ |
| AK-4 Gerät | Am Mac Präsentation aus dem Finder auf die Unterrichtsstunde ziehen | Am iPad in der Tagesansicht sichtbar; belegt `dropDestination` mit Finder-Dateien | ☐ |
| AK-10 Gerät | iPad 11 Zoll quer und hoch, Dienstag mit 5 Unterrichtsstunden, 3 mit Material | alle 5 ohne Scrollen, mit Klasse, Fach, Material | ☐ |
| iPad-Ziehen | Dateien-App in Split View, Datei auf eine Unterrichtsstunde ziehen | wird zugeordnet | ☐ |
| Vier Aussagen | Tagesansicht mit freier Stunde, Stunde ohne Material, nicht verfügbarem Material, Ausfall; zusätzlich Bildschirm in Graustufen (Bedienungshilfen) | alle vier ohne Farbe unterscheidbar | ☐ |

---

### Task 18: Design-Runden 1–10 mit Andreas über `/design:design-runde`

Design-Takt: (Entscheid-Takt) – **nie unbeaufsichtigt**; ein Lauf über `phased-autonomous-delivery` endet vor dieser Aufgabe und legt sie morgens vor.

- [ ] **Step 1: Eingang sammeln:** alle „offene Kategorie“-Zeilen aus den Abschlussberichten der Aufgaben 7–14 plus „Was die Mockups offen gelassen haben“ in `mockup/LIESMICH.md` (Anrede/Wortlaut, Akzentfarbe, Zustandsdarstellung der vier Aussagen, Dichte und Überlauf, Aufbau Vorbereiten, Aufbau der App, Status „auf dem Gerät“, Stand der Quelle, Q-19).
- [ ] **Step 2: Je Runde** `/design:design-runde` mit Andreas: eine Kategorie, 3–4 an der echten Oberfläche (TestFlight-Bau oder Simulator-Bildschirmfotos aus CI) gerenderte Varianten, Ist-Zustand als Option A. Reihenfolge der Kategorien gibt der Befehl vor.
- [ ] **Step 3: Rückfluss im selben Durchgang:** Beschluss als `### UI-n — …` in `DESIGN.md` (nächste freie Nummer nach UI-1 im Hauptstand prüfen), Zeile unter `## Changes`; beantwortete `Q-n` durchstreichen. Änderung per Pull Request mit Review.
- [ ] **Step 4:** Folgearbeit an der Oberfläche als eigene Aufgaben in einem neuen Plan, nicht in dieser Runde bauen.

---

## Abdeckung

| Anforderung / AK | Aufgabe |
|---|---|
| FR-1, AK-1 | 11 (Anlegen), 6 (Tagesansicht) |
| FR-1.1 (AK-2 Logik) | 11 |
| FR-1.2, AK-42 (Tagesansicht-Teil) | 12, 6 |
| FR-3, AK-4 | 3, 9, 10; AK-5 → 17 |
| FR-3.1, AK-6 | 3, 10 |
| FR-3.2, AK-7 | 1, 4, 10 |
| FR-3.3, AK-8 | 4, 8, 10 |
| FR-3.4 | 3, 4 (keine Dateioperation; AK-9 Gerät gehört Teilplan 03) |
| FR-4, AK-10 | 6, 8, 17 |
| FR-7, AK-14 | 1, 6, 9, 13 |
| FR-8, AK-15 | 4, 5, 6, 8, 10 |
| FR-9, AK-16 | 5, 6, 10 |
| FR-11.1 (Eingabe Thema/Bereitlegen/Hausaufgabe) | 9, 10 |
| Stand der Stundenplan-Quelle | 6, 8 |

## Self-Review

- **Spec-Abdeckung:** alle zugewiesenen FR/AK zugeordnet. Nicht hier: AK-3, AK-21, AK-41 (Teilplan 05, Import-Oberfläche nur als Platz in Aufgabe 14), AK-9, AK-11, AK-12, AK-17, AK-19 (Ablage, 03), AK-13, AK-22, AK-23 (Anzeige, 06), AK-24 bis AK-40 (06/07).
- **Typen:** `LessonActions` wächst über 3–5 und wird in 6, 9, 10, 13 nur konsumiert; `DayContent`/`DayRow` in 6 definiert und in 9 wiederverwendet; `MaterialOpenAction` und `AppEnvironment.viewerAvailable` sind die Naht zu 06.
- **Proportion:** Funktionskörper nur für Zeilenbau, `rowHeight` und Zielsuche beschrieben, sonst Signaturen und Tests.

## Abstimmungsbedarf

- **Teilplan 01:** öffentliche Initialisierer von `CalendarDay`, `TimeOfDay`, `LessonKey`, `TimetableEntry`; Semantik `weekVariant == nil` = beide Wochen; mögliche Doppelung von `CalendarDay.addingDays/weekday/mondayOfWeek/init(_:calendar:)` (Aufgabe 1); Schema-Namen `Frontstage-iOS`/`Frontstage-macOS`; App-Testziel `FrontstageTests` in `project.yml` und in `ci.yml`.
- **Teilplan 02:** `FrontstageStore` (vollständiges Protokoll oben), `SwiftDataStore`, `FrontstageModelContainer`, `MaterialLinkItem`, `LessonInfo`, Markierung „von Hand geändert“ in `upsertEntry`; `revision` als beobachtbarer Zähler.
- **Teilplan 03:** `StorageService`, `FileStorageService`, `MaterialReference`, `MaterialFileKind`, `MaterialAvailability`, `FolderGrantStatus`, `StorageError` mit `.outsideGrantedFolders`/`.notAFile`.
- **Teilplan 05:** erfüllt `TimetableSourceStatusProviding` mit `TimetableSourceStatus`/`TimetableSourceKind`; füllt `TimetableSourceSettingsSlot` in `SetupView` (Einrichten der Quelle, Import-Vorschau AK-3).
- **Teilplan 06:** setzt `AppEnvironment.viewerAvailable`, behandelt `MaterialOpenAction.viewer`, legt die Smartboard-Leiste per `.safeAreaInset` unter `DayView` und meldet das Szenen-Zubehör an `RootView` an.
- **Glossar:** kein neuer Fachbegriff; `Origin.source` in der Oberfläche als „laut Stundenplan-Quelle“ (Wortlaut offen).
