import Foundation
import Testing
@testable import FrontstageCore

@Suite("ClassScreen")
struct ClassScreenTests {
  private let bell: [Int: ClosedRange<TimeOfDay>] = [
    2: t(8, 35)...t(9, 20), 4: t(10, 30)...t(11, 15),
  ]
  private let tuesday = d(2026, 11, 17)

  private var plan: Timetable {
    timetable(
      [entry(.tuesday, 2, "8b", "Englisch"), entry(.tuesday, 4, "9c", "Deutsch")], bell: bell)
  }

  private func lessons(cancelGerman: Bool) -> [Lesson] {
    let germanKey = LessonKey(
      date: tuesday, schoolClass: SchoolClass("9c"), subject: Subject("Deutsch"), ordinal: 1)
    let changes: [ScheduleChange] = cancelGerman ? [.cancellation(germanKey, .manual)] : []
    return TimetableCalculator.lessons(
      on: tuesday, timetable: plan, nonTeachingPeriods: [], changes: changes)
  }

  private func lesson(_ cls: String, in all: [Lesson]) -> Lesson {
    all.first { $0.key.schoolClass == SchoolClass(cls) }!
  }

  @Test("Phasen folgen dem Stundenverlauf (AK-36)")
  func phasesFollowLessonCourse() {
    let all = lessons(cancelGerman: true)
    let l8b = lesson("8b", in: all)
    #expect(ClassScreenCalculator.phase(now: t(8, 31), lessons: all) == .upcoming(l8b))
    #expect(ClassScreenCalculator.phase(now: t(8, 40), lessons: all) == .inLesson(l8b))
    #expect(ClassScreenCalculator.phase(now: t(9, 16), lessons: all) == .finalMinutes(l8b))
    #expect(ClassScreenCalculator.phase(now: t(9, 30), lessons: all) == .noMoreLessons)
  }

  @Test("Nur eine laufende Stunde ist die aktuelle, nicht die nächste (FR-11.3)")
  func runningLessonKeyOnlyWhileRunning() {
    let all = lessons(cancelGerman: true)
    let l8b = lesson("8b", in: all)
    #expect(ClassScreenCalculator.phase(now: t(8, 31), lessons: all).runningLessonKey == nil)
    #expect(ClassScreenCalculator.phase(now: t(8, 40), lessons: all).runningLessonKey == l8b.key)
    #expect(ClassScreenCalculator.phase(now: t(9, 16), lessons: all).runningLessonKey == l8b.key)
    #expect(ClassScreenCalculator.phase(now: t(9, 30), lessons: all).runningLessonKey == nil)
  }

  @Test("Laufende Stunde liefert das Ende zur Anzeige (AK-42)")
  func inLessonShowsEndTime() {
    let all = lessons(cancelGerman: true)
    guard case let .inLesson(l) = ClassScreenCalculator.phase(now: t(8, 40), lessons: all) else {
      Issue.record("Erwartet .inLesson")
      return
    }
    #expect(l.time?.upperBound == t(9, 20))
  }

  @Test("Grenzzeiten: Beginn zählt dazu, Ende nicht (AK-36)")
  func boundaryTimes() {
    let all = lessons(cancelGerman: true)
    let l8b = lesson("8b", in: all)
    #expect(ClassScreenCalculator.phase(now: t(8, 35), lessons: all) == .inLesson(l8b))
    #expect(ClassScreenCalculator.phase(now: t(9, 15), lessons: all) == .finalMinutes(l8b))
    #expect(ClassScreenCalculator.phase(now: t(9, 20), lessons: all) == .noMoreLessons)
  }

  @Test("In der Pause erscheint die nächste Stunde (AK-36)")
  func breakShowsNextLesson() {
    let all = lessons(cancelGerman: false)
    let l9c = lesson("9c", in: all)
    #expect(ClassScreenCalculator.phase(now: t(9, 20), lessons: all) == .upcoming(l9c))
    #expect(ClassScreenCalculator.phase(now: t(10, 0), lessons: all) == .upcoming(l9c))
  }

  @Test("Stunden ohne Zeit werden ignoriert (AK-36)")
  func lessonsWithoutTimeAreIgnored() {
    let noTime = timetable([entry(.tuesday, 7, "8b", "Englisch")], bell: bell)
    let all = TimetableCalculator.lessons(
      on: tuesday, timetable: noTime, nonTeachingPeriods: [], changes: [])
    #expect(all.count == 1 && all[0].time == nil)
    for now in [t(0, 0), t(8, 40), t(23, 59)] {
      #expect(ClassScreenCalculator.phase(now: now, lessons: all) == .noMoreLessons)
    }
  }

  @Test("Ohne Stunden gibt es keine weitere Stunde (AK-36)")
  func emptyDayHasNoMoreLessons() {
    #expect(ClassScreenCalculator.phase(now: t(8, 40), lessons: []) == .noMoreLessons)
  }

  @Test("Schlussminuten sind einstellbar (AK-36)")
  func finalMinutesParameter() {
    let all = lessons(cancelGerman: true)
    let l8b = lesson("8b", in: all)
    #expect(
      ClassScreenCalculator.phase(now: t(9, 10), lessons: all, finalMinutes: 10)
        == .finalMinutes(l8b))
    #expect(ClassScreenCalculator.phase(now: t(9, 10), lessons: all) == .inLesson(l8b))
  }
}
