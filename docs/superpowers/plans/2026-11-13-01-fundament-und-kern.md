# Teilplan 01 — Fundament und Kern: Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Projektgerüst (XcodeGen, zwei App-Ziele, CI) und das Swift-Paket `FrontstageCore` mit allen
verbindlichen Kern-Typen der Übersicht, testgetrieben – die Rechenbasis für alle späteren Teilpläne.

**Architecture:** `Packages/FrontstageCore` enthält reine Werttypen und zustandslose Rechner
(`TimetableCalculator`, `ClassScreenCalculator`, `ImportDiffer`), nur mit `Foundation`. Kalendertage
werden ohne Zeitzone über eine fortlaufende Tagesnummer gerechnet; `Date` wird nur an der Grenze
(App → Kern) mit einem übergebenen `Calendar` umgewandelt. Die App-Ziele enthalten in diesem Teilplan
nur einen Platzhalter-Bildschirm, damit Bau und App-Test in CI belegt sind.

**Tech Stack:** Swift 6 (Tools 6.0), Swift Testing, XcodeGen, GitHub Actions (`macos-26`).

**Spec:** `docs/superpowers/plans/2026-11-13-00-uebersicht.md` (Rahmen, verbindliche Schnittstellen),
`docs/PRD.md` (Glossar, FR-1, FR-1.1, FR-1.2, FR-3.3, FR-7, FR-8, FR-9, FR-11.7, AK-1, AK-2, AK-3, AK-8,
AK-14, AK-15, AK-16, AK-36, AK-42), `docs/adr/0005`, `0007`, `0008`, `0009`, `docs/ARCHITECTURE.md`
(Area plattform, Area daten „Schlüssel der Unterrichtsstunde“, Area stundenplan-quellen
„Import-Abgleich“, Area anzeige „Klassenbildschirm“).

**Quellen für Werkzeug-Angaben (nachgeschlagen 2026-11-13):**
- XcodeGen `project.yml`: Context7 `/yonaskolb/xcodegen` (Docs/ProjectSpec.md – `packages` mit `path`,
  `dependencies: - package:`, `scheme.testTargets`, `TEST_HOST` wird für `bundle.unit-test` mit
  App-Abhängigkeit automatisch gesetzt; `.xcstrings` landet automatisch in der Resources-Phase).
- Runner-Label `macos-26` (arm64, = `macos-latest`): github.com/actions/runner-images, README.
- `workflow_dispatch` „will only trigger a workflow run if the workflow file exists on the default
  branch“: docs.github.com, „Events that trigger workflows“ – betrifft Task 10.

## Global Constraints

Alle Zeilen aus **„Global Constraints“ der Übersicht** gelten unverändert (Version 26.0, Swift 6 strikt,
nur `project.yml`, Kern nur `Foundation`, Swift Testing, ADR-0009-Sprachregel, kein lokaler Bau,
Datenhygiene, Bundle-ID-Platzhalter, Commits). Teilplan-eigene Ergänzungen:

- Jeder öffentliche Typ im Kern bekommt ausdrücklich `public init(...)` – Swift erzeugt den
  memberwise-Initialisierer nur `internal`, Teilpläne 02–07 könnten ihn sonst nicht aufrufen.
- Keine Funktion im Kern liest die Uhr oder `TimeZone.current`. „Jetzt“ und „heute“ kommen immer als
  Parameter herein (`now: TimeOfDay`, `on day: CalendarDay`) – so bleiben Tests deterministisch.
- Rechnen mit Kalendertagen nur über `CalendarDay.dayNumber` (Ganzzahl), nie über `Date`/`Calendar`
  innerhalb des Kerns; einzige Ausnahme sind die beiden Grenz-Initialisierer `init(_:calendar:)`.
- Testdaten: Kalender 2026 (Mo 16.11.2026 = A-Woche laut AK-2), Klassen `7a`, `8a`, `8b`, `9c`, `6c`,
  Fächer „Englisch“, „Mathe“, „Deutsch“, „Bio“.
- Kein Teil dieses Plans berührt ein AK aus der Geräte-Checkliste der Übersicht; es gibt daher keine
  Geräte-Checkliste.

## Review Focus

1. **Bezugswoche A ist kein Montag oder liegt nach dem abgefragten Datum** – erwartet: Die Woche, die
   die Bezugswoche enthält, ist A; Wochen davor wechseln ebenso (Abrundung statt Abschneiden bei
   negativen Wochen). Test in Task 4.
2. **Klassennamen in Import-Schreibweise** („8 b“, „08B“, geschütztes Leerzeichen, „10a“) – erwartet:
   gleiche Klasse wird gleich, „10a“ bleibt „10a“. Test in Task 2.
3. **Zeitraster unvollständig** (Stunde ohne Zeit) – erwartet: Unterrichtsstunde erscheint mit
   `time == nil` an ihrer Stelle; der Klassenbildschirm übergeht sie statt abzustürzen oder sie als
   „laufend“ zu zeigen. Tests in Task 5 und Task 7.
4. **Vertretungsstunde derselben Klasse im selben Fach am selben Tag** – erwartet: die laufende Nummer
   der Stunde aus dem Stundenplan bleibt unverändert, sonst hinge vorbereitetes Material plötzlich an
   der falschen Stunde (ADR-0005). Test in Task 5.
5. **Grenzzeitpunkte des Klassenbildschirms** (genau Beginn, genau Beginn der letzten fünf Minuten,
   genau Ende, Pause zwischen zwei Stunden) – erwartet: Beginn → `inLesson`, 9:15 bei Ende 9:20 →
   `finalMinutes`, 9:20 → nächste Stunde `upcoming` bzw. `noMoreLessons`. Test in Task 7.

---

## Dateistruktur

```
project.yml                                   Task 9
.gitignore                                    Task 9 (ergänzt)
.github/workflows/ci.yml                      Task 9
Frontstage/App/FrontstageApp.swift            Task 9 (Platzhalter)
Frontstage/Resources/Localizable.xcstrings    Task 9
FrontstageTests/AppSmokeTests.swift           Task 9
Packages/FrontstageCore/Package.swift         Task 1
Packages/FrontstageCore/Sources/FrontstageCore/
  Calendar/CalendarDay.swift  Calendar/Weekday.swift  Calendar/TimeOfDay.swift        Task 1
  Names/SchoolClass.swift  Names/Subject.swift                                       Task 2
  Lessons/LessonKey.swift  Lessons/Origin.swift                                      Task 3
  Timetable/WeekVariant.swift  Timetable/BellSchedule.swift  Timetable/TimetableEntry.swift
  Timetable/Timetable.swift  Timetable/NonTeachingPeriod.swift                       Task 4
  Lessons/ScheduleChange.swift  Lessons/Lesson.swift  Lessons/TimetableCalculator.swift  Task 4–6
  ClassScreen/ClassScreenPhase.swift  ClassScreen/ClassScreenCalculator.swift        Task 7
  Import/ImportDiff.swift  Import/ImportDiffer.swift                                 Task 8
Packages/FrontstageCore/Tests/FrontstageCoreTests/
  Fixtures.swift  CalendarDayTests.swift  NameNormalizationTests.swift  LessonKeyTests.swift
  WeekVariantTests.swift  LessonsTests.swift  NextLessonTests.swift  ClassScreenTests.swift
  ImportDifferTests.swift
```

Eine Datei je Typ; `TimetableCalculator` wächst über Task 4–6 (je eine `static func`).

---

### Task 1: Kern-Paket anlegen, Kalendertag, Wochentag, Uhrzeit

**Files:**
- Create: `Packages/FrontstageCore/Package.swift`
- Create: `Packages/FrontstageCore/Sources/FrontstageCore/Calendar/CalendarDay.swift`, `Weekday.swift`, `TimeOfDay.swift`
- Create: `Packages/FrontstageCore/Tests/FrontstageCoreTests/Fixtures.swift`, `CalendarDayTests.swift`

**Interfaces:**
- Consumes: –
- Produces (zusätzlich zur Übersicht, für alle Teilpläne):
  ```swift
  public struct CalendarDay: Hashable, Comparable, Codable, Sendable {
    public let year: Int; public let month: Int; public let day: Int
    public init(year: Int, month: Int, day: Int)          // precondition: gültiges Datum
    public init?(isoString: String)                         // "2026-11-17"
    public var isoString: String { get }                    // "2026-11-17", Monat/Tag zweistellig
    public init(dayNumber: Int)                             // Tage seit 1970-01-01
    public var dayNumber: Int { get }
    public func adding(days: Int) -> CalendarDay
    public var weekday: Weekday { get }
    public init(_ date: Date, calendar: Calendar)           // Grenze App → Kern
  }
  public enum Weekday: Int, CaseIterable, Codable, Sendable { case monday = 1, tuesday, wednesday, thursday, friday, saturday, sunday }
  public struct TimeOfDay: Hashable, Comparable, Codable, Sendable {
    public let hour: Int; public let minute: Int
    public init(hour: Int, minute: Int)                     // precondition 0...23, 0...59
    public var minutesSinceMidnight: Int { get }
    public init(_ date: Date, calendar: Calendar)           // Sekunden abgeschnitten
  }
  ```

- [ ] **Step 1: `Package.swift` schreiben**

  ```swift
  // swift-tools-version: 6.0
  import PackageDescription
  let package = Package(
    name: "FrontstageCore",
    platforms: [.iOS("26.0"), .macOS("26.0")],
    products: [.library(name: "FrontstageCore", targets: ["FrontstageCore"])],
    targets: [
      .target(name: "FrontstageCore"),
      .testTarget(name: "FrontstageCoreTests", dependencies: ["FrontstageCore"]),
    ]
  )
  ```
  Tools-Version 6.0 schaltet den Swift-6-Sprachmodus (strikte Nebenläufigkeit) für das Paket ein.
  Versionen als Zeichenkette, weil `.v26`-Konstanten erst in neueren PackageDescription-Ständen sicher
  vorhanden sind.

- [ ] **Step 2: Fixtures und fehlschlagende Tests schreiben**

  `Fixtures.swift` (internal): `func d(_ y: Int, _ m: Int, _ day: Int) -> CalendarDay`,
  `func t(_ h: Int, _ m: Int) -> TimeOfDay`.

  `CalendarDayTests.swift`:
  - `weekdayOfKnownDates` – `d(2026,11,16).weekday == .monday`, `d(2026,11,17).weekday == .tuesday`,
    `d(2024,2,29).weekday == .thursday`, `d(2000,1,1).weekday == .saturday`, `d(1970,1,1).weekday == .thursday`.
  - `dayNumberRoundTrip` – `d(1970,1,1).dayNumber == 0`; für `d(2026,11,16)`, `d(2024,2,29)`,
    `d(1969,12,31)`: `CalendarDay(dayNumber: x.dayNumber) == x`.
  - `addingDaysCrossesMonthAndLeapYear` – `d(2026,11,30).adding(days: 1) == d(2026,12,1)`,
    `d(2024,2,28).adding(days: 1) == d(2024,2,29)`, `d(2026,12,31).adding(days: 1) == d(2027,1,1)`,
    `d(2026,11,23).adding(days: -7) == d(2026,11,16)`.
  - `comparableOrdersByDate` – `d(2026,11,16) < d(2026,11,17)`, `d(2026,12,1) > d(2026,11,30)`.
  - `isoStringRoundTrip` – `d(2026,11,3).isoString == "2026-11-03"`, `CalendarDay(isoString: "2026-11-03") == d(2026,11,3)`,
    `CalendarDay(isoString: "2026-02-30") == nil`, `CalendarDay(isoString: "x") == nil`.
  - `dateConversionUsesGivenTimeZone` – `Date` 2026-03-28T23:30:00Z, Kalender gregorianisch mit
    `TimeZone(identifier: "Europe/Berlin")` → `CalendarDay == d(2026,3,29)`, `TimeOfDay == t(0,30)`;
    mit `TimeZone(identifier: "UTC")` → `d(2026,3,28)`, `t(23,30)`.
  - `timeOfDayOrdering` – `t(8,35) < t(9,20)`, `t(9,20).minutesSinceMidnight == 560`.

  Alle `@Test`-Beschreibungen deutsch, z. B. `@Test("Wochentag bekannter Daten")`.

- [ ] **Step 3: Diff durchsehen** – jeder Test referenziert nur Signaturen aus dem Interfaces-Block
  (sie fehlen noch: das ist der rote Zustand; ausgeführt wird im CI-Lauf, Task 10).

- [ ] **Step 4: Implementieren**

  `dayNumber` und `init(dayNumber:)` mit dem Algorithmus „days from civil“ (H. Hinnant,
  gemeinfrei) – nicht durch Signatur und Test festgelegt, daher hier:
  ```swift
  // days_from_civil
  let y = month <= 2 ? year - 1 : year
  let era = (y >= 0 ? y : y - 399) / 400
  let yoe = y - era * 400
  let mp = (month + 9) % 12                       // März = 0
  let doy = (153 * mp + 2) / 5 + day - 1
  let doe = yoe * 365 + yoe / 4 - yoe / 100 + doy
  return era * 146097 + doe - 719468
  // civil_from_days (Umkehrung): z = n + 719468; era = (z >= 0 ? z : z - 146096) / 146097;
  // doe = z - era*146097; yoe = (doe - doe/1460 + doe/36524 - doe/146096) / 365;
  // doy = doe - (365*yoe + yoe/4 - yoe/100); mp = (5*doy + 2)/153;
  // day = doy - (153*mp + 2)/5 + 1; month = mp < 10 ? mp + 3 : mp - 9; year = yoe + era*400 + (month <= 2 ? 1 : 0)
  ```
  `weekday`: 1970-01-01 war Donnerstag → `Weekday(rawValue: floorMod(dayNumber + 3, 7) + 1)!`
  mit `floorMod(a, n) = ((a % n) + n) % n`. Gültigkeit in `init(year:month:day:)`/`init?(isoString:)`
  über Rundreise `CalendarDay(dayNumber: dayNumber)` prüfen. `Comparable` über `dayNumber`.
  `init(_ date:calendar:)` über `calendar.dateComponents([.year, .month, .day], from: date)`.
  `///`-Doku deutsch: „Kalendertag ohne Zeitzone; zwei Geräte in verschiedenen Zeitzonen meinen mit
  demselben Wert denselben Schultag.“

- [ ] **Step 5: Diff durchsehen** – `public` an Typ, Eigenschaften und jedem `init`; kein `import`
  außer `Foundation`; kein `TimeZone.current`, kein `Date()`.

- [ ] **Step 6: Commit**
  ```bash
  git add Packages/FrontstageCore
  git commit -m "feat(core): add package with CalendarDay, Weekday, TimeOfDay"
  ```

---

### Task 2: Normalisierung von Klasse und Fach

**Files:**
- Create: `Sources/FrontstageCore/Names/SchoolClass.swift`, `Names/Subject.swift`
- Test: `Tests/FrontstageCoreTests/NameNormalizationTests.swift`

**Interfaces:**
- Consumes: –
- Produces:
  ```swift
  public struct SchoolClass: Hashable, Codable, Sendable { public let normalized: String; public init(_ raw: String) }
  public struct Subject: Hashable, Codable, Sendable {
    public let normalized: String; public let display: String; public init(_ raw: String)
    // == und hash(into:) NUR über normalized
  }
  ```

- [ ] **Step 1: Fehlschlagende Tests schreiben**
  - `schoolClassNormalizesSpellings` (parametrisiert, `@Test(arguments:)`): `"8 b"`, `"08B"`, `"8b"`,
    `" 8b "`, `"8\u{00A0}b"`, `"008b"` → `normalized == "8b"`. Beschreibung: „Klassennamen werden
    normalisiert (ADR-0005)“.
  - `schoolClassKeepsMeaningfulZeros` – `SchoolClass("10a").normalized == "10a"`,
    `SchoolClass("Q 11").normalized == "q11"`, `SchoolClass("0").normalized == "0"`.
  - `schoolClassEqualityAfterNormalization` – `SchoolClass("8 b") == SchoolClass("08B")`,
    `SchoolClass("8b") != SchoolClass("8a")`.
  - `subjectComparesNormalizedKeepsDisplay` – `Subject("Englisch") == Subject(" englisch ")`;
    `Subject(" Englisch ").display == "Englisch"`; `Subject("Bildende  Kunst").normalized == "bildende kunst"`;
    `Set([Subject("Englisch"), Subject("ENGLISCH")]).count == 1`.

- [ ] **Step 2: Diff durchsehen** (roter Zustand, Ausführung in Task 10).

- [ ] **Step 3: Implementieren**
  - `SchoolClass.init(_:)`: `lowercased()`, alle Zeichen aus `CharacterSet.whitespacesAndNewlines`
    entfernen (deckt U+00A0 ab), dann führende `"0"` entfernen, solange danach noch eine Ziffer folgt
    (so bleibt `"0"` erhalten und `"10a"` unberührt).
  - `Subject.init(_:)`: `display` = getrimmt; `normalized` = `display.lowercased()` mit
    Leerraum-Folgen zu einem Leerzeichen zusammengefasst. **Keine** Abkürzungs-Zuordnung („E“ →
    „Englisch“) – siehe Abstimmungsbedarf mit Teilplan 05.
  - `Subject`: `static func ==` und `hash(into:)` von Hand über `normalized`; ohne das zählte die
    synthetisierte Gleichheit `display` mit und „Englisch“ ≠ „englisch“ würde jeden Schlüssel brechen.
    Kommentar deutsch mit genau dieser Begründung.

- [ ] **Step 4: Diff durchsehen** – `public` vollständig; Kommentar zu `==` vorhanden.

- [ ] **Step 5: Commit** – `git commit -m "feat(core): normalize school class and subject names"`

---

### Task 3: Schlüssel der Unterrichtsstunde und Herkunft

**Files:**
- Create: `Sources/FrontstageCore/Lessons/LessonKey.swift`, `Lessons/Origin.swift`
- Test: `Tests/FrontstageCoreTests/LessonKeyTests.swift`

**Interfaces:**
- Consumes: `CalendarDay` (Task 1), `SchoolClass`, `Subject` (Task 2)
- Produces:
  ```swift
  public struct LessonKey: Hashable, Codable, Sendable {
    public let date: CalendarDay; public let schoolClass: SchoolClass; public let subject: Subject; public let ordinal: Int
    public init(date: CalendarDay, schoolClass: SchoolClass, subject: Subject, ordinal: Int)
    public var storageText: String { get }
    public init?(storageText: String)
  }
  public enum Origin: String, Codable, Sendable { case manual, source }
  ```
  **Format `storageText` (dauerhaft, steht in jeder gespeicherten Zuordnung):**
  `"<isoString>|<Klasse>|<Fach>|<ordinal>"`, Klasse und Fach jeweils `normalized`, prozentkodiert mit
  `addingPercentEncoding(withAllowedCharacters: .alphanumerics)`. Beispiel:
  `"2026-11-17|8b|englisch|1"`, `"2026-11-17|8b|bildende%20kunst|1"`.

- [ ] **Step 1: Fehlschlagende Tests schreiben**
  - `storageTextFormat` – Schlüssel (17.11.2026, „8 b“, „Englisch“, 1) → `storageText == "2026-11-17|8b|englisch|1"`.
  - `storageTextRoundTrip` – für (17.11.2026, „8b“, „Bildende Kunst“, 2) und (3.11.2026, „10a“, „Mathe|Info“, 1):
    `LessonKey(storageText: k.storageText) == k`.
  - `storageTextRejectsGarbage` – `nil` für `""`, `"2026-11-17|8b|englisch"`, `"2026-13-01|8b|englisch|1"`,
    `"2026-11-17|8b|englisch|0"`, `"2026-11-17|8b|englisch|x"`.
  - `keyEqualityUsesNormalizedNames` – (17.11., „08B“, „ENGLISCH“, 1) `==` (17.11., „8b“, „Englisch“, 1).

- [ ] **Step 2: Diff durchsehen.**

- [ ] **Step 3: Implementieren** – `init?(storageText:)`: genau vier Teile nach `"|"`, Datum über
  `CalendarDay(isoString:)`, Teile 2–3 per `removingPercentEncoding`, `ordinal >= 1`. Aus dem Text
  entsteht `Subject(normalized)`; `display` ist dann klein geschrieben (dokumentieren: Anzeige des
  Fachs kommt aus der berechneten `Lesson`, nicht aus dem Schlüssel).

- [ ] **Step 4: Diff durchsehen.**

- [ ] **Step 5: Commit** – `git commit -m "feat(core): add LessonKey with stable storage text (ADR-0005)"`

---

### Task 4: Stundenplan-Typen und Wochenvariante

**Files:**
- Create: `Sources/FrontstageCore/Timetable/WeekVariant.swift`, `BellSchedule.swift`, `TimetableEntry.swift`, `Timetable.swift`, `NonTeachingPeriod.swift`
- Create: `Sources/FrontstageCore/Lessons/ScheduleChange.swift`, `Lessons/Lesson.swift`, `Lessons/TimetableCalculator.swift`
- Test: `Tests/FrontstageCoreTests/WeekVariantTests.swift`

**Interfaces:**
- Consumes: Task 1–3
- Produces (Typen exakt wie Übersicht, plus):
  ```swift
  public enum WeekVariant: String, Codable, Sendable { case a, b }
  public struct BellSchedule: Hashable, Codable, Sendable { public var periods: [Int: ClosedRange<TimeOfDay>]; public init(periods: [Int: ClosedRange<TimeOfDay>] = [:]) }
  public struct TimetableEntry: Hashable, Codable, Sendable { …; public init(weekVariant: WeekVariant? = nil, weekday: Weekday, period: Int, schoolClass: SchoolClass, subject: Subject) }
  public struct Timetable: Codable, Sendable { …; public init(weekVariantCount: Int = 1, referenceWeekA: CalendarDay, bellSchedule: BellSchedule = BellSchedule(), entries: [TimetableEntry] = []) }
  public struct NonTeachingPeriod: Hashable, Codable, Sendable { …; public init(from: CalendarDay, to: CalendarDay, title: String); public func contains(_ day: CalendarDay) -> Bool }   // beide Enden einschließlich
  public enum ScheduleChange: Hashable, Codable, Sendable { case cancellation(LessonKey, Origin); case substituteLesson(date: CalendarDay, period: Int, schoolClass: SchoolClass, subject: Subject, Origin) }
  public struct Lesson: Hashable, Sendable { …; public init(key: LessonKey, period: Int, time: ClosedRange<TimeOfDay>?, isSubstituteLesson: Bool, isCancelled: Bool, cancellationOrigin: Origin?) }
  public enum TimetableCalculator { public static func weekVariant(for day: CalendarDay, timetable: Timetable) -> WeekVariant? }
  ```
  `TimetableEntry.weekVariant == nil` heißt „gilt in jeder Woche“.

- [ ] **Step 1: Fehlschlagende Tests schreiben**
  - `weekVariantAlternatesFromReference` (**AK-2**) – `weekVariantCount: 2`, `referenceWeekA: d(2026,11,16)`:
    `d(2026,11,16) → .a`, `d(2026,11,23) → .b`, `d(2026,11,30) → .a`, `d(2026,11,22)` (Sonntag) `→ .a`.
  - `weekVariantBeforeReference` (Review Focus 1) – gleiche Einstellung: `d(2026,11,9) → .b`, `d(2026,11,2) → .a`.
  - `referenceWeekNotMonday` (Review Focus 1) – `referenceWeekA: d(2026,11,18)` (Mittwoch):
    `d(2026,11,16) → .a`, `d(2026,11,23) → .b`.
  - `singleVariantHasNoWeekVariant` – `weekVariantCount: 1` → `nil` für `d(2026,11,16)`.
  - `nonTeachingPeriodIsInclusive` – Zeitraum 2.–6.11.2026: `contains` wahr für `d(2026,11,2)`, `d(2026,11,6)`; falsch für `d(2026,11,1)`, `d(2026,11,7)`.
  - `timetableCodableRoundTrip` – `Timetable` mit Zeitraster `[2: t(8,35)...t(9,20)]` und einem Eintrag: `JSONEncoder` → `JSONDecoder` ergibt gleiches `bellSchedule` und gleiche `entries`.

- [ ] **Step 2: Diff durchsehen.**

- [ ] **Step 3: Implementieren `weekVariant(for:timetable:)`** – `nil`, wenn `weekVariantCount != 2`;
  sonst Montag der Woche = `dayNumber - (weekday.rawValue - 1)` für Tag und Bezugswoche,
  `weeks = floorDiv(mondayDay - mondayRef, 7)`, gerade → `.a`, ungerade → `.b` (Abrundung, nicht
  Abschneiden: `floorDiv(a, n) = (a - floorMod(a, n)) / n`). Helfer `floorMod`/`floorDiv` als
  `internal` in `Calendar/CalendarDay.swift` (wiederverwendet aus Task 1).

- [ ] **Step 4: Diff durchsehen** – `ClosedRange<TimeOfDay>` ist `Codable`/`Hashable`/`Sendable` per
  bedingter Konformität, keine eigene Kodierung nötig.

- [ ] **Step 5: Commit** – `git commit -m "feat(core): add timetable types and week variant (FR-1.1)"`

---

### Task 5: Unterrichtsstunden eines Tages

**Files:**
- Modify: `Sources/FrontstageCore/Lessons/TimetableCalculator.swift`
- Test: `Tests/FrontstageCoreTests/LessonsTests.swift`

**Interfaces:**
- Consumes: Task 1–4
- Produces: `TimetableCalculator.lessons(on day: CalendarDay, timetable: Timetable, nonTeachingPeriods: [NonTeachingPeriod], changes: [ScheduleChange]) -> [Lesson]`

- [ ] **Step 1: Fehlschlagende Tests schreiben** (Fixture in `Fixtures.swift`:
  `func timetable(_ entries: [TimetableEntry], bell: [Int: ClosedRange<TimeOfDay>] = [:], variants: Int = 1) -> Timetable` mit `referenceWeekA: d(2026,11,16)`)
  - `entryAppearsEveryTuesday` (**AK-1**) – Eintrag Di, 2. Stunde, 8b, Englisch: für `d(2026,11,17)`,
    `d(2026,11,24)`, `d(2027,1,12)` genau eine `Lesson` mit `period == 2`, `key.schoolClass == SchoolClass("8b")`,
    `key.subject.display == "Englisch"`, `key.ordinal == 1`, `isCancelled == false`; für `d(2026,11,18)` leer.
  - `weekVariantSelectsEntries` (**AK-2**) – `variants: 2`, Mo 1. Stunde A 7a, Mo 1. Stunde B 9c:
    16.11. → einzige Klasse `7a`; 23.11. → einzige Klasse `9c`.
  - `entryWithoutVariantAppliesToBothWeeks` – `variants: 2`, Eintrag Mo 3. Stunde ohne Variante 8a:
    am 16.11. und 23.11. vorhanden.
  - `bellScheduleSetsTime` (**AK-42**) – Di 2. Stunde 8b, Zeitraster leer → `time == nil`; mit
    `[2: t(8,35)...t(9,20)]` → `time == t(8,35)...t(9,20)`.
  - `incompleteBellScheduleKeepsLesson` (Review Focus 3) – Zeitraster nur für Stunde 1; Stunden 1 und 3
    am Tag → zwei Lessons, Stunde 3 mit `time == nil`, Reihenfolge `[1, 3]`.
  - `lessonsSortedByPeriod` – Einträge Di 5, 1, 3 (verschiedene Klassen) → `period`-Folge `[1, 3, 5]`.
  - `nonTeachingDayHasNoLessons` (**AK-14**) – Herbstferien `d(2026,11,2)...d(2026,11,6)`, Eintrag Di
    8b: `lessons(on: d(2026,11,3))` leer; `d(2026,11,10)` hat die Stunde. Auch eine Vertretungsstunde am
    3.11. erscheint nicht (Annahme A2).
  - `cancellationMarksLesson` (**AK-15**) – Di 8b Englisch, Änderung `.cancellation(key(17.11.,8b,Englisch,1), .manual)`:
    Lesson bleibt in der Liste, `isCancelled == true`, `cancellationOrigin == .manual`; am 24.11. nicht ausgefallen.
  - `substituteLessonOnlyOnItsDate` (**AK-16**) – `.substituteLesson(date: d(2026,11,18), period: 4, schoolClass: SchoolClass("6c"), subject: Subject("Mathe"), .manual)`:
    am 18.11. eine Lesson mit `isSubstituteLesson == true`, `period == 4`, Klasse 6c; am 25.11. keine.
  - `doubleLessonOrdinals` – Di 3. und 4. Stunde 8b Englisch → Ordinals `[1, 2]`; zusätzlich Di 6. Stunde
    8a Englisch → Ordinal `1`.
  - `substituteDoesNotShiftRegularOrdinal` (Review Focus 4) – Di 2. Stunde 8b Englisch aus dem Plan,
    Vertretungsstunde Di 1. Stunde 8b Englisch: reguläre Lesson behält `ordinal == 1`, Vertretung hat
    `ordinal == 2`; Liste nach `period` sortiert `[1, 2]`.
  - `duplicateSubstitutesCollapse` – dieselbe Vertretungsstunde zweimal (einmal `.manual`, einmal
    `.source`) → genau eine Lesson.

- [ ] **Step 2: Diff durchsehen.**

- [ ] **Step 3: Implementieren** – Reihenfolge, nicht aus Signatur ableitbar:
  1. Liegt `day` in einem `nonTeachingPeriods`-Zeitraum → `[]`.
  2. `variant = weekVariant(for:)`; reguläre Einträge: `weekday == day.weekday` und
     (`variant == nil` oder `entry.weekVariant == nil` oder `entry.weekVariant == variant`); nach `period` sortieren.
  3. Laufende Nummer: zuerst über die regulären Einträge in `period`-Folge je (Klasse, Fach) zählen,
     **danach** die Vertretungsstunden des Tages (dedupliziert nach Datum, Stunde, Klasse, Fach) in
     `period`-Folge weiterzählen. Kommentar: Vertretungen hinten anstellen, damit eine nachträglich
     eingetragene Vertretung die Schlüssel vorhandener Zuordnungen nicht verschiebt (ADR-0005).
  4. `time = timetable.bellSchedule.periods[period]`.
  5. Ausfälle: `.cancellation(key, origin)` mit passendem Schlüssel markiert die Lesson; liegen beide
     Herkünfte vor, gilt `.manual`.
  6. Ergebnis stabil sortiert nach (`period`, Vertretung nach regulär, `schoolClass.normalized`).

- [ ] **Step 4: Diff durchsehen.**

- [ ] **Step 5: Commit** – `git commit -m "feat(core): compute lessons of a day (FR-1, FR-7, FR-8, FR-9)"`

---

### Task 6: Nächste Unterrichtsstunde der Klasse

**Files:**
- Modify: `Sources/FrontstageCore/Lessons/TimetableCalculator.swift`
- Test: `Tests/FrontstageCoreTests/NextLessonTests.swift`

**Interfaces:**
- Consumes: `lessons(on:…)` (Task 5)
- Produces: `TimetableCalculator.nextLesson(after key: LessonKey, timetable: Timetable, nonTeachingPeriods: [NonTeachingPeriod], changes: [ScheduleChange], maxDays: Int = 28) -> LessonKey?`

Gemeinsames Fixture: Di 2. Stunde 8b Englisch, Mi 1. Stunde 8b Mathe, Do 3. Stunde 8b Englisch,
Di 6. Stunde 8a Englisch. `tue = LessonKey(date: d(2026,11,17), schoolClass: SchoolClass("8b"), subject: Subject("Englisch"), ordinal: 1)`.

- [ ] **Step 1: Fehlschlagende Tests schreiben**
  - `nextLessonIsThursday` (**AK-8**) – `nextLesson(after: tue, …) == LessonKey(d(2026,11,19), 8b, Englisch, 1)`
    (nicht Mi Mathe, nicht Di 8a).
  - `nextLessonSkipsCancelledSource` (**AK-15**) – Di als Ausfall markiert: Ergebnis weiterhin Do 19.11.
  - `nextLessonSkipsCancelledTarget` – zusätzlich Do 19.11. ausgefallen → `d(2026,11,24)`.
  - `nextLessonSkipsHolidays` (**AK-14**) – Schlüssel am 3.11. (in den Herbstferien 2.–6.11., Stunde
    existiert dort nicht) → Do `d(2026,11,5)` liegt in den Ferien, Ergebnis Di `d(2026,11,10)`.
  - `nextLessonWithinDoubleLesson` – Doppelstunde Di 3./4. 8b Englisch: nach Ordinal 1 → derselbe Tag, Ordinal 2.
  - `nextLessonCanBeSubstitute` – Vertretungsstunde Mi 18.11. 5. Stunde 8b Englisch → Ergebnis Mi 18.11., Ordinal 1.
  - `nextLessonNilBeyondMaxDays` – unterrichtsfrei 18.11.2026–31.12.2026 → `nil`.

- [ ] **Step 2: Diff durchsehen.**

- [ ] **Step 3: Implementieren** – am Tag von `key.date`: Kandidaten sind Lessons gleicher Klasse und
  gleichen Fachs mit `ordinal > key.ordinal`; an den Folgetagen `1...maxDays` jede Lesson gleicher
  Klasse und gleichen Fachs; jeweils erste nicht ausgefallene in Listenreihenfolge. Kein Rückgriff auf
  `period` des Ausgangsschlüssels, damit auch Schlüssel „ohne Stunde“ (Ferien, ADR-0005) funktionieren.

- [ ] **Step 4: Diff durchsehen.**

- [ ] **Step 5: Commit** – `git commit -m "feat(core): find next lesson of the class (FR-3.3, FR-8)"`

---

### Task 7: Phase des Klassenbildschirms

**Files:**
- Create: `Sources/FrontstageCore/ClassScreen/ClassScreenPhase.swift`, `ClassScreen/ClassScreenCalculator.swift`
- Test: `Tests/FrontstageCoreTests/ClassScreenTests.swift`

**Interfaces:**
- Consumes: `Lesson`, `TimeOfDay`, `lessons(on:…)` für Testdaten
- Produces:
  ```swift
  public enum ClassScreenPhase: Hashable, Sendable { case upcoming(Lesson); case inLesson(Lesson); case finalMinutes(Lesson); case noMoreLessons }
  public enum ClassScreenCalculator { public static func phase(now: TimeOfDay, lessons: [Lesson], finalMinutes: Int = 5) -> ClassScreenPhase }
  ```
  Thema, Bereitlegen und Hausaufgabe gehören nicht hierher (`LessonInfo`, Teilplan 02/07); der Kern
  liefert nur, **welche** Unterrichtsstunde in **welcher** Fassung gezeigt wird.

Fixture (**AK-36**): Di 17.11., Zeitraster `[2: t(8,35)...t(9,20), 4: t(10,30)...t(11,15)]`,
Di 2. Stunde 8b Englisch, Di 4. Stunde 9c Deutsch als Ausfall markiert. `lessons` aus
`TimetableCalculator.lessons(on: d(2026,11,17), …)`; `l8b` = die 8b-Lesson.

- [ ] **Step 1: Fehlschlagende Tests schreiben**
  - `phasesFollowLessonCourse` (**AK-36**) – `t(8,31) → .upcoming(l8b)`, `t(8,40) → .inLesson(l8b)`,
    `t(9,16) → .finalMinutes(l8b)`, `t(9,30) → .noMoreLessons` (der Ausfall um 10:30 zählt nicht).
  - `inLessonShowsEndTime` (**AK-42**) – bei `t(8,40)`: Phase `.inLesson(l)` mit `l.time?.upperBound == t(9,20)`.
  - `boundaryTimes` (Review Focus 5) – `t(8,35) → .inLesson`, `t(9,15) → .finalMinutes`, `t(9,20) → .noMoreLessons`.
  - `breakShowsNextLesson` (Review Focus 5) – Fixture ohne Ausfall (9c Deutsch 10:30 findet statt):
    `t(9,20)` und `t(10,0)` → `.upcoming(9c-Lesson)`.
  - `lessonsWithoutTimeAreIgnored` (Review Focus 3) – nur Lessons mit `time == nil` → `.noMoreLessons` zu jeder Zeit.
  - `emptyDayHasNoMoreLessons` – `lessons: []` → `.noMoreLessons`.
  - `finalMinutesParameter` – `finalMinutes: 10` bei `t(9,10)` → `.finalMinutes(l8b)`.

- [ ] **Step 2: Diff durchsehen.**

- [ ] **Step 3: Implementieren** – nur Lessons mit `!isCancelled` und `time != nil`, nach
  `time.lowerBound` sortiert. Laufend ist die erste mit `start <= now < end` (Ende ausschließlich);
  davon `.finalMinutes`, wenn `now.minutesSinceMidnight >= end.minutesSinceMidnight - finalMinutes`,
  sonst `.inLesson`. Ohne laufende: erste mit `start > now` → `.upcoming`; sonst `.noMoreLessons`.

- [ ] **Step 4: Diff durchsehen.**

- [ ] **Step 5: Commit** – `git commit -m "feat(core): derive class screen phase (FR-11.7)"`

---

### Task 8: Import-Abgleich

**Files:**
- Create: `Sources/FrontstageCore/Import/ImportDiff.swift`, `Import/ImportDiffer.swift`
- Test: `Tests/FrontstageCoreTests/ImportDifferTests.swift`

**Interfaces:**
- Consumes: `TimetableEntry` (Task 4)
- Produces:
  ```swift
  public struct ImportDiff: Sendable {
    public var added: [TimetableEntry]; public var changed: [(old: TimetableEntry, new: TimetableEntry)]
    public var manualConflicts: [(mine: TimetableEntry, source: TimetableEntry)]; public var removed: [TimetableEntry]
    public init(added: [TimetableEntry] = [], changed: … = [], manualConflicts: … = [], removed: [TimetableEntry] = [])
    public var isEmpty: Bool { get }
  }
  public enum ImportDiffer { public static func compare(existing: [TimetableEntry], manuallyEdited: Set<TimetableEntry>, imported: [TimetableEntry]) -> ImportDiff }
  ```
  **Bedeutung für Teilplan 02/05 (Übernahme):** Was nicht in `removed` steht, bleibt. Von Hand
  angelegte oder geänderte Einträge (`manuallyEdited`) erscheinen **nie** in `removed` und **nie** in
  `changed`; fehlen sie im Import, bleiben sie ohne Eintrag im Diff stehen (AK-3: „geht nicht
  stillschweigend verloren“). Weicht der Import an ihrem Platz ab, landen sie in `manualConflicts` und
  die Vorschau fragt.

- [ ] **Step 1: Fehlschlagende Tests schreiben** (Tupel sind nicht `Equatable` – Vergleich über
  `diff.changed.map(\.old)` / `.map(\.new)`)
  - `importAddsEntriesKeepsManual` (**AK-3**) – `existing = [Mo 1. 7a Deutsch]`, `manuallyEdited = Set(existing)`,
    `imported = [Di 2. 8b Englisch, Mi 3. 9c Mathe, Do 1. 6c Bio]` → `added` diese 3 (in Platz-Reihenfolge),
    `removed == []`, `changed.isEmpty`, `manualConflicts.isEmpty`.
  - `identicalImportIsEmpty` – existing == imported (zwei Einträge, einer von Hand) → `isEmpty`.
  - `sourceEntryChangedAtSameSlot` – existing Di 2. 8b Englisch (nicht von Hand), imported Di 2. 8a Englisch
    → `changed == [(old: 8b, new: 8a)]`, sonst leer.
  - `manualEntryConflictsAtSameSlot` – wie oben, aber existing von Hand → `manualConflicts == [(mine: 8b, source: 8a)]`, `changed` leer.
  - `missingSourceEntryIsRemoved` – existing Fr 5. 9c Mathe (nicht von Hand), fehlt im Import → `removed == [Fr 5. 9c Mathe]`.
  - `normalizedNamesAreNoChange` (Review Focus 2) – existing Di 2. „8b“ „Englisch“, imported Di 2. „8 b“ „englisch“ → `isEmpty`.
  - `duplicateImportedEntriesCountOnce` – Import enthält Di 2. 8b Englisch doppelt, existing leer → `added.count == 1`.

- [ ] **Step 2: Diff durchsehen.**

- [ ] **Step 3: Implementieren** – Algorithmus (nicht durch Signatur festgelegt):
  1. `imported` deduplizieren (erste Fundstelle bleibt).
  2. Beide Seiten nach Platz `(weekVariant, weekday, period)` gruppieren.
  3. Je Platz exakt gleiche Einträge auf beiden Seiten paarweise streichen.
  4. Übrige je Platz der Reihe nach paaren: vorhandener Eintrag in `manuallyEdited` →
     `manualConflicts(mine:source:)`, sonst `changed(old:new:)`.
  5. Übrige importierte → `added`; übrige vorhandene ohne Hand-Markierung → `removed`; übrige von Hand → nirgends (bleiben).
  6. Jede Liste sortiert nach (weekday, period, weekVariant `nil` < `a` < `b`, Klasse normalisiert).

- [ ] **Step 4: Diff durchsehen** – `ImportDiff` ist `Sendable` ohne `@unchecked` (Tupel aus
  `Sendable`-Werten sind `Sendable`).

- [ ] **Step 5: Commit** – `git commit -m "feat(core): compare imported timetable without losing manual entries (AK-3)"`

---

### Task 9: Projekt, App-Gerüst, CI-Workflow

Design-Takt: keiner (Platzhalter-Bildschirm mit einem Text; die echte Oberfläche baut Teilplan 04).

**Files:**
- Create: `project.yml`, `.github/workflows/ci.yml`, `Frontstage/App/FrontstageApp.swift`,
  `Frontstage/Resources/Localizable.xcstrings`, `FrontstageTests/AppSmokeTests.swift`
- Modify: `.gitignore` (Zeilen anhängen, bestehende behalten)

**Interfaces:**
- Consumes: Paket `FrontstageCore` (Task 1–8)
- Produces: Ziele `Frontstage-iOS` (iPadOS 26), `Frontstage-macOS` (macOS 26), beide
  `PRODUCT_NAME`/`PRODUCT_MODULE_NAME` = `Frontstage`, gleiche Bundle-ID `com.example.frontstage`
  (gleiche ID für beide Plattformen = Voraussetzung für den gemeinsamen Kauf aus FR-13); Testziel
  `FrontstageTests` (iOS, Host `Frontstage-iOS`); Schemes `Frontstage-iOS` (mit Tests), `Frontstage-macOS`.
  Teilpläne 02/03/06/07 ergänzen Berechtigungen (iCloud, Sandbox, Kamera …) **in `project.yml`**.

- [ ] **Step 1: `.gitignore` ergänzen**
  ```
  # Xcode-Projekt wird aus project.yml erzeugt (ADR-0008)
  *.xcodeproj/
  *.xcworkspace/
  xcuserdata/
  DerivedData/
  .build/
  .swiftpm/
  ```

- [ ] **Step 2: `project.yml` schreiben** (Werte festgelegt, daher vollständig):
  ```yaml
  name: Frontstage
  options:
    bundleIdPrefix: com.example
    developmentLanguage: de
    deploymentTarget: { iOS: "26.0", macOS: "26.0" }
  settings:
    base:
      SWIFT_VERSION: "6.0"
      SWIFT_STRICT_CONCURRENCY: complete
      GENERATE_INFOPLIST_FILE: YES
      LOCALIZATION_PREFERS_STRING_CATALOGS: YES
      MARKETING_VERSION: "0.1.0"
      CURRENT_PROJECT_VERSION: "1"
      PRODUCT_NAME: Frontstage
      PRODUCT_MODULE_NAME: Frontstage
      PRODUCT_BUNDLE_IDENTIFIER: com.example.frontstage
  packages:
    FrontstageCore: { path: Packages/FrontstageCore }
  targets:
    Frontstage-iOS:
      type: application
      platform: iOS
      sources: [Frontstage]
      dependencies: [{ package: FrontstageCore }]
      settings:
        base:
          TARGETED_DEVICE_FAMILY: "2"
          INFOPLIST_KEY_UILaunchScreen_Generation: YES
          INFOPLIST_KEY_UISupportedInterfaceOrientations_iPad: "UIInterfaceOrientationPortrait UIInterfaceOrientationPortraitUpsideDown UIInterfaceOrientationLandscapeLeft UIInterfaceOrientationLandscapeRight"
      scheme: { testTargets: [FrontstageTests] }
    Frontstage-macOS:
      type: application
      platform: macOS
      sources: [Frontstage]
      dependencies: [{ package: FrontstageCore }]
      scheme: {}
    FrontstageTests:
      type: bundle.unit-test
      platform: iOS
      sources: [FrontstageTests]
      dependencies: [{ target: Frontstage-iOS }]
      settings:
        base:
          PRODUCT_NAME: FrontstageTests
          PRODUCT_MODULE_NAME: FrontstageTests
          PRODUCT_BUNDLE_IDENTIFIER: com.example.frontstage.tests
  ```
  Hinweis für den Entwickler: Die Basis-`settings` gelten für alle Ziele, deshalb überschreibt das
  Testziel Name, Modul und ID. `TEST_HOST` setzt XcodeGen selbst, weil das Testziel von einer App abhängt.

- [ ] **Step 3: Platzhalter-App und Texte**
  - `Frontstage/App/FrontstageApp.swift`: `@main struct FrontstageApp: App` mit `WindowGroup { Text("app.placeholder.title") }`.
    Ein Zeichenketten-Literal in `Text` ist ein `LocalizedStringKey` und wird in der Übersetzungstabelle
    nachgeschlagen. `import FrontstageCore` noch nicht nötig.
  - `Frontstage/Resources/Localizable.xcstrings`: JSON mit `"sourceLanguage": "de"`, `"version": "1.0"`,
    Schlüssel `app.placeholder.title` → `de`: `"Frontstage"` (`stringUnit`, `state: translated`).
  - `FrontstageTests/AppSmokeTests.swift`: `@testable import Frontstage`;
    `@Test("App-Ziel baut und findet die deutsche Übersetzungstabelle") func placeholderStringIsLocalized()` –
    `#expect(String(localized: "app.placeholder.title", bundle: .main) == "Frontstage")`
    (im gehosteten Test ist `Bundle.main` die App).

- [ ] **Step 4: `.github/workflows/ci.yml` schreiben**
  ```yaml
  name: CI
  on:
    workflow_dispatch:
    push:
      tags: ["v*"]
  concurrency: { group: "ci-${{ github.ref }}", cancel-in-progress: true }
  jobs:
    build-and-test:
      runs-on: macos-26
      timeout-minutes: 45
      steps:
        - uses: actions/checkout@v4
        - run: xcodebuild -version && swift --version
        - run: brew install xcodegen
        - run: xcodegen generate
        - name: Core tests
          run: swift test --package-path Packages/FrontstageCore
        - name: Build macOS
          run: xcodebuild build -project Frontstage.xcodeproj -scheme Frontstage-macOS -destination 'generic/platform=macOS' CODE_SIGNING_ALLOWED=NO
        - name: Build iPadOS
          run: xcodebuild build -project Frontstage.xcodeproj -scheme Frontstage-iOS -destination 'generic/platform=iOS' CODE_SIGNING_ALLOWED=NO
        - name: Pick iPad simulator
          id: sim
          run: |
            UDID=$(xcrun simctl list devices available --json | jq -r '[.devices | to_entries[] | select(.key | contains("iOS-26")) | .value[] | select(.name | startswith("iPad"))][0].udid')
            if [ -z "$UDID" ] || [ "$UDID" = "null" ]; then xcrun simctl list devices available; exit 1; fi
            echo "udid=$UDID" >> "$GITHUB_OUTPUT"
        - name: App tests (iPad simulator)
          run: xcodebuild test -project Frontstage.xcodeproj -scheme Frontstage-iOS -destination "platform=iOS Simulator,id=${{ steps.sim.outputs.udid }}" CODE_SIGNING_ALLOWED=NO
  ```
  Simulator per `jq` statt festem Gerätenamen, weil die Namen auf dem Runner mit jeder Xcode-Version
  wechseln. Signieren aus – Bundle-ID und Team aus Secrets braucht erst der TestFlight-Bau (Teilplan 04).

- [ ] **Step 5: Diff durchsehen** – YAML-Einrückung; Zielnamen in `ci.yml` gleich `project.yml`;
  `*.xcodeproj` nicht im Commit; keine echte Bundle-ID, kein Team.

- [ ] **Step 6: Commit**
  ```bash
  git add project.yml .gitignore .github/workflows/ci.yml Frontstage FrontstageTests
  git commit -m "build: add XcodeGen project, placeholder app and CI workflow"
  ```

---

### Task 10: CI-Lauf (workflow_dispatch) und Ergebnis prüfen

**Files:** – (nur bei Fehlern: die betroffenen Dateien aus Task 1–9)

- [ ] **Step 1: Branch pushen** – `git push -u origin <branch>`.

- [ ] **Step 2: Prüfen, ob der Workflow startbar ist** – `gh workflow list` muss `CI` zeigen. Fehlt er:
  `workflow_dispatch` startet nur, wenn `ci.yml` auf dem Hauptbranch liegt (GitHub-Doku, s. Quellen).
  **Anhalten und den Menschen entscheiden lassen** (Merge in `main` braucht Bestätigung): (a) nur
  `.github/workflows/ci.yml` per kleinem PR nach `main` bringen, oder (b) einmalig ein Tag
  `v0.0.0-ci.1` auf den Branch setzen und pushen (löst `push: tags` aus).

- [ ] **Step 3: Lauf starten und beobachten**
  ```bash
  gh workflow run ci.yml --ref <branch>
  RUN_ID=$(gh run list --workflow ci.yml --branch <branch> --limit 1 --json databaseId --jq '.[0].databaseId')
  gh run watch "$RUN_ID" --exit-status
  ```
  Erwartet: Exit 0; im Log „Core tests“ alle Tests aus Task 1–8 bestanden (Swift Testing meldet
  `Test run with N tests passed`), beide Builds `** BUILD SUCCEEDED **`, App-Test `** TEST SUCCEEDED **`.

- [ ] **Step 4: Bei Fehlern** – `gh run view "$RUN_ID" --log-failed`; **alle** Fehler des Laufs sammeln,
  zusammen beheben (je Ursache ein Commit), Diff erneut durchsehen, dann **ein** neuer Lauf. Erfahrungsgemäß
  liefert der erste Lauf mit Swift 6 strikt mehrere Compilerfehler – jeder Lauf kostet Geld, also nie je
  Fehler einen Lauf.

- [ ] **Step 5: Ergebnis festhalten** – Run-URL und Testzahl im Abschlussbericht nennen.

---

## Abdeckung

| Anforderung / AK | Task | Umfang in diesem Teilplan |
|---|---|---|
| FR-1, AK-1 | 4, 5 | Rechnung; Eingabe-Oberfläche in Teilplan 04 |
| FR-1.1, AK-2 | 4, 5 | vollständig (Logik) |
| FR-1.2, AK-42 | 4, 5, 7 | Zeit an der Stunde, „bis 9:20“ über `time.upperBound`; Anzeige in 04/07, Übernahme aus Quelle in 05 |
| FR-3.3, AK-8 | 6 | Ziel-Stunde; Verschieben der Zuordnung in 02/04 |
| FR-7, AK-14 | 4, 5, 6 | keine Stunden, Ziel für Weiterreichen; „Material ohne Stunde“ in 02/04 |
| FR-8, AK-15 | 5, 6 | Ausfall-Markierung und Ziel; Weiterreichen in 02/04 |
| FR-9, AK-16 | 5 | vollständig (Logik) |
| FR-11.7, AK-36 | 7 | Phase; Bereitlegen/Hausaufgabe (`LessonInfo`) in 02/07 |
| AK-3 | 8 | Abgleich; Vorschau 04/05, Übernahme 02/05 |
| ADR-0005, 0007, 0008, 0009 | 1–9 | Schlüssel, Mindestversion, XcodeGen/Paket, Benennung |

## Abstimmungsbedarf

- **Teilplan 02/04/05:** Zusätzliche Kern-API aus diesem Plan nutzen statt eigene zu bauen –
  `CalendarDay.init(_:calendar:)`, `TimeOfDay.init(_:calendar:)`, `CalendarDay.adding(days:)`,
  `.isoString`, `.weekday`, `NonTeachingPeriod.contains(_:)`, `ImportDiff.isEmpty`.
- **Teilplan 02/05 (Übernahme nach `ImportDiffer`):** Regel „was nicht in `removed` steht, bleibt;
  `manuallyEdited` nie in `removed`/`changed`“. 02 muss je `TimetableEntryRecord` eine Hand-Markierung
  führen, aus der `manuallyEdited` entsteht – Feldname dort festlegen.
- **Teilplan 05:** `Subject` bildet keine Abkürzungen ab („E“ ≠ „Englisch“). Liefert Schulmanager
  Kürzel, braucht 05 eine Zuordnung vor dem Abgleich – sonst erzeugt ein Import lauter `changed`.
- **Teilplan 02:** `LessonKey.storageText`-Format (Task 3) ist das gespeicherte Feld jeder Zuordnung –
  nicht ändern, ohne Migration.
- **Teilpläne 02/03/06/07:** Berechtigungen und Entitlements (iCloud/CloudKit, App-Sandbox mit
  Dateizugriff, Kamera, StoreKit-Konfiguration) werden in `project.yml` an den Zielen ergänzt, nicht im
  erzeugten Projekt.
- **Teilplan 04:** TestFlight-Bau ergänzt `ci.yml` um Signieren mit `APPLE_TEAM_ID`/`BUNDLE_ID_PREFIX`.

## Annahmen, die ein Mensch bestätigen sollte

- **A1 — „Nächste Stunde“ heißt gleiche Klasse *und* gleiches Fach** (Übersicht). FR-3.3 und FR-8
  sagen nur „derselben Klasse“; unterrichtet die Lehrkraft eine Klasse in zwei Fächern, wandert
  Englisch-Material sonst in die Mathestunde.
- **A2 — An unterrichtsfreien Tagen erscheinen auch Vertretungsstunden nicht** (Übersicht: „leer an
  unterrichtsfreien Tagen“).
- **A3 — Vertretungsstunden zählen bei der laufenden Nummer hinter den Stunden aus dem Stundenplan.**
  Folge: Eine Vertretung um 1. Stunde und die reguläre 2. Stunde derselben Klasse im selben Fach
  haben Nummer 2 bzw. 1 – stabil, aber nicht zeitlich.
- **A4 — Klassenbildschirm übergeht Stunden ohne Zeit im Zeitraster**; fehlt das Zeitraster ganz,
  zeigt er immer „kein Unterricht mehr“ (nur Uhrzeit und Datum).
- **A5 — Der erste CI-Lauf** braucht entweder `ci.yml` auf `main` oder ein Tag `v0.0.0-ci.1` (Task 10).
- **A6 — Beide App-Ziele tragen dieselbe Bundle-ID** (gemeinsamer Kauf über Plattformen, FR-13).
