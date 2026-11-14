import Foundation

@testable import FrontstageCore

/// Schuljahr 2026/27 für Tests: 14.9.2026, zweites Halbjahr ab 1.2.2027, Ende 28.7.2027.
func year2026() -> SchoolYear {
  SchoolYear(firstDay: d(2026, 9, 14), secondTermStart: d(2027, 2, 1), lastDay: d(2027, 7, 28))
}

/// Schuljahr 2025/26 für Tests (grenzt ohne Überschneidung an 2026/27).
func year2025() -> SchoolYear {
  SchoolYear(firstDay: d(2025, 9, 15), secondTermStart: d(2026, 2, 2), lastDay: d(2026, 7, 29))
}

/// Eine Unterrichtsstunde für Hinweis-Tests (Ordnungszahl 1).
func lesson(_ day: CalendarDay, _ schoolClass: String, _ subject: String, cancelled: Bool = false)
  -> Lesson
{
  Lesson(
    key: LessonKey(
      date: day, schoolClass: SchoolClass(schoolClass), subject: Subject(subject), ordinal: 1),
    period: 1, time: nil, isSubstituteLesson: false, isCancelled: cancelled,
    cancellationOrigin: cancelled ? .manual : nil)
}

/// Plan Englisch Jahrgang 8, 2026/27: Woche ab 9.11.2026 mit Thema, KA am Tag `kaOn`,
/// Vokabeltest ohne Tag.
func english8With(kaOn: CalendarDay?, topic: String? = "Unit 2 – Past tense")
  -> CoursePlanSnapshotEntry
{
  let monday = d(2026, 11, 9)
  let now = Date(timeIntervalSince1970: 0)
  return CoursePlanSnapshotEntry(
    id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
    key: CoursePlanKey(subject: Subject("Englisch"), gradeLevel: GradeLevel(8)!, startYear: 2026),
    planWeeks: [
      PlanWeek(id: UUID(), monday: monday, position: 0, topic: topic, notes: nil, updatedAt: now)
    ],
    assessments: [
      Assessment(
        id: UUID(uuidString: "00000000-0000-0000-0000-0000000000A2")!, monday: monday, day: nil,
        kind: .test, title: "Vokabeltest Unit 2", updatedAt: now),
      Assessment(
        id: UUID(uuidString: "00000000-0000-0000-0000-0000000000A1")!, monday: monday, day: kaOn,
        kind: .classTest, title: "KA 1", updatedAt: now),
    ])
}
