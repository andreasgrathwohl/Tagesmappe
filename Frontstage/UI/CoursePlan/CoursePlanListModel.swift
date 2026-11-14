import Foundation
import FrontstageCore
import Observation

/// Logik der Liste „Jahresplan“ (FR-15.2): Pläne je Schuljahr und „Neuer Jahresplan“.
@MainActor @Observable final class CoursePlanListModel {
  private let store: any CoursePlanStore
  private let today: CalendarDay

  /// Je Schuljahr; das laufende zuerst, dann die neueren (nächstes zuerst), dann die älteren.
  private(set) var groups: [(title: String, plans: [CoursePlanSummary])] = []
  /// `false`, solange „Einrichten › Schuljahre“ leer ist.
  private(set) var hasSchoolYear = false
  var selection: UUID?

  private var years: [SchoolYear] = []

  init(store: any CoursePlanStore, today: CalendarDay) {
    self.store = store
    self.today = today
    reload()
  }

  func reload() {
    years = (try? store.schoolYears()) ?? []
    hasSchoolYear = !years.isEmpty
    let summaries = (try? store.coursePlanSummaries()) ?? []
    let byYear = Dictionary(grouping: summaries, by: { $0.key.startYear })

    // Laufendes Schuljahr: das, das heute enthält; sonst nach dem Kalender (ab August das neue).
    let current =
      years.first { $0.contains(today) }?.startYear ?? (today.month >= 8 ? today.year : today.year - 1)
    let startYears = byYear.keys.sorted()
    let newer = startYears.filter { $0 > current }
    let older = Array(startYears.filter { $0 < current }.reversed())
    let ordered: [Int] = (startYears.contains(current) ? [current] : []) + newer + older

    groups = ordered.map { startYear in
      let title = years.first { $0.startYear == startYear }?.title ?? Self.title(for: startYear)
      return (title: title, plans: byYear[startYear] ?? [])
    }
  }

  /// Vorschläge für „Neuer Jahresplan“: Fächer und Jahrgänge aus dem Stundenplan, Schuljahre aus Einrichten.
  func newPlanOptions() -> (subjects: [Subject], grades: [GradeLevel], startYears: [Int]) {
    let subjects = (try? store.timetableSubjects()) ?? []
    // Jahrgang je Klasse: aus den Ziffern, sonst aus der Handeinstellung (neueres Schuljahr gewinnt).
    var overrides: [String: Int] = [:]
    for year in years { overrides.merge(year.gradeOverrides) { _, new in new } }
    let classes = (try? store.timetableClasses()) ?? []
    let grades = Set(classes.compactMap { GradeLevel.resolve($0, overrides: overrides) }).sorted()
    return (subjects, grades, years.map(\.startYear).sorted())
  }

  /// Legt den Plan an und wählt ihn; gibt es den Schlüssel schon, wird der vorhandene gewählt.
  func create(subject: Subject, grade: GradeLevel, startYear: Int) {
    let key = CoursePlanKey(subject: subject, gradeLevel: grade, startYear: startYear)
    guard let id = try? store.createCoursePlan(key) else { return }
    reload()
    selection = id
  }

  private static func title(for startYear: Int) -> String {
    String(format: "%d/%02d", startYear, (startYear + 1) % 100)
  }
}
