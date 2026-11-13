import Foundation
import Testing
@testable import FrontstageCore

@Suite("WeekVariant")
struct WeekVariantTests {
  private func twoWeekTimetable(reference: CalendarDay) -> Timetable {
    Timetable(weekVariantCount: 2, referenceWeekA: reference)
  }

  @Test("A- und B-Woche wechseln ab der Bezugswoche (AK-2)")
  func weekVariantAlternatesFromReference() {
    let tt = twoWeekTimetable(reference: d(2026, 11, 16))
    #expect(TimetableCalculator.weekVariant(for: d(2026, 11, 16), timetable: tt) == .a)
    #expect(TimetableCalculator.weekVariant(for: d(2026, 11, 23), timetable: tt) == .b)
    #expect(TimetableCalculator.weekVariant(for: d(2026, 11, 30), timetable: tt) == .a)
    #expect(TimetableCalculator.weekVariant(for: d(2026, 11, 22), timetable: tt) == .a)
  }

  @Test("Wochen vor der Bezugswoche werden abgerundet, nicht abgeschnitten (AK-2)")
  func weekVariantBeforeReference() {
    let tt = twoWeekTimetable(reference: d(2026, 11, 16))
    #expect(TimetableCalculator.weekVariant(for: d(2026, 11, 9), timetable: tt) == .b)
    #expect(TimetableCalculator.weekVariant(for: d(2026, 11, 2), timetable: tt) == .a)
  }

  @Test("Bezugswoche gilt auch, wenn der Bezugstag kein Montag ist (AK-2)")
  func referenceWeekNotMonday() {
    let tt = twoWeekTimetable(reference: d(2026, 11, 18))
    #expect(TimetableCalculator.weekVariant(for: d(2026, 11, 16), timetable: tt) == .a)
    #expect(TimetableCalculator.weekVariant(for: d(2026, 11, 23), timetable: tt) == .b)
  }

  @Test("Bei einer Variante gibt es keine Wochenvariante (AK-2)")
  func singleVariantHasNoWeekVariant() {
    let tt = Timetable(weekVariantCount: 1, referenceWeekA: d(2026, 11, 16))
    #expect(TimetableCalculator.weekVariant(for: d(2026, 11, 16), timetable: tt) == nil)
  }

  @Test("Unterrichtsfreie Zeit schließt beide Enden ein (AK-2)")
  func nonTeachingPeriodIsInclusive() {
    let p = NonTeachingPeriod(from: d(2026, 11, 2), to: d(2026, 11, 6), title: "Ferien")
    #expect(p.contains(d(2026, 11, 2)))
    #expect(p.contains(d(2026, 11, 6)))
    #expect(!p.contains(d(2026, 11, 1)))
    #expect(!p.contains(d(2026, 11, 7)))
  }

  @Test("Leerer Stundenplan hat keine Stunden und keine Variante (AK-2)")
  func emptyTimetableHasNoLessons() {
    #expect(Timetable.empty.entries.isEmpty)
    #expect(Timetable.empty.weekVariantCount == 1)
    #expect(TimetableCalculator.weekVariant(for: d(2026, 11, 16), timetable: .empty) == nil)
  }

  @Test("Stundenplan übersteht die JSON-Rundreise (AK-2)")
  func timetableCodableRoundTrip() throws {
    let entry = TimetableEntry(
      weekVariant: .b, weekday: .tuesday, period: 2, schoolClass: SchoolClass("8b"),
      subject: Subject("Englisch"))
    let tt = Timetable(
      weekVariantCount: 2, referenceWeekA: d(2026, 11, 16),
      bellSchedule: BellSchedule(periods: [2: t(8, 35)...t(9, 20)]), entries: [entry])
    let data = try JSONEncoder().encode(tt)
    let back = try JSONDecoder().decode(Timetable.self, from: data)
    #expect(back.bellSchedule == tt.bellSchedule)
    #expect(back.entries == tt.entries)
  }
}
