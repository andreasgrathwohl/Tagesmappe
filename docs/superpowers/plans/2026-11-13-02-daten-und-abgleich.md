# Frontstage — Teilplan 02: Daten und Abgleich

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.
> Rahmen: `docs/superpowers/plans/2026-11-13-00-uebersicht.md` – gilt vollständig und geht diesem Teilplan vor.

**Goal:** Die App-Daten (alle Modelle der Tabelle „Datenmodell“, Area daten) als SwiftData-Modelle mit Spiegelung in die private iCloud-Datenbank, einen Speicher-Baustein mit allen Operationen, die Oberfläche und Stundenplan-Quellen brauchen, und das Zusammenführen von Dubletten nach dem Abgleich bauen.

**Architecture:** Werttypen und die reine Zusammenführ-Logik (`SyncMerger`) liegen in `Packages/FrontstageCore` und werden mit `swift test` geprüft. Die SwiftData-Klassen (Suffix `Record`) liegen in `Frontstage/Data/Records/`, die Übersetzung Record ↔ Kern in `Frontstage/Data/RecordConversion.swift`. Der Speicher-Baustein `DataStore` (`@MainActor`) kapselt jede Schreiboperation, rechnet Unterrichtsstunden über `TimetableCalculator` (Teilplan 01) und wendet den Zusammenführ-Plan an; `SyncMergeTrigger` stößt das Zusammenführen nach dem Abgleich an.

**Tech Stack:** Swift 6 strikt, SwiftData mit `ModelConfiguration(cloudKitDatabase: .private(…))`, Swift Testing, XcodeGen (`entitlements:`/`info:` in `project.yml`).

**Spec:** `docs/ARCHITECTURE.md` (Area daten: Datenmodell, Nebenläufigkeit, Betrieb; Area anzeige: Stiftnotizen, Tafel), `docs/adr/0002`, `0003`, `0005`, `0006`, `0009`, `docs/PRD.md` (Glossar, FR-3 bis FR-3.4, FR-6.1, FR-7 bis FR-9, FR-11.1, FR-12.1, FR-12.2; AK-6, AK-7, AK-8, AK-15, AK-22, AK-25).

**Quellen für Apple-APIs (gelesen 2026-11-13 über Context7, `/websites/developer_apple_swiftdata` und `/yonaskolb/xcodegen`):**
- `ModelConfiguration.CloudKitDatabase.private(_:)` – Spiegelung in den genannten Container; `.none` schaltet sie ab (für Tests).
- `Schema.Attribute.Option.externalStorage` – ab iOS 17/macOS 14.
- „Syncing model data across a person’s devices“: braucht die Fähigkeit iCloud mit CloudKit **und** Background Modes → Remote notifications.
- `HistoryObserver` (beobachtet `ModelContainer`-Fernänderungen) gibt es erst ab iOS/macOS 27 – deshalb hier **nicht** genutzt.
- XcodeGen: `targets.<ziel>.entitlements: { path, properties }` und `info: { path, properties }` erzeugen die Dateien bei jedem Lauf.
- **Nicht in der SwiftData-Doku belegt:** dass SwiftData mit CloudKit die Core-Data-Mitteilung `.NSPersistentStoreRemoteChange` sendet. Sie wird als Auslöser genutzt, aber nie als einziger (Task 10), und am Gerät geprüft (Task 11).

## Global Constraints

Alle Zeilen der Übersicht gelten (Abschnitt „Global Constraints“). Zusätzlich für diesen Teilplan:

- **Kein Teilplan-02-Task berührt Oberfläche → `Design-Takt: keiner`** für alle Aufgaben.
- Jede gespeicherte Eigenschaft hat einen Vorgabewert oder ist optional; jede Beziehung ist optional **und hat eine Gegenrichtung** (`inverse:`), weil die CloudKit-Spiegelung Beziehungen ohne Gegenrichtung nicht abbildet.
- Aufzählungen werden als Rohwert gespeichert (`String`/`Int`), nie als Swift-`enum`-Attribut; Kern-Werte (`CalendarDay`, `LessonKey`) als Text (`dayText`, `lessonKeyText`).
- Jeder Record trägt `recordID: UUID = UUID()` (fachlich bedeutungslos, nicht eindeutig erzwungen) und `createdAt: Date = .now`. `recordID` ist die Kennung, über die Schnappschüsse und `MergePlan` sprechen.
- **Schema nach der ersten Freigabe der CloudKit-Produktionsumgebung nur additiv ändern** (neue optionale Eigenschaften, neue Modelle); nie umbenennen oder löschen.
- Jede Schreiboperation des `DataStore` endet mit `modelContext.save()`; keine Operation schreibt in die Ablage oder kopiert Dateien (FR-3.4).
- App-Tests laufen mit `ModelContainerFactory.makeInMemoryContainer()` (ohne Spiegelung); kein Test braucht ein iCloud-Konto.
- Testdaten: Stundenplan im Schuljahr 2026/27 – **Di 17.11.2026, Mi 18.11.2026, Do 19.11.2026**; Klassen `8a`, `8b`; Fach `Englisch`; Materialnamen „Präsentation“, „Arbeitsblatt“, „Lösung“, „Vokabeln.pdf“; Ordnerfreigabe-Name `Unterricht`.

## Review Focus

1. **Beide Geräte legen beim ersten Start je einen Stundenplan an** → nach dem Abgleich zwei aktive Stundenpläne; erwartet: einer bleibt (der älteste), die Einträge des anderen hängen danach an ihm, doppelte Einträge verschwinden, keine Unterrichtsstunde erscheint doppelt. Test: Task 3 `mergesDuplicateActiveTimetables`, Task 7 `mergeMovesEntriesBeforeDeletingTimetable`.
2. **Zusammenführen löscht eine Zuordnung, deren Stiftnotizen gerade umgehängt werden** → die Löschregel „Stiftnotizen mitlöschen“ darf sie nicht treffen. Test: Task 7 `mergeKeepsPenNotesOfDroppedLink`.
3. **Stundenangaben nur aus Leerzeichen oder Zeilenumbrüchen** → gelten als leer, der Klassenbildschirm zeigt keine leere Zeile. Test: Task 1 `lessonInfoTreatsWhitespaceAsEmpty`.
4. **„In die nächste Stunde“ ohne nächste Stunde in 28 Tagen** (letzte Stunde vor den Sommerferien) → Rückgabe `nil`, die Zuordnung bleibt unverändert an ihrer Unterrichtsstunde. Test: Task 8 `moveToNextLessonWithoutNextLessonKeepsLink`.
5. **„Für Klasse übernehmen“ in eine Stunde, die dieselbe Datei schon hat** → kein zweiter Eintrag derselben Datei. Test: Task 8 `copyLinksSkipsFilesAlreadyInTarget`.

---

## Dateistruktur

| Datei | Verantwortung |
|---|---|
| `Packages/FrontstageCore/Sources/FrontstageCore/Data/CalendarDay+StorageText.swift` | `CalendarDay` ↔ `"JJJJ-MM-TT"` |
| `Packages/FrontstageCore/Sources/FrontstageCore/Data/MaterialReference.swift` | Wert des Materialverweises, `fileIdentity` |
| `Packages/FrontstageCore/Sources/FrontstageCore/Data/LessonInfo.swift` | Stundenangaben als Wert, Normalisierung |
| `Packages/FrontstageCore/Sources/FrontstageCore/Data/ParallelLessonFinder.swift` | passende Unterrichtsstunde einer anderen Klasse (FR-3.2) |
| `Packages/FrontstageCore/Sources/FrontstageCore/Merge/SyncSnapshot.swift` | Schnappschuss-Werte und `MergePlan` |
| `Packages/FrontstageCore/Sources/FrontstageCore/Merge/SyncMerger.swift` | reine Zusammenführ-Logik |
| `Packages/FrontstageCore/Tests/FrontstageCoreTests/DataValuesTests.swift`, `ParallelLessonFinderTests.swift`, `SyncMergerTests.swift` | Kern-Tests |
| `Frontstage/Data/Records/*.swift` | je Modell eine `@Model`-Klasse |
| `Frontstage/Data/ModelContainerFactory.swift` | Schema, Container mit Spiegelung, In-Memory-Container |
| `Frontstage/Data/RecordConversion.swift` | Record ↔ Kern-Typen, Schnappschüsse |
| `Frontstage/Data/DataStore.swift` | Stundenplan, unterrichtsfreie Zeiträume, Abweichungen, Unterrichtsstunden |
| `Frontstage/Data/DataStore+Merge.swift` | `MergePlan` anwenden |
| `Frontstage/Data/DataStore+MaterialLinks.swift` | Zuordnungen, Stiftnotizen |
| `Frontstage/Data/DataStore+LessonData.swift` | Stundenangaben, Tafelseiten |
| `Frontstage/Data/SyncMergeTrigger.swift` | Auslöser für das Zusammenführen |
| `FrontstageTests/Data/*.swift` | App-Tests (Simulator) |
| `project.yml` (ändern) | Entitlements, Info-Schlüssel, Build-Einstellung `CLOUDKIT_CONTAINER_ID` |
| `Frontstage/App/FrontstageApp.swift` (ändern) | Container, `DataStore`, Auslöser einbinden |

---

### Task 1: Kern-Werte für die Datenhaltung

Design-Takt: keiner

**Files:**
- Create: `Packages/FrontstageCore/Sources/FrontstageCore/Data/CalendarDay+StorageText.swift`, `.../Data/MaterialReference.swift`, `.../Data/LessonInfo.swift`
- Test: `Packages/FrontstageCore/Tests/FrontstageCoreTests/DataValuesTests.swift`

**Interfaces:**
- Consumes: `CalendarDay` (Teilplan 01)
- Produces:

```swift
extension CalendarDay {
    /// „JJJJ-MM-TT“, mit führenden Nullen – sortiert als Text wie als Datum.
    public var storageText: String { get }
    public init?(storageText: String)          // nil bei falschem Format oder ungültigem Datum (gregorianisch)
}

/// Materialverweis gemäß ADR-0003: gespiegelter Name der Ordnerfreigabe + Pfad darin, ggf. OneDrive-Kennung.
public struct MaterialReference: Hashable, Codable, Sendable {
    public var folderGrantName: String
    public var relativePath: String
    public var oneDriveItemID: String?
    public var displayName: String
    public var fileType: String                // UTType-Kennung, z. B. "com.adobe.pdf"
    public init(folderGrantName: String, relativePath: String, oneDriveItemID: String? = nil, displayName: String, fileType: String)
    /// Fachlicher Schlüssel „dieselbe Datei“: "onedrive:<id>" wenn eine nicht leere OneDrive-Kennung da ist, sonst "path:<Freigabe>/<Pfad>".
    public var fileIdentity: String { get }
}

public enum LessonInfoField: String, CaseIterable, Codable, Sendable { case topic, toPrepare, homework }

/// Stundenangaben (FR-11.1): leere oder nur aus Leerraum bestehende Felder sind nil.
public struct LessonInfo: Hashable, Codable, Sendable {
    public var topic: String?
    public var toPrepare: String?
    public var homework: String?
    public init(topic: String? = nil, toPrepare: String? = nil, homework: String? = nil)   // normalisiert
    public func normalized() -> LessonInfo     // trimmt .whitespacesAndNewlines, "" → nil
    public var isEmpty: Bool { get }
    public subscript(field: LessonInfoField) -> String? { get set }
}
```

- [ ] **Step 1: Failing Tests schreiben**

```swift
@Test("CalendarDay als Text mit führenden Nullen, hin und zurück")
func calendarDayStorageTextRoundTrip() {
    let day = CalendarDay(year: 2026, month: 11, day: 9)
    #expect(day.storageText == "2026-11-09")
    #expect(CalendarDay(storageText: "2026-11-17") == CalendarDay(year: 2026, month: 11, day: 17))
    #expect("2026-11-09" < "2026-11-17")   // Text sortiert wie das Datum
}

@Test("Ungültiger Datumstext ergibt nil")
func calendarDayRejectsInvalidText() {
    #expect(CalendarDay(storageText: "") == nil)
    #expect(CalendarDay(storageText: "2026-13-01") == nil)
    #expect(CalendarDay(storageText: "2026-02-30") == nil)
    #expect(CalendarDay(storageText: "17.11.2026") == nil)
}

@Test("Dieselbe Datei: OneDrive-Kennung vor Pfad")
func materialReferenceFileIdentity() {
    let a = MaterialReference(folderGrantName: "Unterricht", relativePath: "Englisch/Vokabeln.pdf", displayName: "Vokabeln.pdf", fileType: "com.adobe.pdf")
    #expect(a.fileIdentity == "path:Unterricht/Englisch/Vokabeln.pdf")
    var b = a; b.oneDriveItemID = "01ABC"
    #expect(b.fileIdentity == "onedrive:01ABC")
    b.oneDriveItemID = ""
    #expect(b.fileIdentity == a.fileIdentity)
}

@Test("AK-25: leere Stundenangaben gelten als nicht vorhanden")
func lessonInfoNormalizesEmptyFields() {
    let info = LessonInfo(topic: "Unit 4 – Wortschatz", toPrepare: "", homework: nil)
    #expect(info.topic == "Unit 4 – Wortschatz")
    #expect(info.toPrepare == nil)
    #expect(LessonInfo().isEmpty)
}

@Test("Review Focus 3: nur Leerraum ist leer")
func lessonInfoTreatsWhitespaceAsEmpty() {
    let info = LessonInfo(topic: "  Unit 4 – Wortschatz \n", toPrepare: " \n\t ", homework: "   ")
    #expect(info.topic == "Unit 4 – Wortschatz")
    #expect(info.toPrepare == nil)
    #expect(info.homework == nil)
}
```

- [ ] **Step 2: Diff durchsehen** – nur `import Foundation`; `CalendarDay(year:month:day:)` ist im Paket erreichbar (Tests mit `@testable import FrontstageCore`); Prüfung des Datums über `DateComponents.isValidDate(in: Calendar(identifier: .gregorian))`.
- [ ] **Step 3: Implementieren** gemäß Interfaces.
- [ ] **Step 4: Diff durchsehen** – alle öffentlichen Typen `Sendable`, deutsche `///`-Kommentare, keine Zeitzone im Spiel.
- [ ] **Step 5: Commit**

```bash
git add Packages/FrontstageCore/Sources/FrontstageCore/Data Packages/FrontstageCore/Tests/FrontstageCoreTests/DataValuesTests.swift
git commit -m "core: add storage text, MaterialReference and LessonInfo values"
```

---

### Task 2: Passende Unterrichtsstunde einer anderen Klasse (FR-3.2)

Design-Takt: keiner

**Files:**
- Create: `Packages/FrontstageCore/Sources/FrontstageCore/Data/ParallelLessonFinder.swift`
- Test: `Packages/FrontstageCore/Tests/FrontstageCoreTests/ParallelLessonFinderTests.swift`

**Interfaces:**
- Consumes: `TimetableCalculator.lessons(on:timetable:nonTeachingPeriods:changes:)`, `LessonKey`, `SchoolClass`, `Timetable` (Teilplan 01)
- Produces:

```swift
public enum ParallelLessonFinder {
    /// Erste nicht ausgefallene Unterrichtsstunde von `targetClass` im selben Fach wie `key`,
    /// ab dem Tag von `key` (derselbe Tag zählt, auch eine frühere Stunde), höchstens `maxDays` Tage weit.
    public static func matchingLesson(for key: LessonKey, targetClass: SchoolClass, timetable: Timetable,
                                      nonTeachingPeriods: [NonTeachingPeriod], changes: [ScheduleChange],
                                      maxDays: Int = 28) -> LessonKey?
    /// Klassen, die im Stundenplan dasselbe Fach haben, ohne die Klasse von `key`; sortiert nach `normalized`.
    public static func parallelClasses(for key: LessonKey, timetable: Timetable) -> [SchoolClass]
}
```

Fixture A (auch in Task 8): eine Wochenvariante, Bezugswoche 16.11.2026, Einträge Di 2. Stunde 8a Englisch, Mi 3. Stunde 8b Englisch, Do 1. Stunde 8a Englisch.

- [ ] **Step 1: Failing Tests schreiben**

```swift
@Test("AK-7: Di 8a findet Mi 3. Stunde 8b")
func matchingLessonFindsNextLessonOfParallelClass() {
    let di8a = lessonKey(fixtureA, on: .init(year: 2026, month: 11, day: 17), class: "8a")
    let target = ParallelLessonFinder.matchingLesson(for: di8a, targetClass: SchoolClass("8b"), timetable: fixtureA, nonTeachingPeriods: [], changes: [])
    #expect(target?.date == CalendarDay(year: 2026, month: 11, day: 18))
    #expect(target?.schoolClass == SchoolClass("8b"))
    #expect(target?.subject == Subject("Englisch"))
    #expect(target?.ordinal == 1)
}

@Test("Ausgefallene Stunde der Zielklasse wird übersprungen")
func matchingLessonSkipsCancelledLesson() {
    // Mi 18.11. 8b als Ausfall → nächste 8b-Englisch-Stunde Mi 25.11.
    #expect(target?.date == CalendarDay(year: 2026, month: 11, day: 25))
}

@Test("Keine Stunde der Zielklasse in 28 Tagen ergibt nil")
func matchingLessonReturnsNilWithoutLesson()       // Zielklasse "9c" ohne Eintrag → nil

@Test("Parallelklassen im selben Fach")
func parallelClassesListsOtherClassesWithSameSubject() {
    #expect(ParallelLessonFinder.parallelClasses(for: di8a, timetable: fixtureA) == [SchoolClass("8b")])
}
```

`lessonKey(_:on:class:)` ist ein Test-Helfer, der den Schlüssel aus `TimetableCalculator.lessons(on:…)` holt.

- [ ] **Step 2: Diff durchsehen** – Tagesweiterzählung über `Calendar(identifier: .gregorian)` als `private`-Helfer in dieser Datei (keine öffentliche Erweiterung von `CalendarDay`, um Teilplan 01 nicht zu überschneiden).
- [ ] **Step 3: Implementieren** gemäß Interfaces; Reihenfolge: Tage aufsteigend, innerhalb eines Tages die Reihenfolge von `lessons(on:)`.
- [ ] **Step 4: Diff durchsehen.**
- [ ] **Step 5: Commit** – `git commit -m "core: find matching lesson of a parallel class"`

---

### Task 3: Reine Zusammenführ-Logik `SyncMerger`

Design-Takt: keiner

**Files:**
- Create: `Packages/FrontstageCore/Sources/FrontstageCore/Merge/SyncSnapshot.swift`, `.../Merge/SyncMerger.swift`
- Test: `Packages/FrontstageCore/Tests/FrontstageCoreTests/SyncMergerTests.swift`

**Interfaces:**
- Consumes: `TimetableEntry`, `ScheduleChange`, `NonTeachingPeriod` (Teilplan 01), `LessonInfoField` (Task 1)
- Produces:

```swift
public struct TimetableSnapshot: Hashable, Sendable { public var id: UUID; public var isActive: Bool; public var createdAt: Date }
public struct TimetableEntrySnapshot: Hashable, Sendable { public var id: UUID; public var timetableID: UUID?; public var entry: TimetableEntry; public var createdAt: Date }
public struct MaterialLinkSnapshot: Hashable, Sendable { public var id: UUID; public var lessonKeyText: String; public var fileIdentity: String?; public var createdAt: Date }
public struct PenNoteSnapshot: Hashable, Sendable { public var id: UUID; public var linkID: UUID?; public var page: Int; public var createdAt: Date; public var modifiedAt: Date }
public struct LessonInfoSnapshot: Hashable, Sendable { public var id: UUID; public var lessonKeyText: String; public var createdAt: Date; public var fieldModifiedAt: [LessonInfoField: Date] }
public struct ScheduleChangeSnapshot: Hashable, Sendable { public var id: UUID; public var change: ScheduleChange; public var createdAt: Date }
public struct NonTeachingPeriodSnapshot: Hashable, Sendable { public var id: UUID; public var period: NonTeachingPeriod; public var createdAt: Date }

public struct SyncSnapshot: Sendable {
    public var timetables: [TimetableSnapshot] = []
    public var entries: [TimetableEntrySnapshot] = []
    public var links: [MaterialLinkSnapshot] = []
    public var penNotes: [PenNoteSnapshot] = []
    public var lessonInfos: [LessonInfoSnapshot] = []
    public var scheduleChanges: [ScheduleChangeSnapshot] = []
    public var nonTeachingPeriods: [NonTeachingPeriodSnapshot] = []
    public init(…)   // alle Parameter mit Vorgabe []
}

/// Was nach dem Abgleich zu tun ist. Reihenfolge beim Anwenden: siehe Task 7.
public struct MergePlan: Equatable, Sendable {
    public var deletions: Set<UUID> = []
    public var entryTimetableChanges: [UUID: UUID] = [:]        // Eintrag → behaltener Stundenplan
    public var penNoteLinkChanges: [UUID: UUID] = [:]           // Stiftnotiz → behaltene Zuordnung
    public var penNoteDrawingSources: [UUID: UUID] = [:]        // behaltene Stiftnotiz ← Zeichnung dieser Notiz übernehmen
    public var lessonInfoFieldSources: [UUID: [LessonInfoField: UUID]] = [:]   // behaltener Datensatz ← je Feld Quelle
    public var isEmpty: Bool { get }
}

public enum SyncMerger {
    public static func plan(for snapshot: SyncSnapshot) -> MergePlan
}
```

Regeln (Architecture Doc, Nebenläufigkeit): je fachlichem Schlüssel bleibt der **älteste** Datensatz (`createdAt`, bei Gleichstand die kleinere `id.uuidString`). Inhalt mit „zuletzt gilt“ (Stiftnotiz, Stundenangaben je Feld) kommt vom jüngsten `modifiedAt` der Gruppe – die Hülle bleibt die älteste.

| Daten | fachlicher Schlüssel | Besonderheit |
|---|---|---|
| Stundenplan | nur aktive; alle aktiven bilden eine Gruppe | Einträge aufgegebener Stundenpläne → `entryTimetableChanges` |
| Stundenplan-Eintrag | (wirksame `timetableID`, `entry`) | wirksam = nach `entryTimetableChanges` |
| Zuordnung | (`lessonKeyText`, `fileIdentity`) | `fileIdentity == nil` (Verweis noch nicht abgeglichen) → nie zusammenführen |
| Stiftnotiz | (wirksame `linkID`, `page`) | Notizen aufgegebener Zuordnungen → `penNoteLinkChanges`; Zeichnung vom jüngsten `modifiedAt` |
| Stundenangaben | `lessonKeyText` | je Feld die Quelle mit jüngstem `fieldModifiedAt[field]` (fehlend = `.distantPast`) |
| Abweichung | `change` (inkl. `Origin` – Hand und Quelle werden nie zusammengeführt) | |
| unterrichtsfreier Zeitraum | `period` | |
| Tafelseite | – | wird nicht zusammengeführt; gleiche Positionen löst die Sortierung nach `createdAt` |

Gemeinsamer Helfer (die Signatur legt die Gleichstandsregel nicht fest, deshalb ausgeschrieben):

```swift
/// Liefert je aufgegebenem Datensatz den behaltenen (ältester; bei gleicher Zeit kleinere UUID-Zeichenkette).
static func survivors<Item, Key: Hashable>(_ items: [Item], key: (Item) -> Key?, id: (Item) -> UUID,
                                          createdAt: (Item) -> Date) -> [UUID: UUID] {
    var result: [UUID: UUID] = [:]
    let keyed = items.compactMap { item in key(item).map { ($0, item) } }
    for (_, group) in Dictionary(grouping: keyed, by: { $0.0 }) where group.count > 1 {
        let sorted = group.map(\.1).sorted { (createdAt($0), id($0).uuidString) < (createdAt($1), id($1).uuidString) }
        for dropped in sorted.dropFirst() { result[id(dropped)] = id(sorted[0]) }
    }
    return result
}
```

Eine Stiftnotiz, die selbst aufgegeben wird, steht nur in `deletions`, nicht zusätzlich in `penNoteLinkChanges`; eine Quelle, die der behaltene Datensatz selbst ist, wird nicht eingetragen.

- [ ] **Step 1: Failing Tests schreiben** (feste Zeiten `t1 = Date(timeIntervalSince1970: 1_000)`, `t2 = 2_000`, `t3 = 3_000`; feste UUIDs `id(1)` … `id(9)`)

```swift
@Test("Nebenläufigkeit: doppelte Datei in derselben Stunde → ältere bleibt, Stiftnotizen wandern")
func mergesDuplicateLinksAndMovesPenNotes() {
    // link1 (t1) und link2 (t2): gleiche lessonKeyText, gleiche fileIdentity; note5 an link2, Seite 2
    let plan = SyncMerger.plan(for: snapshot)
    #expect(plan.deletions == [id(2)])
    #expect(plan.penNoteLinkChanges == [id(5): id(1)])
}

@Test("Nebenläufigkeit: beide Zuordnungen haben Seite 1 – älteste Notiz bleibt, jüngste Zeichnung gilt")
func mergesPenNotesOnSamePageKeepingLatestDrawing() {
    // note4 an link1 Seite 1 (createdAt t1, modifiedAt t1); note5 an link2 Seite 1 (createdAt t2, modifiedAt t3)
    #expect(plan.deletions == [id(2), id(5)])
    #expect(plan.penNoteLinkChanges.isEmpty)
    #expect(plan.penNoteDrawingSources == [id(4): id(5)])
}

@Test("Verschiedene Dateien in derselben Stunde bleiben beide")
func keepsDifferentFilesInSameLesson()                     // plan.isEmpty

@Test("Zuordnung ohne abgeglichenen Verweis wird nie zusammengeführt")
func ignoresLinksWithoutFileIdentity()                     // zwei Zuordnungen, fileIdentity nil → plan.isEmpty

@Test("Doppelte Stundenangaben: ältester Datensatz, je Feld der jüngste Stand")
func mergesLessonInfosPerField() {
    // info1 (createdAt t1, topic t1, toPrepare t3), info2 (createdAt t2, topic t2, homework t2)
    #expect(plan.deletions == [id(2)])
    #expect(plan.lessonInfoFieldSources == [id(1): [.topic: id(2), .homework: id(2)]])
}

@Test("Doppelter Ausfall derselben Stunde wird eins; Hand und Quelle bleiben getrennt")
func mergesScheduleChangesByValueIncludingOrigin() {
    // c1 .cancellation(k, .manual) t1, c2 dieselbe t2, c3 .cancellation(k, .source) t3
    #expect(plan.deletions == [id(2)])
}

@Test("Doppelte Vertretungsstunde wird eins")
func mergesDuplicateSubstituteLessons()                    // Mi 18.11. 4. Stunde 6c Mathe zweimal → eine Löschung

@Test("Doppelter unterrichtsfreier Zeitraum wird eins")
func mergesDuplicateNonTeachingPeriods()                   // 02.11.–06.11. „Herbstferien“ zweimal

@Test("Review Focus 1: zwei aktive Stundenpläne – ältester bleibt, Einträge wandern, Dubletten verschwinden")
func mergesDuplicateActiveTimetables() {
    // tt1 aktiv t1 mit e3 (Di 2. Stunde 8b Englisch); tt2 aktiv t2 mit e4 (gleicher Eintrag) und e5 (Do 3. Stunde 8b Englisch)
    #expect(plan.deletions == [id(2), id(4)])
    #expect(plan.entryTimetableChanges == [id(5): id(1)])
}

@Test("Inaktive Stundenpläne werden nicht angefasst")
func ignoresInactiveTimetables()                           // tt1 aktiv, tt2 inaktiv → plan.isEmpty

@Test("Gleichstand der Anlagezeit: kleinere UUID bleibt")
func breaksTiesByUUID()                                     // zwei Abweichungen mit createdAt t1 → die mit größerer UUID in deletions

@Test("Bereinigter Bestand ergibt leeren Plan")
func cleanSnapshotYieldsEmptyPlan()
```

- [ ] **Step 2: Diff durchsehen** – nur `Foundation`; `MergePlan` ist `Equatable` (Tests vergleichen ganze Mengen).
- [ ] **Step 3: Implementieren** – `plan(for:)` in der Reihenfolge der Tabelle (Stundenplan vor Eintrag, Zuordnung vor Stiftnotiz).
- [ ] **Step 4: Diff durchsehen.**
- [ ] **Step 5: Commit** – `git commit -m "core: add pure merge planning after sync"`

---

### Task 4: SwiftData-Modelle, Container und Spiegelung

Design-Takt: keiner

**Files:**
- Create: `Frontstage/Data/Records/TimetableRecord.swift`, `TimetableEntryRecord.swift`, `NonTeachingPeriodRecord.swift`, `ScheduleChangeRecord.swift`, `MaterialLinkRecord.swift`, `MaterialReferenceRecord.swift`, `PenNoteRecord.swift`, `LessonInfoRecord.swift`, `BoardPageRecord.swift`
- Create: `Frontstage/Data/ModelContainerFactory.swift`
- Modify: `project.yml` (beide App-Ziele)
- Test: `FrontstageTests/Data/RecordSchemaTests.swift`, `FrontstageTests/Data/Fixtures.swift`

**Interfaces:**
- Produces (jede Klasse `@Model final class`, jede Eigenschaft wie angegeben mit Vorgabe; dazu immer `var recordID: UUID = UUID()`, `var createdAt: Date = Date.now`; ein `init` mit den fachlichen Feldern):

| Klasse | Eigenschaften |
|---|---|
| `TimetableRecord` | `name: String = ""`, `validFromText: String?`, `validToText: String?`, `sourceKind: String = "manual"`, `weekVariantCount: Int = 1`, `referenceWeekAText: String?`, `bellScheduleData: Data?` (JSON von `BellSchedule`), `isActive: Bool = false`, `@Relationship(deleteRule: .cascade, inverse: \TimetableEntryRecord.timetable) entries: [TimetableEntryRecord]? = []` |
| `TimetableEntryRecord` | `weekVariantRaw: String?`, `weekdayRaw: Int = 1`, `period: Int = 1`, `schoolClassText: String = ""`, `subjectText: String = ""`, `originRaw: String = "manual"`, `timetable: TimetableRecord?` |
| `NonTeachingPeriodRecord` | `fromText: String = ""`, `toText: String = ""`, `title: String = ""` |
| `ScheduleChangeRecord` | `kindRaw: String = "cancellation"` (`cancellation` \| `substituteLesson`), `originRaw: String = "manual"`, `dayText: String = ""`, `lessonKeyText: String?`, `period: Int?`, `schoolClassText: String?`, `subjectText: String?` |
| `MaterialLinkRecord` | `lessonKeyText: String = ""`, `dayText: String = ""`, `position: Int = 0`, `@Relationship(deleteRule: .cascade, inverse: \MaterialReferenceRecord.link) reference: MaterialReferenceRecord?`, `@Relationship(deleteRule: .cascade, inverse: \PenNoteRecord.link) penNotes: [PenNoteRecord]? = []` |
| `MaterialReferenceRecord` | `folderGrantName: String = ""`, `relativePath: String = ""`, `oneDriveItemID: String?`, `displayName: String = ""`, `fileType: String = ""`, `link: MaterialLinkRecord?` |
| `PenNoteRecord` | `modifiedAt: Date = Date.now`, `page: Int = 1`, `@Attribute(.externalStorage) drawingData: Data?`, `pageWidth: Double = 0`, `pageHeight: Double = 0`, `link: MaterialLinkRecord?` |
| `LessonInfoRecord` | `lessonKeyText: String = ""`, `topic: String?`, `toPrepare: String?`, `homework: String?`, `topicModifiedAt: Date?`, `toPrepareModifiedAt: Date?`, `homeworkModifiedAt: Date?` |
| `BoardPageRecord` | `modifiedAt: Date = Date.now`, `lessonKeyText: String = ""`, `dayText: String = ""`, `position: Int = 0`, `backgroundKind: String = "blank"` (`blank` \| `lined` \| `grid` \| `image`), `@Attribute(.externalStorage) backgroundImageData: Data?`, `@Attribute(.externalStorage) drawingData: Data?` |

Entscheidung Materialverweis: eigenes Modell gemäß Tabelle, **1:1 an der Zuordnung, mit ihr gelöscht**. „Für Klasse übernehmen“ legt einen neuen `MaterialReferenceRecord` mit denselben Werten an – das ist ein Verweis, keine Dateikopie (FR-3.4).

```swift
enum ModelContainerFactory {
    /// Alle gespiegelten Modelle. Ordnerfreigaben gehören nicht dazu (nur lokal, Teilplan 03).
    static let modelTypes: [any PersistentModel.Type]
    /// Liest den Schlüssel "FrontstageCloudKitContainer" aus der Info.plist.
    static func cloudKitContainerIdentifier(bundle: Bundle = .main) -> String?
    /// Mit Spiegelung in die private Datenbank: ModelConfiguration(schema:, cloudKitDatabase: .private(identifier)).
    static func makeCloudContainer(identifier: String) throws -> ModelContainer
    /// Für Tests und Vorschauen: isStoredInMemoryOnly: true, cloudKitDatabase: .none.
    static func makeInMemoryContainer() throws -> ModelContainer
    /// Unter Tests (Umgebungsvariable "XCTestConfigurationFilePath" gesetzt) oder ohne Container-Kennung: In-Memory.
    static func makeDefault() throws -> ModelContainer
}
```

`project.yml`, je App-Ziel (Zielnamen aus Teilplan 01):

```yaml
settings:
  base:
    CLOUDKIT_CONTAINER_ID: iCloud.com.example.frontstage   # Platzhalter; echte Kennung per CI-Secret
entitlements:
  path: Frontstage/Resources/Frontstage-<Plattform>.entitlements
  properties:
    com.apple.developer.icloud-services: [CloudKit]
    com.apple.developer.icloud-container-identifiers: [$(CLOUDKIT_CONTAINER_ID)]
    aps-environment: development                      # iPadOS-Ziel
    com.apple.developer.aps-environment: development  # macOS-Ziel (statt der Zeile darüber)
info:
  properties:
    FrontstageCloudKitContainer: $(CLOUDKIT_CONTAINER_ID)
    UIBackgroundModes: [remote-notification]          # nur iPadOS-Ziel
```

Beide Ziele nutzen **dieselbe** Container-Kennung, sonst gleichen iPad und Mac nicht miteinander ab. Hat Teilplan 01 schon `entitlements:`/`info:`-Blöcke angelegt, werden die Schlüssel dort ergänzt (Sandbox- und Datei-Schlüssel für macOS bleiben unberührt).

- [ ] **Step 1: Failing Tests schreiben**

```swift
@MainActor @Suite struct RecordSchemaTests {
    @Test("Jedes Modell lässt sich mit Vorgabewerten anlegen und speichern")
    func everyRecordSavesWithDefaults() throws {
        let context = ModelContext(try ModelContainerFactory.makeInMemoryContainer())
        // je Klasse ein Objekt mit leerem/minimalem init einfügen
        try context.save()
        #expect(try context.fetchCount(FetchDescriptor<BoardPageRecord>()) == 1)
        #expect(try context.fetchCount(FetchDescriptor<PenNoteRecord>()) == 1)
    }

    @Test("Zuordnung löschen löscht Verweis und Stiftnotizen mit (Area anzeige, Stiftnotizen)")
    func deletingLinkCascadesToReferenceAndPenNotes() throws {
        // Zuordnung mit Verweis und zwei Stiftnotizen; Zuordnung löschen
        #expect(try context.fetchCount(FetchDescriptor<PenNoteRecord>()) == 0)
        #expect(try context.fetchCount(FetchDescriptor<MaterialReferenceRecord>()) == 0)
    }

    @Test("Stundenplan löschen löscht seine Einträge mit")
    func deletingTimetableCascadesToEntries() throws

    @Test("Container-Kennung kommt aus der Info.plist, fehlt sie, gilt nil")
    func containerIdentifierFromBundle()   // Bundle(for:) des Testziels hat den Schlüssel nicht → nil
}
```

`Fixtures.swift`: `func makeStore() throws -> DataStore` (In-Memory), `fixtureA`, `fixtureB` (Stundenpläne als Kern-Werte), `func reference(_ name: String) -> MaterialReference` mit `folderGrantName: "Unterricht"`, `relativePath: "Englisch/\(name)"`, `fileType: "com.adobe.pdf"`, Tage `tue17`, `wed18`, `thu19`.

- [ ] **Step 2: Diff durchsehen**
  - Suche `#Unique|\.unique` in `Frontstage/` → kein Treffer (ADR-0002).
  - Jede Beziehung optional, jede `@Relationship` mit `inverse:`, Gegenseite ohne zweites `@Relationship`-Makro (nur eine Seite deklariert die Gegenrichtung).
  - Keine `enum`-Attribute, keine nicht optionalen Eigenschaften ohne Vorgabe.
  - YAML: Einrückung, `$(CLOUDKIT_CONTAINER_ID)` in beiden Zielen gleich.
- [ ] **Step 3: Implementieren** gemäß Interfaces.
- [ ] **Step 4: Diff durchsehen** (wie Step 2).
- [ ] **Step 5: Commit** – `git commit -m "data: add SwiftData records with private CloudKit mirroring"`

---

### Task 5: Übersetzung Record ↔ Kern-Typen

Design-Takt: keiner

**Files:**
- Create: `Frontstage/Data/RecordConversion.swift`
- Test: `FrontstageTests/Data/RecordConversionTests.swift`

**Interfaces:**
- Consumes: Records (Task 4), Kern-Typen (Teilplan 01, Task 1, Task 3)
- Produces:

```swift
extension TimetableRecord {
    /// Fehlt die Bezugswoche, gilt der Tag von createdAt; nicht lesbares Zeitraster → leeres Zeitraster.
    func makeTimetable() -> Timetable
    func setBellSchedule(_ schedule: BellSchedule)          // JSONEncoder → bellScheduleData
    func snapshot() -> TimetableSnapshot
}
extension TimetableEntryRecord {
    func makeEntry() -> TimetableEntry?                     // nil bei ungültigem Wochentag/Wochenvariante
    func apply(_ entry: TimetableEntry, origin: Origin)
    var origin: Origin { get }                               // unbekannter Rohwert → .manual
    func snapshot() -> TimetableEntrySnapshot?
}
extension NonTeachingPeriodRecord { func makePeriod() -> NonTeachingPeriod?; func apply(_ period: NonTeachingPeriod); func snapshot() -> NonTeachingPeriodSnapshot? }
extension ScheduleChangeRecord { func makeChange() -> ScheduleChange?; func apply(_ change: ScheduleChange); func snapshot() -> ScheduleChangeSnapshot? }
extension MaterialReferenceRecord { func makeReference() -> MaterialReference; func apply(_ reference: MaterialReference) }
extension MaterialLinkRecord { var lessonKey: LessonKey? { get }; func setLessonKey(_ key: LessonKey); func snapshot() -> MaterialLinkSnapshot }
extension PenNoteRecord { func snapshot() -> PenNoteSnapshot }
extension LessonInfoRecord {
    func makeInfo() -> LessonInfo
    /// Übernimmt nur geänderte Felder und setzt deren *ModifiedAt auf `now`.
    func apply(_ info: LessonInfo, now: Date)
    func snapshot() -> LessonInfoSnapshot
}
```

`setLessonKey` setzt `lessonKeyText = key.storageText` **und** `dayText = key.date.storageText` (Abfrage je Tag ohne das Format von `LessonKey.storageText` zu kennen). Klasse wird als `schoolClass.normalized`, Fach als `subject.display` gespeichert und über `SchoolClass(_:)`/`Subject(_:)` zurückgelesen.

- [ ] **Step 1: Failing Tests schreiben**

```swift
@Test("Stundenplan hin und zurück, mit A/B-Wochen und Zeitraster")
func timetableRoundTrip() {
    // weekVariantCount 2, referenceWeekA 16.11.2026, Zeitraster 2. Stunde 8:35–9:20, Eintrag (.a, .tuesday, 2, "8b", "Englisch")
    let back = record.makeTimetable()
    #expect(back.weekVariantCount == 2)
    #expect(back.referenceWeekA == CalendarDay(year: 2026, month: 11, day: 16))
    #expect(back.bellSchedule.periods[2] == TimeOfDay(hour: 8, minute: 35)...TimeOfDay(hour: 9, minute: 20))
    #expect(back.entries == [entry])
}

@Test("Klasse wird normalisiert gespeichert, Fach mit Anzeigename")
func entryStoresNormalizedClassAndSubjectDisplay()   // "08B" → schoolClassText "8b"; subjectText "Englisch"

@Test("Ausfall und Vertretungsstunde hin und zurück, mit Herkunft")
func scheduleChangeRoundTrip()                        // .cancellation(key, .source) und .substituteLesson(date: wed18, period: 4, "6c", "Mathe", .manual)

@Test("Zuordnung trägt Schlüssel und Tag als Text")
func linkStoresLessonKeyAndDayText()                  // dayText == "2026-11-17"; lessonKey == key

@Test("Stundenangaben: nur geänderte Felder bekommen einen neuen Zeitstempel")
func lessonInfoApplyStampsOnlyChangedFields() {
    record.apply(LessonInfo(topic: "Unit 4 – Wortschatz", toPrepare: "Buch, Heft"), now: t1)
    record.apply(LessonInfo(topic: "Unit 4 – Wortschatz", toPrepare: nil), now: t2)
    #expect(record.topicModifiedAt == t1)
    #expect(record.toPrepareModifiedAt == t2)
    #expect(record.toPrepare == nil)
}

@Test("Ungültige Rohwerte ergeben nil statt Absturz")
func invalidRawValuesYieldNil()                        // weekdayRaw 9, kindRaw "x", dayText ""
```

- [ ] **Step 2: Diff durchsehen** – öffentliche Initialisierer der Kern-Typen werden benutzt (siehe Abstimmungsbedarf A1); `JSONEncoder`/`JSONDecoder` für `BellSchedule`.
- [ ] **Step 3: Implementieren.**
- [ ] **Step 4: Diff durchsehen.**
- [ ] **Step 5: Commit** – `git commit -m "data: translate records to core values and snapshots"`

---

### Task 6: `DataStore` – Stundenplan, unterrichtsfreie Zeiträume, Abweichungen, Unterrichtsstunden

Design-Takt: keiner

**Files:**
- Create: `Frontstage/Data/DataStore.swift`
- Test: `FrontstageTests/Data/DataStoreTimetableTests.swift`

**Interfaces:**
- Consumes: Records, Übersetzung (Task 4, 5), `TimetableCalculator` (Teilplan 01)
- Produces:

```swift
/// Einziger Schreibzugang zu den App-Daten. Lesen für Listen darf die Oberfläche auch per @Query.
@MainActor @Observable final class DataStore {
    let modelContext: ModelContext
    init(modelContext: ModelContext)

    // Stundenplan (FR-1, FR-1.1, FR-1.2)
    func activeTimetableRecord() throws -> TimetableRecord?        // ältester aktiver
    func timetable() throws -> Timetable?
    func addEntry(_ entry: TimetableEntry, origin: Origin = .manual) throws   // legt bei Bedarf den aktiven Stundenplan an
    func replaceEntry(_ old: TimetableEntry, with new: TimetableEntry) throws // Herkunft wird .manual
    func removeEntry(_ entry: TimetableEntry) throws
    func setWeekVariants(count: Int, referenceWeekA: CalendarDay) throws      // count nur 1 oder 2
    func setBellSchedule(_ schedule: BellSchedule) throws
    func setTimetableSource(_ sourceKind: String) throws
    func manuallyEditedEntries() throws -> Set<TimetableEntry>                // Herkunft .manual (für ImportDiffer, AK-3)
    func applyImport(adding: [TimetableEntry], changing: [(old: TimetableEntry, new: TimetableEntry)], removing: [TimetableEntry]) throws  // Herkunft .source

    // unterrichtsfreie Zeiträume (FR-7)
    func nonTeachingPeriods() throws -> [NonTeachingPeriod]
    func addNonTeachingPeriod(_ period: NonTeachingPeriod) throws
    func removeNonTeachingPeriod(_ period: NonTeachingPeriod) throws

    // Abweichungen (FR-8, FR-9, FR-2.2)
    func scheduleChanges() throws -> [ScheduleChange]
    func markCancelled(_ key: LessonKey) throws                    // idempotent
    func removeCancellation(_ key: LessonKey) throws               // nur Herkunft .manual
    @discardableResult
    func addSubstituteLesson(date: CalendarDay, period: Int, schoolClass: SchoolClass, subject: Subject) throws -> LessonKey?
    func removeSubstituteLesson(date: CalendarDay, period: Int, schoolClass: SchoolClass, subject: Subject) throws
    /// Ersetzt alle Abweichungen mit Herkunft .source im Zeitraum; von Hand angelegte bleiben (Area stundenplan-quellen).
    func replaceSourceScheduleChanges(_ changes: [ScheduleChange], from: CalendarDay, to: CalendarDay) throws

    // Unterrichtsstunden (berechnet, nie gespeichert)
    func lessons(on day: CalendarDay) throws -> [Lesson]           // leer ohne Stundenplan
    func nextLesson(after key: LessonKey) throws -> LessonKey?
}
```

Der aktive Stundenplan wird erst beim ersten Schreiben angelegt (nicht beim App-Start) – das verringert doppelte Stundenpläne bei zwei Geräten (Review Focus 1). Neuer Stundenplan: `isActive = true`, `referenceWeekAText` = Montag der laufenden Woche.

- [ ] **Step 1: Failing Tests schreiben**

```swift
@MainActor @Suite struct DataStoreTimetableTests {
    @Test("AK-1 (Daten): Eintrag Di 2. Stunde 8b Englisch erscheint an jedem Dienstag")
    func addedEntryAppearsEveryTuesday() throws {
        try store.addEntry(TimetableEntry(weekVariant: nil, weekday: .tuesday, period: 2, schoolClass: SchoolClass("8b"), subject: Subject("Englisch")))
        #expect(try store.lessons(on: tue17).map(\.key.schoolClass) == [SchoolClass("8b")])
        #expect(try store.lessons(on: CalendarDay(year: 2026, month: 11, day: 24)).count == 1)
    }

    @Test("AK-15 (Daten): Di 8b als Ausfall markiert, Stundenplan-Eintrag bleibt")
    func markCancelledFlagsLessonAndKeepsEntry() throws {
        // fixtureB: Di 2. Stunde 8b Englisch, Do 3. Stunde 8b Englisch
        try store.markCancelled(di8b)
        try store.markCancelled(di8b)                                   // idempotent
        let tue = try store.lessons(on: tue17)
        #expect(tue.first?.isCancelled == true)
        #expect(tue.first?.cancellationOrigin == .manual)
        #expect(try store.scheduleChanges() == [.cancellation(di8b, .manual)])
        #expect(try store.timetable()?.entries.count == 2)
    }

    @Test("AK-16 (Daten): Vertretungsstunde Mi 4. Stunde 6c Mathe nur an diesem Datum")
    func substituteLessonOnlyOnItsDate() throws {
        let key = try store.addSubstituteLesson(date: wed18, period: 4, schoolClass: SchoolClass("6c"), subject: Subject("Mathe"))
        #expect(key?.date == wed18)
        #expect(try store.lessons(on: wed18).contains { $0.isSubstituteLesson && $0.period == 4 })
        #expect(try store.lessons(on: CalendarDay(year: 2026, month: 11, day: 25)).contains { $0.isSubstituteLesson } == false)
    }

    @Test("Quelle ersetzt nur eigene Abweichungen im Zeitraum")
    func replaceSourceChangesKeepsManualOnes()      // manueller Ausfall Di bleibt, alter Quell-Ausfall Do weg, neuer Quell-Ausfall Mi da

    @Test("Von Hand geänderter Eintrag gilt als manuell (AK-3-Vorarbeit)")
    func replacedImportedEntryBecomesManual()       // applyImport(adding: [e]) → manuallyEditedEntries() == []; replaceEntry(e, with: e2) → == [e2]

    @Test("Unterrichtsfreier Zeitraum: keine Unterrichtsstunden")
    func nonTeachingPeriodHasNoLessons()            // 02.11.–06.11.2026 „Herbstferien“ → lessons(on: 03.11.) == []
}
```

- [ ] **Step 2: Diff durchsehen** – jede Schreiboperation endet mit `try modelContext.save()`; keine Datei-API im Diff; `Origin`-Rohwerte `"manual"`/`"source"`.
- [ ] **Step 3: Implementieren.**
- [ ] **Step 4: Diff durchsehen.**
- [ ] **Step 5: Commit** – `git commit -m "data: add DataStore for timetable, non-teaching periods and schedule changes"`

---

### Task 7: Zusammenführen nach dem Abgleich anwenden

Design-Takt: keiner

**Files:**
- Create: `Frontstage/Data/DataStore+Merge.swift`
- Test: `FrontstageTests/Data/DataStoreMergeTests.swift`

**Interfaces:**
- Consumes: `SyncMerger.plan(for:)`, `SyncSnapshot`, `MergePlan` (Task 3), `snapshot()` (Task 5)
- Produces:

```swift
extension DataStore {
    func makeSyncSnapshot() throws -> SyncSnapshot     // alle Records (Mengen im Hunderterbereich)
    /// Schnappschuss → Plan → anwenden → speichern. Idempotent; leerer Plan speichert nichts.
    @discardableResult func mergeDuplicates() throws -> MergePlan
}
```

**Reihenfolge beim Anwenden (verbindlich, sonst greifen Löschregeln zu früh):**
1. `entryTimetableChanges` – Einträge an den behaltenen Stundenplan hängen,
2. `penNoteLinkChanges` – Stiftnotizen an die behaltene Zuordnung hängen,
3. `penNoteDrawingSources` – `drawingData`, `pageWidth`, `pageHeight`, `modifiedAt` übernehmen,
4. `lessonInfoFieldSources` – Feldwert und Feld-Zeitstempel übernehmen,
5. `deletions` – Records löschen (Kaskaden treffen jetzt nur noch Aufgegebenes),
6. `save()`.

Die Records werden über `recordID` gefunden (ein Wörterbuch je Modell aus dem Schnappschuss-Lauf).

- [ ] **Step 1: Failing Tests schreiben**

```swift
@Test("Review Focus 2: Stiftnotizen der aufgegebenen Zuordnung überleben das Löschen")
func mergeKeepsPenNotesOfDroppedLink() throws {
    // zwei Zuordnungen Di 8a „Vokabeln.pdf“ (createdAt t1, t2); Notiz Seite 2 an der jüngeren
    try store.mergeDuplicates()
    let links = try store.links(for: di8a)                 // aus Task 8; bis dahin per FetchDescriptor
    #expect(links.count == 1)
    #expect(links[0].createdAt == t1)
    #expect(links[0].penNotes?.map(\.page) == [2])
}

@Test("Gleiche Seite: Zeichnung der zuletzt geänderten Notiz bleibt")
func mergeTakesLatestDrawingForSamePage()                   // drawingData Data([1]) (modifiedAt t1) vs Data([2]) (t3) → Data([2]), eine Notiz

@Test("Review Focus 1: Einträge wandern vor dem Löschen des Stundenplans")
func mergeMovesEntriesBeforeDeletingTimetable() throws {
    // zwei aktive Stundenpläne (t1, t2); am jüngeren Do 3. Stunde 8b Englisch
    try store.mergeDuplicates()
    #expect(try store.timetable()?.entries.contains { $0.weekday == .thursday && $0.period == 3 } == true)
    #expect(try modelContext.fetchCount(FetchDescriptor<TimetableRecord>()) == 1)
}

@Test("Doppelte Stundenangaben: je Feld der jüngste Stand")
func mergeLessonInfoFields()                                // Ergebnis: topic aus dem jüngeren, toPrepare aus dem älteren; ein Datensatz

@Test("Zweiter Lauf ändert nichts")
func mergeIsIdempotent()                                    // zweites mergeDuplicates().isEmpty == true
```

- [ ] **Step 2: Diff durchsehen** – Reihenfolge 1–6 wörtlich im Code als deutsche Kommentare; kein `save()` bei leerem Plan.
- [ ] **Step 3: Implementieren.**
- [ ] **Step 4: Diff durchsehen.**
- [ ] **Step 5: Commit** – `git commit -m "data: apply merge plan after sync"`

---

### Task 8: Zuordnungen und Stiftnotizen

Design-Takt: keiner

**Files:**
- Create: `Frontstage/Data/DataStore+MaterialLinks.swift`
- Test: `FrontstageTests/Data/DataStoreMaterialLinkTests.swift`

**Interfaces:**
- Consumes: `ParallelLessonFinder` (Task 2), `mergeDuplicates()` (Task 7), `nextLesson(after:)` (Task 6)
- Produces:

```swift
extension DataStore {
    /// Sortiert nach (position, createdAt, recordID.uuidString) – löst gleiche Positionen nach Anlagezeit auf.
    func links(for key: LessonKey) throws -> [MaterialLinkRecord]
    /// index nil → ans Ende; sonst an diese Stelle, alle Positionen der Stunde werden 0…n-1 neu vergeben.
    /// Ist dieselbe Datei (fileIdentity) schon zugeordnet, wird die vorhandene Zuordnung unverändert zurückgegeben.
    @discardableResult func assign(_ reference: MaterialReference, to key: LessonKey, at index: Int? = nil) throws -> MaterialLinkRecord
    /// Semantik wie SwiftUI `onMove`: toOffset zählt vor dem Entfernen. Danach Positionen 0…n-1.
    func moveLinks(in key: LessonKey, fromOffsets: IndexSet, toOffset: Int) throws
    func parallelClasses(for key: LessonKey) throws -> [SchoolClass]
    /// FR-3.2: neue Zuordnungen mit neuem Verweis gleicher Werte, ohne Stiftnotizen, ans Ende; Dateien, die das Ziel schon hat, werden übersprungen.
    @discardableResult func copyLinks(from key: LessonKey, toClass: SchoolClass) throws -> LessonKey?
    /// FR-3.3: ändert nur den Schlüssel; Stiftnotizen bleiben an der Zuordnung. nil → nichts geändert. Danach mergeDuplicates().
    @discardableResult func moveLinkToNextLesson(_ link: MaterialLinkRecord) throws -> LessonKey?
    /// FR-8: alle Zuordnungen der Stunde in die nächste Stunde (Ausfälle übersprungen), Reihenfolge bleibt, ans Ende.
    @discardableResult func moveAllLinksToNextLesson(from key: LessonKey) throws -> LessonKey?
    /// FR-7: Zuordnung „ohne Stunde“ an eine gewählte Unterrichtsstunde hängen.
    func moveLink(_ link: MaterialLinkRecord, to key: LessonKey) throws
    func removeLink(_ link: MaterialLinkRecord) throws                       // Stiftnotizen per Kaskade
    /// Zuordnungen mit dayText des Tages, zu deren Schlüssel keine berechnete Unterrichtsstunde passt (Area daten, „ohne Stunde“).
    func orphanedLinks(on day: CalendarDay) throws -> [MaterialLinkRecord]

    // Stiftnotizen (ADR-0006, FR-6.1) – Zeichnen und Verzögerung baut Teilplan 06
    func penNote(for link: MaterialLinkRecord, page: Int) throws -> PenNoteRecord?
    func savePenNote(for link: MaterialLinkRecord, page: Int, drawingData: Data, pageWidth: Double, pageHeight: Double) throws  // legt an oder überschreibt, setzt modifiedAt
}
```

- [ ] **Step 1: Failing Tests schreiben** (Fixture A für AK-7/AK-22, Fixture B für AK-8/AK-15)

```swift
@Test("AK-6: Lösung an Position 1 ziehen")
func moveSolutionToFirstPosition() throws {
    for name in ["Präsentation", "Arbeitsblatt", "Lösung"] { try store.assign(reference(name), to: di8b) }
    try store.moveLinks(in: di8b, fromOffsets: [2], toOffset: 0)
    #expect(try store.links(for: di8b).map { $0.reference?.displayName } == ["Lösung", "Präsentation", "Arbeitsblatt"])
    #expect(try store.links(for: di8b).map(\.position) == [0, 1, 2])
}

@Test("AK-6: Präsentation ans Ende ziehen (toOffset zählt vor dem Entfernen)")
func moveFirstToEnd() throws {
    try store.moveLinks(in: di8b, fromOffsets: [0], toOffset: 3)
    #expect(names == ["Arbeitsblatt", "Lösung", "Präsentation"])
}

@Test("Gleiche Positionen nach dem Abgleich: Anlagezeit entscheidet, Verschieben nummeriert neu")
func equalPositionsSortByCreationAndRenumber()      // zwei Records position 0 (t1, t2) → Reihenfolge t1, t2; nach moveLinks Positionen [0, 1]

@Test("Zuordnen an Position einfügen")
func assignAtIndexInsertsAndRenumbers()            // „Lösung“ at: 0 vor zwei vorhandenen → ["Lösung", "Präsentation", "Arbeitsblatt"]

@Test("Dieselbe Datei zweimal zuordnen ergibt eine Zuordnung")
func assignSameFileTwiceKeepsOne()

@Test("AK-7: Für 8b übernehmen – Mi 3. Stunde 8b hat dieselben 2 Materialien")
func copyLinksToParallelClass() throws {
    try store.assign(reference("Präsentation"), to: di8a); try store.assign(reference("Arbeitsblatt"), to: di8a)
    let target = try store.copyLinks(from: di8a, toClass: SchoolClass("8b"))
    #expect(target == mi8b)
    #expect(try store.links(for: mi8b).map { $0.reference?.makeReference() } == [reference("Präsentation"), reference("Arbeitsblatt")])
    #expect(try store.links(for: di8a).count == 2)
}

@Test("Review Focus 5: Datei, die das Ziel schon hat, wird nicht doppelt übernommen")
func copyLinksSkipsFilesAlreadyInTarget()           // Mi 8b hat „Präsentation“ → nach copyLinks 2 Zuordnungen, nicht 3

@Test("AK-8: X in die nächste Stunde – steht am Do, nicht mehr am Di")
func moveLinkToNextLessonMovesToThursday() throws {
    let x = try store.assign(reference("Vokabeln.pdf"), to: di8b)
    let target = try store.moveLinkToNextLesson(x)
    #expect(target?.date == thu19)
    #expect(try store.links(for: di8b).isEmpty)
    #expect(try store.links(for: target!).map(\.recordID) == [x.recordID])
}

@Test("Review Focus 4: ohne nächste Stunde bleibt die Zuordnung, wo sie ist")
func moveToNextLessonWithoutNextLessonKeepsLink()   // Stundenplan nur Di 8b, alle Di vom 18.11. bis 15.12. unterrichtsfrei → nil; links(for: di8b).count == 1

@Test("AK-15: Ausfall markieren, Material weiterreichen – Material am Do")
func cancelAndPassOnMovesAllLinks() throws {
    try store.assign(reference("Präsentation"), to: di8b); try store.assign(reference("Arbeitsblatt"), to: di8b)
    try store.markCancelled(di8b)
    let target = try store.moveAllLinksToNextLesson(from: di8b)
    #expect(target?.date == thu19)
    #expect(try store.links(for: target!).map { $0.reference?.displayName } == ["Präsentation", "Arbeitsblatt"])
    #expect(try store.lessons(on: tue17).first?.isCancelled == true)
}

@Test("AK-22 (Daten): Übernehmen ohne Notiz, Schieben mit Notiz")
func penNotesFollowMoveButNotCopy() throws {
    let pdf = try store.assign(reference("Vokabeln.pdf"), to: di8a)
    try store.savePenNote(for: pdf, page: 1, drawingData: Data([0x01, 0x02]), pageWidth: 595, pageHeight: 842)
    try store.copyLinks(from: di8a, toClass: SchoolClass("8b"))
    #expect(try store.links(for: mi8b).first?.penNotes?.isEmpty == true)
    let thursday = try store.moveLinkToNextLesson(pdf)
    #expect(thursday?.date == thu19)
    let moved = try store.links(for: thursday!).first!
    #expect(try store.penNote(for: moved, page: 1)?.drawingData == Data([0x01, 0x02]))
    #expect(moved.reference?.makeReference() == reference("Vokabeln.pdf"))
}

@Test("AK-14 (Daten): Material am Ferientag bleibt als „ohne Stunde“ erhalten")
func linkOnNonTeachingDayIsOrphaned()                // Zuordnung Di 17.11., danach 16.11.–20.11. unterrichtsfrei → orphanedLinks(on: tue17).count == 1; moveLink(_:to: do-Stunde 26.11.) → orphanedLinks leer

@Test("Zuordnung löschen löscht ihre Stiftnotizen")
func removeLinkDeletesPenNotes()

@Test("Stiftnotiz überschreiben setzt modifiedAt neu und legt keine zweite an")
func savePenNoteOverwritesSamePage()
```

`di8a`, `mi8b`, `di8b` holt der Test über `store.lessons(on:)`.

- [ ] **Step 2: Diff durchsehen** – keine `FileManager`-/`URL`-Schreibzugriffe (FR-3.4); `moveLinkToNextLesson` ändert nur `lessonKeyText`/`dayText`/`position`; Verschieben ohne Ziel speichert nicht.
- [ ] **Step 3: Implementieren.**
- [ ] **Step 4: Diff durchsehen.**
- [ ] **Step 5: Commit** – `git commit -m "data: add material link operations and pen note storage"`

---

### Task 9: Stundenangaben und Tafelseiten

Design-Takt: keiner

**Files:**
- Create: `Frontstage/Data/DataStore+LessonData.swift`
- Test: `FrontstageTests/Data/DataStoreLessonDataTests.swift`

**Interfaces:**
- Produces:

```swift
extension DataStore {
    // Stundenangaben (FR-11.1) – höchstens ein Datensatz je Unterrichtsstunde
    func lessonInfo(for key: LessonKey) throws -> LessonInfo          // ohne Datensatz: LessonInfo()
    func setLessonInfo(_ info: LessonInfo, for key: LessonKey) throws // normalisiert; ältester Datensatz wird beschrieben, sonst neu angelegt

    // Tafelseiten (FR-12.1, FR-12.2) – Zeichnen, Kamera und Vorlage baut Teilplan 07
    func boardPages(for key: LessonKey) throws -> [BoardPageRecord]   // sortiert (position, createdAt, recordID)
    @discardableResult func addBoardPage(for key: LessonKey, backgroundKind: String, backgroundImageData: Data? = nil) throws -> BoardPageRecord   // ans Ende
    func saveBoardPageDrawing(_ page: BoardPageRecord, drawingData: Data) throws   // setzt modifiedAt
    func deleteBoardDrawing(for key: LessonKey) throws                // alle Tafelseiten der Stunde
    func lessonKeysWithBoardPages() throws -> Set<LessonKey>          // für „letztes Tafelbild“ (FR-12.3)
}
```

- [ ] **Step 1: Failing Tests schreiben**

```swift
@Test("AK-25 (Daten): Thema und Bereitlegen eintragen, dann Bereitlegen leeren")
func lessonInfoClearPrepareKeepsTopic() throws {
    try store.setLessonInfo(LessonInfo(topic: "Unit 4 – Wortschatz", toPrepare: "Buch, Heft"), for: di8b)
    #expect(try store.lessonInfo(for: di8b) == LessonInfo(topic: "Unit 4 – Wortschatz", toPrepare: "Buch, Heft"))
    try store.setLessonInfo(LessonInfo(topic: "Unit 4 – Wortschatz", toPrepare: ""), for: di8b)
    let info = try store.lessonInfo(for: di8b)
    #expect(info.topic == "Unit 4 – Wortschatz")
    #expect(info.toPrepare == nil)
    #expect(try modelContext.fetchCount(FetchDescriptor<LessonInfoRecord>()) == 1)
}

@Test("Stundenangaben gelten nur für ihre Unterrichtsstunde")
func lessonInfoIsPerLesson()                         // Di 8b gesetzt → lessonInfo(for: do8b).isEmpty

@Test("AK-31/AK-32 (Daten): zwei Seiten bleiben, Löschen leert das Tafelbild")
func boardPagesPersistAndDelete() throws {
    let p1 = try store.addBoardPage(for: di8b, backgroundKind: "blank")
    try store.saveBoardPageDrawing(p1, drawingData: Data([0x0A]))
    try store.addBoardPage(for: di8b, backgroundKind: "grid")
    #expect(try store.boardPages(for: di8b).map(\.backgroundKind) == ["blank", "grid"])
    #expect(try store.boardPages(for: di8b).first?.drawingData == Data([0x0A]))
    #expect(try store.lessonKeysWithBoardPages() == [di8b])
    try store.deleteBoardDrawing(for: di8b)
    #expect(try store.boardPages(for: di8b).isEmpty)
}
```

- [ ] **Step 2: Diff durchsehen** – `setLessonInfo` nutzt `LessonInfoRecord.apply(_:now:)` (Task 5), damit Feld-Zeitstempel fürs Zusammenführen stimmen.
- [ ] **Step 3: Implementieren.**
- [ ] **Step 4: Diff durchsehen.**
- [ ] **Step 5: Commit** – `git commit -m "data: add lesson info and board page storage"`

---

### Task 10: Auslöser für das Zusammenführen und Einbindung in die App

Design-Takt: keiner

**Files:**
- Create: `Frontstage/Data/SyncMergeTrigger.swift`
- Modify: `Frontstage/App/FrontstageApp.swift` (Teilplan 01)
- Test: `FrontstageTests/Data/SyncMergeTriggerTests.swift`

**Interfaces:**
- Consumes: `ModelContainerFactory.makeDefault()` (Task 4), `DataStore.mergeDuplicates()` (Task 7)
- Produces:

```swift
/// Stößt das Zusammenführen an: beim Start, beim Wechsel in den Vordergrund und nach Fernänderungen (entprellt).
@MainActor final class SyncMergeTrigger {
    init(store: DataStore, debounce: Duration = .seconds(2))
    func start()                 // einmal mergeDuplicates(); Beobachter für .NSPersistentStoreRemoteChange anmelden
    func sceneDidBecomeActive()  // mergeDuplicates()
    func remoteChangeReceived()  // laufende Wartezeit abbrechen, nach `debounce` mergeDuplicates()
}
```

Beobachtung über `NotificationCenter.default.addObserver(forName: .NSPersistentStoreRemoteChange, object: nil, queue: .main)` mit `MainActor.assumeIsolated { remoteChangeReceived() }` (Swift 6: der Block ist nicht als Main-Actor markiert, läuft aber auf der Hauptwarteschlange). `import CoreData` nur für den Namen der Mitteilung. Jeder Lauf nach einer Fernänderung protokolliert „Zusammenführen nach Fernänderung“ (`Logger`, Subsystem = Bundle-ID, Stufe `.info`) – das prüft die Geräte-Checkliste. Fehler von `mergeDuplicates()` werden ebenso protokolliert, nie angezeigt.

`FrontstageApp`: `let container = try ModelContainerFactory.makeDefault()`, `DataStore(modelContext: container.mainContext)`, `.modelContainer(container)`, `.environment(store)`, `trigger.start()` beim Start, `.onChange(of: scenePhase) { if $1 == .active { trigger.sceneDidBecomeActive() } }`. Schlägt der Container fehl, `fatalError` mit deutscher Meldung (ohne Daten kein sinnvoller Betrieb).

- [ ] **Step 1: Failing Tests schreiben**

```swift
@Test("Fernänderung führt nach der Entprellzeit zusammen")
func remoteChangeMergesAfterDebounce() async throws {
    // In-Memory-Store mit zwei doppelten Ausfällen; trigger = SyncMergeTrigger(store:, debounce: .milliseconds(50))
    trigger.remoteChangeReceived(); trigger.remoteChangeReceived()
    try await Task.sleep(for: .milliseconds(200))
    #expect(try store.scheduleChanges().count == 1)
}

@Test("Vordergrund führt sofort zusammen")
func becomingActiveMergesImmediately()
```

- [ ] **Step 2: Diff durchsehen** – kein `Task.detached`; Beobachter-Token gehalten; `.NSPersistentStoreRemoteChange` ist **nicht** der einzige Auslöser.
- [ ] **Step 3: Implementieren.**
- [ ] **Step 4: Diff durchsehen.**
- [ ] **Step 5: Commit** – `git commit -m "data: trigger merge on launch, activation and remote change"`

---

### Task 11: CI-Lauf (workflow_dispatch) und Ergebnis prüfen

Design-Takt: keiner

- [ ] **Step 1: Gesamten Diff des Teilplans durchsehen** – `#Unique|\.unique` kein Treffer; jedes `@Model` ohne nicht optionale Beziehung; `FrontstageCore` importiert nur `Foundation`; alle Test-Beschreibungen deutsch mit AK-Nummer, wo eines betroffen ist.
- [ ] **Step 2: Lauf starten**

```bash
git push -u origin "$(git branch --show-current)"
gh workflow run ci.yml --ref "$(git branch --show-current)"
gh run list --workflow ci.yml --limit 1
gh run watch <run-id> --exit-status
```

Erwartet: Job Kern-Tests (`swift test --package-path Packages/FrontstageCore`) grün mit `DataValuesTests`, `ParallelLessonFinderTests`, `SyncMergerTests`; Job App-Tests (`xcodebuild test`, iPad-Simulator) grün mit `RecordSchemaTests`, `RecordConversionTests`, `DataStoreTimetableTests`, `DataStoreMergeTests`, `DataStoreMaterialLinkTests`, `DataStoreLessonDataTests`, `SyncMergeTriggerTests`; macOS-Ziel baut.

- [ ] **Step 3: Bei Rot** – `gh run view <run-id> --log-failed`, Ursache mit superpowers:systematic-debugging klären, alle Korrekturen sammeln, dann **ein** neuer Lauf.

---

## Geräte-Checkliste (Mensch mit iPad und Mac, nach Task 11)

Die Datenteile von AK-4/AK-5 und der Wiederherstellungsweg lassen sich nur mit echtem iCloud-Konto belegen. Der Logeintrag in Punkt 5 lautet „Zusammenführen nach Fernänderung“ (Task 10).

| # | Schritte | Erwartet | Ergebnis / Datum |
|---|---|---|---|
| 1 | Entwicklungsbau starten, eine Zuordnung anlegen; CloudKit Console (Entwicklung) öffnen | Record-Typen `CD_TimetableRecord` … `CD_BoardPageRecord` (9) vorhanden. Vor dem ersten TestFlight-Bau „Deploy Schema Changes“ in die Produktion | ☐ |
| 2 | AK-4/AK-5 (Daten): am Mac Material Di 8b zuordnen; danach am iPad eines zuordnen | jeweils binnen einer Minute auf dem anderen Gerät sichtbar | ☐ |
| 3 | Beide Geräte offline; dieselbe Datei derselben Stunde zuordnen; am iPad Stiftnotiz Seite 1; beide online | eine Zuordnung, die Notiz ist da | ☐ |
| 4 | Beide Geräte offline Di 8b als Ausfall markieren; online | ein Ausfall | ☐ |
| 5 | Konsole (Subsystem Bundle-ID) beobachten, am anderen Gerät etwas ändern | Logeintrag erscheint; wenn nie: vermerken (dann greifen nur Start und Vordergrund) | ☐ |
| 6 | Wiederherstellungsweg (Area daten, Betrieb): App auf zweitem Gerät mit derselben Apple-ID installieren | Stundenplan, Zuordnungen, Stiftnotizen, Stundenangaben, Tafelseiten erscheinen ohne Zutun | ☐ |
| 7 | TestFlight-Bau: `codesign -d --entitlements - <App>` | `aps-environment` = `production` | ☐ |

---

## Abdeckung

| Anforderung / AK | Task |
|---|---|
| ADR-0002 (SwiftData, Spiegelung, Modellregeln) | 4, 10, 11 |
| Area daten – Datenmodell (alle 9 gespiegelten Modelle) | 4, 5 |
| Area daten – Nebenläufigkeit, Zusammenführen | 3, 7, 10 |
| FR-3, FR-3.1 (Daten) – AK-6 | 8 |
| FR-3.2 – AK-7 | 2, 8 |
| FR-3.3 – AK-8 | 8 |
| FR-3.4 (Daten: nie kopieren) | 4, 8 |
| FR-6.1 (Daten) – AK-22 | 8 |
| FR-7 (Daten, „ohne Stunde“) – AK-14 Datenteil | 6, 8 |
| FR-8 – AK-15 | 6, 8 |
| FR-9 (Daten) – AK-16 Datenteil | 6 |
| FR-11.1 (Daten) – AK-25 | 1, 9 |
| FR-12.1, FR-12.2 (Daten) | 9 |
| FR-1.2, FR-2.2 (Speicherung) | 5, 6 |

Nicht hier: Oberfläche zu allen AK (Teilplan 04/06/07), Ordnerfreigaben (Teilplan 03, nur lokal), Zeichnen/Speicherverzögerung von Stiftnotizen (06), Kamera/Vorlage (07), Import-Logik (05).

## Abstimmungsbedarf

- **A1 (Teilplan 01):** Die Kern-Werttypen brauchen **öffentliche** Initialisierer – Swift erzeugt den memberwise-`init` nur `internal`, die App (anderes Modul) kann sonst `CalendarDay`, `TimeOfDay`, `BellSchedule`, `TimetableEntry`, `Timetable`, `NonTeachingPeriod` nicht anlegen. Ebenso `LessonKey` (mindestens über `init?(storageText:)` vorhanden).
- **A2 (Teilplan 01):** Dieser Teilplan legt in `FrontstageCore` die Ordner `Sources/FrontstageCore/Data/` und `Sources/FrontstageCore/Merge/` an und erweitert `CalendarDay` um `storageText`/`init?(storageText:)`. Falls Teilplan 01 dieselben Namen schon vergibt, gilt dessen Fassung und Task 1 entfällt dort.
- **A3 (Teilplan 01):** Namen der beiden App-Ziele in `project.yml`, ob dort schon `entitlements:`/`info:` stehen, und dass `ci.yml` App-Tests im iPad-Simulator ausführt; CI muss `CLOUDKIT_CONTAINER_ID=iCloud.<BUNDLE_ID_PREFIX>.frontstage` für Release-Bauten setzen (Secret `BUNDLE_ID_PREFIX`). `Frontstage/App/FrontstageApp.swift` muss existieren.
- **A4 (Teilplan 03):** `MaterialReference` (Task 1) ist der Wert, den der Baustein Ablage auflöst; `folderGrantName` ist der gespiegelte Name der Ordnerfreigabe. Ordnerfreigaben (`FolderGrant`) speichert Teilplan 03 **außerhalb** des gespiegelten Containers – falls per SwiftData, mit eigener `ModelConfiguration(cloudKitDatabase: .none)`; `ModelContainerFactory.modelTypes` enthält sie nicht.
- **A5 (Teilplan 05):** `DataStore.applyImport(adding:changing:removing:)`, `manuallyEditedEntries()`, `replaceSourceScheduleChanges(_:from:to:)`, `setBellSchedule(_:)`, `setTimetableSource(_:)`. `TimetableSource` steht im Glossar, der Typ ist aber nirgends festgelegt – hier vorläufig `sourceKind: String` (`"manual"`, `"schulmanager"`).
- **A6 (Teilplan 06):** `savePenNote(for:page:drawingData:pageWidth:pageHeight:)`, `penNote(for:page:)`; `PenNoteRecord.pageWidth/pageHeight` in PDF-Punkten.
- **A7 (Teilplan 07):** `LessonInfo` (Kern, Task 1) für den Klassenbildschirm; Tafelseiten-API aus Task 9. Der Hintergrund der Tafelseite hat im Glossar keinen Code-Namen – hier vorläufig `backgroundKind: String` mit `blank`, `lined`, `grid`, `image`; Teilplan 07 legt ggf. einen Kern-Typ dafür fest (Glossar-Zeile nötig?).
- **A8 (Teilplan 04):** Die Oberfläche schreibt nur über `DataStore`; Lesen per `@Query` erlaubt. `DataStore` kommt über `.environment(store)`.
- **A9 (Glossar):** Neue Code-Namen ohne Glossarzeile, die rein technisch sind und keinen Fachbegriff tragen: `DataStore`, `SyncMerger`, `MergePlan`, `SyncSnapshot`, `ParallelLessonFinder`, `ModelContainerFactory`, `SyncMergeTrigger`, `LessonInfoField`. Bitte bestätigen, dass dafür keine Glossarzeile nötig ist.

## Annahmen, die ein Mensch bestätigen sollte

1. **„Passende Unterrichtsstunde“ bei „Für <Klasse> übernehmen“** = erste nicht ausgefallene Stunde der Zielklasse im selben Fach ab demselben Tag (auch eine frühere Stunde am selben Tag). Das PRD sagt nur „passende“.
2. **Materialverweis 1:1 an der Zuordnung** (Übernehmen legt einen neuen Verweis mit gleichen Werten an). Folge: Neuverknüpfen gilt je Zuordnung, nicht für alle Stunden mit derselben Datei.
3. **Zwei aktive Stundenpläne nach dem Abgleich** werden zu einem zusammengeführt (ältester bleibt) – die Tabelle „Nebenläufigkeit“ nennt diesen Fall nicht; abgeleitet aus „ältesten behalten“ und „genau einer ist aktiv“.
4. **Doppelte Stundenplan-Einträge** im selben Stundenplan werden zusammengeführt (sonst verschieben sich die laufenden Nummern der Schlüssel, ADR-0005).
5. **Stiftnotiz und Stundenangaben beim Zusammenführen:** Hülle vom ältesten, Inhalt vom zuletzt geänderten Datensatz – Auslegung von „zuletzt abgeglichener Stand gilt“ über den Änderungszeitpunkt.
6. **Abweichungen mit Herkunft „von Hand“ und „Quelle“** für dieselbe Stunde werden nicht zusammengeführt (sonst könnte der nächste Import einen Ausfall von Hand löschen).
7. **Weiterreichen bei Ausfall nimmt Stundenangaben nicht mit** – nur Zuordnungen samt Stiftnotizen (FR-8 nennt nur „Material“).
8. **Tafelseiten werden nicht zusammengeführt**, auch nicht bei gleicher Position (beide Seiten bleiben, Reihenfolge nach Anlagezeit).
