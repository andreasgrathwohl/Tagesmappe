import Testing
@testable import FrontstageCore

@Suite("ParallelLessonFinder")
struct ParallelLessonFinderTests {
  /// Fixture A: eine Wochenvariante, Bezugswoche 16.11.2026.
  private var fixtureA: Timetable {
    timetable([
      entry(.tuesday, 2, "8a", "Englisch"),
      entry(.wednesday, 3, "8b", "Englisch"),
      entry(.thursday, 1, "8a", "Englisch"),
      entry(.friday, 4, "8b", "Mathe"),
      entry(.monday, 5, "9c", "Deutsch"),
    ])
  }

  @Test("AK-7: Kandidaten der 8b ab Di 17.11. – Mi 3. Stunde Englisch zuerst, jedes Fach")
  func candidatesListUpcomingLessonsOfTargetClass() {
    let list = ParallelLessonFinder.candidates(
      for: SchoolClass("8b"), from: d(2026, 11, 17), timetable: fixtureA,
      nonTeachingPeriods: [], changes: [])
    #expect(
      list.first?.key
        == LessonKey(
          date: d(2026, 11, 18), schoolClass: SchoolClass("8b"), subject: Subject("Englisch"),
          ordinal: 1))
    #expect(list.dropFirst().first?.key.subject == Subject("Mathe"))
    #expect(list.allSatisfy { $0.key.schoolClass == SchoolClass("8b") })
    #expect(list.last.map { $0.key.date <= d(2026, 12, 14) } == true)
  }

  @Test("Ausgefallene Stunden sind nicht wählbar")
  func candidatesSkipCancelledLessons() {
    let cancelled = LessonKey(
      date: d(2026, 11, 18), schoolClass: SchoolClass("8b"), subject: Subject("Englisch"),
      ordinal: 1)
    let list = ParallelLessonFinder.candidates(
      for: SchoolClass("8b"), from: d(2026, 11, 17), timetable: fixtureA,
      nonTeachingPeriods: [], changes: [.cancellation(cancelled, .manual)])
    #expect(list.first?.key.date == d(2026, 11, 20))
    #expect(list.first?.key.subject == Subject("Mathe"))
    #expect(list.allSatisfy { !$0.isCancelled })
  }

  @Test("Klasse ohne Eintrag hat keine Kandidaten")
  func candidatesEmptyWithoutLessons() {
    let list = ParallelLessonFinder.candidates(
      for: SchoolClass("6c"), from: d(2026, 11, 17), timetable: fixtureA,
      nonTeachingPeriods: [], changes: [])
    #expect(list.isEmpty)
  }

  @Test("Klassen zur Wahl: alle außer der eigenen")
  func selectableClassesExcludeOwnClass() {
    #expect(
      ParallelLessonFinder.selectableClasses(in: fixtureA, excluding: SchoolClass("8a"))
        == [SchoolClass("8b"), SchoolClass("9c")])
  }
}
