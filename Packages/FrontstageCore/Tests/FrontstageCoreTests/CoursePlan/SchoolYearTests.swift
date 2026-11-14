import Testing

@testable import FrontstageCore

@Suite("CoursePlan SchoolYear") struct SchoolYearTests {
  @Test("ISO-Woche: Jahreswechsel und KW 53")
  func isoWeeks() {
    #expect(d(2026, 9, 14).isoWeek == ISOWeek(year: 2026, week: 38))
    #expect(d(2027, 1, 1).isoWeek == ISOWeek(year: 2026, week: 53))
    #expect(d(2026, 1, 1).isoWeek == ISOWeek(year: 2026, week: 1))
    #expect(d(2024, 12, 30).isoWeek == ISOWeek(year: 2025, week: 1))
    #expect(d(2027, 2, 7).isoWeek == ISOWeek(year: 2027, week: 5))  // Sonntag gehört zur laufenden Woche
  }

  @Test("FR-15.1: Schuljahr 2026/27 – Titel, Halbjahre, Grenzen")
  func schoolYearBasics() {
    let y = year2026()
    #expect(y.startYear == 2026 && y.title == "2026/27")
    #expect(y.term(of: d(2027, 1, 29)) == .first && y.term(of: d(2027, 2, 1)) == .second)
    #expect(y.term(of: d(2026, 9, 13)) == nil && y.term(of: d(2027, 7, 29)) == nil)
    #expect(
      SchoolYear(firstDay: d(2099, 9, 1), secondTermStart: d(2100, 2, 1), lastDay: d(2100, 7, 1))
        .title == "2099/00")
  }

  @Test("Prüfung: Reihenfolge der Daten und Überschneidung")
  func schoolYearIssues() {
    #expect(
      SchoolYear(firstDay: d(2026, 9, 14), secondTermStart: d(2027, 2, 1), lastDay: d(2026, 9, 1))
        .issue(among: []) == .lastDayBeforeFirstDay)
    #expect(
      SchoolYear(firstDay: d(2026, 9, 14), secondTermStart: d(2027, 8, 1), lastDay: d(2027, 7, 28))
        .issue(among: []) == .secondTermOutside)
    #expect(
      SchoolYear(firstDay: d(2027, 7, 1), secondTermStart: d(2028, 2, 1), lastDay: d(2028, 7, 1))
        .issue(among: [year2026()]) == .overlaps(startYear: 2026))
    #expect(year2026().issue(among: [year2026(), year2025()]) == nil)  // gleiches startYear wird ersetzt
  }

  @Test("FR-15: Jahrgang aus der ersten Ziffernfolge")
  func gradeFromFirstDigitRun() {
    #expect(GradeLevel.derived(from: SchoolClass("8b"))?.value == 8)
    #expect(GradeLevel.derived(from: SchoolClass("10 a"))?.value == 10)
    #expect(GradeLevel.derived(from: SchoolClass("Q11"))?.value == 11)
    #expect(GradeLevel.derived(from: SchoolClass("EF")) == nil)
    #expect(GradeLevel.derived(from: SchoolClass("K14")) == nil)  // außerhalb 1...13
  }

  @Test("Hand-Jahrgang nur, wo nichts abgeleitet wird")
  func gradeOverrides() {
    #expect(GradeLevel.resolve(SchoolClass("EF"), overrides: ["ef": 11])?.value == 11)
    #expect(GradeLevel.resolve(SchoolClass("8b"), overrides: ["8b": 9])?.value == 8)
    #expect(GradeLevel.resolve(SchoolClass("EF"), overrides: [:]) == nil)
  }
}
