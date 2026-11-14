# Teilplan 04 — Oberfläche Kern: Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.
> Rahmen: `docs/superpowers/plans/2026-11-13-00-uebersicht.md` — gilt vollständig (insbesondere Abstimmung Punkte 14 und 15). **Aufgabe 18 (Design-Runden) läuft nie unbeaufsichtigt; Aufgabe 17 braucht einen Menschen mit Geräten.**
> **Überarbeitet 2026-11-14:** Dienste mit `DataStore` entstehen in `ScopedAppContent` innerhalb von `DataScopedRoot` (Teilplan 08); `RelinkResult.saveFailed`, Ladezustand während `StorageService.open` wartet, Hinweis beim Abmelden von Microsoft bei Datenort OneDrive; Naht `PenNoteFileRelocating` für Stiftnotizen neben dem Dokument (ADR-0011, gefüllt von Teilplan 06).

**Goal:** Die drei Bildschirme des Kerns bauen – Tagesansicht, Vorbereiten, Einrichten – samt App-Gerüst und Navigation auf iPad und Mac, sodass eine Lehrkraft einen Stundenplan anlegt, Material zuordnet, Ausfall und Vertretung pflegt und im Unterricht den Tag sieht; danach der erste TestFlight-Bau und die Design-Runden 1–10.

**Architecture:** Jede Ansicht hat ein `@MainActor @Observable`-View-Modell ohne SwiftUI-Import, das nur über zwei schmale Protokolle spricht, die dieser Teilplan selbst anlegt (Übersicht, Abstimmung Punkt 4): `PreparationStore` (Daten; `extension DataStore: PreparationStore` ruft nur vorhandene `DataStore`-Methoden aus Teilplan 02) und `MaterialStorage` (Ablage; `extension StorageService: MaterialStorage` mit den Signaturen aus Teilplan 03). Stand und Einrichten der Stundenplan-Quelle kommen als fertige Ansichten aus Teilplan 05 und werden hier nur eingehängt. Alle Rechnung über Unterrichtsstunden liegt in Teilplan 01/02 (`TimetableCalculator`, `ParallelLessonFinder`, `DataStore`); dieser Teilplan legt **keine** Kern-Typen an. Die Tests prüfen die View-Modelle gegen einen echten `DataStore` im Speicher (`makeStore()`, Teilplan 02) und eine Attrappe von `MaterialStorage`; die Views selbst sind dünn und ohne Logik.

**Tech Stack:** SwiftUI (`TabView` mit `.sidebarAdaptable`, `NavigationSplitView`, `.fileImporter`, `.dropDestination(for:isEnabled:action:)`), Observation (`@Observable`), Swift Testing, GitHub Actions (`xcodebuild archive` / `-exportArchive`).

**Spec:** `docs/PRD.md` (FR-1, FR-1.1, FR-1.2, FR-3 bis FR-3.4, FR-4, FR-7, FR-8, FR-9, FR-11.1 als Eingabe; AK-1, AK-4 bis AK-8, AK-10, AK-14 bis AK-16, AK-42 Tagesansichts-Teil), `docs/ARCHITECTURE.md` (Area plattform, daten, ablage, stundenplan-quellen), ADR-0002, ADR-0003, ADR-0005, ADR-0008, ADR-0009, ADR-0011 (Stiftnotizen neben dem Dokument – nur die Naht), ADR-0012 (Datenort – Abmelde-Hinweis), `DESIGN.md` (Wiederkehrende Fallen), `mockup/tagesansicht.html`, `mockup/vorbereiten.html`, `mockup/einrichten.html`, `mockup/LIESMICH.md` (Beispieldaten, offene Gestaltungsfragen).

## Global Constraints

Alle Zeilen aus „Global Constraints“ und „Gestaltung in den Aufgaben“ der Übersicht gelten. Zusätzlich für diesen Teilplan:

- **Quellen der verwendeten Apple-APIs** (gelesen 2026-11-13 über `developer.apple.com/tutorials/data/documentation/…json`):
  - `dropDestination(for:isEnabled:action:)` mit `action: ([T], DropSession) -> Void` – **iOS/macOS 26.0**; die ältere Form `dropDestination(for:action:isTargeted:)` ist ab 27.3 als veraltet markiert → nur die neue Form nutzen. `DropSession.location: CGPoint` ab 26.0.
  - `fileImporter(isPresented:allowedContentTypes:allowsMultipleSelection:onCompletion:)` – ab iOS 14 / macOS 11, liefert `Result<[URL], any Error>`.
  - `TabViewStyle.sidebarAdaptable` – ab iOS 18 / macOS 15. `NavigationSplitView` ab iOS 16 / macOS 13. `ViewThatFits` ab iOS 16 / macOS 13.
- **View-Modelle importieren kein SwiftUI** (nur `Foundation`, `Observation`, `FrontstageCore`; für `Logger` zusätzlich `OSLog`, wie in `DataStore+Merge.swift`), damit sie im Testziel ohne Ansicht prüfbar sind. Ausnahme: keine.
- **Heute ist ein Parameter:** Jedes View-Modell bekommt `today: @escaping @MainActor () -> CalendarDay`; nie `Date()` im View-Modell. Tests fixieren **Dienstag, 2026-11-17** (Woche 47, A-Woche, Bezugswoche A = Montag 2026-11-16).
- **Neue Ordner:** `Frontstage/UI/Shared/` (gemeinsame Zeilen-Modelle und Aktionen der drei Bildschirme). Test-Hilfen kommen in den vorhandenen Ordner `FrontstageTests/TestSupport/` (dort liegt schon der Typalias `DataStore = Frontstage.DataStore` gegen die Namensgleichheit mit SwiftData), Tests in den vorhandenen Ordner `FrontstageTests/UI/`. Ergänzt die Ordnerliste der Übersicht, widerspricht ihr nicht.
- **Oberflächentexte:** Jede Aufgabe trägt ihre Schlüssel in `Frontstage/Resources/Localizable.xcstrings` ein, Präfix je Bildschirm (`app.`, `dayView.`, `preparation.`, `setup.`, `lesson.`). Werte deutsch, unpersönlich, als Platzhalter.
- **Material wird nie kopiert:** Kein View-Modell ruft mit einer Datei-URL etwas anderes auf als `MaterialStorage.reference(forPickedFile:)` bzw. `relink(_:toPickedFile:)`; Übernehmen und Schieben verwenden vorhandene `MaterialReference`-Werte weiter (FR-3.4).
- **Für <Klasse> übernehmen (FR-3.2, Nutzerentscheidung 2026-11-13):** Die Lehrkraft wählt Klasse (alle Klassen im Stundenplan außer der eigenen) **und** Zielstunde aus einer Liste der kommenden Unterrichtsstunden dieser Klasse (höchstens 28 Tage, Ausfälle nicht wählbar). Keine automatische Zielwahl.
- **Kostenlos (FR-13, Nutzerentscheidung 2026-11-13):** Eintragen und Anzeigen von Thema, Bereitlegen und Hausaufgabe in Tagesansicht und Vorbereiten gehören zum kostenlosen Kern; kein Bildschirm dieses Teilplans fragt `Unlock` ab.
- **Offene Gestaltung:** Jede Aufgabe mit Oberfläche nimmt den SwiftUI-Systemstandard und nennt im Abschlussbericht je berührter offener Kategorie eine Zeile (Sammelstelle: Aufgabe 18).
- **Datenort (Teilplan 08, Übersicht Abstimmung 15):** `StorageService`, `AppEnvironment` und alles andere, was einen `DataStore` hält, entstehen in `ScopedAppContent` – der Ansicht in der Closure von `DataScopedRoot` –, nie einmalig im `App`-Typ. Im `App`-Typ bleiben nur `DataLocationController`, `MicrosoftAccount`, `NetworkMonitor` und die Halter, die einen Wechsel überstehen müssen (Teilplan 05: `SourceCoordinatorHolder`). Hat Teilplan 08 die Closure-Ansicht unter anderem Namen angelegt, gilt dieser Name; dieser Plan nennt sie `ScopedAppContent`.
- **Stiftnotizen (ADR-0011):** Schieben, Weiterreichen und Material ohne Stunde zuordnen melden die bewegten Zuordnungen an `AppEnvironment.penNotes` (`PenNoteFileRelocating.linksMoved`); Neu verknüpfen fragt danach, ob Notizen mitgenommen werden. Die Vorgabe `NoPenNoteFileRelocation` tut nichts; Teilplan 06 setzt die echte Umsetzung. Übernehmen meldet nichts (FR-6.1).

## Review Focus

Was die Spec voraussetzt, aber kein AK prüft – wahrscheinlichstes zuerst; jede Zeile hat ihren Test in der genannten Aufgabe:

1. **Zeitraster leer oder lückenhaft** (Stunde ohne Zeit, typisch nach dem ersten Anlegen): Tagesansicht zeigt die Unterrichtsstunden trotzdem in Stundenreihenfolge, ohne Zeit, ohne Absturz – Aufgabe 6 (`dayRowsWithoutBellScheduleKeepPeriodOrder`).
2. **Keine nächste Unterrichtsstunde innerhalb von 28 Tagen** (Schuljahresende, lange Ferien) beim Schieben/Weiterreichen/Übernehmen: Aktion meldet `nil`, Material bleibt unverändert an der alten Stunde – Aufgabe 4 (`moveToNextLessonWithoutTargetKeepsLink`).
3. **Datei außerhalb jeder Ordnerfreigabe** oder Nicht-Datei-URL wird gezogen/gewählt: kein Datensatz entsteht, Fehler wird gemeldet mit Angebot, den Ordner freizugeben – Aufgabe 3 (`assignOutsideGrantedFolderStoresNothing`).
4. **Ausfall doppelt markieren / Ausfall aus der Quelle von Hand aufheben:** zweite Markierung erzeugt keine zweite Abweichung; eine Abweichung mit Herkunft `source` lässt sich nicht von Hand entfernen – Aufgabe 5 (`markCancelledTwiceStoresOneChange`, `unmarkSourceCancellationIsRejected`).
5. **Wechsel von zwei Wochenvarianten zurück auf eine**, während A/B-spezifische Einträge existieren: nichts geht still verloren; Wechsel verlangt Bestätigung und nennt die Zahl der B-Einträge – Aufgabe 11 (`reducingToOneVariantRequiresConfirmation`).

---

## Interfaces

### Consumes – Teilplan 01 (Kern)

`CalendarDay` (inkl. `init(year:month:day:)`, `init(_:calendar:)`, `adding(days:)`, `weekday`, `mondayOfWeek`, `storageText`), `Weekday`, `WeekVariant`, `SchoolClass`, `Subject`, `TimeOfDay` (inkl. `init(hour:minute:)`), `BellSchedule`, `TimetableEntry` (`weekVariant == nil` = A- und B-Woche), `Timetable`, `NonTeachingPeriod` (inkl. `contains(_:)`), `LessonKey` (inkl. `init(date:schoolClass:subject:ordinal:)`), `Origin`, `ScheduleChange`, `Lesson`, `TimetableCalculator` – alle mit öffentlichen Initialisierern. Keine eigene Tagesrechnung.

### Consumes – Teilplan 02 (Daten)

Kern: `LessonInfo`, `MaterialReference` (`folderGrantName`, `relativePath`, `displayName`, `fileKind`, `locationKey`), `MaterialFileKind` (inkl. `opensInViewer`). App: `DataStore` (`revision` und die Methoden aus 02 Task 6, 8, 9, die `PreparationStore` unten nennt), `MaterialLinkRecord` (`id`, `lessonKey`, `position`, `reference`), Test-Hilfe `makeStore()`.

### Consumes – Teilplan 03 (Ablage)

`StorageService` mit `grants`, `availability`, `suggestedGrantName(for:)`, `addGrant(folderURL:name:)`, `removeGrant(id:)`, `reference(forPickedFile:)`, `relink(_:toPickedFile:)`, `refreshAvailability(for:)`, `open(_:anchor:)`, `openWithoutAutoSave(_:anchor:)`, `offerOpenWithoutAutoSave(now:)`, `didAssign(_:)`, `prepareForTeaching(today:timetable:nonTeachingPeriods:changes:)`; `FolderGrant`, `GrantNameSuggestion`, `MaterialAvailability`, `OpenOutcome`, `RelinkResult`, `HandOffAnchor`, `HandOffAnchorReader`, `MicrosoftAccount`, `NetworkMonitor`.

Stand der Umsetzung von 03 (im Repo umgesetzt, Bündel A): `RelinkResult` hat zusätzlich den Fall **`saveFailed`** (Verweis gefunden, Speichern im `DataStore` gescheitert); `open(_:anchor:)` wartet bis zu **120 s** auf ein Herunterladen, ein zweiter Tipp auf dasselbe Material liefert währenddessen sofort `.waitingForDownload`, und `availability` zeigt in der Zeit `.downloading(progress:)`; `MicrosoftAccount(signedInUsernameForTesting:)` gibt es für Tests (ohne MSAL; gilt als konfiguriert); `HandOffAnchor()` ohne Ort gibt es für Tests; `HandOffAnchorReader(onResolve:)` liefert `(HandOffAnchor, AuthPresentationAnchor)`; `GrantNameSuggestion` (`name`, `matchesMirroredName`) liegt im Kern; Ordnerfreigaben sind lesend und schreibend.

### Consumes – Teilplan 05 (Stundenplan-Quelle)

`TimetableSourceKind`, `TimetableSourceCoordinator` (aus der Umgebung, erzeugt über `SourceCoordinatorHolder.coordinator(for:)` in `ScopedAppContent`), Ansichten `TimetableSourceSettingsView()`, `ImportPreviewView`, `SourceStatusBar()`.

### Consumes – Teilplan 08 (Datenort)

`DataScopedRoot(controller:content:)` (Closure bekommt `DataStore` und `ModelContainer`), `DataLocationController` (`location`, `store`, `container`, `generation`, `sceneDidBecomeActive()` …; `@Observable`), `DataLocation` (`iCloud`, `oneDrive`, Kern), Ansicht `DataLocationSettingsView(controller:isOneDriveAvailable:accountUsername:)` (ein `Section` zum Einbetten in ein `Form`, vor „Ablage“; 08 hat `SetupView` nicht angelegt – 04 hängt sie in Aufgabe 11 ein). 08 ersetzt den Container-Aufbau aus 02 in `FrontstageApp`; dieser Plan baut darauf auf.

### Produces – Verbraucher-Protokolle (dieser Teilplan, Übersicht Abstimmung Punkt 4)

```swift
/// Wertabbild einer Zuordnung (MaterialLinkRecord) für die Oberfläche.
struct MaterialLinkItem: Identifiable, Hashable, Sendable {
    let id: UUID; var lessonKey: LessonKey?; var position: Int; var reference: MaterialReference
}

/// Schmale Sicht auf die Daten für Tagesansicht, Vorbereiten und Einrichten.
@MainActor protocol PreparationStore: AnyObject {
    var revision: Int { get }
    // Stundenplan, Zeiträume, Abweichungen – gleiche Signaturen wie DataStore (02 Task 6)
    func timetable() throws -> Timetable?
    func lessons(on day: CalendarDay) throws -> [Lesson]
    func nextLesson(after key: LessonKey) throws -> LessonKey?
    func manuallyEditedEntries() throws -> Set<TimetableEntry>
    func addEntry(_ entry: TimetableEntry, origin: Origin) throws
    func replaceEntry(_ old: TimetableEntry, with new: TimetableEntry) throws
    func removeEntry(_ entry: TimetableEntry) throws
    func setWeekVariants(count: Int, referenceWeekA: CalendarDay) throws
    func setBellSchedule(_ schedule: BellSchedule) throws
    func nonTeachingPeriods() throws -> [NonTeachingPeriod]
    func addNonTeachingPeriod(_ period: NonTeachingPeriod) throws
    func removeNonTeachingPeriod(_ period: NonTeachingPeriod) throws
    func scheduleChanges() throws -> [ScheduleChange]
    func markCancelled(_ key: LessonKey) throws
    func removeCancellation(_ key: LessonKey) throws -> Bool
    func addSubstituteLesson(date: CalendarDay, period: Int, schoolClass: SchoolClass, subject: Subject) throws -> LessonKey?
    func removeSubstituteLesson(date: CalendarDay, period: Int, schoolClass: SchoolClass, subject: Subject) throws -> Bool
    // Übernehmen (02 Task 8) und Stundenangaben (02 Task 9) – gleiche Signaturen wie DataStore
    func candidateLessons(for schoolClass: SchoolClass, from day: CalendarDay, maxDays: Int) throws -> [Lesson]
    func selectableClasses(excluding: SchoolClass) throws -> [SchoolClass]
    func copyMaterialLinks(from source: LessonKey, to target: LessonKey) throws -> Int
    func moveLinks(in key: LessonKey, fromOffsets: IndexSet, toOffset: Int) throws
    func moveAllLinksToNextLesson(from key: LessonKey) throws -> LessonKey?
    func folderGrantNames() throws -> Set<String>
    func lessonInfo(for key: LessonKey) throws -> LessonInfo
    func setLessonInfo(_ info: LessonInfo, for key: LessonKey) throws
    // Zuordnungen als Werte und über ihre id – die Erweiterung bildet sie aus DataStore-Methoden
    func materialLinkItems(for key: LessonKey) throws -> [MaterialLinkItem]
    func materialLinkItems(from: CalendarDay, through: CalendarDay) throws -> [MaterialLinkItem]
    func orphanedLinkItems(on day: CalendarDay) throws -> [MaterialLinkItem]
    func assignItem(_ reference: MaterialReference, to key: LessonKey, at index: Int?) throws -> MaterialLinkItem
    func moveLinkToNextLesson(id: UUID) throws -> LessonKey?
    func moveLink(id: UUID, to key: LessonKey) throws
    func removeLink(id: UUID) throws
}
/// Ruft nur vorhandene DataStore-Methoden: link(id:), links(for:), links(from:through:), orphanedLinks(on:),
/// assign(_:to:at:), moveLinkToNextLesson(_:), moveLink(_:to:), removeLink(_:); alle übrigen Anforderungen
/// erfüllt DataStore mit gleicher Signatur direkt. Unbekannte id → nichts geändert bzw. nil.
extension DataStore: PreparationStore { … }

/// Schmale Sicht auf die Ablage; Signaturen gleich StorageService (Teilplan 03).
@MainActor protocol MaterialStorage: AnyObject {
    var grants: [FolderGrant] { get }
    var availability: [String: MaterialAvailability] { get }      // Schlüssel MaterialReference.locationKey
    func suggestedGrantName(for folderURL: URL) -> GrantNameSuggestion
    func addGrant(folderURL: URL, name: String) async throws -> FolderGrant
    func removeGrant(id: UUID)
    func reference(forPickedFile url: URL) -> MaterialReference?
    func relink(_ old: MaterialReference, toPickedFile url: URL) -> RelinkResult
    func refreshAvailability(for references: [MaterialReference])
    func open(_ reference: MaterialReference, anchor: HandOffAnchor) async -> OpenOutcome
    func openWithoutAutoSave(_ reference: MaterialReference, anchor: HandOffAnchor) async -> OpenOutcome
    func offerOpenWithoutAutoSave(now: ContinuousClock.Instant) -> MaterialReference?
    func didAssign(_ references: [MaterialReference]) async
    func prepareForTeaching(today: CalendarDay, timetable: Timetable, nonTeachingPeriods: [NonTeachingPeriod], changes: [ScheduleChange]) async
}
extension StorageService: MaterialStorage {}
```

### Produces – für Teilplan 06 und 07

```swift
/// Naht zu Teilplan 06 (Stiftnotizen neben dem Dokument, ADR-0011). 04 ruft sie, 06 setzt die Umsetzung.
struct PenNoteMove: Hashable, Sendable { let reference: MaterialReference; let from: LessonKey; let to: LessonKey }
@MainActor protocol PenNoteFileRelocating: AnyObject {
    /// Nach Schieben, Weiterreichen oder Zuordnen von Material ohne Stunde: Notiz-Datei und Notiz-PDF umbenennen.
    /// Synchron: die Umsetzung merkt sich den Umzug dauerhaft und führt ihn selbst aus (Teilplan 06).
    func linksMoved(_ moves: [PenNoteMove])
    /// Ausstehende Umbenennungen nachholen (Aktivwerden, vor dem Öffnen der Anzeige).
    func retryPending() async
    /// Nach Neu verknüpfen: Zahl der Unterrichtsstunden mit Notizen am alten Ort; 0 = nichts anzubieten.
    func notesCount(beside old: MaterialReference) async -> Int
    /// Notizen vom alten Ort neben die neue Datei verschieben.
    func moveNotes(from old: MaterialReference, to new: MaterialReference) async throws
}
/// Vorgabe bis Teilplan 06: tut nichts, bietet nichts an.
final class NoPenNoteFileRelocation: PenNoteFileRelocating { … }

@MainActor @Observable final class AppEnvironment {
    init(store: any PreparationStore, storage: any MaterialStorage, today: @escaping @MainActor () -> CalendarDay,
         dataLocation: @escaping @MainActor () -> DataLocation = { .iCloud })
    let store: any PreparationStore
    let storage: any MaterialStorage
    /// Setzt Teilplan 06; false (Vorgabe) → PDF und Bild werden wie jedes Material übergeben.
    var viewerAvailable: Bool
    /// Setzt Teilplan 06; Vorgabe NoPenNoteFileRelocation().
    var penNotes: any PenNoteFileRelocating
    let today: @MainActor () -> CalendarDay
    /// Aktueller Datenort (Teilplan 08) – nur für den Hinweis beim Abmelden von Microsoft (Aufgabe 14).
    let dataLocation: @MainActor () -> DataLocation
}
enum MaterialOpenAction: Equatable { case viewer(MaterialLinkItem); case open(MaterialReference); case unavailable(MaterialReference) }
/// Die Ansicht in der Closure von DataScopedRoot (08): hält StorageService, AppEnvironment und den Koordinator aus 05
/// in @State; entsteht nach jedem Wechsel des Datenorts neu.
struct ScopedAppContent: View { init(store: DataStore, container: ModelContainer, dataLocation: DataLocationController, account: MicrosoftAccount, network: NetworkMonitor, sourceCoordinators: SourceCoordinatorHolder) }
struct RootView: View; struct DayView: View; struct PreparationView: View; struct LessonDetailView: View; struct SetupView: View
```

### Nicht mehr hier (abgeglichen)

Die erste Fassung erwartete `FrontstageStore`, `SwiftDataStore`, `FrontstageModelContainer`, ein `StorageService`-Protokoll mit `FileStorageService`, `FolderGrantStatus`, `StorageError`, `TimetableSourceStatusProviding`, `TimetableSourceStatus`, `ManualTimetableSourceStatus` sowie die Kern-Ergänzungen `CalendarDay+Navigation` und `LessonMatching`. Sie entfallen: Daten über `PreparationStore`/`DataStore`, Ablage über `MaterialStorage`/`StorageService`, Quelle über Teilplan 05, Tagesrechnung aus 01, Übernehmen über `ParallelLessonFinder` (02).


---

## Dateien

| Datei | Verantwortung | Aufgabe |
|---|---|---|
| `Frontstage/UI/Preparation/PreparationStore.swift` | `MaterialLinkItem`, Protokoll `PreparationStore`, `extension DataStore: PreparationStore` | 1 |
| `Frontstage/UI/Shared/MaterialStorage.swift` | Protokoll `MaterialStorage`, `extension StorageService: MaterialStorage` | 1 |
| `FrontstageTests/TestSupport/FakeStorage.swift`, `UIFixtures.swift` | Attrappe `MaterialStorage`, Beispieldaten Woche 47 (Daten über `makeStore()` aus 02) | 2 |
| `Frontstage/UI/Shared/LessonActions.swift` | Zuordnen, Reihenfolge, Übernehmen, Schieben, Ausfall, Vertretung, Neuverknüpfen | 3–5 |
| `Frontstage/UI/Shared/PenNoteFileRelocating.swift` | Naht zu 06: `PenNoteMove`, `PenNoteFileRelocating`, `NoPenNoteFileRelocation` | 3 |
| `Frontstage/App/ScopedAppContent.swift`; `FrontstageApp.swift` (ändern) | Dienste je Datenort innerhalb `DataScopedRoot` | 7 |
| `Frontstage/UI/Shared/LessonRow.swift`, `DayStatement.swift`, `MaterialOpenAction.swift` | gemeinsame Zeilen-Modelle | 6 |
| `Frontstage/App/AppEnvironment.swift` | Abhängigkeitsbündel | 6 |
| `Frontstage/App/AppSection.swift`, `RootView.swift` | Gerüst, Navigation | 7 |
| `Frontstage/UI/DayView/DayViewModel.swift`, `DayViewLayout.swift` | Tagesansicht-Logik | 6 |
| `Frontstage/UI/DayView/DayView.swift`, `DayRowView.swift` | Tagesansicht (Kopf mit `SourceStatusBar` aus 05) | 8 |
| `Frontstage/UI/Preparation/PreparationViewModel.swift`, `LessonInfoEditor.swift` | Vorbereiten-Logik | 9 |
| `Frontstage/UI/Preparation/PreparationView.swift`, `LessonDetailView.swift`, `MaterialDropTarget.swift`, `SubstituteLessonSheet.swift`, `CopyTargetPicker.swift` | Vorbereiten | 10 |
| `Frontstage/UI/Setup/TimetableEditorViewModel.swift`, `TimetableEditorView.swift`, `TimetableEntrySheet.swift`, `SetupView.swift` | Stundenplan von Hand, A/B, Bezugswoche | 11 |
| `Frontstage/UI/Setup/BellScheduleEditorViewModel.swift`, `BellScheduleEditorView.swift` | Zeitraster | 12 |
| `Frontstage/UI/Setup/NonTeachingPeriodsViewModel.swift`, `NonTeachingPeriodsView.swift` | unterrichtsfreie Zeiträume, Material ohne Stunde | 13 |
| `Frontstage/UI/Setup/StorageSettingsViewModel.swift`, `StorageSettingsView.swift` | Ordnerfreigaben, Microsoft an/ab; Einhängen von `TimetableSourceSettingsView` (05) | 14 |
| `.github/workflows/testflight.yml`, `ci/ExportOptions-TestFlight.plist`, `project.yml` (ändern) | TestFlight-Bau | 16 |

Tests: je View-Modell `FrontstageTests/UI/<Name>Tests.swift`. Dieser Teilplan hat keine Kern-Tests (keine Kern-Typen).

---

### Task 1: Verbraucher-Protokolle `PreparationStore` und `MaterialStorage`

Design-Takt: keiner

**Files:**
- Create: `Frontstage/UI/Preparation/PreparationStore.swift`, `Frontstage/UI/Shared/MaterialStorage.swift`
- Test: `FrontstageTests/UI/PreparationStoreTests.swift`

**Interfaces:**
- Consumes: `DataStore` (02, Task 6, 8, 9), `MaterialLinkRecord.id/lessonKey/position/reference` (02, Task 5), `StorageService` (03, Task 11).
- Produces: `MaterialLinkItem`, `PreparationStore`, `extension DataStore: PreparationStore`, `MaterialStorage`, `extension StorageService: MaterialStorage` (Interfaces-Block oben).

- [ ] **Step 1: Tests schreiben** (echter `DataStore` aus `makeStore()`, Teilplan 02)

```swift
@MainActor @Suite struct PreparationStoreTests {
    @Test("Zuordnung als Wert: id, Schlüssel, Position und Verweis kommen aus dem Datensatz")
    func assignItemReturnsValue() throws {
        let store: any PreparationStore = try makeStore()
        let item = try store.assignItem(Fixtures.reference("Unit 4 – Präsentation.pptx", .presentation), to: Fixtures.key(.tue17, "8b", "Englisch"), at: nil)
        #expect(try store.materialLinkItems(for: Fixtures.key(.tue17, "8b", "Englisch")) == [item])
        #expect(item.position == 0)
    }
    @Test("Unbekannte id ändert nichts und liefert nil")
    func unknownIDIsIgnored() throws {
        #expect(try store.moveLinkToNextLesson(id: UUID()) == nil)
        try store.removeLink(id: UUID())            // kein Fehler, keine Änderung
    }
    @Test("Material ohne Stunde als Werte (FR-7)")
    func orphanedItems()                            // Ferien 2.–6.11., Zuordnung am 3.11. → orphanedLinkItems(on: nov3).count == 1
}
```

- [ ] **Step 2: Implementieren.** Die Erweiterung bildet `MaterialLinkItem(id: r.id, lessonKey: r.lessonKey, position: r.position, reference: r.reference)` aus `MaterialLinkRecord`; id-Methoden holen den Datensatz über `link(id:)`. `extension StorageService: MaterialStorage {}` bleibt leer (gleiche Signaturen). Swift-Hinweis: Erfüllt eine Klasse ein Protokoll schon mit gleichnamigen Methoden gleicher Signatur, genügt eine leere Erweiterung `extension X: P {}`.
- [ ] **Step 3: Diff durchsehen:** keine Methode des `DataStore` wird hier neu erfunden; jede aufgerufene steht in Teilplan 02.
- [ ] **Step 4: Commit** `feat(ui): consumer protocols for data and storage`

---

### Task 2: Test-Attrappe und Beispieldaten

Design-Takt: keiner

**Files:**
- Create: `FrontstageTests/TestSupport/FakeStorage.swift`, `FrontstageTests/TestSupport/UIFixtures.swift` (nicht `Fixtures.swift`: `FrontstageTests/Data/Fixtures.swift` aus 02 gibt es schon, und zwei gleichnamige Swift-Dateien in einem Ziel brechen den Bau ab – „filename used twice“; die globalen `tue17`, `wed18`, `thu19`, `reference(_:)` und `makeStore()` von dort nicht doppelt anlegen)

**Interfaces:**
- Consumes: `MaterialStorage` (Task 1), `makeStore()` (02).
- Produces:
```swift
@MainActor final class FakeStorage: MaterialStorage {
    var grants: [FolderGrant]; var availability: [String: MaterialAvailability]; var rejectURLs: Set<URL>
    var relinkResultOverride: RelinkResult?          // z. B. .saveFailed
    var openOutcome: OpenOutcome = .handedOff; var openDelay: Duration?   // simuliert das Warten von open (bis 120 s in 03)
    var mirroredNames: Set<String>                   // gespiegelte Freigabe-Namen für suggestedGrantName (Aufgabe 14)
    private(set) var pickedFileCalls: Int; private(set) var opened: [MaterialReference]; private(set) var assigned: [[MaterialReference]]
}
/// Zeichnet die Aufrufe der Naht auf; notesCountResult steuert das Angebot beim Neu verknüpfen.
@MainActor final class FakePenNoteRelocation: PenNoteFileRelocating {
    private(set) var moves: [PenNoteMove]; var notesCountResult: Int; private(set) var movedNotes: [(MaterialReference, MaterialReference)]
}
enum Fixtures {
    static let tue17 = CalendarDay(year: 2026, month: 11, day: 17)   // + wed18, thu19, tue24, wed25, nov3
    static let bellSchedule: BellSchedule   // 1: 7:45–8:30, 2: 8:35–9:20, 3: 9:40–10:25, 4: 10:30–11:15, 5: 11:35–12:20, 6: 12:25–13:10
    /// Legt im DataStore einen Stundenplan an (setWeekVariants, setBellSchedule, addEntry je Eintrag); referenceWeekA 2026-11-16.
    static func seed(_ store: DataStore, _ entries: [TimetableEntry], variants: Int = 1, bell: BellSchedule = bellSchedule) throws
    static func entry(_ weekday: Weekday, _ period: Int, _ cls: String, _ subject: String, _ variant: WeekVariant? = nil) -> TimetableEntry
    static func reference(_ name: String, _ kind: MaterialFileKind) -> MaterialReference   // folderGrantName "Unterricht", relativePath = name
    static func key(_ day: CalendarDay, _ cls: String, _ subject: String, _ ordinal: Int = 1) -> LessonKey
    static func environment(store: DataStore, storage: FakeStorage, today: CalendarDay = tue17, dataLocation: DataLocation = .iCloud) -> AppEnvironment   // erst in Aufgabe 6 ergänzt
}
/// Damit `.tue17` als implizites Glied (`Fixtures.key(.tue17, …)`, `date: .wed18`) übersetzt: Swift sucht es in `CalendarDay`.
extension CalendarDay { static let tue17 = Fixtures.tue17 /* + wed18, thu19, tue24, wed25, nov3 */ }
```

- [ ] **Step 1: Attrappe schreiben.** `FakeStorage.reference(forPickedFile:)` liefert `nil` für URLs in `rejectURLs` und für Nicht-`file:`-URLs, sonst `Fixtures.reference(url.lastPathComponent, MaterialFileKind(fileExtension: url.pathExtension))`; `relink` liefert `relinkResultOverride`, falls gesetzt, sonst `.outsideGrants` für `rejectURLs`, sonst `.relinked(…)`; `open` wartet `openDelay` (`Task.sleep`), merkt sich den Verweis und liefert `openOutcome`; ruft man `open` für denselben `locationKey` auf, während ein früherer Aufruf noch wartet, liefert es sofort `.waitingForDownload` (wie 03). `suggestedGrantName(for:)` liefert `FolderGrantNaming.suggestion(folderName: url.lastPathComponent, localGrantNames: Set(grants.map(\.name)), mirroredNames: mirroredNames)`. `FakePenNoteRelocation` (gleiche Datei) zeichnet `linksMoved` und `moveNotes` auf. Daten laufen immer über den echten `DataStore` (kein `FakeStore` – sonst prüften die Tests nur die Attrappe).
- [ ] **Step 2: Diff durchsehen:** nur erfundene Materialnamen („Unit 4 – Präsentation“, „Arbeitsblatt Vokabeln“, „Lösung Vokabeln“), Klassen `7a 8a 8b 9c 6c`.
- [ ] **Step 3: Commit** `test: storage fake and fixtures for UI view models`

---

### Task 3: Zuordnen, Reihenfolge, Neuverknüpfen (FR-3, FR-3.1, FR-3.4)

Design-Takt: keiner

**Files:**
- Create: `Frontstage/UI/Shared/LessonActions.swift`, `Frontstage/UI/Shared/PenNoteFileRelocating.swift`
- Test: `FrontstageTests/UI/LessonActionsAssignTests.swift`

**Interfaces:**
- Consumes: `PreparationStore`, `MaterialStorage` (Task 1); `RelinkResult` inkl. `saveFailed` (03).
- Produces: `PenNoteMove`, `PenNoteFileRelocating`, `NoPenNoteFileRelocation` (Interfaces-Block oben) und:
```swift
/// Fehler beim Zuordnen aus der Ablage; Datenfehler werden protokolliert und als .saveFailed gemeldet.
enum AssignError: Error, Equatable { case outsideGrantedFolders, saveFailed }
@MainActor struct LessonActions {
    init(store: any PreparationStore, storage: any MaterialStorage, penNotes: any PenNoteFileRelocating = NoPenNoteFileRelocation())
    /// Je URL ein Verweis, hinten angehängt; bricht bei der ersten ungültigen URL ab, ohne vorher Angelegtes zurückzunehmen.
    /// Danach `storage.didAssign` (Bereithalten, 03).
    @discardableResult func assign(fileURLs: [URL], to key: LessonKey) async throws(AssignError) -> [MaterialLinkItem]
    func reorder(_ key: LessonKey, fromOffsets: IndexSet, toOffset: Int)   // Semantik wie Array.move(fromOffsets:toOffset:)
    /// Neu verknüpfen (ADR-0003): ersetzt den Ort an allen Zuordnungen mit demselben alten Ort (03, StorageService.relink).
    /// Liefert den neuen Verweis; RelinkResult.outsideGrants → .outsideGrantedFolders, .saveFailed → .saveFailed (nichts geändert).
    @discardableResult func relink(_ item: MaterialLinkItem, fileURL: URL) throws(AssignError) -> MaterialReference
    /// ADR-0011: Zahl der Stunden mit Notizen am alten Ort (0 = kein Angebot) und Mitnehmen auf Wunsch.
    func notesToCarry(from old: MaterialReference) async -> Int
    func carryNotes(from old: MaterialReference, to new: MaterialReference) async throws
    func remove(linkID: UUID)
}
```

- [ ] **Step 1: Tests schreiben**

```swift
@Test("AK-4: zugeordnete Präsentation steht an der Unterrichtsstunde") func assignAddsLink() async throws {
    let items = try await actions.assign(fileURLs: [URL(filePath: "/Unterricht/Unit 4 – Präsentation.pptx")], to: Fixtures.key(.tue17, "8b", "Englisch"))
    #expect(try store.materialLinkItems(for: key).map(\.reference.displayName) == ["Unit 4 – Präsentation.pptx"])
    #expect(items.count == 1)
    #expect(storage.assigned.count == 1)                       // Bereithalten angestoßen
}
@Test("AK-6: Lösung an Position 1") func reorderMovesSolutionFirst() throws {
    // Präsentation, Arbeitsblatt, Lösung
    actions.reorder(key, fromOffsets: [2], toOffset: 0)
    #expect(try store.materialLinkItems(for: key).map(\.reference.displayName) == ["Lösung Vokabeln", "Unit 4 – Präsentation", "Arbeitsblatt Vokabeln"])
}
@Test("Datei außerhalb der Freigaben legt nichts an") func assignOutsideGrantedFolderStoresNothing() async throws {
    await #expect(throws: AssignError.outsideGrantedFolders) { try await actions.assign(fileURLs: [rejected], to: key) }
    #expect(try store.materialLinkItems(for: key).isEmpty)
}
@Test("Neuverknüpfen außerhalb der Freigaben wird abgelehnt") func relinkOutsideGrantsThrows()   // .outsideGrants → AssignError.outsideGrantedFolders
@Test("Neuverknüpfen: Speichern gescheitert wird gemeldet, Verweis bleibt") func relinkSaveFailedIsReported() throws {
    storage.relinkResultOverride = .saveFailed
    #expect(throws: AssignError.saveFailed) { try actions.relink(item, fileURL: newURL) }
    #expect(try store.materialLinkItems(for: key).map(\.reference) == [item.reference])
}
@Test("ADR-0011: nach Neuverknüpfen werden Notizen am alten Ort angeboten und mitgenommen") func relinkOffersToCarryNotes() async throws {
    penNotes.notesCountResult = 2
    let new = try actions.relink(item, fileURL: newURL)
    #expect(await actions.notesToCarry(from: item.reference) == 2)
    try await actions.carryNotes(from: item.reference, to: new)
    #expect(penNotes.movedNotes.map(\.1) == [new])
}
```

- [ ] **Step 2: Implementieren** gemäß Signaturen; `reorder` ruft `store.moveLinks(in:fromOffsets:toOffset:)`; `relink` bildet `RelinkResult` ab (`.relinked(r)` → `r`, `.outsideGrants` → `.outsideGrantedFolders`, `.saveFailed` → `.saveFailed`); `notesToCarry`/`carryNotes` reichen an `penNotes` durch. Fehler aus dem Store werden mit `Logger` protokolliert.
- [ ] **Step 3: Diff durchsehen:** kein `FileManager`, kein Schreiben in die Ablage; `throws(AssignError)` (typisierte Fehler, Swift 6: der Aufrufer kennt den genauen Fehlertyp).
- [ ] **Step 4: Commit** `feat(ui): assign, reorder and relink material`

---

### Task 4: Übernehmen und Schieben (FR-3.2, FR-3.3, FR-8 Weiterreichen)

Design-Takt: keiner

**Files:**
- Modify: `Frontstage/UI/Shared/LessonActions.swift`
- Test: `FrontstageTests/UI/LessonActionsMoveTests.swift`

**Interfaces:**
- Consumes: `PreparationStore.selectableClasses(excluding:)`, `.candidateLessons(for:from:maxDays:)`, `.copyMaterialLinks(from:to:)`, `.moveLinkToNextLesson(id:)`, `.moveAllLinksToNextLesson(from:)`, `.moveLink(id:to:)` (Task 1 → DataStore, Teilplan 02).
- Produces:
```swift
extension LessonActions {
    /// FR-3.2: Klassen zur Wahl – alle Klassen im Stundenplan außer der eigenen.
    func copyTargetClasses(for key: LessonKey) -> [SchoolClass]
    /// FR-3.2: Unterrichtsstunden der gewählten Klasse ab dem Tag von `key`, höchstens 28 Tage, ohne Ausfälle – die Lehrkraft wählt daraus.
    func copyTargetLessons(for schoolClass: SchoolClass, from key: LessonKey) -> [Lesson]
    /// FR-3.2: kopiert alle Zuordnungen in die **gewählte** Zielstunde (ohne Stiftnotizen); liefert die Zahl der neuen Zuordnungen.
    @discardableResult func copyLinks(from key: LessonKey, to target: LessonKey) -> Int
    /// FR-3.3 für ein Material (gleiche Klasse, gleiches Fach); nil → keine nächste Stunde, nichts geändert.
    @discardableResult func moveToNextLesson(linkID: UUID) -> LessonKey?
    /// FR-8: alles Material der Stunde; Reihenfolge bleibt, hinten an das Ziel angehängt.
    @discardableResult func passOnAll(from key: LessonKey) -> LessonKey?
    /// Material ohne Stunde einer gewählten Unterrichtsstunde zuordnen (FR-7).
    func move(linkID: UUID, to key: LessonKey)
}
```

- [ ] **Step 1: Tests schreiben**

```swift
@Test("AK-7: Für 8b übernehmen in die gewählte Mi 3. Stunde – zwei Zuordnungen, keine Dateien") func copyToChosenLesson() throws {
    // Di 2. Std 8a Englisch mit 2 Materialien, Mi 3. Std 8b Englisch ohne, Fr 4. Std 8b Mathe
    #expect(actions.copyTargetClasses(for: tue8a) == [.init("8b")])
    let choices = actions.copyTargetLessons(for: .init("8b"), from: tue8a)
    #expect(choices.map(\.key).prefix(2) == [wed8b, fri8bMathe])           // Liste zur Wahl, kein automatisches Ziel
    #expect(actions.copyLinks(from: tue8a, to: wed8b) == 2)
    #expect(try store.materialLinkItems(for: wed8b).map(\.reference) == store.materialLinkItems(for: tue8a).map(\.reference))
    #expect(try store.materialLinkItems(for: tue8a).count == 2)
    #expect(storage.pickedFileCalls == 0)
}
@Test("Ausgefallene Stunde ist nicht wählbar") func cancelledLessonIsNotACopyTarget()   // Mi 8b Ausfall → wed8b nicht in copyTargetLessons
@Test("AK-8: X steht am Donnerstag, nicht mehr am Dienstag") func moveToNextLesson() throws {
    #expect(actions.moveToNextLesson(linkID: x.id) == thu8b)
    #expect(try store.materialLinkItems(for: thu8b).map(\.id) == [x.id])     // dieselbe Zuordnung → Stiftnotizen wandern mit
    #expect(try store.materialLinkItems(for: tue8b).isEmpty)
}
@Test("AK-15: Weiterreichen nach Ausfall") func passOnAfterCancellation() throws {
    try store.markCancelled(tue8b)
    #expect(actions.passOnAll(from: tue8b) == thu8b)
    #expect(try store.materialLinkItems(for: thu8b).count == 1)
}
@Test("Ohne nächste Stunde bleibt das Material") func moveToNextLessonWithoutTargetKeepsLink() throws {
    // Ferien vom 18.11. bis 31.12. → keine 8b-Stunde in 28 Tagen
    #expect(actions.moveToNextLesson(linkID: x.id) == nil)
    #expect(try store.materialLinkItems(for: tue8b).map(\.id) == [x.id])
    #expect(penNotes.moves.isEmpty)
}
@Test("ADR-0011: Schieben und Weiterreichen melden die Umzüge für die Notiz-Dateien, Übernehmen nicht") func movesAreReportedForPenNotes() throws {
    _ = actions.copyLinks(from: tue8b, to: wed8bOther)
    #expect(penNotes.moves.isEmpty)                                          // FR-6.1: Übernehmen ohne Notizen
    _ = actions.moveToNextLesson(linkID: x.id)
    #expect(penNotes.moves == [PenNoteMove(reference: x.reference, from: tue8b, to: thu8b)])
    // passOnAll meldet je Zuordnung der Stunde einen Umzug; move(linkID:to:) für Material ohne Stunde ebenso
}
```

- [ ] **Step 2: Implementieren.** Ziele kommen immer aus dem Store (`nextLesson` in 02 = gleiche Klasse und gleiches Fach, Nutzerentscheidung 2026-11-13); `copyTargetLessons` ruft `candidateLessons(for:from: key.date, maxDays: 28)`. Fehler aus dem Store → protokollieren, Ergebnis `nil` bzw. `0`. Vor dem Schieben die betroffenen `MaterialLinkItem`s (Verweis, alter Schlüssel) lesen; nach erfolgreichem Schieben `penNotes.linksMoved(...)` mit je einem `PenNoteMove` (bei `move(linkID:to:)` nur, wenn die Zuordnung einen gültigen alten Schlüssel hat). Scheitert das Schieben, wird nichts gemeldet.
- [ ] **Step 3: Diff durchsehen:** Schieben ruft `moveLinkToNextLesson`/`moveLink` (nie kopieren + löschen), Übernehmen ruft `copyMaterialLinks(from:to:)` nur mit einer von der Lehrkraft gewählten Zielstunde und meldet nichts an `penNotes`.
- [ ] **Step 4: Commit** `feat(ui): copy to a chosen lesson of another class, move to next lesson, pass on`

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
@Test("AK-15: Ausfall markieren") func markCancelled() throws {
    #expect(actions.setCancelled(true, key: tue8b) == .changed)
    #expect(try store.scheduleChanges() == [.cancellation(tue8b, .manual)])
}
@Test("Doppelt markiert ergibt eine Abweichung") func markCancelledTwiceStoresOneChange()   // zweites Mal .unchanged, count == 1
@Test("Ausfall aus der Quelle lässt sich nicht von Hand aufheben") func unmarkSourceCancellationIsRejected() throws {
    try store.replaceScheduleChanges([.cancellation(tue8b, .source)], sourceFetchedAt: nil)   // DataStore direkt (Teilplan 02)
    #expect(actions.setCancelled(false, key: tue8b) == .blockedBySource)
    #expect(try store.scheduleChanges().count == 1)
}
@Test("AK-16: Vertretungsstunde Mi 4. Stunde 6c Mathe") func addSubstituteLesson() throws {
    actions.addSubstituteLesson(date: .wed18, period: 4, schoolClass: .init("6c"), subject: .init("Mathe"))
    #expect(try store.scheduleChanges() == [.substituteLesson(date: .wed18, period: 4, schoolClass: .init("6c"), subject: .init("Mathe"), .manual)])
}
```

- [ ] **Step 2: Implementieren** über `markCancelled`/`removeCancellation`/`addSubstituteLesson`/`removeSubstituteLesson` des Stores; vorher `scheduleChanges()` lesen: Ausfall mit beliebiger Herkunft schon vorhanden → `setCancelled(true)` liefert `.unchanged`; `setCancelled(false)` ohne jeden Ausfall → `.unchanged`; `removeCancellation` liefert `false`, obwohl ein Ausfall besteht (dann nur mit Herkunft `.source`, `DataStore` hebt nur `.manual` auf) → `.blockedBySource`.
- [ ] **Step 3: Diff durchsehen.**
- [ ] **Step 4: Commit** `feat(ui): cancellation and substitute lesson actions`

---

### Task 6: Tagesansicht-Logik (FR-4, FR-7, FR-8, FR-9, FR-11.1 Anzeige)

Design-Takt: keiner

**Files:**
- Create: `Frontstage/UI/Shared/LessonRow.swift`, `DayStatement.swift`, `MaterialOpenAction.swift`
- Create: `Frontstage/App/AppEnvironment.swift` (Abhängigkeitsbündel; Tests bauen es über `Fixtures.environment(store:storage:)` aus `makeStore()` und `FakeStorage`)
- Create: `Frontstage/UI/DayView/DayViewModel.swift`, `Frontstage/UI/DayView/DayViewLayout.swift`
- Test: `FrontstageTests/UI/DayViewModelTests.swift`, `DayViewLayoutTests.swift`

**Interfaces:**
- Consumes: `LessonActions` (3–5), `PreparationStore.lessons(on:)`, `.orphanedLinkItems(on:)`, `.lessonInfo(for:)`, `MaterialStorage.availability`, `.refreshAvailability(for:)`, `.open(_:anchor:)`, `NonTeachingPeriod.contains(_:)` (01), `MaterialFileKind.opensInViewer` (02).
- Produces:
```swift
enum LessonStatus: Hashable { case regular, substitute, cancelled(Origin) }
/// availability nil = noch nicht gelesen (Systemstandard: kein Zustandssymbol).
struct MaterialRow: Identifiable, Hashable { let item: MaterialLinkItem; let availability: MaterialAvailability?; var id: UUID { item.id } }
/// info: Thema, Bereitlegen, Hausaufgabe – Anzeige kostenlos (FR-13, Nutzerentscheidung 2026-11-13).
struct LessonRow: Identifiable, Hashable { let lesson: Lesson; let status: LessonStatus; let materials: [MaterialRow]; let info: LessonInfo; var id: String { lesson.key.storageText } }
enum DayRow: Identifiable, Hashable { case noLesson(period: Int, time: ClosedRange<TimeOfDay>?); case lesson(LessonRow)
    var id: String { get } }   // z. B. "free-<period>" bzw. lesson.key.storageText
enum DayContent: Hashable { case nonTeachingDay(title: String); case noLessons; case rows([DayRow]) }
/// Die vier Aussagen aus DESIGN.md – je eigenes Symbol und eigener Text, nie nur Farbe.
enum DayStatement: CaseIterable { case noLesson, lessonWithoutMaterial, materialUnavailable, cancellation
    var symbolName: String { get }; var labelKey: String { get } }
enum DayViewLayout {
    static let minRowHeight: CGFloat = 44; static let maxRowHeight: CGFloat = 96
    static func rowHeight(availableHeight: CGFloat, rowCount: Int, spacing: CGFloat = 8) -> CGFloat?   // nil → Rückfall auf Scrollen
}
@MainActor @Observable final class DayViewModel {
    init(environment: AppEnvironment)
    var day: CalendarDay
    private(set) var content: DayContent
    private(set) var materialsWithoutLesson: [MaterialLinkItem]
    let actions: LessonActions
    func reload()
    func showPreviousDay(); func showNextDay(); func showToday()
    func openAction(for row: MaterialRow) -> MaterialOpenAction
    /// Zuordnungen, deren Öffnen gerade läuft (StorageService.open wartet bis 120 s auf das Herunterladen) – Ladezustand der Zeile.
    private(set) var openingLinkIDs: Set<UUID>
    /// Nur für .open: übergibt an StorageService.open; das Ergebnis (OpenOutcome) zeigt die Ansicht an.
    /// Während des Wartens steht die Zuordnung in openingLinkIDs; ein zweiter Tipp ruft open erneut (03 liefert dann sofort .waitingForDownload).
    func open(_ row: MaterialRow, anchor: HandOffAnchor) async -> OpenOutcome
}
```
Stand der Quelle zeigt die Tagesansicht über `SourceStatusBar()` aus Teilplan 05 (Aufgabe 8); dieses View-Modell kennt die Quelle nicht.

Platzhalter-Symbole (SF Symbols, Systemstandard bis zur Design-Runde): `noLesson` → `minus`, `lessonWithoutMaterial` → `tray`, `materialUnavailable` → `exclamationmark.triangle`, `cancellation` → `xmark.circle`.

Zeilenbau (Signatur legt ihn nicht fest):
1. Liegt `day` in einem `NonTeachingPeriod` (`period.contains(day)`, Teilplan 01) → `.nonTeachingDay(title:)` des ersten Treffers.
2. Sonst `store.lessons(on:)`; leer → `.noLessons`.
3. Sonst für jede Stunde von der kleinsten bis zur größten `period` der Liste: alle Unterrichtsstunden dieser Stunde in Kern-Reihenfolge als `.lesson`, keine → `.noLesson(period:time:)` mit Zeit aus `bellSchedule.periods[period]`.
4. `materialsWithoutLesson` = `store.orphanedLinkItems(on: day)` (Teilplan 02).
5. `reload()` ruft `storage.refreshAvailability(for:)` mit dem Material des Tages; Bereithalten selbst stößt `prepareForTeaching` beim Aktivwerden an (Aufgabe 7, Teilplan 03).
6. `openAction`: `viewerAvailable && fileKind.opensInViewer` → `.viewer(item)`; Zustand `.unavailable` → `.unavailable(reference)`; sonst `.open(reference)`.
7. `open`: `openingLinkIDs.insert` vor dem `await storage.open`, `remove` danach – nur wenn dieser Aufruf ihn eingefügt hat (zweiter Tipp entfernt nicht den Ladezustand des ersten). Während des Wartens zeigt die Zeile zusätzlich `availability` (`.downloading(progress:)`, von 03 laufend aktualisiert).
8. `LessonActions` bekommt `environment.penNotes`.

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
    #expect(dayRows(vm)[2] == .noLesson(period: 3, time: …))   // dayRows/lessonRows/lessonRow: Test-Hilfen, die aus vm.content == .rows(…) lesen
    #expect(lessonRow(4).status == .cancelled(.source))
    #expect(lessonRow(5).status == .substitute && lessonRow(5).materials.isEmpty)
    #expect(lessonRow(6).materials.first?.availability == .unavailable(.fileMissing))
}
@Test("Thema und Hausaufgabe erscheinen in der Zeile, ohne Kauf (FR-11.1, FR-13)") func rowShowsLessonInfo()   // setLessonInfo(topic: "Unit 4 – Wortschatz") → lessonRow(2).info.topic == "Unit 4 – Wortschatz"
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
    // viewerAvailable == false, pdf → .open(reference); viewerAvailable == true → .viewer(item); Zustand .unavailable → .unavailable(reference)
}
@Test("Ladezustand, solange open auf das Herunterladen wartet (03: bis 120 s)") func openShowsLoadingWhileWaiting() async {
    storage.openDelay = .milliseconds(200); storage.openOutcome = .handedOff
    let task = Task { await vm.open(row, anchor: anchor) }
    await Task.yield(); #expect(vm.openingLinkIDs.contains(row.id))
    guard case .handedOff = await task.value else { Issue.record("erwartet .handedOff"); return }   // OpenOutcome ist nicht Equatable
    #expect(vm.openingLinkIDs.isEmpty)
}
@Test("Zweiter Tipp während des Wartens: .waitingForDownload, Ladezustand bleibt bis zum Ende des ersten") func secondTapWhileWaiting() async   // FakeStorage liefert beim zweiten Aufruf .waitingForDownload
```

- [ ] **Step 2: Implementieren** nach dem Zeilenbau oben; `rowHeight` = `min(maxRowHeight, (availableHeight − spacing·(n−1)) / n)`, `nil` wenn kleiner `minRowHeight`. Die beiden Grenzwerte sind Platzhalter der offenen Kategorie Dichte.
- [ ] **Step 3: Diff durchsehen:** kein `import SwiftUI` in View-Modell und Zeilen-Modellen (`CGFloat` aus `Foundation`); `Lesson` ist `Hashable`, also genügen die `Hashable`-Ableitungen.
- [ ] **Step 4: Commit** `feat(ui): day view model with four distinct statements`

---

### Task 7: App-Gerüst und Navigation

Design-Takt: Hauptstufe

**Files:**
- Create: `Frontstage/App/AppSection.swift`, `Frontstage/App/RootView.swift`, `Frontstage/App/ScopedAppContent.swift` (falls 08 die Closure-Ansicht schon angelegt hat: diese erweitern, Global Constraints)
- Modify: `Frontstage/App/FrontstageApp.swift` (Stand nach 02, 03, 05, 08 – vorher ganz lesen, nichts entfernen, Übersicht Abstimmung 13)
- Test: `FrontstageTests/UI/AppSectionTests.swift`

**Interfaces:**
- Consumes: `DataScopedRoot`, `DataLocationController` (08 – ersetzt `ModelContainerFactory.makeDefault()`, `DataStore`-Aufbau und `SyncMergeTrigger` aus 02 im `App`-Typ); `StorageService` samt Bausteinen, `MicrosoftAccount.handleRedirect(_:)`, `NetworkMonitor` (03); `TimetableSourceCoordinator`, `SourceCoordinatorHolder` (05); `AppEnvironment` (Aufgabe 6).
- Produces: `enum AppSection: String, CaseIterable, Hashable { case dayView, preparation, setup; static func initial(isMac: Bool, hasTimetable: Bool) -> AppSection }`; `struct RootView: View { init() }`; `ScopedAppContent` (Interfaces-Block).

- [ ] **Step 1: Test schreiben**

```swift
@Test("Startbereich: ohne Stundenplan Einrichten, sonst iPad Tagesansicht, Mac Vorbereiten") func initialSection() {
    #expect(AppSection.initial(isMac: false, hasTimetable: false) == .setup)
    #expect(AppSection.initial(isMac: false, hasTimetable: true) == .dayView)
    #expect(AppSection.initial(isMac: true, hasTimetable: true) == .preparation)
}
```

- [ ] **Step 2: Implementieren.** `RootView`: `TabView(selection:)` mit drei `Tab`s und `.tabViewStyle(.sidebarAdaptable)` (iPad: Leiste oder Seitenleiste nach Wahl der Lehrkraft, Mac: Seitenleiste).
  - `FrontstageApp` (Stand nach 08): Im `App`-Typ bleiben `DataLocationController`, `MicrosoftAccount`, `NetworkMonitor`, `SourceCoordinatorHolder` (05) und `.backgroundTask` (05). Inhalt des `WindowGroup`: `DataScopedRoot(controller: dataLocation) { store, container in ScopedAppContent(store: store, container: container, dataLocation: dataLocation, account: account, network: network, sourceCoordinators: sourceCoordinators) }`; `.onOpenURL { _ = MicrosoftAccount.handleRedirect($0) }` am `DataScopedRoot` (außen, übersteht einen Wechsel).
  - `ScopedAppContent` hält in `@State`: `StorageService` aus den Bausteinen von 03 (`references:` = dieser `DataStore`, `account:`/`network:` = die App-weiten; konkret `let grants = FolderGrantStore()`, `let resolver = MaterialResolver(grants: grants)`, `Prefetcher(resolver: resolver, store: store, downloader: SystemFileDownloader())`, `OneDriveService(account: account, graph: GraphClient(tokens: account.tokenProvider), grants: grants, resolver: resolver)`, `handOff: SystemDocumentHandOff()` – Vorbild `FrontstageTests/Storage/StorageServiceTests.swift`), `AppEnvironment(store: store, storage: storageService, today: { CalendarDay(Date(), calendar: .current) }, dataLocation: { dataLocation.location })`, den Koordinator über `sourceCoordinators.coordinator(for: store)` (05). `body`: `RootView()` mit `.modelContainer(container)`, `.environment(store)`, `.environment(storageService)`, `.environment(environment)`, `.environment(coordinator)`, `.environment(account)` (für Einrichten › Ablage, Aufgabe 14), `.environment(dataLocation)` (für `DataLocationSettingsView` in Einrichten, Aufgabe 11); bei Szenenphase `.active` und beim Wechsel `network.isOnline` → `true` (`.onChange(of: network.isOnline)`; `NetworkMonitor` ist `@Observable`) `storage.prepareForTeaching(today:timetable:nonTeachingPeriods:changes:)` mit den Werten aus dem `DataStore` (ohne Stundenplan: nichts) und die Koordinator-Aufrufe aus 05. Nicht `network.onBecameOnline` setzen: die Closure ist einzeln, `FrontstageApp.init` hat dort schon `DataLocationController.networkDidBecomeAvailable()` eingehängt, und eine je Datenort neu entstehende Ansicht würde sie überschreiben oder Verkettungen anhäufen. Die Koordinator-Aufrufe aus 05 stehen heute in der Closure von `DataScopedRoot` (`.onChange(of: scenePhase, initial: true)`: `.active` → `coordinator.refresh(.appBecameActive)`, `.background` → `MorningRefresh.schedule()` unter `#if os(iOS)`) und ziehen unverändert nach `ScopedAppContent` um; der Platzhalter `Text("app.placeholder.title")` und sein Schlüssel in `Localizable.xcstrings` entfallen. Swift-Hinweis: `DataScopedRoot` hängt den Inhalt mit `.id(generation)` an – nach einem Wechsel des Datenorts legt SwiftUI `ScopedAppContent` samt allen `@State`-Diensten neu an, auf dem neuen `DataStore`.
  - Szenen-Zubehör für den Zweitbildschirm meldet Teilplan 06 am `DataScopedRoot` an – hier nur ein Kommentar an der Stelle.
- [ ] **Step 3: Strings:** `app.section.dayView` „Heute“, `app.section.preparation` „Vorbereiten“, `app.section.setup` „Einrichten“, `app.dataUnavailable` „Die Daten konnten nicht geöffnet werden.“ (Platzhalter, Kategorie Wortlaut offen).
- [ ] **Step 4: Diff durchsehen:** `@MainActor` an `AppEnvironment`; kein `StorageService`, `AppEnvironment` oder Koordinator mehr als `@State` im `App`-Typ; genau ein `DataStore` in Gebrauch (der aus der Closure). Ein `ModelContainer`-Fehler beim Start gehört dem `DataLocationController` (08); dort steht das `fatalError` heute in `DataLocationController.init` (Teilplan 08, `container` und `store` sind nicht optional). Diese Aufgabe ersetzt es durch eine Fehleransicht (`ContentUnavailableView`, Text `app.dataUnavailable`) – siehe Abstimmungsbedarf, weil das die Schnittstelle von 08 berührt.
- [ ] **Step 5: Commit** `feat(app): root navigation between day view, preparation and setup`

---

### Task 8: Tagesansicht (Oberfläche)

Design-Takt: voll

**Files:**
- Create: `Frontstage/UI/DayView/DayView.swift`, `DayRowView.swift`

**Interfaces:**
- Consumes: `DayViewModel`, `DayViewLayout`, `DayStatement` (Aufgabe 6); `SourceStatusBar()` (Teilplan 05, Aufgabe 13); `HandOffAnchorReader`, `OpenOutcome` (03).
- Produces: `struct DayView: View { init(model: DayViewModel) }` – Teilplan 06 legt die Smartboard-Leiste per `.safeAreaInset(edge: .bottom)` darunter; die Höhe kommt damit automatisch aus dem `GeometryReader`.

- [ ] **Step 1: Bauen.** Kopf: Datum groß, Vor/Zurück/Heute in der Symbolleiste, rechts `SourceStatusBar()` aus Teilplan 05 (blendet sich bei Quelle „von Hand“ selbst aus; „Aktualisieren“ und Stand gehören dorthin). Je Unterrichtsstunde zusätzlich Thema, Bereitlegen und Hausaufgabe aus `LessonRow.info`, wenn nicht leer (kostenlos, FR-13). Öffnen: `HandOffAnchorReader` an jeder Materialzeile liefert den Anker (erstes Argument von `onResolve`); `.open` → `model.open(_:anchor:)`; solange die Zuordnung in `model.openingLinkIDs` steht oder `availability` `.downloading(progress:)` meldet, zeigt die Zeile einen Ladezustand (`ProgressView`, mit Fortschritt, wenn bekannt; Text `dayView.loading`) – `open` kann bis 120 s auf das Herunterladen warten (03); Ergebnis `.waitingForDownload` (zweiter Tipp) ändert daran nichts, `.failed` → Hinweis `dayView.openFailed`, `.unavailable` → „Neu verknüpfen“, `.showInViewer` behandelt Teilplan 06; „Neu verknüpfen“: `.fileImporter` → `actions.relink(_:fileURL:)`; `.saveFailed` → Hinweis `dayView.relinkSaveFailed` (nichts geändert), `.outsideGrantedFolders` → Hinweis mit „Ordner freigeben“; danach `await actions.notesToCarry(from: alter Verweis)` > 0 → `.confirmationDialog` `lesson.relink.carryNotes` („Notizen mitnehmen“ / „Hier lassen“) → `actions.carryNotes(from:to:)`, Fehler → Hinweis `lesson.relink.carryNotesFailed`; nach Rückkehr in die App `storage.offerOpenWithoutAutoSave(now:)` → Angebot „ohne AutoSpeichern öffnen“. Inhalt: `GeometryReader` → `DayViewLayout.rowHeight`; Wert vorhanden → `VStack` fester Zeilenhöhe, `nil` → `ScrollView`. Je Zeile: Stunde, Zeit, Klasse, Fach, Material als Knöpfe in Reihenfolge (`ViewThatFits`: alle Namen → gekürzte Namen → erster Name plus Anzahl). Jede der vier Aussagen zeigt `DayStatement.symbolName` **und** Text, nie nur Farbe. Ausgefallene Stunde: Kontextmenü „Ausfall aufheben“ (nur `.manual`), „Material weiterreichen“; Material: „In die nächste Stunde“, nicht verfügbar → „Neu verknüpfen“ über `.fileImporter`. Unter der Liste „Material ohne Stunde“ mit „Zuordnen …“ (Auswahl einer Unterrichtsstunde der nächsten 14 Tage). `.onChange(of: environment.store.revision) { model.reload() }`.
- [ ] **Step 2: Strings** unter `dayView.*` (u. a. `dayView.noLesson`, `dayView.withoutMaterial`, `dayView.unavailable`, `dayView.cancelled`, `dayView.substitute`, `dayView.withoutLesson`, `dayView.openWithoutAutoSave`, `dayView.loading` „Wird geladen …“, `dayView.openFailed` „Material konnte nicht geöffnet werden.“, `dayView.relinkSaveFailed` „Die neue Verknüpfung konnte nicht gespeichert werden.“; Texte des Stands kommen aus Teilplan 05) und `lesson.relink.carryNotes` „Am alten Ort liegen Notizen zu %lld Stunden. Mitnehmen?“, `lesson.relink.carryNotes.yes` „Notizen mitnehmen“, `lesson.relink.carryNotes.no` „Hier lassen“, `lesson.relink.carryNotesFailed` „Die Notizen konnten nicht verschoben werden; sie liegen weiter am alten Ort.“
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
/// Thema, Bereitlegen, Hausaufgabe eintragen – kostenlos (FR-13, Nutzerentscheidung 2026-11-13); Teilplan 07 nutzt diesen Editor mit.
@MainActor @Observable final class LessonInfoEditor {
    init(key: LessonKey, store: any PreparationStore)
    var topic: String; var toPrepare: String; var homework: String
    func save()   // über store.setLessonInfo; LessonInfo normalisiert (02): getrimmt, leer → nil (FR-11.1)
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
    #expect(try store.lessonInfo(for: key) == LessonInfo(topic: "Unit 4 – Wortschatz", toPrepare: nil, homework: nil))
}
```

- [ ] **Step 2: Implementieren.** `weekStart = today().mondayOfWeek`; Wochenwechsel ±7 Tage.
- [ ] **Step 3: Diff durchsehen:** `DayViewModel` nutzt danach dieselbe statische Funktion (kein doppelter Zeilenbau).
- [ ] **Step 4: Commit** `feat(ui): preparation week model and lesson info editor`

---

### Task 10: Vorbereiten (Oberfläche) – Woche, Zuordnen per Ziehen und Dateiauswahl

Design-Takt: voll

**Files:**
- Create: `Frontstage/UI/Preparation/PreparationView.swift`, `LessonDetailView.swift`, `MaterialDropTarget.swift`, `SubstituteLessonSheet.swift`, `CopyTargetPicker.swift`

**Interfaces:**
- Consumes: `PreparationViewModel`, `LessonInfoEditor`, `LessonActions`.
- Produces: `struct PreparationView: View { init(model: PreparationViewModel) }`; `struct LessonDetailView: View { init(key: LessonKey, model: PreparationViewModel) }` (Teilplan 07 ergänzt hier „Tafelbilder dieser Stunde“); `struct MaterialDropTarget: ViewModifier { init(key: LessonKey, actions: LessonActions, onError: @escaping (AssignError) -> Void) }`; `struct CopyTargetPicker: View { init(source: LessonKey, actions: LessonActions, onDone: @escaping (Int) -> Void) }` (FR-3.2: erst Klasse, dann Zielstunde wählen).

- [ ] **Step 1: Woche bauen.** `NavigationSplitView`: Inhalt = Woche (je Tag eine Spalte am Mac und auf dem iPad quer, sonst Liste je Tag – Systemstandard, Aufbau ist offene Kategorie), Detail = `LessonDetailView` der `selection`. Wochenwechsel in der Symbolleiste, „Vertretungsstunde“ öffnet `SubstituteLessonSheet` (Datum, Stunde aus Zeitraster oder 1–10, Klasse, Fach; Herkunft `.manual`).
- [ ] **Step 2: Zuordnen.** `MaterialDropTarget` an jeder Unterrichtsstunde und am Detail: `.dropDestination(for: URL.self, isEnabled: true) { urls, session in … }` (iOS/macOS 26, siehe Quellen) → `actions.assign(fileURLs:to:)`; am Mac zieht die Lehrkraft aus dem Finder, am iPad aus der Dateien-App in Split View. Zusätzlich Knopf „Material hinzufügen“ → `.fileImporter(isPresented:allowedContentTypes: [.item], allowsMultipleSelection: true)`. Fehler `AssignError.outsideGrantedFolders` → Hinweis mit Knopf „Ordner freigeben“ (springt zu Einrichten › Ablage).
- [ ] **Step 3: Detail.** Materialliste mit `ForEach(...).onMove { actions.reorder(key, fromOffsets:toOffset:) }` (Mac: Ziehen in der Liste; iPad: Bearbeiten-Modus), Entfernen; Aktionen „Für <Klasse> übernehmen“ (`CopyTargetPicker` als Sheet: Liste `copyTargetClasses`, dann Liste `copyTargetLessons` mit Datum, Stunde, Fach; leere Liste → Hinweis „keine Unterrichtsstunde in den nächsten 28 Tagen“; erst die Wahl der Lehrkraft ruft `copyLinks(from:to:)`), „In die nächste Stunde“, „Ausfall“ (Umschalter; `.blockedBySource` → Hinweis „laut Stundenplan-Quelle“), „Material weiterreichen“; Felder Thema, Bereitlegen, Hausaufgabe (`LessonInfoEditor`, Speichern bei `onSubmit` und `onDisappear`). Material ohne Stunde je Tag mit „Zuordnen …“ (`upcomingLessons(days: 14)`).
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
struct SetupView: View   // Form: Stundenplan, Zeitraster, Unterrichtsfrei, Datenort (DataLocationSettingsView aus 08 als Section, vor Ablage), Ablage, Stundenplan-Quelle (TimetableSourceSettingsView aus 05, Aufgabe 14)
```

- [ ] **Step 1: Tests schreiben**

```swift
@Test("AK-1: Eintrag Di 2. Std 8b Englisch anlegen") func addEntryFromEmpty() throws {
    try vm.save(Fixtures.entry(.tuesday, 2, "8b", "Englisch"), replacing: nil)
    #expect(try store.timetable()?.entries == [Fixtures.entry(.tuesday, 2, "8b", "Englisch")])
    #expect(try store.manuallyEditedEntries().contains(Fixtures.entry(.tuesday, 2, "8b", "Englisch")))   // Herkunft .manual (AK-3)
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

- [ ] **Step 2: Implementieren.** `save(_:replacing: nil)` → `store.addEntry(_:origin: .manual)`, sonst `store.replaceEntry(_:with:)` (02 markiert Quell-Einträge als von Hand geändert); `setWeekVariantCount(1, confirmed: true)` löscht `.b`-Einträge per `removeEntry` und ersetzt `.a`-Einträge per `replaceEntry` durch dieselben ohne Variante. Bezugswoche = `day.mondayOfWeek` (01); Klasse/Fach über `SchoolClass(_:)`/`Subject(_:)`, leer nach `normalized` → Fehler. Ansicht: Raster Wochentag × Stunde (Systemstandard `Grid`), Tipp auf Feld → `TimetableEntrySheet` (Klasse, Fach, bei 2 Varianten „gilt für: beide / A / B“).
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
    #expect(try store.timetable()?.bellSchedule.periods[2] == TimeOfDay(hour: 8, minute: 35)...TimeOfDay(hour: 9, minute: 20))
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
@Test("Zeitraum entfernen löscht kein Material") func removeKeepsLinks()   // store.materialLinkItems(for: nov3-Schlüssel).count unverändert
```

- [ ] **Step 2: Implementieren;** `materialsWithoutLesson(in:)` sammelt `store.orphanedLinkItems(on:)` für jeden Tag von `from` bis `to` (`adding(days:)`, Teilplan 01). Ansicht: Liste der Zeiträume, je Zeitraum Zahl des Materials ohne Stunde und Aufklappliste mit „Zuordnen …“.
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
/// Folge des Abmeldens von Microsoft (ADR-0012): bei Datenort OneDrive hält der Abgleich an.
enum MicrosoftSignOutImpact: Equatable { case none, stopsDataFolderSync }
@MainActor @Observable final class StorageSettingsViewModel {
    init(environment: AppEnvironment, account: MicrosoftAccount)
    private(set) var grants: [FolderGrant]                  // auf diesem Gerät (03)
    /// Gespiegelte Namen aus Zuordnungen (store.folderGrantNames()) ohne lokale Freigabe – sortiert.
    var missingOnThisDevice: [String] { get }
    func suggestion(for folderURL: URL) -> GrantNameSuggestion
    func add(folderURL: URL, name: String) async throws
    func remove(id: UUID)
    var isSignedIn: Bool { get }                            // account.isSignedIn
    /// .stopsDataFolderSync, wenn environment.dataLocation() == .oneDrive und angemeldet.
    func signOutImpact() -> MicrosoftSignOutImpact
    /// Ohne Bestätigung bei .stopsDataFolderSync: nichts tun, false. Sonst account.signOut(), true.
    func signOut(confirmed: Bool) async -> Bool
}
```
`SetupView` zeigt unter „Stundenplan-Quelle“ die fertige `TimetableSourceSettingsView()` aus Teilplan 05 (Koordinator aus der Umgebung) als Ziel eines `NavigationLink` – die Ansicht ist selbst ein `Form` mit `navigationTitle` und darf nicht in ein anderes `Form` geschachtelt werden. Unter „Ablage“ zusätzlich Microsoft an/ab über `MicrosoftAccount` (nur wenn `isConfigured`, Teilplan 03) und je Freigabe den OneDrive-Pfad (Anzeige). Der Datenort selbst (Wahl, Stand des Abgleichs, Koppeln) ist Teilplan 08; `SetupView` bettet `DataLocationSettingsView(controller: dataLocation, isOneDriveAvailable: account.isConfigured, accountUsername: { account.signedInUsername })` als Abschnitt vor „Ablage“ ein (Controller und Konto aus der Umgebung, Aufgabe 7).

- [ ] **Step 1: Tests schreiben**

```swift
@Test("Fehlende Freigabe auf diesem Gerät wird gemeldet") func missingGrantListed()   // lokale Freigabe "Unterricht", Zuordnungen mit "Unterricht" und "Klausuren" → missing == ["Klausuren"]
@Test("Freigabe entfernen löscht keine Zuordnung") func removeGrantKeepsLinks()
@Test("Gespiegelter Name wird vorgeschlagen (zweites Gerät)") func suggestsMirroredName()   // FakeStorage liefert matchesMirroredName → Vorschlag "Unterricht"
@Test("ADR-0012: Abmelden bei Datenort OneDrive verlangt Bestätigung") func signOutWithOneDriveDataLocationRequiresConfirmation() async {
    let vm = StorageSettingsViewModel(environment: Fixtures.environment(store: store, storage: storage, dataLocation: .oneDrive),
                                      account: MicrosoftAccount(signedInUsernameForTesting: "lehrkraft@example.com"))
    #expect(vm.signOutImpact() == .stopsDataFolderSync)
    #expect(await vm.signOut(confirmed: false) == false)
    #expect(vm.isSignedIn)
}
@Test("Abmelden bei Datenort iCloud ohne Rückfrage") func signOutWithICloudNeedsNoConfirmation()   // dataLocation .iCloud → signOutImpact() == .none
```
Hinweis: `signOut()` berührt mit dem Test-Initialisierer MSAL nicht (`application == nil`, nur der Schlüssel `MicrosoftAccountIdentifier` in `UserDefaults.standard` wird entfernt); der Fall „bestätigt → abgemeldet“ (`signOut(confirmed: true)` → `true`, danach `isSignedIn == false`) lässt sich deshalb im Test prüfen. Das echte Abmelden mit Datenort OneDrive steht zusätzlich in der Geräte-Checkliste von Teilplan 08 (Zeile 8).

- [ ] **Step 2: Implementieren;** Ansicht: Liste, „Ordner freigeben“ → `.fileImporter(allowedContentTypes: [.folder], allowsMultipleSelection: false)`, Name aus `suggestion(for:)` vorbelegt, fehlende Freigaben mit Knopf „Hier freigeben“. „Bei Microsoft abmelden“: `signOutImpact() == .stopsDataFolderSync` → `.confirmationDialog` mit `setup.microsoft.signOut.warning` („Der Datenort ist OneDrive. Nach dem Abmelden gleicht Frontstage nicht mehr ab, bis wieder angemeldet wird. Änderungen bleiben auf diesem Gerät erhalten.“), Knöpfe `setup.microsoft.signOut.confirm` „Trotzdem abmelden“ und Abbrechen; sonst sofort abmelden. Wortlaut Platzhalter (offene Kategorie).
- [ ] **Step 3: Diff durchsehen.**
- [ ] **Step 4: Commit** `feat(ui): storage folder grants in setup`

---

### Task 15: CI-Lauf (workflow_dispatch) und Ergebnis prüfen

Design-Takt: keiner

**Diese Aufgabe führt der Controller aus, nicht ein Implementierer** (Sparregel der Übersicht und `CLAUDE.md`: CI kostet macOS-Minuten, höchstens ein Lauf je Teilplan). Im Bündel B läuft der CI-Lauf gemeinsam mit Teilplan 05 (dessen Aufgabe 14) einmal am Bündelende.

- [ ] **Step 0: Syntaxprüfung** – `.\scripts\swift-parse.ps1` lokal, Syntaxfehler vor dem Lauf beheben (Übersicht, Global Constraints).
- [ ] **Step 1: Diff des ganzen Teilplans durchsehen** gegen die Global Constraints (ADR-0002-Regeln unberührt, kein `import SwiftUI` in View-Modellen, englische Bezeichner, deutsche Kommentare, Strings nur in `Localizable.xcstrings`).
- [ ] **Step 2: Lauf anstoßen**

```bash
git push -u origin feature/batch-b-schulmanager-oberflaeche
gh workflow run ci.yml --ref feature/batch-b-schulmanager-oberflaeche
gh run watch
```
Erwartet: Job grün; `swift test` unverändert grün (dieser Teilplan ändert den Kern nicht); `xcodebuild test` mit allen `FrontstageTests/UI/*`-Tests grün (inkl. `PreparationStoreTests`), beide Ziele (iPadOS, macOS) bauen.
- [ ] **Step 3: Bei Rot** `superpowers:systematic-debugging`, alle Fehler im Log sammeln, gesammelt beheben, **ein** neuer Lauf.

---

### Task 16: Erster TestFlight-Bau

Design-Takt: keiner

**Files:**
- Create: `.github/workflows/testflight.yml`, `ci/ExportOptions-TestFlight.plist`
- Modify: `project.yml` (`ITSAppUsesNonExemptEncryption: false` – Boolean, nicht der Text „NO“ – in den Info.plist-Eigenschaften beider Ziele; `CFBundleVersion: $(CURRENT_PROJECT_VERSION)` steht dort schon, `CURRENT_PROJECT_VERSION=$GITHUB_RUN_NUMBER` auf der Kommandozeile genügt)

**Voraussetzungen (Mensch, einmalig):** Apple-Entwicklerkonto (RISK-4); App-Eintrag in App Store Connect; CloudKit-Container aus Teilplan 02 angelegt; App-Store-Connect-API-Schlüssel (Rolle „App Manager“). Secrets im Repo: `APPLE_TEAM_ID`, `BUNDLE_ID_PREFIX`, `ASC_KEY_ID`, `ASC_ISSUER_ID`, `ASC_KEY_P8_BASE64`, `MSAL_CLIENT_ID` (Teilplan 03; leer = OneDrive-Zusatz ausgeblendet). `CLOUDKIT_CONTAINER_ID` (Teilplan 02) wird aus `BUNDLE_ID_PREFIX` gebildet. Nur interne Tester, solange Q-31 offen ist.

- [ ] **Step 1: Workflow schreiben.** Auslöser nur `workflow_dispatch`. Schritte: Checkout → `brew install xcodegen` → `xcodegen generate` → API-Schlüssel aus `ASC_KEY_P8_BASE64` nach `$RUNNER_TEMP/AuthKey.p8` → 
```bash
xcodebuild archive -project Frontstage.xcodeproj -scheme Frontstage-iOS -destination 'generic/platform=iOS' \
  -archivePath build/Frontstage-iOS.xcarchive DEVELOPMENT_TEAM="$APPLE_TEAM_ID" \
  PRODUCT_BUNDLE_IDENTIFIER="$BUNDLE_ID_PREFIX.frontstage" CURRENT_PROJECT_VERSION="$GITHUB_RUN_NUMBER" \
  CLOUDKIT_CONTAINER_ID="iCloud.$BUNDLE_ID_PREFIX.frontstage" MSAL_CLIENT_ID="$MSAL_CLIENT_ID" \
  -allowProvisioningUpdates -authenticationKeyPath "$RUNNER_TEMP/AuthKey.p8" \
  -authenticationKeyID "$ASC_KEY_ID" -authenticationKeyIssuerID "$ASC_ISSUER_ID"
xcodebuild -exportArchive -archivePath build/Frontstage-iOS.xcarchive -exportOptionsPlist ci/ExportOptions-TestFlight.plist \
  -exportPath build/export -allowProvisioningUpdates -authenticationKeyPath "$RUNNER_TEMP/AuthKey.p8" \
  -authenticationKeyID "$ASC_KEY_ID" -authenticationKeyIssuerID "$ASC_ISSUER_ID"
```
  Schlüsseldatei am Ende löschen (`if: always()`). Zweiter Job gleich für `Frontstage-macOS` mit `-destination 'generic/platform=macOS'`. Schema-Namen aus Teilplan 01 übernehmen, falls sie abweichen.
- [ ] **Step 2: `ExportOptions-TestFlight.plist`:** `method` = `app-store-connect`, `destination` = `upload`, `signingStyle` = `automatic`, `teamID` als Platzhalter `$(APPLE_TEAM_ID)` – im Workflow vor dem Export per `plutil -replace teamID -string "$APPLE_TEAM_ID"` gesetzt. Quelle: `xcodebuild -help` (Abschnitt „Available keys for -exportOptionsPlist“) am Runner – Step 3 gibt ihn ins Log aus, um die Schlüssel zu belegen.
- [ ] **Step 3: Diff durchsehen:** keine echte Team-ID, Bundle-ID oder Schlüssel im Repo; `xcodebuild -help | sed -n '/exportOptionsPlist/,/^$/p'` als erster Schritt im Workflow.
- [ ] **Step 4: Lauf – führt der Controller aus, nicht ein Implementierer** (kostet macOS-Minuten; erst nach den Voraussetzungen des Menschen). `workflow_dispatch` startet nur, wenn `testflight.yml` auf `main` liegt (Übersicht, Abstimmung 7): vorher ein kleiner PR nur mit dem Workflow nach `main`. Dann `gh workflow run testflight.yml --ref <branch>`, `gh run watch`. Erwartet: beide Jobs grün; in App Store Connect › TestFlight erscheint Build `$GITHUB_RUN_NUMBER` für iPadOS und macOS.
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
| FR-3.2, AK-7 | 4, 10 (Auswahl der Zielstunde) |
| FR-3.3, AK-8 | 4, 8, 10 |
| FR-3.4 | 3, 4 (keine Dateioperation; AK-9 Gerät gehört Teilplan 03) |
| FR-4, AK-10 | 6, 8, 17 |
| FR-7, AK-14 | 6, 9, 13 |
| FR-8, AK-15 | 4, 5, 6, 8, 10 |
| FR-9, AK-16 | 5, 6, 10 |
| FR-11.1 (Eingabe und Anzeige Thema/Bereitlegen/Hausaufgabe, kostenlos) | 6, 8, 9, 10 |
| Stand der Stundenplan-Quelle | 8 (Ansicht aus 05) |
| FR-6.1 / ADR-0011 – Naht: Schieben meldet Umzüge, Neu verknüpfen bietet Mitnehmen an (Umsetzung 06) | 3, 4, 8 |
| ADR-0003 Neu verknüpfen inkl. `saveFailed` | 3, 8 |
| NFR-1 – Ladezustand, solange `open` auf das Herunterladen wartet | 6, 8 |
| FR-14 / ADR-0012 – Hinweis beim Abmelden von Microsoft bei Datenort OneDrive | 14 |

## Self-Review

- **Spec-Abdeckung:** alle zugewiesenen FR/AK zugeordnet. Nicht hier: AK-3, AK-21, AK-41 (Teilplan 05, Import-Oberfläche nur als Platz in Aufgabe 14), AK-9, AK-11, AK-12, AK-17, AK-19 (Ablage, 03), AK-13, AK-22, AK-23 (Anzeige, 06), AK-24 bis AK-40 (06/07).
- **Typen:** `PreparationStore`/`MaterialStorage` in 1; `LessonActions` wächst über 3–5 und wird in 6, 9, 10, 13 nur konsumiert; `DayContent`/`DayRow` in 6 definiert und in 9 wiederverwendet; `MaterialOpenAction`, `AppEnvironment.viewerAvailable` und `PenNoteFileRelocating` (`AppEnvironment.penNotes`) sind die Naht zu 06; `ScopedAppContent` ist die einzige Stelle, an der Dienste mit `DataStore` entstehen.
- **Proportion:** Funktionskörper nur für Zeilenbau, `rowHeight` und Abbildung auf Store-Methoden beschrieben, sonst Signaturen und Tests.

## Abstimmungsbedarf

- **Offen nach Preflight 2026-11-14** (Entwurfsebene, nicht still entschieden): (a) Ruling aus Bündel A – Einrichten/Koppeln soll außerhalb des generation-gebundenen `DataScopedRoot`-Teilbaums liegen, damit ein Datenort-Wechsel den Kopplungsablauf nicht abreißt; dieser Plan legt `SetupView` in `RootView` innerhalb von `ScopedAppContent`. (b) Das `fatalError` in `DataLocationController.init` durch eine Fehleransicht zu ersetzen (Aufgabe 7) ändert die Schnittstelle von 08 (`container`/`store` nicht optional, genutzt in `FrontstageApp` und `runMorningRefresh`).
- Sonst keiner offen (abgeglichen nach Übersicht, Abschnitt „Abstimmung“, Punkte 14 und 15): Kern aus 01, Daten über `PreparationStore` → `DataStore` (02), Ablage über `MaterialStorage` → `StorageService` (03, inkl. `RelinkResult.saveFailed` und Warten in `open`), Quelle als fertige Ansichten aus 05 (Koordinator über `SourceCoordinatorHolder`), Dienste je Datenort in `ScopedAppContent` innerhalb `DataScopedRoot` (08), Hinweis beim Abmelden von Microsoft bei Datenort OneDrive (Aufgabe 14, aus dem Abstimmungsbedarf von 08), Übernehmen mit Auswahl der Zielstunde (Nutzerentscheidung 2026-11-13).
- **Teilplan 06** setzt `AppEnvironment.viewerAvailable` und `AppEnvironment.penNotes` (in `ScopedAppContent`), behandelt `MaterialOpenAction.viewer` und `OpenOutcome.showInViewer`, legt die Smartboard-Leiste per `.safeAreaInset` unter `DayView` und meldet das Szenen-Zubehör am `DataScopedRoot` an (06 nennt diese Dateien als `Modify`).
- **Teilplan 07** ergänzt `LessonDetailView` (Tafelbilder) und `SetupView` (Kauf wiederherstellen) als `Modify`.
- **Glossar:** kein neuer Fachbegriff; `Origin.source` in der Oberfläche als „laut Stundenplan-Quelle“ (Wortlaut offen).
