import Foundation
import Testing
@testable import FrontstageCore

@Suite("PrefetchPlanner")
struct PrefetchPlannerTests {
  private func keys(
    today: CalendarDay, _ tt: Timetable, nonTeaching: [NonTeachingPeriod] = [],
    changes: [ScheduleChange] = [], lookahead: Int = 14
  ) -> [LessonKey] {
    PrefetchPlanner.lessonKeys(
      today: today, timetable: tt, nonTeachingPeriods: nonTeaching, changes: changes,
      lookaheadDays: lookahead)
  }

  private let weekFixture = timetable([
    entry(.friday, 1, "8b", "Englisch"),
    entry(.monday, 2, "7a", "Mathe"),
  ])

  @Test("Heute und nächster Unterrichtstag (NFR-1, AK-17)")
  func coversTodayAndNextTeachingDay() {
    let result = keys(today: d(2026, 11, 13), weekFixture)
    #expect(Set(result.map(\.date)) == [d(2026, 11, 13), d(2026, 11, 16)])
    #expect(result.count == 2)
  }

  @Test("Ferien werden übersprungen (AK-14-Aufbau)")
  func skipsNonTeachingPeriod() {
    let holidays = [NonTeachingPeriod(from: d(2026, 11, 2), to: d(2026, 11, 6), title: "Ferien")]
    let result = keys(today: d(2026, 10, 30), weekFixture, nonTeaching: holidays)
    #expect(Set(result.map(\.date)) == [d(2026, 10, 30), d(2026, 11, 9)])
  }

  @Test("Heute ohne Unterricht: nur der nächste Unterrichtstag")
  func weekendYieldsNextTeachingDayOnly() {
    let result = keys(today: d(2026, 11, 14), weekFixture)
    #expect(result.map(\.date) == [d(2026, 11, 16)])
  }

  @Test("Tag nur mit Ausfällen zählt nicht als nächster Unterrichtstag")
  func cancelledOnlyDayIsSkipped() {
    let tt = timetable([entry(.monday, 1, "7a", "Mathe"), entry(.tuesday, 1, "8b", "Englisch")])
    let cancelled = LessonKey(
      date: d(2026, 11, 16), schoolClass: SchoolClass("7a"), subject: Subject("Mathe"), ordinal: 1)
    let result = keys(today: d(2026, 11, 15), tt, changes: [.cancellation(cancelled, .manual)])
    #expect(result.map(\.date) == [d(2026, 11, 17)])
  }

  @Test("Vertretungsstunde wird bereitgehalten (FR-9)")
  func substituteLessonIncluded() {
    let change = ScheduleChange.substituteLesson(
      date: d(2026, 11, 18), period: 4, schoolClass: SchoolClass("6c"), subject: Subject("Mathe"),
      .manual)
    let result = keys(today: d(2026, 11, 17), timetable([]), changes: [change])
    #expect(result.count == 1)
    #expect(result.first?.date == d(2026, 11, 18))
    #expect(result.first?.schoolClass == SchoolClass("6c"))
  }

  @Test("Ohne Unterricht in 14 Tagen: leer")
  func emptyWithinLookahead() {
    #expect(keys(today: d(2026, 11, 13), timetable([])).isEmpty)
  }

  @Test("Gleiche Datei in zwei Stunden nur einmal")
  func referencesAreDeduplicated() {
    let k1 = LessonKey(
      date: d(2026, 11, 13), schoolClass: SchoolClass("8b"), subject: Subject("Englisch"), ordinal: 1)
    let k2 = LessonKey(
      date: d(2026, 11, 16), schoolClass: SchoolClass("8b"), subject: Subject("Englisch"), ordinal: 1)
    let first = MaterialReference(
      folderGrantName: "Material", relativePath: "8b/Vokabeln Unit 4.pptx",
      displayName: "Vokabeln Unit 4", fileKind: .presentation)
    let second = MaterialReference(
      folderGrantName: "Material", relativePath: "8B/vokabeln unit 4.pptx",
      displayName: "vokabeln unit 4", fileKind: .presentation)
    let result = PrefetchPlanner.references(
      for: [k1, k2], links: [(key: k1, reference: first), (key: k2, reference: second)])
    #expect(result == [first])
  }

  @Test("Verweise fremder Stunden werden nicht bereitgehalten")
  func referencesIgnoreOtherLessons() {
    let k1 = LessonKey(
      date: d(2026, 11, 13), schoolClass: SchoolClass("8b"), subject: Subject("Englisch"), ordinal: 1)
    let other = LessonKey(
      date: d(2026, 11, 20), schoolClass: SchoolClass("8b"), subject: Subject("Englisch"), ordinal: 1)
    let ref = MaterialReference(
      folderGrantName: "Material", relativePath: "a.pdf", displayName: "a", fileKind: .pdf)
    #expect(PrefetchPlanner.references(for: [k1], links: [(key: other, reference: ref)]).isEmpty)
  }
}
