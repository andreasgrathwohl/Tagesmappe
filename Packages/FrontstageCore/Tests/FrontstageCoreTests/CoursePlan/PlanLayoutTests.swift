import Foundation
import Testing

@testable import FrontstageCore

private let holidays2026: [NonTeachingPeriod] = [
  NonTeachingPeriod(from: d(2026, 11, 2), to: d(2026, 11, 6), title: "Herbst"),
  NonTeachingPeriod(from: d(2026, 12, 23), to: d(2027, 1, 8), title: "Weihnachten"),
  NonTeachingPeriod(from: d(2027, 3, 26), to: d(2027, 3, 26), title: "Karfreitag"),
  NonTeachingPeriod(from: d(2027, 4, 5), to: d(2027, 4, 5), title: "Ostermontag"),
]

private func uid(_ n: Int) -> UUID {
  UUID(uuidString: String(format: "00000000-0000-0000-0000-%012d", n))!
}

private func at(_ n: Int) -> Date { Date(timeIntervalSince1970: Double(n) * 1000) }

@Suite("CoursePlan Layout") struct PlanLayoutTests {
  @Test("AK-47: Einträge in Woche 8, getrennt nach Halbjahren")
  func entriesLandInTheirWeek() {
    let weeks = TeachingWeekCalculator.weeks(of: year2026(), nonTeachingPeriods: holidays2026)
    let week = PlanWeek(
      id: uid(1), monday: d(2026, 11, 9), position: 0, topic: "Unit 2 – Past tense",
      notes: "8b: Hörverstehen nachholen", updatedAt: at(1))
    let ka = Assessment(
      id: uid(2), monday: d(2026, 11, 9), day: d(2026, 11, 10), kind: .classTest, title: "KA 1",
      updatedAt: at(1))
    let test = Assessment(
      id: uid(3), monday: d(2026, 11, 9), day: nil, kind: .test, title: "Vokabeltest Unit 2",
      updatedAt: at(1))
    let layout = PlanLayouter.layout(weeks: weeks, planWeeks: [week], assessments: [test, ka])
    #expect(layout.first.count == 17 && layout.second.count == 26)
    #expect(layout.first[7].planWeek == week && layout.first[7].assessments == [ka, test])
    #expect(layout.unassignedWeeks.isEmpty && layout.unassignedAssessments.isEmpty)
  }

  @Test("AK-47: Woche fällt weg → nicht zugeordnet")
  func orphanedWeekBecomesUnassigned() {
    let holidays =
      holidays2026 + [
        NonTeachingPeriod(from: d(2026, 11, 9), to: d(2026, 11, 13), title: "Brückenwoche")
      ]
    let weeks = TeachingWeekCalculator.weeks(of: year2026(), nonTeachingPeriods: holidays)
    let week = PlanWeek(
      id: uid(1), monday: d(2026, 11, 9), position: 0, topic: "Unit 2", notes: nil,
      updatedAt: at(1))
    let ka = Assessment(
      id: uid(2), monday: d(2026, 11, 9), day: d(2026, 11, 10), kind: .classTest, title: "KA 1",
      updatedAt: at(1))
    let test = Assessment(
      id: uid(3), monday: d(2026, 11, 9), day: nil, kind: .test, title: "Test", updatedAt: at(1))
    let layout = PlanLayouter.layout(weeks: weeks, planWeeks: [week], assessments: [test, ka])
    #expect(layout.unassignedWeeks == [week])
    #expect(layout.unassignedAssessments == [ka, test])
    #expect(layout.first[7].week.monday == d(2026, 11, 16))
    #expect(layout.first[7].planWeek == nil && layout.first[7].assessments.isEmpty)
  }

  @Test("Nicht zugeordnet: erst ohne Montag nach Position, dann verwaiste nach Datum")
  func unassignedOrder() {
    let weeks = TeachingWeekCalculator.weeks(of: year2026(), nonTeachingPeriods: holidays2026)
    let orphanLate = PlanWeek(
      id: uid(1), monday: d(2026, 11, 2), position: 0, topic: "spät", notes: nil, updatedAt: at(1))
    let orphanEarly = PlanWeek(
      id: uid(2), monday: d(2026, 9, 7), position: 1, topic: "früh", notes: nil, updatedAt: at(1))
    let loose2 = PlanWeek(
      id: uid(3), monday: nil, position: 2, topic: "b", notes: nil, updatedAt: at(1))
    let loose1 = PlanWeek(
      id: uid(4), monday: nil, position: 1, topic: "a", notes: nil, updatedAt: at(1))
    let layout = PlanLayouter.layout(
      weeks: weeks, planWeeks: [orphanLate, orphanEarly, loose2, loose1], assessments: [])
    #expect(layout.unassignedWeeks == [loose1, loose2, orphanEarly, orphanLate])

    let aOrphan = Assessment(
      id: uid(5), monday: d(2026, 11, 2), day: nil, kind: .test, title: "A", updatedAt: at(1))
    let aLoose = Assessment(
      id: uid(6), monday: nil, day: nil, kind: .test, title: "Z", updatedAt: at(1))
    let l2 = PlanLayouter.layout(weeks: weeks, planWeeks: [], assessments: [aOrphan, aLoose])
    #expect(l2.unassignedAssessments == [aLoose, aOrphan])
  }

  @Test("Doppelte Planwoche: die zuletzt geänderte steht in der Woche")
  func duplicateWeekShowsLatest() {
    let weeks = TeachingWeekCalculator.weeks(of: year2026(), nonTeachingPeriods: holidays2026)
    let older = PlanWeek(
      id: uid(1), monday: d(2026, 11, 9), position: 0, topic: "alt", notes: nil, updatedAt: at(1))
    let newer = PlanWeek(
      id: uid(2), monday: d(2026, 11, 9), position: 1, topic: "neu", notes: nil, updatedAt: at(2))
    let layout = PlanLayouter.layout(weeks: weeks, planWeeks: [newer, older], assessments: [])
    #expect(layout.first[7].planWeek == newer)
    #expect(layout.unassignedWeeks == [older])
  }

  @Test("Leistungsnachweise: mit Tag aufsteigend, dann ohne Tag, dann nach Titel")
  func assessmentOrder() {
    let weeks = TeachingWeekCalculator.weeks(of: year2026(), nonTeachingPeriods: holidays2026)
    let m = d(2026, 11, 9)
    let noDayB = Assessment(
      id: uid(1), monday: m, day: nil, kind: .test, title: "B", updatedAt: at(1))
    let noDayA = Assessment(
      id: uid(2), monday: m, day: nil, kind: .test, title: "A", updatedAt: at(1))
    let late = Assessment(
      id: uid(3), monday: m, day: d(2026, 11, 12), kind: .test, title: "C", updatedAt: at(1))
    let early = Assessment(
      id: uid(4), monday: m, day: d(2026, 11, 10), kind: .test, title: "D", updatedAt: at(1))
    let layout = PlanLayouter.layout(
      weeks: weeks, planWeeks: [], assessments: [noDayB, late, noDayA, early])
    #expect(layout.first[7].assessments == [early, late, noDayA, noDayB])
  }

  @Test("Zuweisen behält den Wochentag, wenn er Unterrichtstag ist")
  func assignKeepsWeekdayWhenTeaching() {
    let weeks = TeachingWeekCalculator.weeks(of: year2026(), nonTeachingPeriods: holidays2026)
    let target = weeks.first { $0.monday == d(2026, 11, 16) }!
    let a = Assessment(
      id: uid(1), monday: d(2026, 11, 9), day: d(2026, 11, 10), kind: .classTest, title: "KA",
      updatedAt: at(1))
    let moved = PlanLayouter.assign(a, to: target)
    #expect(moved.monday == d(2026, 11, 16) && moved.day == d(2026, 11, 17))
    #expect(moved.id == a.id && moved.title == a.title)
  }

  @Test("Zuweisen verliert den Tag, wenn er nicht Unterrichtstag ist")
  func assignDropsDayWhenNotTeaching() {
    let short = TeachingWeek(
      number: 14, monday: d(2027, 3, 22), isoWeek: d(2027, 3, 22).isoWeek, term: .second,
      teachingDays: [d(2027, 3, 22), d(2027, 3, 23)])
    let wed = Assessment(
      id: uid(1), monday: d(2026, 11, 9), day: d(2026, 11, 11), kind: .test, title: "T",
      updatedAt: at(1))
    let moved = PlanLayouter.assign(wed, to: short)
    #expect(moved.monday == d(2027, 3, 22) && moved.day == nil)
    #expect(PlanLayouter.isValidDay(d(2027, 3, 23), for: short))
    #expect(!PlanLayouter.isValidDay(d(2027, 3, 24), for: short))
  }

  @Test("Leere Texte werden nil; isEmpty")
  func planWeekNormalizes() {
    let w = PlanWeek(
      id: uid(1), monday: nil, position: 0, topic: "  ", notes: "", updatedAt: at(1))
    #expect(w.topic == nil && w.notes == nil && w.isEmpty)
    let t = PlanWeek(
      id: uid(2), monday: nil, position: 0, topic: " Unit 1 ", notes: nil, updatedAt: at(1))
    #expect(t.topic == "Unit 1" && !t.isEmpty)
  }
}
