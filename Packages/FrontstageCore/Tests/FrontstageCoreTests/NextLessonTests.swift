import Foundation
import Testing
@testable import FrontstageCore

@Suite("NextLesson")
struct NextLessonTests {
  private let fixture = timetable([
    entry(.tuesday, 2, "8b", "Englisch"),
    entry(.wednesday, 1, "8b", "Mathe"),
    entry(.thursday, 3, "8b", "Englisch"),
    entry(.tuesday, 6, "8a", "Englisch"),
  ])

  private func key(_ day: CalendarDay, _ cls: String, _ subject: String, _ ordinal: Int)
    -> LessonKey
  {
    LessonKey(
      date: day, schoolClass: SchoolClass(cls), subject: Subject(subject), ordinal: ordinal)
  }

  private var tue: LessonKey { key(d(2026, 11, 17), "8b", "Englisch", 1) }

  private func next(
    _ from: LessonKey, _ tt: Timetable? = nil, nonTeaching: [NonTeachingPeriod] = [],
    changes: [ScheduleChange] = [], maxDays: Int = 28
  ) -> LessonKey? {
    TimetableCalculator.nextLesson(
      after: from, timetable: tt ?? fixture, nonTeachingPeriods: nonTeaching, changes: changes,
      maxDays: maxDays)
  }

  @Test("Nächste Stunde derselben Klasse und Fachs ist der Donnerstag (AK-8)")
  func nextLessonIsThursday() {
    #expect(next(tue) == key(d(2026, 11, 19), "8b", "Englisch", 1))
  }

  @Test("Ausgefallene Ausgangsstunde ändert das Ergebnis nicht (AK-15)")
  func nextLessonSkipsCancelledSource() {
    let changes: [ScheduleChange] = [.cancellation(tue, .manual)]
    #expect(next(tue, changes: changes) == key(d(2026, 11, 19), "8b", "Englisch", 1))
  }

  @Test("Ausgefallene Zielstunde wird übersprungen")
  func nextLessonSkipsCancelledTarget() {
    let changes: [ScheduleChange] = [
      .cancellation(tue, .manual),
      .cancellation(key(d(2026, 11, 19), "8b", "Englisch", 1), .source),
    ]
    #expect(next(tue, changes: changes) == key(d(2026, 11, 24), "8b", "Englisch", 1))
  }

  @Test("Ferien werden übersprungen, Ausgangsschlüssel ohne Stunde funktioniert (AK-14)")
  func nextLessonSkipsHolidays() {
    let holidays = [
      NonTeachingPeriod(from: d(2026, 11, 2), to: d(2026, 11, 6), title: "Herbstferien")
    ]
    let inHolidays = key(d(2026, 11, 3), "8b", "Englisch", 1)
    #expect(
      next(inHolidays, nonTeaching: holidays) == key(d(2026, 11, 10), "8b", "Englisch", 1))
  }

  @Test("In einer Doppelstunde folgt die zweite Stunde desselben Tages")
  func nextLessonWithinDoubleLesson() {
    let tt = timetable([
      entry(.tuesday, 3, "8b", "Englisch"), entry(.tuesday, 4, "8b", "Englisch"),
    ])
    let first = key(d(2026, 11, 17), "8b", "Englisch", 1)
    #expect(next(first, tt) == key(d(2026, 11, 17), "8b", "Englisch", 2))
  }

  @Test("Eine Vertretungsstunde kann die nächste Stunde sein")
  func nextLessonCanBeSubstitute() {
    let changes: [ScheduleChange] = [
      .substituteLesson(
        date: d(2026, 11, 18), period: 5, schoolClass: SchoolClass("8b"),
        subject: Subject("Englisch"), .manual)
    ]
    #expect(next(tue, changes: changes) == key(d(2026, 11, 18), "8b", "Englisch", 1))
  }

  /// Vertretung Di 1. Stunde 8b Englisch: Sie bekommt Nummer 2, liegt aber vor der regulären
  /// 2. Stunde mit Nummer 1 – Nummernfolge ist hier nicht Zeitfolge.
  private var earlySubstitute: [ScheduleChange] {
    [
      .substituteLesson(
        date: d(2026, 11, 17), period: 1, schoolClass: SchoolClass("8b"),
        subject: Subject("Englisch"), .manual)
    ]
  }

  @Test("Nach der regulären Stunde zählt eine frühere Vertretung desselben Tages nicht (AK-8)")
  func nextLessonAfterRegularSkipsEarlierSubstitute() {
    #expect(next(tue, changes: earlySubstitute) == key(d(2026, 11, 19), "8b", "Englisch", 1))
  }

  @Test("Nach einer frühen Vertretung folgt die spätere reguläre Stunde desselben Tages (AK-8)")
  func nextLessonAfterSubstituteIsLaterRegular() {
    let substitute = key(d(2026, 11, 17), "8b", "Englisch", 2)
    #expect(next(substitute, changes: earlySubstitute) == tue)
  }

  @Test("maxDays ist die Grenze: zwei Tage entfernt braucht maxDays 2")
  func nextLessonRespectsMaxDaysBoundary() {
    #expect(next(tue, maxDays: 1) == nil)
    #expect(next(tue, maxDays: 2) == key(d(2026, 11, 19), "8b", "Englisch", 1))
  }

  @Test("Jenseits von maxDays gibt es kein Ergebnis")
  func nextLessonNilBeyondMaxDays() {
    let off = [
      NonTeachingPeriod(from: d(2026, 11, 18), to: d(2026, 12, 31), title: "Unterrichtsfrei")
    ]
    #expect(next(tue, nonTeaching: off) == nil)
  }
}
