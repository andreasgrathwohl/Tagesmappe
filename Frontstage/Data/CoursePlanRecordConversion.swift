import Foundation
import FrontstageCore

// Übersetzung zwischen den Jahresplan-Datensätzen (Rohtext) und den reinen Kern-Typen.
// Unlesbare Rohwerte ergeben `nil`, nie einen Absturz (wie in `RecordConversion.swift`).

extension SchoolYearRecord {
  /// `nil`, wenn einer der drei Tagestexte nicht lesbar ist.
  func makeSchoolYear() -> SchoolYear? {
    guard let first = CalendarDay(storageText: firstDayText),
      let second = CalendarDay(storageText: secondTermStartText),
      let last = CalendarDay(storageText: lastDayText)
    else { return nil }
    let overrides = gradeOverridesData.flatMap { try? JSONDecoder().decode([String: Int].self, from: $0) } ?? [:]
    return SchoolYear(firstDay: first, secondTermStart: second, lastDay: last, gradeOverrides: overrides)
  }

  /// Übernimmt die Tage und die Jahrgangs-Zuordnung von Hand.
  func apply(_ year: SchoolYear) {
    firstDayText = year.firstDay.storageText
    secondTermStartText = year.secondTermStart.storageText
    lastDayText = year.lastDay.storageText
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys]
    gradeOverridesData = year.gradeOverrides.isEmpty ? nil : try? encoder.encode(year.gradeOverrides)
  }
}

extension CoursePlanRecord {
  /// Schlüssel (ADR-0013); `nil` bei Jahrgang außerhalb 1...13.
  var key: CoursePlanKey? {
    GradeLevel(gradeLevel).map {
      CoursePlanKey(subject: Subject(subjectText), gradeLevel: $0, startYear: startYear)
    }
  }
}

extension PlanWeekRecord {
  /// Ein nicht lesbarer Montag gilt wie „nicht zugeordnet“.
  func makePlanWeek() -> PlanWeek {
    PlanWeek(
      id: id, monday: mondayText.flatMap { CalendarDay(storageText: $0) }, position: position,
      topic: topic, notes: notes, updatedAt: updatedAt)
  }

  /// Übernimmt Montag, Position, Thema, Notizen und Änderungszeit; `id` und Jahresplan bleiben.
  func apply(_ week: PlanWeek) {
    mondayText = week.monday?.storageText
    position = week.position
    topic = week.topic
    notes = week.notes
    updatedAt = week.updatedAt
  }
}

extension AssessmentRecord {
  /// `nil` bei unbekannter Art.
  func makeAssessment() -> Assessment? {
    guard let kind = AssessmentKind(rawValue: kindRaw) else { return nil }
    return Assessment(
      id: id, monday: mondayText.flatMap { CalendarDay(storageText: $0) },
      day: dayText.flatMap { CalendarDay(storageText: $0) }, kind: kind, title: title,
      updatedAt: updatedAt)
  }

  func apply(_ assessment: Assessment) {
    mondayText = assessment.monday?.storageText
    dayText = assessment.day?.storageText
    kindRaw = assessment.kind.rawValue
    title = assessment.title
    updatedAt = assessment.updatedAt
  }
}
