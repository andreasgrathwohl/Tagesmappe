import Testing

@testable import FrontstageCore

/// Synthetische unterrichtsfreie Zeiten 2026/27: Herbstferien-Woche, Weihnachten 23.12.–8.1.,
/// dazu Einzeltage im zweiten Halbjahr, die keine Woche leeren.
private let holidays2026: [NonTeachingPeriod] = [
  NonTeachingPeriod(from: d(2026, 11, 2), to: d(2026, 11, 6), title: "Herbst"),
  NonTeachingPeriod(from: d(2026, 12, 23), to: d(2027, 1, 8), title: "Weihnachten"),
  NonTeachingPeriod(from: d(2027, 3, 26), to: d(2027, 3, 26), title: "Karfreitag"),
  NonTeachingPeriod(from: d(2027, 4, 5), to: d(2027, 4, 5), title: "Ostermontag"),
]

/// Synthetische unterrichtsfreie Zeiten 2025/26: eine freie Herbstwoche, Weihnachten ohne leere Woche.
private let holidays2025: [NonTeachingPeriod] = [
  NonTeachingPeriod(from: d(2025, 11, 3), to: d(2025, 11, 7), title: "Herbst"),
  NonTeachingPeriod(from: d(2025, 12, 24), to: d(2026, 1, 1), title: "Weihnachten"),
]

@Suite("CoursePlan TeachingWeeks") struct TeachingWeekTests {
  @Test("AK-46: 2026/27 hat 43 Unterrichtswochen, 17 + 26")
  func schoolYear2026() {
    let weeks = TeachingWeekCalculator.weeks(of: year2026(), nonTeachingPeriods: holidays2026)
    #expect(weeks.count == 43)
    #expect(
      weeks.filter { $0.term == .first }.count == 17
        && weeks.filter { $0.term == .second }.count == 26)
    #expect(
      weeks[0].number == 1 && weeks[0].monday == d(2026, 9, 14)
        && weeks[0].isoWeek == ISOWeek(year: 2026, week: 38))
    #expect(
      !weeks.contains { [d(2026, 11, 2), d(2026, 12, 28), d(2027, 1, 4)].contains($0.monday) })
    #expect(
      weeks[13].monday == d(2026, 12, 21)
        && weeks[13].teachingDays == [d(2026, 12, 21), d(2026, 12, 22)])
    #expect(weeks[17].number == 18 && weeks[17].monday == d(2027, 2, 1) && weeks[17].term == .second)
    #expect(weeks.last?.teachingDays == [d(2027, 7, 26), d(2027, 7, 27), d(2027, 7, 28)])
  }

  @Test("2025/26 hat 45 Unterrichtswochen")
  func schoolYear2025() {
    let weeks = TeachingWeekCalculator.weeks(of: year2025(), nonTeachingPeriods: holidays2025)
    #expect(weeks.count == 45)
    #expect(weeks[7].number == 8 && weeks[7].monday == d(2025, 11, 10))
  }

  @Test("Beginn am Mittwoch: Woche 1 zählt ab dem ersten Schultag")
  func midweekStartCountsFromFirstDay() {
    let year = SchoolYear(
      firstDay: d(2026, 9, 16), secondTermStart: d(2027, 2, 1), lastDay: d(2027, 7, 28))
    let weeks = TeachingWeekCalculator.weeks(of: year, nonTeachingPeriods: [])
    #expect(weeks[0].number == 1 && weeks[0].monday == d(2026, 9, 14))
    #expect(weeks[0].teachingDays == [d(2026, 9, 16), d(2026, 9, 17), d(2026, 9, 18)])
  }

  @Test("Woche des Halbjahreswechsels gehört zum Halbjahr ihres ersten Unterrichtstags")
  func termOfSplitWeekFollowsFirstTeachingDay() {
    var year = SchoolYear(
      firstDay: d(2026, 9, 14), secondTermStart: d(2027, 2, 3), lastDay: d(2027, 7, 28))
    var weeks = TeachingWeekCalculator.weeks(of: year, nonTeachingPeriods: [])
    #expect(weeks.first { $0.monday == d(2027, 2, 1) }?.term == .first)

    year.secondTermStart = d(2027, 2, 2)
    let mondayFree = [NonTeachingPeriod(from: d(2027, 2, 1), to: d(2027, 2, 1), title: "Frei")]
    weeks = TeachingWeekCalculator.weeks(of: year, nonTeachingPeriods: mondayFree)
    #expect(weeks.first { $0.monday == d(2027, 2, 1) }?.term == .second)
  }

  @Test("Wochenende und Zeiträume außerhalb des Schuljahrs zählen nicht")
  func weekendsAndOutsideDays() {
    let year = year2026()
    #expect(!TeachingWeekCalculator.isTeachingDay(d(2026, 9, 19), in: year, nonTeachingPeriods: holidays2026))
    #expect(!TeachingWeekCalculator.isTeachingDay(d(2026, 11, 2), in: year, nonTeachingPeriods: holidays2026))
    #expect(!TeachingWeekCalculator.isTeachingDay(d(2026, 9, 13), in: year, nonTeachingPeriods: holidays2026))
    #expect(TeachingWeekCalculator.isTeachingDay(d(2026, 9, 15), in: year, nonTeachingPeriods: holidays2026))
  }
}
