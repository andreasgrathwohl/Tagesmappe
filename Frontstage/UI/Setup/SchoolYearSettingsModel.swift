import Foundation
import FrontstageCore
import Observation

/// Logik von „Einrichten › Schuljahre“ (FR-15.1): Schuljahre anlegen, ändern, entfernen und für
/// Klassen ohne Ziffern im Namen den Jahrgang von Hand festlegen (AK-45, AK-46).
///
/// Swift-Hinweis: `@Observable` ersetzt `ObservableObject`; die Ansicht liest die Eigenschaften
/// direkt und zeichnet nur neu, was sie tatsächlich gelesen hat.
@MainActor @Observable final class SchoolYearSettingsModel {
  private let store: any CoursePlanStore
  private let today: CalendarDay

  /// Nach `startYear` aufsteigend.
  private(set) var years: [SchoolYear] = []
  /// Schuljahr im Bearbeiten-Sheet; `nil`, wenn keins offen ist.
  var draft: SchoolYear?
  /// Schlüssel der Meldung zu einem abgelehnten Schuljahr (`Localizable.xcstrings`); `nil` ohne Meldung.
  private(set) var issueKey: String?
  /// Titel des überschneidenden Schuljahrs für `setup.schoolYears.error.overlap %@`.
  private(set) var issueOverlapTitle: String?
  /// Startjahr, unter dem der Entwurf bisher gespeichert war; `nil` bei einem neuen Schuljahr.
  private var editingStartYear: Int?

  init(store: any CoursePlanStore, today: CalendarDay) {
    self.store = store
    self.today = today
    reload()
  }

  /// Liest den Stand neu (auch nach Änderungen vom anderen Gerät).
  func reload() {
    years = (try? store.schoolYears()) ?? []
  }

  /// Neues Schuljahr: dieselben Tage ein Jahr nach dem letzten, sonst 1.8./1.2./31.7. des laufenden Schuljahrs.
  func newYear() {
    clearIssue()
    editingStartYear = nil
    if let last = years.last {
      draft = SchoolYear(
        firstDay: Self.shifted(last.firstDay, byYears: 1),
        secondTermStart: Self.shifted(last.secondTermStart, byYears: 1),
        lastDay: Self.shifted(last.lastDay, byYears: 1))
    } else {
      // Ab August zählt das Kalenderjahr als Startjahr, davor das Vorjahr.
      let start = today.month >= 8 ? today.year : today.year - 1
      draft = SchoolYear(
        firstDay: CalendarDay(year: start, month: 8, day: 1),
        secondTermStart: CalendarDay(year: start + 1, month: 2, day: 1),
        lastDay: CalendarDay(year: start + 1, month: 7, day: 31))
    }
  }

  func edit(startYear: Int) {
    guard let year = years.first(where: { $0.startYear == startYear }) else { return }
    clearIssue()
    editingStartYear = startYear
    draft = year
  }

  /// Speichert den Entwurf. Bei einer Ablehnung bleibt er offen und `issueKey` nennt den Grund.
  ///
  /// Geprüft wird gegen die übrigen Schuljahre ohne den eigenen alten Stand. Ändert sich das Startjahr
  /// (erster Schultag in ein anderes Kalenderjahr verschoben) und gibt es schon ein anderes Schuljahr
  /// mit dem neuen Startjahr, wird abgelehnt – sonst ersetzte der Store es still samt Hand-Jahrgängen.
  func saveDraft() {
    guard let draft else { return }
    let current = (try? store.schoolYears()) ?? years
    let others = current.filter { $0.startYear != editingStartYear }
    if let issue = draft.issue(among: others) {
      apply(issue)
      return
    }
    if others.contains(where: { $0.startYear == draft.startYear }) {
      apply(.overlaps(startYear: draft.startYear))
      return
    }
    do {
      if let old = editingStartYear, old != draft.startYear {
        try move(from: old, to: draft, previous: current.first { $0.startYear == old })
      } else {
        try store.saveSchoolYear(draft)
      }
      self.draft = nil
      editingStartYear = nil
      clearIssue()
      reload()
    } catch CoursePlanError.invalidSchoolYear(let issue) {
      apply(issue)
    } catch {
      issueKey = "setup.schoolYears.error.save"
    }
  }

  func cancelDraft() {
    draft = nil
    editingStartYear = nil
    clearIssue()
  }

  /// Entfernt nur das Schuljahr; seine Jahrespläne bleiben erhalten.
  func remove(startYear: Int) {
    try? store.removeSchoolYear(startYear: startYear)
    reload()
  }

  /// Klassen ohne Ziffern im Stundenplan mit ihrem Hand-Jahrgang im Schuljahr `startYear`.
  /// Ist gerade ein Entwurf für dieses Schuljahr offen, zählt dessen Stand.
  func classesNeedingGrade(startYear: Int) -> [(schoolClass: SchoolClass, grade: GradeLevel?)] {
    let classes = (try? store.timetableClasses()) ?? []
    let overrides = overrides(startYear: startYear)
    return classes.filter { GradeLevel.derived(from: $0) == nil }.map { schoolClass in
      (schoolClass, overrides[schoolClass.normalized].flatMap { GradeLevel($0) })
    }
  }

  /// Setzt den Jahrgang von Hand. Im offenen Entwurf wirkt er erst mit `saveDraft()`; sonst sofort.
  func setGrade(_ grade: GradeLevel?, for schoolClass: SchoolClass, startYear: Int) {
    if var current = draft, current.startYear == startYear {
      if let grade {
        current.gradeOverrides[schoolClass.normalized] = grade.value
      } else {
        current.gradeOverrides.removeValue(forKey: schoolClass.normalized)
      }
      draft = current
      return
    }
    try? store.setGradeOverride(grade, for: schoolClass, startYear: startYear)
    reload()
  }

  // MARK: - Hilfen

  /// Neues Startjahr: erst den alten Stand entfernen, damit die Prüfung des Stores ihn nicht als
  /// Überschneidung mit sich selbst meldet; scheitert das Speichern, kommt der alte Stand zurück.
  private func move(from old: Int, to year: SchoolYear, previous: SchoolYear?) throws {
    try store.removeSchoolYear(startYear: old)
    do {
      try store.saveSchoolYear(year)
    } catch {
      if let previous { try? store.saveSchoolYear(previous) }
      throw error
    }
  }

  private func overrides(startYear: Int) -> [String: Int] {
    if let draft, draft.startYear == startYear { return draft.gradeOverrides }
    return years.first(where: { $0.startYear == startYear })?.gradeOverrides ?? [:]
  }

  private func clearIssue() {
    issueKey = nil
    issueOverlapTitle = nil
  }

  private func apply(_ issue: SchoolYearIssue) {
    issueOverlapTitle = nil
    switch issue {
    case .lastDayBeforeFirstDay:
      issueKey = "setup.schoolYears.error.order"
    case .secondTermOutside:
      issueKey = "setup.schoolYears.error.secondTerm"
    case .overlaps(let startYear):
      issueKey = "setup.schoolYears.error.overlap %@"
      issueOverlapTitle = String(format: "%d/%02d", startYear, (startYear + 1) % 100)
    }
  }

  /// Derselbe Tag `years` Jahre später; der 29.2. wird im Nicht-Schaltjahr zum 28.2.
  private static func shifted(_ day: CalendarDay, byYears years: Int) -> CalendarDay {
    let year = day.year + years
    let isLeap = (year % 4 == 0 && year % 100 != 0) || year % 400 == 0
    let clamped = (day.month == 2 && day.day == 29 && !isLeap) ? 28 : day.day
    return CalendarDay(year: year, month: day.month, day: clamped)
  }
}
