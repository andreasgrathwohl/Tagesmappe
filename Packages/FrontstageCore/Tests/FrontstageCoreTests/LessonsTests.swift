import Foundation
import Testing
@testable import FrontstageCore

@Suite("Lessons")
struct LessonsTests {
  private func lessons(
    _ day: CalendarDay, _ tt: Timetable, nonTeaching: [NonTeachingPeriod] = [],
    changes: [ScheduleChange] = []
  ) -> [Lesson] {
    TimetableCalculator.lessons(
      on: day, timetable: tt, nonTeachingPeriods: nonTeaching, changes: changes)
  }

  private func key(_ day: CalendarDay, _ cls: String, _ subject: String, _ ordinal: Int)
    -> LessonKey
  {
    LessonKey(
      date: day, schoolClass: SchoolClass(cls), subject: Subject(subject), ordinal: ordinal)
  }

  @Test("Eintrag erscheint jeden Dienstag (AK-1)")
  func entryAppearsEveryTuesday() {
    let tt = timetable([entry(.tuesday, 2, "8b", "Englisch")])
    for day in [d(2026, 11, 17), d(2026, 11, 24), d(2027, 1, 12)] {
      let result = lessons(day, tt)
      #expect(result.count == 1)
      #expect(result.first?.period == 2)
      #expect(result.first?.key.schoolClass == SchoolClass("8b"))
      #expect(result.first?.key.subject.display == "Englisch")
      #expect(result.first?.key.ordinal == 1)
      #expect(result.first?.isCancelled == false)
    }
    #expect(lessons(d(2026, 11, 18), tt).isEmpty)
  }

  @Test("Wochenvariante wählt die Einträge (AK-2)")
  func weekVariantSelectsEntries() {
    let tt = timetable(
      [
        entry(.monday, 1, "7a", "Mathe", variant: .a),
        entry(.monday, 1, "9c", "Mathe", variant: .b),
      ], variants: 2)
    #expect(lessons(d(2026, 11, 16), tt).map(\.key.schoolClass) == [SchoolClass("7a")])
    #expect(lessons(d(2026, 11, 23), tt).map(\.key.schoolClass) == [SchoolClass("9c")])
  }

  @Test("Eintrag ohne Variante gilt in beiden Wochen (AK-2)")
  func entryWithoutVariantAppliesToBothWeeks() {
    let tt = timetable([entry(.monday, 3, "8a", "Deutsch")], variants: 2)
    #expect(lessons(d(2026, 11, 16), tt).count == 1)
    #expect(lessons(d(2026, 11, 23), tt).count == 1)
  }

  @Test("Zeitraster setzt die Zeit (AK-42)")
  func bellScheduleSetsTime() {
    let entries = [entry(.tuesday, 2, "8b", "Englisch")]
    #expect(lessons(d(2026, 11, 17), timetable(entries)).first?.time == nil)
    let tt = timetable(entries, bell: [2: t(8, 35)...t(9, 20)])
    #expect(lessons(d(2026, 11, 17), tt).first?.time == t(8, 35)...t(9, 20))
  }

  @Test("Lückenhaftes Zeitraster behält die Stunde (AK-42)")
  func incompleteBellScheduleKeepsLesson() {
    let tt = timetable(
      [entry(.tuesday, 1, "8b", "Englisch"), entry(.tuesday, 3, "8a", "Mathe")],
      bell: [1: t(7, 45)...t(8, 30)])
    let result = lessons(d(2026, 11, 17), tt)
    #expect(result.map(\.period) == [1, 3])
    #expect(result[0].time != nil)
    #expect(result[1].time == nil)
  }

  @Test("Stunden sind nach Stundennummer sortiert (AK-1)")
  func lessonsSortedByPeriod() {
    let tt = timetable([
      entry(.tuesday, 5, "8a", "Mathe"), entry(.tuesday, 1, "8b", "Englisch"),
      entry(.tuesday, 3, "9c", "Physik"),
    ])
    #expect(lessons(d(2026, 11, 17), tt).map(\.period) == [1, 3, 5])
  }

  @Test("Unterrichtsfreie Zeit hat keine Stunden, auch keine Vertretung (AK-14)")
  func nonTeachingDayHasNoLessons() {
    let tt = timetable([entry(.tuesday, 2, "8b", "Englisch")])
    let holidays = [
      NonTeachingPeriod(from: d(2026, 11, 2), to: d(2026, 11, 6), title: "Herbstferien")
    ]
    let sub = ScheduleChange.substituteLesson(
      date: d(2026, 11, 3), period: 4, schoolClass: SchoolClass("6c"), subject: Subject("Mathe"),
      .manual)
    #expect(lessons(d(2026, 11, 3), tt, nonTeaching: holidays, changes: [sub]).isEmpty)
    #expect(lessons(d(2026, 11, 10), tt, nonTeaching: holidays).count == 1)
  }

  @Test("Ausfall markiert die Stunde, bleibt in der Liste (AK-15)")
  func cancellationMarksLesson() {
    let tt = timetable([entry(.tuesday, 2, "8b", "Englisch")])
    let cancel = ScheduleChange.cancellation(key(d(2026, 11, 17), "8b", "Englisch", 1), .manual)
    let hit = lessons(d(2026, 11, 17), tt, changes: [cancel])
    #expect(hit.count == 1)
    #expect(hit[0].isCancelled)
    #expect(hit[0].cancellationOrigin == .manual)
    #expect(lessons(d(2026, 11, 24), tt, changes: [cancel])[0].isCancelled == false)
  }

  @Test("Liegen beide Herkünfte vor, gilt manuell (AK-15)")
  func manualCancellationWins() {
    let tt = timetable([entry(.tuesday, 2, "8b", "Englisch")])
    let k = key(d(2026, 11, 17), "8b", "Englisch", 1)
    let changes: [ScheduleChange] = [.cancellation(k, .source), .cancellation(k, .manual)]
    #expect(lessons(d(2026, 11, 17), tt, changes: changes)[0].cancellationOrigin == .manual)
    #expect(
      lessons(d(2026, 11, 17), tt, changes: changes.reversed())[0].cancellationOrigin == .manual)
  }

  @Test("Vertretungsstunde nur an ihrem Datum (AK-16)")
  func substituteLessonOnlyOnItsDate() {
    let tt = timetable([])
    let sub = ScheduleChange.substituteLesson(
      date: d(2026, 11, 18), period: 4, schoolClass: SchoolClass("6c"), subject: Subject("Mathe"),
      .manual)
    let hit = lessons(d(2026, 11, 18), tt, changes: [sub])
    #expect(hit.count == 1)
    #expect(hit[0].isSubstituteLesson)
    #expect(hit[0].period == 4)
    #expect(hit[0].key.schoolClass == SchoolClass("6c"))
    #expect(lessons(d(2026, 11, 25), tt, changes: [sub]).isEmpty)
  }

  @Test("Doppelstunde zählt laufende Nummern je Klasse und Fach (AK-1)")
  func doubleLessonOrdinals() {
    let tt = timetable([
      entry(.tuesday, 3, "8b", "Englisch"), entry(.tuesday, 4, "8b", "Englisch"),
      entry(.tuesday, 6, "8a", "Englisch"),
    ])
    #expect(lessons(d(2026, 11, 17), tt).map(\.key.ordinal) == [1, 2, 1])
  }

  @Test("Vertretung verschiebt die Nummer regulärer Stunden nicht (ADR-0005)")
  func substituteDoesNotShiftRegularOrdinal() {
    let tt = timetable([entry(.tuesday, 2, "8b", "Englisch")])
    let sub = ScheduleChange.substituteLesson(
      date: d(2026, 11, 17), period: 1, schoolClass: SchoolClass("8b"),
      subject: Subject("Englisch"), .manual)
    let result = lessons(d(2026, 11, 17), tt, changes: [sub])
    #expect(result.map(\.period) == [1, 2])
    #expect(result[1].key.ordinal == 1)
    #expect(result[1].isSubstituteLesson == false)
    #expect(result[0].key.ordinal == 2)
    #expect(result[0].isSubstituteLesson)
  }

  @Test("Gleiche Stunde und Klasse: Reihenfolge nach Fach, dann laufender Nummer (AK-1)")
  func sameSlotOrderedBySubjectThenOrdinal() {
    let entries = [
      entry(.tuesday, 2, "8b", "Mathe"), entry(.tuesday, 2, "8b", "Englisch"),
      entry(.tuesday, 2, "8b", "Mathe"),
    ]
    for tt in [timetable(entries), timetable(entries.reversed())] {
      let result = lessons(d(2026, 11, 17), tt)
      #expect(result.map(\.key.subject.normalized) == ["englisch", "mathe", "mathe"])
      #expect(result.map(\.key.ordinal) == [1, 1, 2])
    }
  }

  @Test("Doppelte Vertretung wird zu einer Stunde (AK-16)")
  func duplicateSubstitutesCollapse() {
    let tt = timetable([])
    func sub(_ origin: Origin) -> ScheduleChange {
      .substituteLesson(
        date: d(2026, 11, 18), period: 4, schoolClass: SchoolClass("6c"),
        subject: Subject("Mathe"), origin)
    }
    #expect(lessons(d(2026, 11, 18), tt, changes: [sub(.manual), sub(.source)]).count == 1)
  }
}
