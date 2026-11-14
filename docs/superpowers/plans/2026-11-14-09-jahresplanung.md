# Frontstage — Teilplan 09: Jahresplanung je Fach, Jahrgang und Schuljahr

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.
> Rahmen: `docs/superpowers/plans/2026-11-13-00-uebersicht.md` – gilt vollständig und geht diesem Teilplan vor.

**Goal:** Die Lehrkraft plant je Fach, Jahrgang und Schuljahr vor, in welcher Unterrichtswoche welches Thema dran ist und wann Tests und Klassenarbeiten geschrieben werden, mit Notizen (FR-15 bis FR-15.6, ADR-0013); sie sieht frühere Jahre nebeneinander, übernimmt den Vorjahresplan, und Vorbereiten und Tagesansicht zeigen Wochenthema und Leistungsnachweise an den Unterrichtsstunden.

**Architecture:** Alle Regeln sind reine Logik im Kern (`Packages/FrontstageCore/Sources/FrontstageCore/CoursePlan/`): ISO-Woche, Schuljahr und Halbjahr, Jahrgang aus dem Klassennamen, Unterrichtswochen eines Schuljahrs, Zuordnung der Einträge zu Wochen samt „nicht zugeordnet“, Übernahme des Vorjahresplans, frühere Jahre und Vergleich, Hinweis zur Unterrichtsstunde, Zusammenführen nach dem Abgleich, Datensatz-Inhalte für den Datenordner – lokal mit `scripts\swift-test.ps1` getestet. Die App speichert vier neue SwiftData-Records, übersetzt sie für den OneDrive-Abgleich (`RecordCodec`), bietet `DataStore`-Methoden, zeigt Einrichten › Schuljahr, einen neuen Hauptbereich „Jahresplan“ (iPad und Mac über dieselbe `TabView`) mit Wochenliste je Halbjahr und Vergleich früherer Jahre, und hängt Hinweise in Tagesansicht und Vorbereiten ein.

**Tech Stack:** Swift 6 strikt, SwiftData, SwiftUI (Systemstandard), Swift Testing, XcodeGen. Keine neue Abhängigkeit.

**Spec:** `docs/PRD.md` (FR-15 bis FR-15.6, AK-45 bis AK-51, RISK-10, Q-35, Q-36, Glossar „Schuljahr“ `SchoolYear`, „Halbjahr“ `Term`, „Unterrichtswoche“ `TeachingWeek`, „Jahrgang“ `GradeLevel`, „Jahresplan“ `CoursePlan`, „Planwoche“ `PlanWeek`, „Leistungsnachweis“ `Assessment` mit `test`/`classTest`), `docs/adr/0013-jahresplan-je-fach-jahrgang-und-schuljahr.md`, `docs/ARCHITECTURE.md` (Area daten: Datenmodell, Abschnitt „Jahresplanung“, Nebenläufigkeit), `docs/adr/0012-datenort-icloud-oder-onedrive-nativ.md` (jede Modelländerung in beiden Abgleichwegen).

**Baut auf (Code auf `main`):** Teilplan 01 (`CalendarDay` mit `dayNumber`, `adding(days:)`, `weekday`, `mondayOfWeek`, `storageText`, `init?(storageText:)`; `SchoolClass.normalized`; `Subject` mit `normalized`/`display`, Gleichheit nur über `normalized`; `NonTeachingPeriod.contains(_:)`; `LessonKey`; `Lesson` mit `isCancelled`), 02 (`DataStore` mit `saveAndBump()`, `applyExternalChanges(_:)`, `timetable()`, `nonTeachingPeriods()`, `setLessonInfo(_:for:)`; `ModelContainerFactory.modelTypes`; `DataStore.mergeDuplicates()` in `DataStore+Merge.swift` mit `LoadedRecords`; Test-Hilfe `makeStore()`), 04 (`AppSection`, `RootView` mit `TabView(.sidebarAdaptable)` und `scoped { … }`, `SetupView`, `ScopedAppContent`, `AppEnvironment`, `PreparationStore`, `DayViewModel.content(for:store:storage:)`, `LessonRow`, `DayRowView`/`LessonRowView`, `PreparationView`, `LessonDetailView` mit `LessonInfoEditor`, `Localizable.xcstrings`, `\.showSetup`), 08 (`SyncModel`, `RecordPayload`, `RecordCodec` mit `exportAll`/`export(_:from:)`/`liveIDs`/`upsert`/`delete`, `HasRecordID`, `RecordCodecTests`). **Teilpläne 06 und 07 müssen gemergt sein** (sie ändern `RootView`, `ScopedAppContent` und `DayRowView`); dieser Teilplan läuft danach als eigenes Bündel D.

## Global Constraints

Alle Zeilen der Übersicht gelten (Abschnitt „Global Constraints“, Abstimmung Punkte 1–16). Zusätzlich für diesen Teilplan:

- **Kern zuerst und lokal belegt:** Tasks 1–8 berühren nur `Packages/FrontstageCore` (nur `import Foundation`) und laufen TDD mit `.\scripts\swift-test.ps1 -Filter <Suite>` (RED und GREEN lokal belegen). Tasks 9–15 sind App-Code: auf Windows nicht baubar; „Test ausführen“ heißt dort Task 16 (ein CI-Lauf, startet der Controller). Vor Task 16 `.\scripts\swift-parse.ps1` und Diff-Durchsicht.
- **Begriffe:** Kern-Werttypen ohne Suffix (`SchoolYear`, `Term`, `TeachingWeek`, `GradeLevel`, `CoursePlanKey`, `PlanWeek`, `Assessment`, `AssessmentKind` mit `test`, `classTest`), SwiftData-Klassen mit Suffix `Record` (`SchoolYearRecord`, `CoursePlanRecord`, `PlanWeekRecord`, `AssessmentRecord`). Halbjahre `Term.first`/`.second`. Weitere Namen nur aus den Interfaces-Blöcken unten.
- **iCloud-Regeln (ADR-0002/0012):** kein `@Attribute(.unique)`, kein `#Unique`; jede Eigenschaft optional oder mit Vorgabewert; Beziehungen optional. Eindeutigkeit sichert das Zusammenführen (Task 7, Task 9).
- **Abgleich:** Die vier neuen Records bekommen Inhalt in `RecordPayload` (Task 8) und Übersetzung in `RecordCodec` (Task 9) im selben Teilplan; der Rundlauf-Test in `RecordCodecTests` wird auf zwölf Modelle erweitert (Regel aus Teilplan 08, „Produziert für spätere Teilpläne“).
- **Unterrichtswochen werden nie gespeichert**, nur berechnet (Task 2). Gespeichert wird eine Planwoche über den Montag ihrer Kalenderwoche (`mondayText`), nie über ihre Nummer.
- **Nichts überschreiben, nichts verlieren:** Übernehmen schreibt nie in belegte Wochen (Task 4); Einträge, deren Woche wegfällt, bleiben unter „nicht zugeordnet“ (Task 3); eine Planwoche wird nur gelöscht, wenn Thema und Notizen leer sind; Jahrespläne werden beim Löschen eines Schuljahrs nicht gelöscht.
- **Vorschlag, kein Schreiben:** Das Wochenthema wird nur auf Tipp in `LessonInfo.topic` übernommen (FR-15.5).
- **Freischaltung:** keine (Q-35 offen; bis zur Antwort kostenlos).
- **Gestaltung:** Tasks 11–15 tragen `Design-Takt`; nur Systemstandard (SwiftUI `Form`, `List`, `NavigationSplitView`, `Section`, `LabeledContent`, `DatePicker`, `Picker`, `TextField(axis: .vertical)`), SF-Symbole als Platzhalter. Offene Kategorien (Wochenzeile, Darstellung der Hinweise, Vergleichsansicht, Symbol des Bereichs) im Abschlussbericht nennen, nichts selbst entscheiden.
- **Testdaten:** Klassen `8a`, `8b`, `7a`, `ef`; Fach `Englisch`, `Mathe`; Schuljahr 2026/27 = erster Schultag Mo 14.9.2026, zweites Halbjahr ab Mo 1.2.2027, letzter Schultag Mi 28.7.2027, Herbstferien 2.–6.11.2026, Weihnachtsferien 23.12.2026–9.1.2027 (→ 43 Unterrichtswochen, 17 + 26); Schuljahr 2025/26 = Mo 15.9.2025, 2.2.2026, Mi 29.7.2026, Herbstferien 27.–31.10.2025 (→ 45 Unterrichtswochen); Themen „Unit 1 – Back to school“, „Unit 2 – Past tense“, „Projekt Schulfest“; Leistungsnachweise „KA 1“ (`classTest`), „Vokabeltest Unit 2“ (`test`). Kern-Testhilfen stehen **einmal** in `Packages/FrontstageCore/Tests/FrontstageCoreTests/CoursePlan/CoursePlanFixtures.swift` (`year2026()`, `year2025()`, `holidays2026`, `holidays2025`, `uid(_ n: Int) -> UUID` zwölfstellig wie `id(_:)` in 08 – anderer Name, weil `id(_:)` in den DataFolder-Tests schon existiert; `at(_ n: TimeInterval) -> Date`). `d(_:_:_:)` aus `Fixtures.swift` wird wiederverwendet.

## Entscheidungen dieses Teilplans (mit Begründung)

1. **Schuljahr über `startYear` erkannt** (= `firstDay.year`), ohne Verweis vom Jahresplan auf den Schuljahr-Datensatz. *Grund:* Zusammenführen doppelter Schuljahre bricht dann keinen Verweis; Vergleich über Jahre ist ein Zahlenvergleich (ADR-0013).
2. **Planwoche über den Montag** (`mondayText`, leer = „nicht zugeordnet“). *Grund:* Einträge überstehen Änderungen an Schuljahr und Ferien (FR-15.2, AK-47).
3. **Leistungsnachweis als eigener Datensatz am Jahresplan**, nicht an der Planwoche. *Grund:* Eine Woche kann einen Leistungsnachweis und kein Thema haben; die Planwoche bleibt löschbar, wenn sie leer ist (RISK-10: keine leeren Planwochen speichern).
4. **Hand-Jahrgänge im Schuljahr** (`gradeOverrides: [String: Int]`, Schlüssel `SchoolClass.normalized`). *Grund:* Klassennamen ohne Ziffern gelten pro Schuljahr; ein eigenes Modell wäre ein fünfter Record für eine Handvoll Werte. Die Ableitung aus Ziffern hat Vorrang; die Hand-Zuordnung wird nur für Klassen ohne Ziffern angeboten (FR-15).
5. **Vergleich und Übernahme zählen gleich** – Woche n ab Beginn des Schuljahrs. *Grund:* Was die Lehrkraft im Vergleich in Zeile n sieht, landet beim Übernehmen in Woche n. *Verworfen:* Ausrichtung je Halbjahr – passt besser zu Klassenarbeiten je Halbjahr, widerspricht aber der Zählung beim Übernehmen.
6. **Ein Hinweis zur Unterrichtsstunde wird berechnet und nie gespeichert** (`LessonPlanHinter`, Task 6); Vorbereiten lädt ihn mit den Zeilen (`LessonRow.planHint`), die Tagesansicht ebenso, weil beide `DayViewModel.content(for:store:storage:)` nutzen.
7. **Neuer Hauptbereich `AppSection.coursePlan`** zwischen Vorbereiten und Einrichten. *Grund:* Jahresplanung ist eine eigene Tätigkeit neben dem Wochen-Vorbereiten; über die vorhandene `TabView(.sidebarAdaptable)` erscheint er am iPad als Tab bzw. Seitenleiste, am Mac in der Seitenleiste – ohne eigenen Navigationscode je Plattform.
8. **Zusammenführen der Jahrespläne getrennt** vom bestehenden `SyncMerger` (`CoursePlanMerger`, Task 7), aufgerufen in `mergeDuplicates()`. *Grund:* `SyncMerger` und `SyncSnapshot` bleiben unverändert (fertiger, getesteter Code aus 02); RISK-10 verlangt ohnehin getrenntes Zusammenführen.

## Review Focus

1. **Woche fällt nach Änderung der Ferien oder Schuljahresdaten weg** → Thema, Notizen und Leistungsnachweise stehen unter „nicht zugeordnet“, nichts verschwindet; Zuweisen an eine neue Woche behält den Wochentag, wenn er dort Unterrichtstag ist. Tests: Task 3 `orphanedWeekBecomesUnassigned`, `assignKeepsWeekdayWhenTeaching`, `assignDropsDayWhenNotTeaching`; Task 10 `holidayChangeKeepsEntries`.
2. **Zwei Geräte legen denselben Jahresplan bzw. dieselbe Woche an** (offline am Mac und am iPad) → nach dem Abgleich ein Plan, keine Planwoche doppelt, der zuletzt geänderte Inhalt gilt, kein Leistungsnachweis verloren. Tests: Task 7 `duplicatePlansKeepOldestAndMoveChildren`, `duplicateWeeksTakeLatestContent`; Task 9 `mergeDuplicatesCollapsesCoursePlans`.
3. **Schuljahr beginnt nicht am Montag oder Halbjahreswechsel mitten in der Woche** → Woche 1 beginnt mit dem Montag vor dem ersten Schultag und zählt nur die Unterrichtstage ab dem ersten Schultag; die Woche des Wechsels gehört zum Halbjahr ihres ersten Unterrichtstags. Tests: Task 2 `midweekStartCountsFromFirstDay`, `termOfSplitWeekFollowsFirstTeachingDay`.
4. **Fach im Stundenplan anders geschrieben oder Klasse ohne Ziffern** → „englisch“/„Englisch “ finden den Plan „Englisch“ (Normalisierung); „EF“ ohne Hand-Jahrgang bekommt keinen Hinweis statt eines falschen; mit Hand-Jahrgang 11 den Plan des Jahrgangs 11. Tests: Task 1 `gradeFromFirstDigitRun`, Task 6 `subjectMatchesNormalized`, `classWithoutDigitsUsesOverrideOrNothing`.
5. **Übernehmen in ein kürzeres Schuljahr oder in teils gefüllte Wochen** → nichts überschrieben, Überzähliges unter „nicht zugeordnet“ in Wochenreihenfolge, gleiche Leistungsnachweise nicht doppelt, zweimal übernehmen erzeugt keine Dubletten. Tests: Task 4 `overflowGoesToUnassignedInOrder`, `occupiedTargetWeekKeepsOwnContent`, `copyingTwiceAddsNoDuplicateAssessments`.

---

## Dateistruktur

| Datei | Verantwortung | Task |
|---|---|---|
| `Packages/FrontstageCore/Sources/FrontstageCore/CoursePlan/ISOWeek.swift`, `SchoolYear.swift`, `GradeLevel.swift` | ISO-Woche, Schuljahr, Halbjahr, Prüfung, Jahrgang | 1 |
| `…/CoursePlan/TeachingWeekCalculator.swift` | Unterrichtswochen eines Schuljahrs | 2 |
| `…/CoursePlan/CoursePlanValues.swift`, `PlanLayouter.swift` | Planwoche, Leistungsnachweis, Schlüssel; Wochenliste und „nicht zugeordnet“ | 3 |
| `…/CoursePlan/CoursePlanCopier.swift` | Vorjahresplan übernehmen | 4 |
| `…/CoursePlan/CoursePlanHistory.swift` | frühere Jahre, Vergleich nebeneinander | 5 |
| `…/CoursePlan/LessonPlanHinter.swift` | Hinweis zur Unterrichtsstunde, Leistungsnachweise der Woche | 6 |
| `…/CoursePlan/CoursePlanMerger.swift` | Zusammenführen nach dem Abgleich | 7 |
| `…/DataFolder/SyncModel.swift`, `RecordPayload.swift` (ändern), `…/DataFolder/CoursePlanPayloads.swift` | Dateiformat der neuen Modelle | 8 |
| `Packages/FrontstageCore/Tests/FrontstageCoreTests/CoursePlan/*Tests.swift`, `CoursePlanFixtures.swift`; `…/DataFolder/RecordFormatTests.swift` (ändern) | Kern-Tests | 1–8 |
| `Frontstage/Data/Records/SchoolYearRecord.swift`, `CoursePlanRecord.swift`, `PlanWeekRecord.swift`, `AssessmentRecord.swift`, `Frontstage/Data/CoursePlanRecordConversion.swift`; `ModelContainerFactory.swift`, `Folder/RecordCodec.swift`, `DataStore+Merge.swift` (ändern) | Records, Schema, Abgleich, Zusammenführen | 9 |
| `Frontstage/Data/DataStore+CoursePlans.swift`, `Frontstage/UI/CoursePlan/CoursePlanStore.swift` | Datenzugriff | 10 |
| `Frontstage/UI/Setup/SchoolYearSettingsModel.swift`, `SchoolYearSettingsView.swift`; `SetupView.swift` (ändern) | Einrichten › Schuljahr | 11 |
| `Frontstage/UI/CoursePlan/CoursePlanListModel.swift`, `CoursePlanEditorModel.swift`, `PlanWeekEditor.swift` | Logik des Bereichs Jahresplan | 12 |
| `Frontstage/UI/CoursePlan/CoursePlanScreen.swift`, `CoursePlanView.swift`, `PlanWeekSheet.swift`, `NewCoursePlanSheet.swift`; `App/AppSection.swift`, `App/RootView.swift` (ändern) | Oberfläche Jahresplan, Navigation | 13 |
| `Frontstage/UI/CoursePlan/CoursePlanComparisonModel.swift`, `CoursePlanComparisonView.swift` | Frühere Jahre nebeneinander | 14 |
| `Frontstage/UI/Preparation/PreparationStore.swift`, `UI/Shared/LessonRow.swift`, `UI/DayView/DayViewModel.swift`, `UI/DayView/DayRowView.swift`, `UI/Preparation/PreparationView.swift`, `UI/Preparation/LessonDetailView.swift`, `UI/Preparation/PreparationViewModel.swift` (ändern), `UI/Shared/PlanHintLabel.swift` | Hinweise in Tagesansicht und Vorbereiten | 15 |
| `FrontstageTests/Data/CoursePlanStoreTests.swift`, `FrontstageTests/UI/*CoursePlan*Tests.swift`, `FrontstageTests/UI/SchoolYearSettingsModelTests.swift`, `FrontstageTests/UI/PlanHintTests.swift`; `FrontstageTests/Data/Folder/RecordCodecTests.swift`, `FrontstageTests/Data/RecordSchemaTests.swift` (ändern) | App-Tests (Simulator) | 9–15 |
| `Frontstage/Resources/Localizable.xcstrings` (ändern) | Texte | 11–15 |

---

### Task 1: ISO-Woche, Schuljahr, Halbjahr, Jahrgang

Design-Takt: keiner

**Files:**
- Create: `Packages/FrontstageCore/Sources/FrontstageCore/CoursePlan/ISOWeek.swift`, `SchoolYear.swift`, `GradeLevel.swift`
- Create: `Packages/FrontstageCore/Tests/FrontstageCoreTests/CoursePlan/CoursePlanFixtures.swift`, `SchoolYearTests.swift`

**Interfaces:**
- Consumes: `CalendarDay` (`dayNumber`, `weekday`, `mondayOfWeek`, `adding(days:)`), `SchoolClass.normalized` (Teilplan 01)
- Produces:

```swift
/// Kalenderwoche nach ISO 8601 (Woche beginnt Montag; Woche 1 enthält den ersten Donnerstag des Jahres).
public struct ISOWeek: Hashable, Comparable, Codable, Sendable {
  public let year: Int; public let week: Int
  public init(year: Int, week: Int)
}
extension CalendarDay { public var isoWeek: ISOWeek { get } }

/// Halbjahr (Glossar).
public enum Term: String, Codable, Sendable, CaseIterable { case first, second }

/// Schuljahr (Glossar, ADR-0013). Kennung ist `startYear`.
public struct SchoolYear: Hashable, Codable, Sendable {
  public var firstDay: CalendarDay
  public var secondTermStart: CalendarDay   // erster Tag des zweiten Halbjahrs
  public var lastDay: CalendarDay
  /// Jahrgang von Hand je Klasse (Schlüssel `SchoolClass.normalized`), nur für Klassen ohne Ziffern.
  public var gradeOverrides: [String: Int]
  public init(firstDay: CalendarDay, secondTermStart: CalendarDay, lastDay: CalendarDay, gradeOverrides: [String: Int] = [:])
  public var startYear: Int { get }          // firstDay.year
  public var title: String { get }           // "2026/27"
  public func contains(_ day: CalendarDay) -> Bool
  public func term(of day: CalendarDay) -> Term?   // nil außerhalb
}

public enum SchoolYearIssue: Hashable, Sendable { case lastDayBeforeFirstDay, secondTermOutside, overlaps(startYear: Int) }
extension SchoolYear {
  /// Prüft gegen die übrigen Schuljahre; ein Schuljahr mit gleichem `startYear` in `others` zählt nicht (wird ersetzt).
  public func issue(among others: [SchoolYear]) -> SchoolYearIssue?
}

/// Jahrgang (Glossar), 1...13.
public struct GradeLevel: Hashable, Comparable, Codable, Sendable {
  public let value: Int
  public init?(_ value: Int)
  /// Erste Ziffernfolge in `normalized` („8b“ → 8, „q11“ → 11); ohne Ziffern oder außerhalb 1...13 → nil.
  public static func derived(from schoolClass: SchoolClass) -> GradeLevel?
  /// Abgeleitet, sonst `overrides[schoolClass.normalized]`, sonst nil.
  public static func resolve(_ schoolClass: SchoolClass, overrides: [String: Int]) -> GradeLevel?
}
```

ISO-Woche: Donnerstag derselben Woche bestimmen (`mondayOfWeek.adding(days: 3)`); dessen Jahr ist das ISO-Jahr, Woche = (Tag im Jahr des Donnerstags − 1) / 7 + 1 – über `dayNumber`, ohne `Calendar`.

- [ ] **Step 1: Fixtures und failing Tests schreiben** (`@Suite("CoursePlan SchoolYear")`)

```swift
@Test("ISO-Woche: Jahreswechsel und KW 53")
func isoWeeks() {
  #expect(d(2026, 9, 14).isoWeek == ISOWeek(year: 2026, week: 38))
  #expect(d(2027, 1, 1).isoWeek == ISOWeek(year: 2026, week: 53))
  #expect(d(2026, 1, 1).isoWeek == ISOWeek(year: 2026, week: 1))
  #expect(d(2024, 12, 30).isoWeek == ISOWeek(year: 2025, week: 1))
  #expect(d(2027, 2, 7).isoWeek == ISOWeek(year: 2027, week: 5))   // Sonntag gehört zur laufenden Woche
}

@Test("FR-15.1: Schuljahr 2026/27 – Titel, Halbjahre, Grenzen")
func schoolYearBasics() {
  let y = year2026()   // 14.9.2026, 1.2.2027, 28.7.2027
  #expect(y.startYear == 2026 && y.title == "2026/27")
  #expect(y.term(of: d(2027, 1, 29)) == .first && y.term(of: d(2027, 2, 1)) == .second)
  #expect(y.term(of: d(2026, 9, 13)) == nil && y.term(of: d(2027, 7, 29)) == nil)
  #expect(SchoolYear(firstDay: d(2099, 9, 1), secondTermStart: d(2100, 2, 1), lastDay: d(2100, 7, 1)).title == "2099/00")
}

@Test("Prüfung: Reihenfolge der Daten und Überschneidung")
func schoolYearIssues() {
  #expect(SchoolYear(firstDay: d(2026, 9, 14), secondTermStart: d(2027, 2, 1), lastDay: d(2026, 9, 1)).issue(among: []) == .lastDayBeforeFirstDay)
  #expect(SchoolYear(firstDay: d(2026, 9, 14), secondTermStart: d(2027, 8, 1), lastDay: d(2027, 7, 28)).issue(among: []) == .secondTermOutside)
  #expect(SchoolYear(firstDay: d(2027, 7, 1), secondTermStart: d(2028, 2, 1), lastDay: d(2028, 7, 1)).issue(among: [year2026()]) == .overlaps(startYear: 2026))
  #expect(year2026().issue(among: [year2026(), year2025()]) == nil)   // gleiches startYear wird ersetzt
}

@Test("FR-15: Jahrgang aus der ersten Ziffernfolge")
func gradeFromFirstDigitRun() {
  #expect(GradeLevel.derived(from: SchoolClass("8b"))?.value == 8)
  #expect(GradeLevel.derived(from: SchoolClass("10 a"))?.value == 10)
  #expect(GradeLevel.derived(from: SchoolClass("Q11"))?.value == 11)
  #expect(GradeLevel.derived(from: SchoolClass("EF")) == nil)
  #expect(GradeLevel.derived(from: SchoolClass("K14")) == nil)   // außerhalb 1...13
}

@Test("Hand-Jahrgang nur, wo nichts abgeleitet wird")
func gradeOverrides() {
  #expect(GradeLevel.resolve(SchoolClass("EF"), overrides: ["ef": 11])?.value == 11)
  #expect(GradeLevel.resolve(SchoolClass("8b"), overrides: ["8b": 9])?.value == 8)
  #expect(GradeLevel.resolve(SchoolClass("EF"), overrides: [:]) == nil)
}
```

- [ ] **Step 2: Rot belegen** – `.\scripts\swift-test.ps1 -Filter "CoursePlan SchoolYear"` → Fehler „cannot find 'ISOWeek' in scope“.
- [ ] **Step 3: Implementieren** (Dateien und Signaturen oben; `title` mit `String(format: "%d/%02d", startYear, (startYear + 1) % 100)`).
- [ ] **Step 4: Grün belegen** – dieselbe Suite, danach das ganze Paket.
- [ ] **Step 5: Commit** – `git commit -m "core: add ISO week, school year, term and grade level"`

---

### Task 2: Unterrichtswochen eines Schuljahrs (FR-15.1)

Design-Takt: keiner

**Files:**
- Create: `Packages/FrontstageCore/Sources/FrontstageCore/CoursePlan/TeachingWeekCalculator.swift`
- Test: `Packages/FrontstageCore/Tests/FrontstageCoreTests/CoursePlan/TeachingWeekTests.swift`

**Interfaces:**
- Consumes: `SchoolYear`, `ISOWeek`, `Term` (Task 1); `NonTeachingPeriod.contains(_:)` (01)
- Produces:

```swift
/// Unterrichtswoche (Glossar): ISO-Woche im Schuljahr mit mindestens einem Unterrichtstag.
public struct TeachingWeek: Hashable, Sendable {
  public let number: Int               // 1, 2, … ab Beginn des Schuljahrs
  public let monday: CalendarDay
  public let isoWeek: ISOWeek
  public let term: Term                // Halbjahr des ersten Unterrichtstags
  public let teachingDays: [CalendarDay]   // aufsteigend
  public init(number:monday:isoWeek:term:teachingDays:)
}
public enum TeachingWeekCalculator {
  /// Unterrichtstag: Montag bis Freitag, im Schuljahr, in keinem unterrichtsfreien Zeitraum.
  public static func isTeachingDay(_ day: CalendarDay, in year: SchoolYear, nonTeachingPeriods: [NonTeachingPeriod]) -> Bool
  public static func weeks(of year: SchoolYear, nonTeachingPeriods: [NonTeachingPeriod]) -> [TeachingWeek]
}
```

- [ ] **Step 1: Failing Tests schreiben** (`@Suite("CoursePlan TeachingWeeks")`)

```swift
@Test("AK-46: 2026/27 hat 43 Unterrichtswochen, 17 + 26")
func schoolYear2026() {
  let weeks = TeachingWeekCalculator.weeks(of: year2026(), nonTeachingPeriods: holidays2026)
  #expect(weeks.count == 43)
  #expect(weeks.filter { $0.term == .first }.count == 17 && weeks.filter { $0.term == .second }.count == 26)
  #expect(weeks[0].number == 1 && weeks[0].monday == d(2026, 9, 14) && weeks[0].isoWeek == ISOWeek(year: 2026, week: 38))
  #expect(!weeks.contains { [d(2026, 11, 2), d(2026, 12, 28), d(2027, 1, 4)].contains($0.monday) })
  #expect(weeks[13].monday == d(2026, 12, 21) && weeks[13].teachingDays == [d(2026, 12, 21), d(2026, 12, 22)])
  #expect(weeks[17].number == 18 && weeks[17].monday == d(2027, 2, 1) && weeks[17].term == .second)
  #expect(weeks.last?.teachingDays == [d(2027, 7, 26), d(2027, 7, 27), d(2027, 7, 28)])
}

@Test("2025/26 hat 45 Unterrichtswochen") func schoolYear2025()        // year2025(), holidays2025 → count 45; Woche 8 = Montag 10.11.2025

@Test("Beginn am Mittwoch: Woche 1 zählt ab dem ersten Schultag")
func midweekStartCountsFromFirstDay()     // erster Schultag Mi 16.9.2026 → weeks[0].monday == 14.9., teachingDays == [16., 17., 18.9.]

@Test("Woche des Halbjahreswechsels gehört zum Halbjahr ihres ersten Unterrichtstags")
func termOfSplitWeekFollowsFirstTeachingDay()  // zweites Halbjahr ab Mi 3.2.2027 → Woche mit Montag 1.2. hat term .first; mit Mo 1.2. frei und Di 2.2. Beginn → .second

@Test("Wochenende und Zeiträume außerhalb des Schuljahrs zählen nicht")
func weekendsAndOutsideDays()             // isTeachingDay: Sa 19.9.2026 false, Mo 2.11.2026 false, So 13.9.2026 false, Di 15.9.2026 true
```

- [ ] **Step 2: Rot belegen** – `.\scripts\swift-test.ps1 -Filter "CoursePlan TeachingWeeks"`.
- [ ] **Step 3: Implementieren** – Tage von `firstDay.mondayOfWeek` bis `lastDay` in 7er-Schritten; je Woche die Unterrichtstage sammeln, leere Wochen auslassen, fortlaufend nummerieren.
- [ ] **Step 4: Grün belegen.**
- [ ] **Step 5: Commit** – `git commit -m "core: compute teaching weeks of a school year"`

---

### Task 3: Planwochen, Leistungsnachweise, Wochenliste und „nicht zugeordnet“ (FR-15.2)

Design-Takt: keiner

**Files:**
- Create: `Packages/FrontstageCore/Sources/FrontstageCore/CoursePlan/CoursePlanValues.swift`, `PlanLayouter.swift`
- Test: `Packages/FrontstageCore/Tests/FrontstageCoreTests/CoursePlan/PlanLayoutTests.swift`

**Interfaces:**
- Consumes: `TeachingWeek` (Task 2), `GradeLevel` (Task 1), `Subject` (01)
- Produces:

```swift
public enum AssessmentKind: String, Codable, Sendable, CaseIterable { case test, classTest }

/// Schlüssel eines Jahresplans (ADR-0013): Fach (normalisiert verglichen) + Jahrgang + Schuljahr.
public struct CoursePlanKey: Hashable, Codable, Sendable {
  public let subject: Subject; public let gradeLevel: GradeLevel; public let startYear: Int
  public init(subject:gradeLevel:startYear:)
}

/// Planwoche (Glossar); `monday == nil` heißt „nicht zugeordnet“.
public struct PlanWeek: Hashable, Sendable {
  public var id: UUID; public var monday: CalendarDay?; public var position: Int
  public var topic: String?; public var notes: String?; public var updatedAt: Date
  public init(id:monday:position:topic:notes:updatedAt:)   // topic/notes normalisiert wie LessonInfo (getrimmt, leer → nil)
  public var isEmpty: Bool { get }
}

/// Leistungsnachweis (Glossar).
public struct Assessment: Hashable, Sendable {
  public var id: UUID; public var monday: CalendarDay?; public var day: CalendarDay?
  public var kind: AssessmentKind; public var title: String; public var updatedAt: Date
  public init(id:monday:day:kind:title:updatedAt:)
}

public struct PlanLayoutWeek: Hashable, Sendable {
  public let week: TeachingWeek; public let planWeek: PlanWeek?; public let assessments: [Assessment]
}
public struct PlanLayout: Hashable, Sendable {
  public let first: [PlanLayoutWeek]; public let second: [PlanLayoutWeek]
  public let unassignedWeeks: [PlanWeek]; public let unassignedAssessments: [Assessment]
}
public enum PlanLayouter {
  public static func layout(weeks: [TeachingWeek], planWeeks: [PlanWeek], assessments: [Assessment]) -> PlanLayout
  /// Zuweisen: setzt `monday`; der Tag bleibt als gleicher Wochentag, wenn der in `week` Unterrichtstag ist, sonst nil.
  public static func assign(_ assessment: Assessment, to week: TeachingWeek) -> Assessment
  public static func isValidDay(_ day: CalendarDay, for week: TeachingWeek) -> Bool   // week.teachingDays.contains(day)
}
```

Regeln für `layout`: Planwoche und Leistungsnachweis gehören zu der Woche, deren `monday` gleich ist. Mehrere Planwochen mit gleichem Montag (vor dem Zusammenführen): die zuletzt geänderte steht in der Woche, die übrigen unter „nicht zugeordnet“. „Nicht zugeordnet“ = `monday == nil` (nach `position`) und danach Montage ohne Unterrichtswoche (nach Datum). Leistungsnachweise je Woche: mit Tag aufsteigend, dann ohne Tag, dann nach Titel; ein Leistungsnachweis mit Tag, der kein Unterrichtstag der Woche mehr ist, bleibt in der Woche und behält den Tag (die Oberfläche markiert ihn nicht – offene Kategorie).

- [ ] **Step 1: Failing Tests schreiben** (`@Suite("CoursePlan Layout")`)

```swift
@Test("AK-47: Einträge in Woche 8, getrennt nach Halbjahren")
func entriesLandInTheirWeek() {
  let weeks = TeachingWeekCalculator.weeks(of: year2026(), nonTeachingPeriods: holidays2026)
  let week = PlanWeek(id: uid(1), monday: d(2026, 11, 9), position: 0, topic: "Unit 2 – Past tense", notes: "8b: Hörverstehen nachholen", updatedAt: at(1))
  let ka = Assessment(id: uid(2), monday: d(2026, 11, 9), day: d(2026, 11, 10), kind: .classTest, title: "KA 1", updatedAt: at(1))
  let test = Assessment(id: uid(3), monday: d(2026, 11, 9), day: nil, kind: .test, title: "Vokabeltest Unit 2", updatedAt: at(1))
  let layout = PlanLayouter.layout(weeks: weeks, planWeeks: [week], assessments: [test, ka])
  #expect(layout.first.count == 17 && layout.second.count == 26)
  #expect(layout.first[7].planWeek == week && layout.first[7].assessments == [ka, test])
  #expect(layout.unassignedWeeks.isEmpty && layout.unassignedAssessments.isEmpty)
}

@Test("AK-47: Woche fällt weg → nicht zugeordnet")
func orphanedWeekBecomesUnassigned()   // holidays2026 + 9.–13.11.2026: Planwoche und beide Leistungsnachweise in unassigned…; first[7].week.monday == 16.11.2026

@Test("Nicht zugeordnet: erst ohne Montag nach Position, dann verwaiste nach Datum")
func unassignedOrder()

@Test("Doppelte Planwoche: die zuletzt geänderte steht in der Woche")
func duplicateWeekShowsLatest()

@Test("Zuweisen behält den Wochentag, wenn er Unterrichtstag ist")
func assignKeepsWeekdayWhenTeaching()  // Di 10.11.2026 → Woche ab 16.11. → day 17.11.2026

@Test("Zuweisen verliert den Tag, wenn er nicht Unterrichtstag ist")
func assignDropsDayWhenNotTeaching()   // Mi → Woche 14 (nur Mo, Di) → day nil

@Test("Leere Texte werden nil; isEmpty") func planWeekNormalizes()   // topic "  " → nil, notes "" → nil → isEmpty
```

- [ ] **Step 2: Rot belegen** – `.\scripts\swift-test.ps1 -Filter "CoursePlan Layout"`.
- [ ] **Step 3: Implementieren.**
- [ ] **Step 4: Grün belegen.**
- [ ] **Step 5: Commit** – `git commit -m "core: lay out plan weeks and assessments by teaching week"`

---

### Task 4: Vorjahresplan übernehmen (FR-15.4)

Design-Takt: keiner

**Files:**
- Create: `Packages/FrontstageCore/Sources/FrontstageCore/CoursePlan/CoursePlanCopier.swift`
- Test: `Packages/FrontstageCore/Tests/FrontstageCoreTests/CoursePlan/CoursePlanCopierTests.swift`

**Interfaces:**
- Consumes: `TeachingWeek` (2), `PlanWeek`, `Assessment`, `PlanLayouter.assign` (3)
- Produces:

```swift
/// Neu anzulegende Einträge im Ziel; der Quellplan bleibt unberührt.
public struct CopyResult: Equatable, Sendable {
  public var planWeeks: [PlanWeek]          // neue ids; monday nil = nicht zugeordnet
  public var assessments: [Assessment]
  public var planNote: String?              // nur gesetzt, wenn das Ziel keine Notiz hat
  public var unassignedCount: Int { get }   // planWeeks + assessments mit monday == nil
}
public enum CoursePlanCopier {
  public static func copy(
    sourceWeeks: [TeachingWeek], sourcePlanWeeks: [PlanWeek], sourceAssessments: [Assessment], sourceNote: String?,
    targetWeeks: [TeachingWeek], targetPlanWeeks: [PlanWeek], targetAssessments: [Assessment], targetNote: String?,
    nextUnassignedPosition: Int, now: Date, makeID: () -> UUID
  ) -> CopyResult
}
```

Regeln (Architecture Doc, „Jahresplanung“): Quellwoche Nummer n → Zielwoche Nummer n. Planwoche: Ziel hat in dieser Woche eine nicht leere Planwoche → neue Planwoche „nicht zugeordnet“; keine Zielwoche n → „nicht zugeordnet“; Quell-Planwochen ohne Unterrichtswoche (Montag nil oder verwaist) → „nicht zugeordnet“. Positionen ab `nextUnassignedPosition` fortlaufend, in Quellreihenfolge (Wochen aufsteigend, dann bisher nicht Zugeordnete nach Position). Leistungsnachweis: Zielwoche n vorhanden → `PlanLayouter.assign` (gleicher Wochentag oder ohne Tag), auch wenn die Woche belegt ist; sonst Montag und Tag nil. Ein Leistungsnachweis, den das Ziel schon gleich hat (Montag, Tag, Art, Titel getrimmt), entfällt. `updatedAt = now` für alles Neue.

- [ ] **Step 1: Failing Tests schreiben** (`@Suite("CoursePlan Copy")`)

```swift
@Test("AK-49: Woche 1 → Woche 1, KA 1 am selben Wochentag, Überzähliges nicht zugeordnet")
func copiesWeekByWeek() {
  let source = TeachingWeekCalculator.weeks(of: year2025(), nonTeachingPeriods: holidays2025)   // 45
  let target = TeachingWeekCalculator.weeks(of: year2026(), nonTeachingPeriods: holidays2026)   // 43
  let sourceWeeks = source.map { PlanWeek(id: uid($0.number), monday: $0.monday, position: 0, topic: "Thema \($0.number)", notes: nil, updatedAt: at(1)) }
  let ka = Assessment(id: uid(100), monday: d(2025, 11, 10), day: d(2025, 11, 11), kind: .classTest, title: "KA 1", updatedAt: at(1))
  let own = PlanWeek(id: uid(200), monday: target[1].monday, position: 0, topic: "Projekt Schulfest", notes: nil, updatedAt: at(2))
  var n = 1000
  let result = CoursePlanCopier.copy(
    sourceWeeks: source, sourcePlanWeeks: sourceWeeks, sourceAssessments: [ka], sourceNote: "Lektüre im 2. Halbjahr",
    targetWeeks: target, targetPlanWeeks: [own], targetAssessments: [], targetNote: nil,
    nextUnassignedPosition: 0, now: at(9), makeID: { n += 1; return uid(n) })
  #expect(result.planWeeks.first { $0.monday == d(2026, 9, 14) }?.topic == "Thema 1")
  #expect(result.assessments == [Assessment(id: result.assessments[0].id, monday: d(2026, 11, 9), day: d(2026, 11, 10), kind: .classTest, title: "KA 1", updatedAt: at(9))])
  #expect(result.planWeeks.filter { $0.monday == nil }.map(\.topic) == ["Thema 2", "Thema 44", "Thema 45"])
  #expect(result.planWeeks.filter { $0.monday == nil }.map(\.position) == [0, 1, 2])
  #expect(!result.planWeeks.contains { $0.monday == target[1].monday })
  #expect(result.planNote == "Lektüre im 2. Halbjahr" && result.unassignedCount == 3)
  #expect(Set(result.planWeeks.map(\.id)).isDisjoint(with: Set(sourceWeeks.map(\.id))))
}

@Test("Belegte Zielwoche behält ihr Thema") func occupiedTargetWeekKeepsOwnContent()
@Test("Überzähliges in Wochenreihenfolge, Positionen ab nextUnassignedPosition") func overflowGoesToUnassignedInOrder()   // nextUnassignedPosition 5 → 5, 6, …
@Test("Zweimal übernehmen legt keinen Leistungsnachweis doppelt an") func copyingTwiceAddsNoDuplicateAssessments()   // zweiter Lauf mit targetAssessments = Ergebnis des ersten → assessments leer
@Test("Ziel mit eigener Notiz behält sie") func targetNoteIsKept()   // planNote == nil
@Test("Leistungsnachweis ohne Zielwoche wird ohne Woche und ohne Tag übernommen") func assessmentWithoutTargetWeekIsUnassigned()
```

- [ ] **Step 2: Rot belegen** – `.\scripts\swift-test.ps1 -Filter "CoursePlan Copy"`.
- [ ] **Step 3: Implementieren.**
- [ ] **Step 4: Grün belegen.**
- [ ] **Step 5: Commit** – `git commit -m "core: copy a previous year's course plan week by week"`

---

### Task 5: Frühere Jahre und Vergleich nebeneinander (FR-15.3)

Design-Takt: keiner

**Files:**
- Create: `Packages/FrontstageCore/Sources/FrontstageCore/CoursePlan/CoursePlanHistory.swift`
- Test: `Packages/FrontstageCore/Tests/FrontstageCoreTests/CoursePlan/CoursePlanHistoryTests.swift`

**Interfaces:**
- Consumes: `CoursePlanKey`, `PlanWeek`, `Assessment`, `PlanLayouter.layout` (3), `TeachingWeek` (2)
- Produces:

```swift
public enum CoursePlanHistory {
  /// Gleiches Fach (normalisiert) und gleicher Jahrgang, kleineres startYear; neuestes zuerst.
  public static func earlier(than key: CoursePlanKey, among keys: [CoursePlanKey]) -> [CoursePlanKey]
}
public struct ComparisonColumn: Sendable {
  public let key: CoursePlanKey; public let weeks: [TeachingWeek]; public let planWeeks: [PlanWeek]; public let assessments: [Assessment]
  public init(key:weeks:planWeeks:assessments:)
}
public struct ComparisonCell: Hashable, Sendable {
  public let week: TeachingWeek; public let topic: String?; public let assessments: [Assessment]
  public let startsSecondTerm: Bool     // erste Woche des zweiten Halbjahrs in dieser Spalte
}
public struct ComparisonRow: Hashable, Sendable { public let number: Int; public let cells: [ComparisonCell?] }   // je Spalte; nil = Jahr hat diese Woche nicht
public enum CoursePlanComparison { public static func rows(_ columns: [ComparisonColumn]) -> [ComparisonRow] }   // 1...max(weeks.count)
```

- [ ] **Step 1: Failing Tests schreiben** (`@Suite("CoursePlan History")`)

```swift
@Test("AK-48: nur gleiches Fach und gleicher Jahrgang, neuestes zuerst")
func earlierYears() {
  let e8 = { (y: Int) in CoursePlanKey(subject: Subject("Englisch"), gradeLevel: GradeLevel(8)!, startYear: y) }
  let keys = [e8(2024), e8(2025), CoursePlanKey(subject: Subject("Englisch"), gradeLevel: GradeLevel(7)!, startYear: 2025),
              CoursePlanKey(subject: Subject("englisch "), gradeLevel: GradeLevel(8)!, startYear: 2023), e8(2027)]
  #expect(CoursePlanHistory.earlier(than: e8(2026), among: keys).map(\.startYear) == [2025, 2024, 2023])
}

@Test("AK-48: Zeile n zeigt Woche n jedes Jahres; kürzeres Jahr hat leere Zellen")
func rowsAlignByWeekNumber()     // 2025/26 (45) und 2026/27 (43): rows.count == 45; rows[44].cells[1] == nil; rows[0].cells[0]?.topic == Thema der Woche 1
@Test("Halbjahresgrenze je Spalte markiert") func marksSecondTermStart()   // 2026/27: nur rows[17].cells[i]?.startsSecondTerm == true
```

- [ ] **Step 2: Rot belegen** – `.\scripts\swift-test.ps1 -Filter "CoursePlan History"`.
- [ ] **Step 3: Implementieren** – Zelle aus `PlanLayouter.layout` je Spalte.
- [ ] **Step 4: Grün belegen.**
- [ ] **Step 5: Commit** – `git commit -m "core: list earlier course plans and align them week by week"`

---

### Task 6: Hinweis zur Unterrichtsstunde (FR-15.5, FR-15.6)

Design-Takt: keiner

**Files:**
- Create: `Packages/FrontstageCore/Sources/FrontstageCore/CoursePlan/LessonPlanHinter.swift`
- Test: `Packages/FrontstageCore/Tests/FrontstageCoreTests/CoursePlan/LessonPlanHintTests.swift`

**Interfaces:**
- Consumes: `SchoolYear`, `GradeLevel.resolve` (1), `CoursePlanKey`, `PlanWeek`, `Assessment` (3), `Lesson`, `LessonKey` (01)
- Produces:

```swift
/// Ein Jahresplan mit seinen Einträgen, wie ihn die Hinweisrechnung braucht.
public struct CoursePlanSnapshotEntry: Sendable {
  public let id: UUID; public let key: CoursePlanKey; public let planWeeks: [PlanWeek]; public let assessments: [Assessment]
  public init(id:key:planWeeks:assessments:)
}
public enum AssessmentTiming: Hashable, Sendable { case onDay, thisWeek }
public struct AssessmentMarker: Hashable, Sendable { public let assessment: Assessment; public let timing: AssessmentTiming }
public struct LessonPlanHint: Hashable, Sendable {
  public let coursePlanID: UUID; public let plannedTopic: String?; public let markers: [AssessmentMarker]   // onDay vor thisWeek
}
/// Leistungsnachweis einer Woche samt Plan, für die Wochenansicht in Vorbereiten.
public struct PlannedAssessment: Hashable, Sendable { public let key: CoursePlanKey; public let assessment: Assessment }
public enum LessonPlanHinter {
  /// nil: Ausfall, kein Schuljahr für das Datum, kein Jahrgang, kein Plan – oder weder Thema noch Leistungsnachweis.
  public static func hint(for lesson: Lesson, schoolYears: [SchoolYear], plans: [CoursePlanSnapshotEntry]) -> LessonPlanHint?
  /// Alle Leistungsnachweise mit diesem Montag, nach Tag (ohne Tag zuletzt), dann Fach, Jahrgang.
  public static func assessments(inWeekOf monday: CalendarDay, plans: [CoursePlanSnapshotEntry]) -> [PlannedAssessment]
}
```

Rechnung: Schuljahr mit `contains(lesson.key.date)` → `GradeLevel.resolve(lesson.key.schoolClass, overrides: year.gradeOverrides)` → Plan mit `key == CoursePlanKey(subject: lesson.key.subject, gradeLevel:, startYear: year.startYear)` (Gleichheit von `Subject` über `normalized`) → Planwoche mit `monday == lesson.key.date.mondayOfWeek` (bei mehreren die zuletzt geänderte) → Leistungsnachweise dieses Montags: `day == date` → `.onDay`, `day == nil` → `.thisWeek`, anderer Tag → nicht dabei. Gibt es zwei Pläne gleichen Schlüssels (vor dem Zusammenführen), gilt der mit der kleineren id.

- [ ] **Step 1: Failing Tests schreiben** (`@Suite("CoursePlan Hint")`)

```swift
@Test("AK-50/AK-51: 8a Englisch am Di 10.11.2026")
func hintForLesson() {
  let hint = LessonPlanHinter.hint(for: lesson(d(2026, 11, 10), "8a", "Englisch"), schoolYears: [year2026()], plans: [english8With(kaOn: d(2026, 11, 10))])
  #expect(hint?.plannedTopic == "Unit 2 – Past tense")
  #expect(hint?.markers.map(\.assessment.title) == ["KA 1", "Vokabeltest Unit 2"])
  #expect(hint?.markers.map(\.timing) == [.onDay, .thisWeek])
}
// lesson(_:_:_:) und english8With(kaOn:) stehen in CoursePlanFixtures.swift

@Test("AK-51: Do 8b sieht nur den Test der Woche") func otherDayShowsOnlyWeekMarker()
@Test("AK-50: 7a Englisch und 8a Mathe bekommen keinen Hinweis") func otherGradeOrSubjectHasNoHint()
@Test("Fach normalisiert: „englisch“ findet „Englisch“") func subjectMatchesNormalized()
@Test("Klasse ohne Ziffern: mit Hand-Jahrgang Plan 11, ohne keiner") func classWithoutDigitsUsesOverrideOrNothing()
@Test("Ausfall und Datum außerhalb jedes Schuljahrs: kein Hinweis") func cancelledOrOutsideHasNoHint()
@Test("Woche ohne Thema und ohne Leistungsnachweis: nil") func emptyWeekIsNil()
@Test("Leistungsnachweise der Woche für Vorbereiten") func weekAssessments()   // assessments(inWeekOf: 9.11.2026) → KA 1, dann Vokabeltest
```

- [ ] **Step 2: Rot belegen** – `.\scripts\swift-test.ps1 -Filter "CoursePlan Hint"`.
- [ ] **Step 3: Implementieren.**
- [ ] **Step 4: Grün belegen.**
- [ ] **Step 5: Commit** – `git commit -m "core: derive course plan hints for lessons"`

---

### Task 7: Zusammenführen nach dem Abgleich (Area daten, Nebenläufigkeit)

Design-Takt: keiner

**Files:**
- Create: `Packages/FrontstageCore/Sources/FrontstageCore/CoursePlan/CoursePlanMerger.swift`
- Test: `Packages/FrontstageCore/Tests/FrontstageCoreTests/CoursePlan/CoursePlanMergerTests.swift`

**Interfaces:**
- Consumes: `CoursePlanKey`, `AssessmentKind` (3)
- Produces:

```swift
public struct CoursePlanMergeSnapshot: Sendable {
  public struct Year: Hashable, Sendable { public var id: UUID; public var startYear: Int; public var createdAt: Date; public init(id:startYear:createdAt:) }
  public struct Plan: Hashable, Sendable { public var id: UUID; public var key: CoursePlanKey; public var createdAt: Date; public init(id:key:createdAt:) }
  public struct Week: Hashable, Sendable { public var id: UUID; public var planID: UUID?; public var monday: CalendarDay?; public var createdAt: Date; public var updatedAt: Date; public init(id:planID:monday:createdAt:updatedAt:) }
  public struct Item: Hashable, Sendable { public var id: UUID; public var planID: UUID?; public var monday: CalendarDay?; public var day: CalendarDay?; public var kind: AssessmentKind; public var title: String; public var createdAt: Date; public init(id:planID:monday:day:kind:title:createdAt:) }
  public var years: [Year]; public var plans: [Plan]; public var weeks: [Week]; public var assessments: [Item]
  public init(years: [Year] = [], plans: [Plan] = [], weeks: [Week] = [], assessments: [Item] = [])
}
public struct CoursePlanMergePlan: Equatable, Sendable {
  public var deletions: Set<UUID> = []
  public var parentChanges: [UUID: UUID] = [:]          // Planwoche/Leistungsnachweis → behaltener Jahresplan
  public var weekContentSources: [UUID: UUID] = [:]     // behaltene Planwoche → Planwoche, deren Thema/Notizen gelten
  public init()
  public var isEmpty: Bool { get }
}
public enum CoursePlanMerger { public static func plan(for snapshot: CoursePlanMergeSnapshot) -> CoursePlanMergePlan }
```

Regeln: „ältester bleibt“ = kleinstes `createdAt`, bei Gleichstand kleinere id (wie `SyncMerger`). (1) Schuljahre gleichen `startYear`: ältestes bleibt, übrige in `deletions`. (2) Jahrespläne gleichen Schlüssels: ältester bleibt; Kinder der übrigen → `parentChanges`; übrige in `deletions`. (3) Planwochen mit gleichem (wirksamer Plan, Montag ≠ nil): älteste bleibt, übrige in `deletions`; ist eine übrige später geändert (`updatedAt`) als die behaltene, `weekContentSources[behalten] = jüngste`. Planwochen ohne Montag werden nie zusammengeführt. (4) Leistungsnachweise mit gleichem (wirksamer Plan, Montag, Tag, Art, Titel getrimmt): ältester bleibt.

- [ ] **Step 1: Failing Tests schreiben** (`@Suite("CoursePlan Merge")`)

```swift
@Test("Doppelter Jahresplan: ältester bleibt, Kinder wandern") func duplicatePlansKeepOldestAndMoveChildren()
  // Plan uid(1) (createdAt at(1)) und uid(2) (at(2)), gleicher Schlüssel Englisch 8 2026; Woche uid(10) an uid(2), Montag 14.9.
  // → deletions == [uid(2)], parentChanges == [uid(10): uid(1)]
@Test("Doppelte Planwoche: älteste bleibt, jüngster Inhalt gilt") func duplicateWeeksTakeLatestContent()
  // Wochen uid(10) (created at(1), updated at(5)) und uid(11) (created at(2), updated at(8)) an uid(1), Montag 14.9.
  // → deletions == [uid(11)], weekContentSources == [uid(10): uid(11)]
@Test("Doppelte Planwoche über zwei doppelte Pläne hinweg wird erkannt") func weeksOfMergedPlansCollapse()
@Test("Nicht zugeordnete Planwochen bleiben alle") func unassignedWeeksAreNeverMerged()
@Test("Gleicher Leistungsnachweis einmal, verschiedene Titel beide") func duplicateAssessments()
@Test("Doppeltes Schuljahr: ältestes bleibt") func duplicateSchoolYears()
@Test("Nichts doppelt → leerer Plan") func nothingToMerge()
```

- [ ] **Step 2: Rot belegen** – `.\scripts\swift-test.ps1 -Filter "CoursePlan Merge"`.
- [ ] **Step 3: Implementieren.**
- [ ] **Step 4: Grün belegen.**
- [ ] **Step 5: Commit** – `git commit -m "core: merge duplicate school years and course plans after sync"`

---

### Task 8: Datensatz-Inhalte für den Datenordner (ADR-0012)

Design-Takt: keiner

**Files:**
- Modify: `Packages/FrontstageCore/Sources/FrontstageCore/DataFolder/SyncModel.swift` – vier Fälle **hinten** anhängen
- Modify: `Packages/FrontstageCore/Sources/FrontstageCore/DataFolder/RecordPayload.swift` – vier Fälle in `RecordPayload`, `model`, `attachments`, `parentID`, `encode(to:)`, `init(from:)`
- Create: `Packages/FrontstageCore/Sources/FrontstageCore/DataFolder/CoursePlanPayloads.swift`
- Modify (Test): `Packages/FrontstageCore/Tests/FrontstageCoreTests/DataFolder/RecordFormatTests.swift`

**Interfaces:**
- Consumes: `RecordPayload`, `SyncModel`, `DataFolderCoding` (08)
- Produces:

```swift
// SyncModel (rawValue = Unterordner): … case boardPage = "BoardPage"
case schoolYear = "SchoolYear", coursePlan = "CoursePlan", planWeek = "PlanWeek", assessment = "Assessment"

public struct SchoolYearPayload: Codable, Hashable, Sendable {
  public var createdAt: Date; public var firstDayText: String; public var secondTermStartText: String; public var lastDayText: String
  public var gradeOverrides: [String: Int]
}
public struct CoursePlanPayload: Codable, Hashable, Sendable {
  public var createdAt: Date; public var subjectText: String; public var gradeLevel: Int; public var startYear: Int; public var notes: String?
}
public struct PlanWeekPayload: Codable, Hashable, Sendable {
  public var createdAt: Date; public var coursePlanID: UUID?; public var mondayText: String?; public var position: Int
  public var topic: String?; public var notes: String?; public var updatedAt: Date
}
public struct AssessmentPayload: Codable, Hashable, Sendable {
  public var createdAt: Date; public var coursePlanID: UUID?; public var mondayText: String?; public var dayText: String?
  public var kindRaw: String; public var title: String; public var updatedAt: Date
}
// je ein öffentlicher Initialisierer mit allen Feldern (Reihenfolge wie oben)
// RecordPayload: case schoolYear(SchoolYearPayload), coursePlan(CoursePlanPayload), planWeek(PlanWeekPayload), assessment(AssessmentPayload)
// parentID: planWeek/assessment → coursePlanID; attachments: keine
```

- [ ] **Step 1: Failing Tests ergänzen** (in `@Suite("DataFolder Format")`)

```swift
@Test("FR-15: Jahresplan-Modelle hin und zurück")
func coursePlanPayloadsRoundTrip() throws   // je Modell eine Hülle mit allen Feldern → encode → decode == Hülle; gradeOverrides ["ef": 11]

@Test("Eltern vor Kindern: Jahresplan vor Planwoche und Leistungsnachweis")
func coursePlanApplyOrder() {
  let order = SyncModel.applyOrder
  #expect(order.firstIndex(of: .coursePlan)! < order.firstIndex(of: .planWeek)!)
  #expect(order.firstIndex(of: .coursePlan)! < order.firstIndex(of: .assessment)!)
  #expect(Array(order.prefix(8)) == [.timetable, .timetableEntry, .nonTeachingPeriod, .scheduleChange, .materialLink, .penNote, .lessonInfo, .boardPage])
}

@Test("parentID der Planwoche und des Leistungsnachweises") func coursePlanParentIDs()
```

- [ ] **Step 2: Rot belegen** – `.\scripts\swift-test.ps1 -Filter "DataFolder Format"`.
- [ ] **Step 3: Implementieren.** Vorhandene Tests der Suite bleiben unverändert grün (die acht alten Fälle behalten Reihenfolge und Namen).
- [ ] **Step 4: Grün belegen**, danach das ganze Paket (auch `DataFolder Layout`: neue Ordnernamen werden über `SyncModel(rawValue:)` erkannt).
- [ ] **Step 5: Commit** – `git commit -m "core: add data folder payloads for school years and course plans"`

---

### Task 9: Records, Schema, `RecordCodec`, Zusammenführen

Design-Takt: keiner

**Files:**
- Create: `Frontstage/Data/Records/SchoolYearRecord.swift`, `CoursePlanRecord.swift`, `PlanWeekRecord.swift`, `AssessmentRecord.swift`, `Frontstage/Data/CoursePlanRecordConversion.swift`
- Modify: `Frontstage/Data/ModelContainerFactory.swift` (`modelTypes` um die vier Typen ergänzen), `Frontstage/Data/Folder/RecordCodec.swift` (Export, `export(_:from:)`-`switch`, `liveIDs`, `upsert`, `delete`, `HasRecordID`), `Frontstage/Data/DataStore+Merge.swift`
- Modify (Test): `FrontstageTests/Data/Folder/RecordCodecTests.swift`, `FrontstageTests/Data/RecordSchemaTests.swift`
- Test: `FrontstageTests/Data/CoursePlanMergeTests.swift`

**Interfaces:**
- Consumes: Payloads (Task 8), `CoursePlanMerger` (Task 7), Kern-Werte (Tasks 1, 3)
- Produces:

```swift
@Model final class SchoolYearRecord {
  var id: UUID = UUID(); var createdAt: Date = Date.now
  var firstDayText: String = ""; var secondTermStartText: String = ""; var lastDayText: String = ""
  var gradeOverridesData: Data?                       // JSON [String: Int]
}
@Model final class CoursePlanRecord {
  var id: UUID = UUID(); var createdAt: Date = Date.now
  var subjectText: String = ""; var gradeLevel: Int = 0; var startYear: Int = 0; var notes: String?
  @Relationship(deleteRule: .cascade, inverse: \PlanWeekRecord.coursePlan) var planWeeks: [PlanWeekRecord]? = []
  @Relationship(deleteRule: .cascade, inverse: \AssessmentRecord.coursePlan) var assessments: [AssessmentRecord]? = []
}
@Model final class PlanWeekRecord {
  var id: UUID = UUID(); var createdAt: Date = Date.now; var coursePlan: CoursePlanRecord?
  var mondayText: String?; var position: Int = 0; var topic: String?; var notes: String?; var updatedAt: Date = Date.now
}
@Model final class AssessmentRecord {
  var id: UUID = UUID(); var createdAt: Date = Date.now; var coursePlan: CoursePlanRecord?
  var mondayText: String?; var dayText: String?; var kindRaw: String = "test"; var title: String = ""; var updatedAt: Date = Date.now
}
// CoursePlanRecordConversion.swift
extension SchoolYearRecord { func makeSchoolYear() -> SchoolYear?; func apply(_ year: SchoolYear) }
extension CoursePlanRecord { var key: CoursePlanKey? { get } }          // nil bei Jahrgang außerhalb 1...13
extension PlanWeekRecord { func makePlanWeek() -> PlanWeek; func apply(_ week: PlanWeek) }
extension AssessmentRecord { func makeAssessment() -> Assessment?; func apply(_ assessment: Assessment) }   // nil bei unbekanntem kindRaw
```

`DataStore.mergeDuplicates()`: zusätzlich `CoursePlanMerger.plan(for:)` aus einem `CoursePlanMergeSnapshot` (alle vier Records, unlesbare übergehen) berechnen; der frühe Ausgang gilt nur, wenn **beide** Pläne leer sind. Anwenden in dieser Reihenfolge: `parentChanges` (Kind an den behaltenen Plan hängen), `weekContentSources` (Thema, Notizen, `updatedAt` übernehmen), dann `deletions` – vor dem Löschen der Pläne, sonst nähme die Kaskade die Kinder mit. Rückgabewert bleibt `MergePlan` aus 02.

- [ ] **Step 1: Failing Tests schreiben**

```swift
// RecordCodecTests: Rundlauf auf zwölf Modelle erweitert
@Test("FR-14/FR-15: Jedes der zwölf Modelle hin und zurück ergibt dieselbe Prüfsumme") func roundTripKeepsHashForEveryModel() throws
@Test("Planwoche und Leistungsnachweis kommen über die Kennung des Jahresplans zurück") func coursePlanChildrenRestoredByParentID() throws
@Test("Löschen eines Jahresplans nimmt Planwochen und Leistungsnachweise mit") func deletingCoursePlanCascades() throws
// RecordSchemaTests: je neuer Record einfügen, speichern, zählen (Schema enthält die vier Typen)
// CoursePlanMergeTests
@MainActor @Suite struct CoursePlanMergeTests {
  @Test("Zwei Jahrespläne Englisch 8 2026 nach dem Abgleich → einer, beide Wochen daran") func mergeDuplicatesCollapsesCoursePlans() throws
  @Test("Gleiche Woche zweimal → eine, Thema der zuletzt geänderten") func mergeDuplicatesTakesLatestWeekContent() throws
  @Test("Nur Jahrespläne doppelt: Zusammenführen läuft trotz leerem MergePlan") func coursePlanMergeRunsWhenTimetableMergeIsEmpty() throws
}
```

- [ ] **Step 2: Diff durchsehen** – jede Eigenschaft je Record hin **und** zurück im Codec; kein `save()` im Codec; Records ohne `.unique`, alle Felder mit Vorgabe oder optional.
- [ ] **Step 3: Implementieren.**
- [ ] **Step 4: Diff durchsehen** (Test läuft in Task 16).
- [ ] **Step 5: Commit** – `git commit -m "data: add school year and course plan records with sync and merge"`

---

### Task 10: `DataStore`-Methoden und `CoursePlanStore`

Design-Takt: keiner

**Files:**
- Create: `Frontstage/Data/DataStore+CoursePlans.swift`, `Frontstage/UI/CoursePlan/CoursePlanStore.swift`
- Test: `FrontstageTests/Data/CoursePlanStoreTests.swift`

**Interfaces:**
- Consumes: Records und Konversion (9); Kern Tasks 1–6; `DataStore.timetable()`, `nonTeachingPeriods()`, `saveAndBump()` (02)
- Produces:

```swift
enum CoursePlanError: Error, Equatable {
  case invalidSchoolYear(SchoolYearIssue), schoolYearMissing(startYear: Int), planMissing(UUID), weekOccupied, dayNotInWeek
}
/// Ein Jahresplan mit Inhalt, als Werte für die Oberfläche.
struct CoursePlanContent: Hashable, Sendable {
  let id: UUID; let key: CoursePlanKey; var notes: String?; var planWeeks: [PlanWeek]; var assessments: [Assessment]
}
struct CoursePlanSummary: Identifiable, Hashable, Sendable { let id: UUID; let key: CoursePlanKey }

@MainActor protocol CoursePlanStore: AnyObject {
  var revision: Int { get }
  func schoolYears() throws -> [SchoolYear]                                   // nach startYear
  func saveSchoolYear(_ year: SchoolYear) throws                              // nach startYear einfügen/ersetzen; Prüfung → invalidSchoolYear
  func removeSchoolYear(startYear: Int) throws                                // Jahrespläne bleiben
  func setGradeOverride(_ grade: GradeLevel?, for schoolClass: SchoolClass, startYear: Int) throws
  func timetableClasses() throws -> [SchoolClass]                             // Klassen des aktiven Stundenplans, sortiert
  func timetableSubjects() throws -> [Subject]
  func teachingWeeks(startYear: Int) throws -> [TeachingWeek]                 // [] ohne Schuljahr
  func coursePlanSummaries() throws -> [CoursePlanSummary]                   // nach startYear absteigend, dann Fach, Jahrgang
  func coursePlan(id: UUID) throws -> CoursePlanContent?
  func createCoursePlan(_ key: CoursePlanKey) throws -> UUID                  // gleicher Schlüssel vorhanden → dessen id
  func setPlanNote(_ notes: String?, planID: UUID) throws
  func savePlanWeek(_ week: PlanWeek, planID: UUID) throws                    // nach id einfügen/ersetzen; leer → löschen
  func assignPlanWeek(id: UUID, to monday: CalendarDay) throws                // Zielwoche mit nicht leerer Planwoche → weekOccupied
  func saveAssessment(_ assessment: Assessment, planID: UUID) throws          // day muss Unterrichtstag der Woche sein → sonst dayNotInWeek
  func removeAssessment(id: UUID) throws
  func assignAssessment(id: UUID, to week: TeachingWeek) throws               // PlanLayouter.assign
  func copyCoursePlan(from sourceID: UUID, to targetID: UUID) throws -> CopyResult   // Quell-/Zielwochen aus den Schuljahren; fehlt eins → schoolYearMissing
  func classes(following key: CoursePlanKey) throws -> [SchoolClass]          // Klassen des Stundenplans mit diesem Fach und Jahrgang („gilt für 8a, 8b“)
}
extension DataStore: CoursePlanStore {}

// zusätzlich für Task 15 (in DataStore+CoursePlans.swift):
extension DataStore {
  func lessonPlanHint(for lesson: Lesson) throws -> LessonPlanHint?
  func plannedAssessments(inWeekOf monday: CalendarDay) throws -> [PlannedAssessment]
}
```

Jede Schreibmethode endet mit `saveAndBump()`; `updatedAt` setzt der Store (`Date.now`). `copyCoursePlan` legt die Records aus `CopyResult` an und setzt `notes`, wenn `planNote != nil`. Schuljahr ohne passenden Datensatz für einen Plan (Schuljahr gelöscht): Plan bleibt in der Liste, `teachingWeeks` liefert `[]`, alle Einträge erscheinen unter „nicht zugeordnet“.

- [ ] **Step 1: Failing Tests schreiben** (`makeStore()` aus `FrontstageTests/Data/Fixtures.swift`; Stundenplan, Ferien und Schuljahr wie in den Global Constraints; `lessonPlanHint` mit einer `Lesson` am 10.11.2026)

```swift
@MainActor @Suite struct CoursePlanStoreTests {
  @Test("AK-45: ein Plan für Englisch 8 2026/27, zweites Anlegen liefert dieselbe id") func createIsIdempotentPerKey() throws
  @Test("AK-45: gilt für 8a und 8b, nicht für 7a") func classesFollowingPlan() throws
  @Test("AK-46: 43 Unterrichtswochen aus Schuljahr und Ferien des Stores") func teachingWeeksFromStore() throws
  @Test("Schuljahr mit Überschneidung wird abgelehnt") func overlappingSchoolYearThrows() throws
  @Test("AK-47: Ferien ändern → Einträge unter nicht zugeordnet, nichts gelöscht") func holidayChangeKeepsEntries() throws
  @Test("Leere Planwoche wird gelöscht") func emptyPlanWeekIsDeleted() throws
  @Test("Zuweisen in belegte Woche wirft weekOccupied") func assignToOccupiedWeekThrows() throws
  @Test("Tag außerhalb der Woche wirft dayNotInWeek") func assessmentDayOutsideWeekThrows() throws
  @Test("AK-49: Übernehmen aus 2025/26 legt Einträge an, Quelle unverändert") func copyLeavesSourceUntouched() throws
  @Test("Schuljahr löschen lässt Jahrespläne stehen") func removingSchoolYearKeepsPlans() throws
  @Test("Hand-Jahrgang für ef macht den Plan Jahrgang 11 zuständig") func gradeOverrideApplies() throws
  @Test("AK-50: Hinweis für 8a Englisch am 10.11.2026") func lessonPlanHintFromStore() throws
}
```

- [ ] **Step 2: Diff durchsehen** – kein SwiftData-Objekt verlässt den Store (nur Werte); jede Schreibmethode speichert genau einmal.
- [ ] **Step 3: Implementieren.**
- [ ] **Step 4: Diff durchsehen.**
- [ ] **Step 5: Commit** – `git commit -m "data: add course plan store methods"`

---

### Task 11: Einrichten › Schuljahr (FR-15.1, Jahrgang von Hand)

Design-Takt: Hauptstufe (vor dem Editieren `apple-design` laden; nur Systemstandard)

**Files:**
- Create: `Frontstage/UI/Setup/SchoolYearSettingsModel.swift`, `Frontstage/UI/Setup/SchoolYearSettingsView.swift`
- Modify: `Frontstage/UI/Setup/SetupView.swift` – im ersten `Section` nach „unterrichtsfreie Zeiträume“: `NavigationLink("setup.schoolYears.title") { scoped { SchoolYearSettingsScreen() } }`
- Modify: `Frontstage/Resources/Localizable.xcstrings`
- Test: `FrontstageTests/UI/SchoolYearSettingsModelTests.swift`

**Interfaces:**
- Consumes: `CoursePlanStore` (10), `SchoolYear`, `SchoolYearIssue`, `GradeLevel` (1)
- Produces:

```swift
@MainActor @Observable final class SchoolYearSettingsModel {
  init(store: any CoursePlanStore, today: CalendarDay)
  private(set) var years: [SchoolYear]
  var draft: SchoolYear?                 // Bearbeiten/Neu; neu: Vorschlag aus dem letzten Jahr + 1 (gleiche Tage) oder 1.8./1.2./31.7. des laufenden Schuljahrs
  private(set) var issueKey: String?     // Schlüssel der Meldung zu SchoolYearIssue
  func newYear(); func edit(startYear: Int); func saveDraft(); func cancelDraft(); func remove(startYear: Int)
  /// Klassen ohne Ziffern im Stundenplan mit ihrem Hand-Jahrgang im Schuljahr `startYear`.
  func classesNeedingGrade(startYear: Int) -> [(schoolClass: SchoolClass, grade: GradeLevel?)]
  func setGrade(_ grade: GradeLevel?, for schoolClass: SchoolClass, startYear: Int)
}
```

Ansicht: `List` der Schuljahre (Titel, Zeitraum als sekundärer Text); Bearbeiten in einem Sheet mit `Form`: drei `DatePicker(.date)` (erster Schultag, Beginn 2. Halbjahr, letzter Schultag), Hinweis „Ferien und Feiertage kommen aus den unterrichtsfreien Zeiträumen“, Abschnitt „Jahrgang von Hand“ mit `Picker` je Klasse ohne Ziffern (keiner, 1–13). `DatePicker` arbeitet mit `Date`; Umrechnung nur über `CalendarDay(_:calendar:)` und `Calendar.current.date(from:)`.

Texte (Platzhalter): `setup.schoolYears.title` Schuljahre · `setup.schoolYears.add` Schuljahr hinzufügen · `setup.schoolYears.firstDay` Erster Schultag · `setup.schoolYears.secondTerm` Beginn 2. Halbjahr · `setup.schoolYears.lastDay` Letzter Schultag · `setup.schoolYears.holidaysHint` Ferien und Feiertage kommen aus den unterrichtsfreien Zeiträumen. · `setup.schoolYears.grades` Jahrgang von Hand · `setup.schoolYears.grade.none` keiner · `setup.schoolYears.error.order` Der letzte Schultag liegt vor dem ersten. · `setup.schoolYears.error.secondTerm` Das 2. Halbjahr muss im Schuljahr beginnen. · `setup.schoolYears.error.overlap %@` Überschneidet sich mit dem Schuljahr %@. · `setup.schoolYears.removeHint` Jahrespläne dieses Schuljahrs bleiben erhalten.

- [ ] **Step 1: Failing Tests schreiben** (Attrappe `FakeCoursePlanStore` in `FrontstageTests/TestSupport/FakeCoursePlanStore.swift`, wird in Tasks 12–14 weiterverwendet)

```swift
@MainActor @Suite struct SchoolYearSettingsModelTests {
  @Test("AK-46: Schuljahr 2026/27 anlegen") func savesNewYear()
  @Test("Neues Jahr nach 2025/26 schlägt dieselben Tage ein Jahr später vor") func proposesFollowingYear()
  @Test("Überschneidung → Meldung, nichts gespeichert") func overlapShowsIssue()   // issueKey == "setup.schoolYears.error.overlap %@"
  @Test("AK-45: EF braucht einen Jahrgang, 8a nicht") func listsClassesWithoutDigits()
}
```

- [ ] **Step 2: Diff durchsehen** – Systemstandard; alle Texte über `Localizable.xcstrings`; keine Logik in der Ansicht.
- [ ] **Step 3: Implementieren.**
- [ ] **Step 4: Diff durchsehen**; offene Gestaltungskategorien im Abschlussbericht (Wortlaut, Ort in Einrichten).
- [ ] **Step 5: Commit** – `git commit -m "ui: school year settings with manual grade levels"`

---

### Task 12: Logik des Bereichs Jahresplan

Design-Takt: keiner

**Files:**
- Create: `Frontstage/UI/CoursePlan/CoursePlanListModel.swift`, `CoursePlanEditorModel.swift`, `PlanWeekEditor.swift`
- Test: `FrontstageTests/UI/CoursePlanEditorModelTests.swift`, `FrontstageTests/UI/CoursePlanListModelTests.swift`

**Interfaces:**
- Consumes: `CoursePlanStore` (10), `PlanLayouter`, `PlanLayout` (3), `CoursePlanHistory` (5), `FakeCoursePlanStore` (11)
- Produces:

```swift
@MainActor @Observable final class CoursePlanListModel {
  init(store: any CoursePlanStore, today: CalendarDay)
  private(set) var groups: [(title: String, plans: [CoursePlanSummary])]   // je Schuljahr, laufendes zuerst, dann neuere, dann ältere
  private(set) var hasSchoolYear: Bool
  var selection: UUID?
  /// Vorschläge für „Neuer Jahresplan“: Fächer und Jahrgänge aus dem Stundenplan, Schuljahre aus Einrichten.
  func newPlanOptions() -> (subjects: [Subject], grades: [GradeLevel], startYears: [Int])
  func create(subject: Subject, grade: GradeLevel, startYear: Int)          // setzt selection
  func reload()
}

@MainActor @Observable final class CoursePlanEditorModel {
  init(planID: UUID, store: any CoursePlanStore)
  private(set) var key: CoursePlanKey?
  private(set) var layout: PlanLayout?          // nil, solange nicht geladen
  private(set) var followingClasses: [SchoolClass]
  var notes: String
  private(set) var earlierPlans: [CoursePlanSummary]   // für „Frühere Jahre“ und „Vorjahresplan übernehmen“
  private(set) var noticeKey: String?           // z. B. Ergebnis der Übernahme
  private(set) var noticeArgument: Int?
  func reload(); func saveNotes()
  func editor(for week: TeachingWeek) -> PlanWeekEditor
  func editor(forUnassigned week: PlanWeek) -> PlanWeekEditor
  func emptyWeeks() -> [TeachingWeek]           // Ziele für „Zuweisen“
  func assign(planWeekID: UUID, to week: TeachingWeek)
  func assign(assessmentID: UUID, to week: TeachingWeek)
  func copy(from sourceID: UUID)                // noticeKey "coursePlan.copy.done %lld" mit unassignedCount
}

/// Bearbeiten einer Planwoche samt ihrer Leistungsnachweise (Sheet).
@MainActor @Observable final class PlanWeekEditor {
  let week: TeachingWeek?                       // nil bei nicht zugeordnet
  var topic: String; var notes: String
  private(set) var assessments: [Assessment]
  func addAssessment(kind: AssessmentKind, title: String, day: CalendarDay?)
  func updateAssessment(_ assessment: Assessment); func removeAssessment(id: UUID)
  var selectableDays: [CalendarDay] { get }     // week?.teachingDays ?? []
  func save()                                   // Thema/Notizen über savePlanWeek; leer → gelöscht
}
```

- [ ] **Step 1: Failing Tests schreiben**

```swift
@MainActor @Suite struct CoursePlanEditorModelTests {
  @Test("AK-47: Woche 8 bearbeiten → Thema, KA 1 am Di, Test ohne Tag, Notiz") func editsWeekEight()
  @Test("AK-47: Jahresnotiz bleibt nach reload") func savesPlanNote()
  @Test("AK-49: Übernehmen meldet die Zahl der nicht zugeordneten Einträge") func copyReportsUnassignedCount()
  @Test("Zuweisen bietet nur leere Wochen an") func emptyWeeksOnlyOffersFreeWeeks()
  @Test("AK-45: Kopf zeigt gilt für 8a, 8b") func followingClasses()
  @Test("Thema leeren und speichern löscht die Planwoche") func clearingWeekDeletesIt()
}
@MainActor @Suite struct CoursePlanListModelTests {
  @Test("Laufendes Schuljahr zuerst, dann neuere, dann ältere") func groupsCurrentYearFirst()
  @Test("Ohne Schuljahr: hasSchoolYear false") func withoutSchoolYear()
  @Test("Neuer Plan mit vorhandenem Schlüssel wählt den vorhandenen") func createSelectsExisting()
}
```

- [ ] **Step 2: Diff durchsehen** – View-Modelle halten nur Werte; jede Änderung lädt `layout` neu.
- [ ] **Step 3: Implementieren.**
- [ ] **Step 4: Diff durchsehen.**
- [ ] **Step 5: Commit** – `git commit -m "ui: course plan list and editor models"`

---

### Task 13: Oberfläche Jahresplan und Navigation (FR-15, FR-15.2, FR-15.4)

Design-Takt: voll (vor dem Editieren `apple-design` laden; nach der Aufgabe Prüfung mit `apple-design` als Prüfer; nur Systemstandard)

**Files:**
- Create: `Frontstage/UI/CoursePlan/CoursePlanScreen.swift`, `CoursePlanView.swift`, `PlanWeekSheet.swift`, `NewCoursePlanSheet.swift`
- Modify: `Frontstage/App/AppSection.swift` – `case coursePlan` zwischen `preparation` und `setup`, `titleKey` `"app.section.coursePlan"`, `systemImage` `"calendar"` (Platzhalter)
- Modify: `Frontstage/App/RootView.swift` – `Tab(AppSection.coursePlan.titleKey, systemImage: AppSection.coursePlan.systemImage, value: AppSection.coursePlan) { scoped { CoursePlanScreen() } }` zwischen Vorbereiten und Einrichten; sonst nichts ändern
- Modify: `Frontstage/Resources/Localizable.xcstrings`
- Test: `FrontstageTests/UI/AppSectionTests.swift` (ergänzen)

**Interfaces:**
- Consumes: `CoursePlanListModel`, `CoursePlanEditorModel`, `PlanWeekEditor` (12); `DataStore` aus der Umgebung (`ScopedAppContent` setzt `.environment(store)`), `AppEnvironment.today`; `\.showSetup` (04)
- Produces: `CoursePlanScreen` (Wurzel des Bereichs, holt `DataStore` und `AppEnvironment` aus der Umgebung und legt die Modelle mit `@State` an – Muster wie `PreparationScreen`), `CoursePlanView(model:)`, `PlanWeekSheet(editor:)`, `NewCoursePlanSheet(options:onCreate:)`

Aufbau (Systemstandard): `NavigationSplitView` – Seitenleiste: Liste der Jahrespläne je Schuljahr („Englisch · Jahrgang 8“), Knopf „Neuer Jahresplan“; ohne Schuljahr `ContentUnavailableView` mit Knopf „Schuljahr einrichten“ (`showSetup`). Inhalt: `List` mit Kopf (Titel „Englisch · Jahrgang 8 · 2026/27“, „gilt für 8a, 8b“), `Section` „Notiz zum Jahresplan“ (`TextField(axis: .vertical)`), `Section` „1. Halbjahr“ und „2. Halbjahr“ mit je einer Zeile pro Unterrichtswoche („Woche 8 · KW 46 · 9.–13.11.“, Thema, Leistungsnachweise als Text „Klassenarbeit: KA 1 (Di)“), `Section` „nicht zugeordnet“ (nur wenn nicht leer) mit Menü „Zuweisen“ (leere Wochen). Tipp auf eine Woche öffnet `PlanWeekSheet` (`Form`: Thema, Notizen, Leistungsnachweise mit `Picker` Art, `TextField` Titel, `Picker` Tag „ohne Tag“ + Unterrichtstage). Werkzeugleiste: „Frühere Jahre“ (öffnet Task 14), Menü „Vorjahresplan übernehmen“ mit den früheren Plänen und `confirmationDialog`; danach Hinweis mit `noticeKey`. Am Mac dieselben Ansichten (kein `#if os`, außer `.navigationBarTitleDisplayMode` wie in `LessonDetailView`).

Texte (Platzhalter): `app.section.coursePlan` Jahresplan · `coursePlan.new` Neuer Jahresplan · `coursePlan.noSchoolYear` Noch kein Schuljahr eingerichtet. · `coursePlan.setupSchoolYear` Schuljahr einrichten · `coursePlan.title %@ %lld %@` %1$@ · Jahrgang %2$lld · %3$@ · `coursePlan.followedBy %@` gilt für %@ · `coursePlan.notes` Notiz zum Jahresplan · `coursePlan.term.first` 1. Halbjahr · `coursePlan.term.second` 2. Halbjahr · `coursePlan.unassigned` nicht zugeordnet · `coursePlan.assign` Zuweisen · `coursePlan.week %lld %lld %@` Woche %1$lld · KW %2$lld · %3$@ · `coursePlan.topic` Thema · `coursePlan.weekNotes` Notizen · `coursePlan.assessments` Leistungsnachweise · `coursePlan.assessment.add` Leistungsnachweis hinzufügen · `assessment.kind.test` Test · `assessment.kind.classTest` Klassenarbeit · `coursePlan.assessment.noDay` ohne Tag · `coursePlan.earlierYears` Frühere Jahre · `coursePlan.copy` Vorjahresplan übernehmen · `coursePlan.copy.confirm %@` Themen, Leistungsnachweise und Notizen aus %@ übernehmen? Vorhandene Einträge bleiben. · `coursePlan.copy.done %lld` Übernommen. %lld Einträge stehen unter „nicht zugeordnet“. · `coursePlan.subject` Fach · `coursePlan.grade` Jahrgang · `coursePlan.schoolYear` Schuljahr

- [ ] **Step 1: Failing Test ergänzen**

```swift
@Test("Jahresplan liegt zwischen Vorbereiten und Einrichten")
func coursePlanSectionOrder() {
  #expect(AppSection.allCases == [.dayView, .preparation, .coursePlan, .setup])
  #expect(AppSection.initial(isMac: true, hasTimetable: true) == .preparation)   // Startbereich unverändert
}
```

- [ ] **Step 2: Diff durchsehen** – Systemstandard; keine Logik in Ansichten; `RootView` nur um den Tab ergänzt (06/07-Einträge bleiben).
- [ ] **Step 3: Implementieren.**
- [ ] **Step 4: Diff durchsehen**; Prüfung mit `apple-design` (Navigation iPad/Mac, Listen, Sheets); offene Kategorien im Abschlussbericht (Wochenzeile, Symbol des Bereichs, Darstellung der Leistungsnachweise, Wortlaut).
- [ ] **Step 5: Commit** – `git commit -m "ui: course plan area with weeks per term"`

---

### Task 14: Frühere Jahre nebeneinander (FR-15.3)

Design-Takt: Hauptstufe (vor dem Editieren `apple-design` laden; nur Systemstandard)

**Files:**
- Create: `Frontstage/UI/CoursePlan/CoursePlanComparisonModel.swift`, `CoursePlanComparisonView.swift`
- Modify: `Frontstage/UI/CoursePlan/CoursePlanView.swift` – „Frühere Jahre“ öffnet die Ansicht (`navigationDestination` bzw. Sheet)
- Modify: `Frontstage/Resources/Localizable.xcstrings`
- Test: `FrontstageTests/UI/CoursePlanComparisonModelTests.swift`

**Interfaces:**
- Consumes: `CoursePlanStore` (10), `CoursePlanHistory`, `CoursePlanComparison`, `ComparisonColumn`, `ComparisonRow` (5), `FakeCoursePlanStore` (11)
- Produces:

```swift
@MainActor @Observable final class CoursePlanComparisonModel {
  init(planID: UUID, store: any CoursePlanStore)
  private(set) var earlier: [CoursePlanSummary]       // Liste, neuestes zuerst
  var selected: [UUID]                                // Vorgabe: aktueller Plan + bis zu zwei frühere
  private(set) var columnTitles: [String]             // "2026/27", "2025/26", …
  private(set) var rows: [ComparisonRow]
  func toggle(_ planID: UUID)                         // höchstens vier Spalten
}
```

Ansicht: oben die Liste der früheren Jahre zum Auswählen; darunter `ScrollView([.horizontal, .vertical])` mit `Grid` – Spalte 0 „Woche n“, je Plan eine Spalte mit Thema und Leistungsnachweisen; leere Zelle bei fehlender Woche; Trennlinie, wo `startsSecondTerm`. Nur lesen (keine Eingabefelder, keine Kontextmenüs zum Ändern).

Texte (Platzhalter): `coursePlan.compare.title` Frühere Jahre · `coursePlan.compare.none` Keine früheren Jahrespläne für dieses Fach und diesen Jahrgang. · `coursePlan.compare.week %lld` Woche %lld · `coursePlan.compare.secondTerm` 2. Halbjahr

- [ ] **Step 1: Failing Tests schreiben**

```swift
@MainActor @Suite struct CoursePlanComparisonModelTests {
  @Test("AK-48: frühere Jahre 2025/26 und 2024/25, nicht Englisch 7") func listsEarlierYears()
  @Test("AK-48: Spalten 2026/27, 2025/26, 2024/25; Zeile 1 mit den Themen der Woche 1") func buildsRows()
  @Test("Höchstens vier Spalten") func limitsColumns()
}
```

- [ ] **Step 2: Diff durchsehen** – kein Schreibzugriff aus dieser Ansicht.
- [ ] **Step 3: Implementieren.**
- [ ] **Step 4: Diff durchsehen**; offene Kategorie (Vergleichsdarstellung, Breite am iPad hochkant) im Abschlussbericht.
- [ ] **Step 5: Commit** – `git commit -m "ui: compare earlier course plans side by side"`

---

### Task 15: Wochenthema und Leistungsnachweise in Tagesansicht und Vorbereiten (FR-15.5, FR-15.6)

Design-Takt: Hauptstufe (vor dem Editieren `apple-design` laden; nur Systemstandard)

**Files:**
- Modify: `Frontstage/UI/Preparation/PreparationStore.swift` – zwei Anforderungen plus Vorgabe-Implementierung in einer Protokoll-Erweiterung (damit vorhandene Test-Attrappen ohne Änderung bauen):
  `func lessonPlanHint(for lesson: Lesson) throws -> LessonPlanHint?` (Vorgabe `nil`), `func plannedAssessments(inWeekOf monday: CalendarDay) throws -> [PlannedAssessment]` (Vorgabe `[]`); `DataStore` erfüllt beide mit den Methoden aus Task 10. Swift-Hinweis: Hat der konforme Typ eine eigene Methode gleicher Signatur, gewinnt sie über die Vorgabe der Erweiterung – aber nur, weil die Methode als **Anforderung** im Protokoll steht; stünde sie nur in der Erweiterung, riefe ein Aufruf über `any PreparationStore` immer die Vorgabe.
- Modify: `Frontstage/UI/Shared/LessonRow.swift` – `LessonRow` um `var planHint: LessonPlanHint? = nil` (letzte Eigenschaft, mit Vorgabe – vorhandene Aufrufe des Initialisierers bleiben gültig)
- Modify: `Frontstage/UI/DayView/DayViewModel.swift` – in `content(for:store:storage:)` je Unterrichtsstunde `planHint: try store.lessonPlanHint(for: lesson)` setzen (Ausfälle liefert der Kern als nil)
- Create: `Frontstage/UI/Shared/PlanHintLabel.swift` – Zeilen „Klassenarbeit: KA 1“ bzw. „diese Woche: Test Vokabeltest Unit 2“
- Modify: `Frontstage/UI/DayView/DayRowView.swift` (`LessonRowView`: `PlanHintLabel` unter den Stundenangaben; nur die Leistungsnachweise, kein geplantes Thema – im Unterricht zählt das eingetragene Thema)
- Modify: `Frontstage/UI/Preparation/PreparationViewModel.swift` – neue Eigenschaft `private(set) var weekAssessments: [PlannedAssessment] = []`, in `reload()` aus `environment.store.plannedAssessments(inWeekOf: weekStart)` gefüllt (`PreparationDay` bleibt unverändert)
- Modify: `Frontstage/UI/Preparation/PreparationView.swift` (vorhanden: `PreparationView` mit `List(selection:)`, privates `LessonWeekRow`) – `model.weekAssessments` als erste `Section` der Liste (nur wenn nicht leer); `LessonWeekRow` zeigt `PlanHintLabel`
- Modify: `Frontstage/UI/Preparation/LessonDetailView.swift` – in `infoSection` (vorhanden): hat die Stunde einen Hinweis (`lessonRow?.planHint`, vorhandene berechnete Eigenschaft `lessonRow` der Ansicht) mit `plannedTopic` und ist es ungleich `editor.topic`, eine Zeile „Aus dem Jahresplan: <Thema>“ mit Knopf „Als Thema übernehmen“ → `editor.topic = plannedTopic; editor.save()`
- Modify: `Frontstage/Resources/Localizable.xcstrings`
- Test: `FrontstageTests/UI/PlanHintTests.swift`

**Interfaces:**
- Consumes: `LessonPlanHint`, `AssessmentMarker`, `PlannedAssessment` (6); `DataStore.lessonPlanHint(for:)`, `plannedAssessments(inWeekOf:)` (10); `LessonInfoEditor` (04)
- Produces: `LessonRow.planHint`, `PreparationViewModel.weekAssessments: [PlannedAssessment]`, `PlanHintLabel(markers: [AssessmentMarker])`

Texte (Platzhalter): `planHint.onDay %@ %@` %1$@: %2$@ · `planHint.thisWeek %@ %@` diese Woche: %1$@ %2$@ · `planHint.suggestion %@` Aus dem Jahresplan: %@ · `planHint.useTopic` Als Thema übernehmen · `preparation.weekAssessments` Leistungsnachweise dieser Woche

- [ ] **Step 1: Failing Tests schreiben** (In-Memory-`DataStore` aus `makeStore()` mit Stundenplan Di 2. Stunde 8a Englisch, Do 3. Stunde 8b Englisch, Di 4. Stunde 8a Mathe, Di 5. Stunde 7a Englisch; Schuljahr 2026/27; Plan wie AK-47)

```swift
@MainActor @Suite struct PlanHintTests {
  @Test("AK-51: Tagesansicht Di 10.11. – 8a Englisch mit KA 1 und Test, 8a Mathe ohne") func dayRowsCarryMarkers()
  @Test("AK-51: Do 12.11. – 8b nur der Test der Woche") func thursdayShowsWeekMarkerOnly()
  @Test("AK-51: Vorbereiten-Woche ab 9.11. listet beide Leistungsnachweise") func preparationWeekListsAssessments()
  @Test("AK-50: Vorschlag übernehmen schreibt das Thema, ohne Tipp bleibt es leer") func suggestionWritesTopicOnlyOnTap()
  @Test("AK-50: 7a bekommt keinen Vorschlag") func noSuggestionForOtherGrade()
  @Test("Ausfall trägt keinen Hinweis") func cancelledLessonHasNoHint()
}
```

`suggestionWritesTopicOnlyOnTap` prüft über `LessonInfoEditor`: vor dem Übernehmen `store.lessonInfo(for:).topic == nil`, danach `"Unit 2 – Past tense"`.

- [ ] **Step 2: Diff durchsehen** – vorhandene Tests aus 04 (`DayViewModelTests`, `PreparationViewModelTests`) bauen unverändert (Vorgaben im Protokoll, `planHint` mit Vorgabe).
- [ ] **Step 3: Implementieren.**
- [ ] **Step 4: Diff durchsehen**; offene Kategorien im Abschlussbericht (Darstellung der Hinweise in Tagesansicht und Vorbereiten, Ort des Vorschlags, ob der Klassenbildschirm Leistungsnachweise zeigt – bisher nein).
- [ ] **Step 5: Commit** – `git commit -m "ui: show course plan topic suggestion and assessments in day view and preparation"`

---

### Task 16: CI-Lauf (workflow_dispatch) und Ergebnis prüfen – führt der Controller aus

Design-Takt: keiner

- [ ] **Step 1: Gesamtdiff durchsehen** – `git diff main...HEAD -- Packages Frontstage FrontstageTests project.yml`: `FrontstageCore` importiert nur `Foundation`; Swift 6 strikt; die vier Records ohne `.unique`, alle Felder mit Vorgabe oder optional; `ModelContainerFactory.modelTypes` enthält zwölf Typen; `RecordCodec` behandelt zwölf Modelle in Export, `export(_:from:)`, `liveIDs`, `upsert`, `delete`; `mergeDuplicates()` wendet `CoursePlanMerger` an, auch wenn `SyncMerger` nichts findet; `RootView` behält alles aus 04–08 und 06/07.
- [ ] **Step 2: Kern lokal** – `.\scripts\swift-test.ps1` → alle Suites grün; `.\scripts\swift-parse.ps1` → keine Syntaxfehler.
- [ ] **Step 3: Lauf starten**

```bash
git push -u origin "$(git branch --show-current)"
gh workflow run ci.yml --ref "$(git branch --show-current)"
gh run list --workflow ci.yml --limit 1
gh run watch <run-id> --exit-status
```

Erwartet: Schritt „Core tests“ grün inkl. `CoursePlan SchoolYear`, `CoursePlan TeachingWeeks`, `CoursePlan Layout`, `CoursePlan Copy`, `CoursePlan History`, `CoursePlan Hint`, `CoursePlan Merge`, `DataFolder Format`; Schritt „App tests (iPad simulator)“ grün mit `RecordCodecTests`, `RecordSchemaTests`, `CoursePlanMergeTests`, `CoursePlanStoreTests`, `SchoolYearSettingsModelTests`, `CoursePlanEditorModelTests`, `CoursePlanListModelTests`, `CoursePlanComparisonModelTests`, `PlanHintTests`, `AppSectionTests` sowie allen vorhandenen; Schritt „Build macOS“ grün. Implementierer pushen nicht und starten keinen Lauf.

- [ ] **Step 4: Bei Rot** – `gh run view <run-id> --log-failed`, Ursache mit superpowers:systematic-debugging klären, alle Korrekturen sammeln, **ein** neuer Lauf.

---

## Geräte-Checkliste (Mensch mit iPad und Mac, nach Task 16)

| # | Aufbau | Handlung | Erwartet | Ergebnis |
|---|---|---|---|---|
| 1 | **AK-45:** iPad und Mac mit demselben Datenort, Stundenplan 8a/8b Englisch | Mac: Schuljahr 2026/27 und Jahresplan Englisch 8 anlegen, Woche 1 Thema eintragen | iPad zeigt den Plan mit Thema nach dem Abgleich; bei OneDrive liegen Dateien in `Apps/Frontstage/CoursePlan/` und `PlanWeek/` | ☐ iCloud ☐ OneDrive |
| 2 | beide Geräte offline | denselben Jahresplan an beiden Geräten neu anlegen, je eine andere Woche füllen; dann online | ein Plan mit beiden Wochen | ☐ |
| 3 | Jahresplan am iPad hochkant und am Mac | Bereich Jahresplan öffnen, Woche bearbeiten, Frühere Jahre öffnen | Navigation erreichbar (Tab bzw. Seitenleiste), Sheets bedienbar, Vergleich scrollt in beide Richtungen | ☐ |
| 4 | **AK-50/AK-51** am iPad | Tagesansicht und Vorbereiten am 10.11.2026 (Datum des Geräts oder Navigation) | Hinweise und Vorschlag wie im AK | ☐ |

---

## Abdeckung

| Anforderung | Task |
|---|---|
| FR-15 – Plan je Fach, Jahrgang, Schuljahr; Jahrgang aus dem Klassennamen, von Hand ohne Ziffern; Abgleich | 1, 3, 8, 9, 10, 11, 13; Geräte-Checkliste 1, 2 |
| FR-15.1 – Schuljahr, Halbjahre, Unterrichtswochen | 1, 2, 10, 11 |
| FR-15.2 – Planwochen mit Thema, Leistungsnachweisen, Notizen; „nicht zugeordnet“ | 3, 10, 12, 13 |
| FR-15.3 – frühere Jahre, nebeneinander, nur lesen | 5, 12, 14 |
| FR-15.4 – Vorjahresplan übernehmen | 4, 10, 12, 13 |
| FR-15.5 – Wochenthema als Stundenthema vorschlagen | 6, 10, 15 |
| FR-15.6 – Leistungsnachweise in Tagesansicht und Vorbereiten | 6, 10, 15 |
| ADR-0013 – Schlüssel, `startYear`, Montag als Wochen-Kennung | 1, 3, 7, 9 |
| Area daten – Nebenläufigkeit (Zusammenführen) | 7, 9 |
| ADR-0012 – beide Abgleichwege | 8, 9 |
| RISK-10 – keine leeren Planwochen, getrenntes Zusammenführen | 7, 9, 10 |
| AK-45 bis AK-51 | 1–6 (Kern), 10–15 (App), Geräte-Checkliste |

## Produziert für spätere Teilpläne (Zusammenfassung)

- **Kern:** `ISOWeek`, `CalendarDay.isoWeek`, `Term`, `SchoolYear`, `SchoolYearIssue`, `GradeLevel`, `TeachingWeek`, `TeachingWeekCalculator`, `AssessmentKind`, `CoursePlanKey`, `PlanWeek`, `Assessment`, `PlanLayout`, `PlanLayoutWeek`, `PlanLayouter`, `CopyResult`, `CoursePlanCopier`, `CoursePlanHistory`, `ComparisonColumn`, `ComparisonCell`, `ComparisonRow`, `CoursePlanComparison`, `CoursePlanSnapshotEntry`, `AssessmentTiming`, `AssessmentMarker`, `LessonPlanHint`, `PlannedAssessment`, `LessonPlanHinter`, `CoursePlanMergeSnapshot`, `CoursePlanMergePlan`, `CoursePlanMerger`, vier Payloads und `SyncModel`-Fälle.
- **App:** `SchoolYearRecord`, `CoursePlanRecord`, `PlanWeekRecord`, `AssessmentRecord`, `CoursePlanStore`, `CoursePlanContent`, `CoursePlanSummary`, `CoursePlanError`, `AppSection.coursePlan`, `LessonRow.planHint`, `PreparationStore.lessonPlanHint(for:)`/`plannedAssessments(inWeekOf:)`, `PlanHintLabel`.

## Abstimmungsbedarf

- **Q-35 (PRD):** Jahresplanung kostenlos oder im Einmalkauf? Gebaut wird kostenlos; eine Freischaltung wäre eine Abfrage in `CoursePlanScreen`.
- **Q-36 (PRD):** Klassen, die vom Plan abweichen – reichen Notizen? Gebaut wird nur die Notiz; der Vorschlag folgt der Kalenderwoche.
- **Klassenbildschirm:** Zeigt er Leistungsnachweise („Morgen: Vokabeltest“)? Nicht verlangt, nicht gebaut; bei Bedarf eigene Anforderung.

## Offene Risiken

1. **RISK-10 – Menge über die Jahre:** `mergeDuplicates()` lädt alle Jahresplan-Records; bei einigen tausend Datensätzen messbar. Erst bei Bedarf auf Abfragen je Plan umstellen.
2. **Ferien früherer Jahre gelöscht:** Die Wochenzählung eines früheren Jahresplans hängt an den unterrichtsfreien Zeiträumen jenes Jahres. Löscht die Lehrkraft alte Ferien, verschieben sich Wochennummern im Vergleich und beim Übernehmen (Einträge bleiben an ihren Montagen, nur die Zählung ändert sich). Hinweis in Einrichten wäre eine Design-Frage.
3. **Fach unterschiedlich geschrieben** („E“ im Schulmanager-Import, „Englisch“ im Plan): kein Hinweis in Vorbereiten. `NewCoursePlanSheet` bietet deshalb die Fächer des Stundenplans zur Auswahl an.
4. **Gemischte App-Versionen:** Ein Gerät ohne Teilplan 09 ignoriert die neuen Ordner (OneDrive) bzw. Datensatzarten (iCloud) und zeigt keine Jahrespläne, löscht aber nichts.
