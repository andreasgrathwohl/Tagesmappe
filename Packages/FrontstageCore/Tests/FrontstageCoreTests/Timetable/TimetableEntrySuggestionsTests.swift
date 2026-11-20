import Testing
@testable import FrontstageCore

@Suite("Timetable Entry Suggestions (FR-1.3)")
struct TimetableEntrySuggestionsTests {
  private func entry(_ day: Weekday, _ period: Int, _ cls: String, _ subject: String) -> TimetableEntry {
    TimetableEntry(weekday: day, period: period, schoolClass: SchoolClass(cls), subject: Subject(subject))
  }

  private var sample: [TimetableEntry] {
    [
      entry(.monday, 1, "8b", "Englisch"),
      entry(.monday, 2, "8b", "Englisch"),
      entry(.monday, 3, "9c", "Deutsch"),
      entry(.tuesday, 1, "8b", "Deutsch"),
      entry(.tuesday, 2, "9c", "Englisch"),
      entry(.tuesday, 3, "9c", "Englisch"),
      entry(.wednesday, 1, "10a", "Deutsch"),
    ]
  }

  @Test("Klassen nach Häufigkeit, bei Gleichstand alphabetisch, ohne Doppelte")
  func classesByFrequency() {
    let result = TimetableEntrySuggestions.classes(in: sample, matching: "")
    #expect(result.map(\.normalized) == ["8b", "9c", "10a"])
  }

  @Test("Klassen gefiltert auf den Anfang der Eingabe, normalisiert")
  func classesFiltered() {
    #expect(TimetableEntrySuggestions.classes(in: sample, matching: " 9").map(\.normalized) == ["9c"])
    #expect(TimetableEntrySuggestions.classes(in: sample, matching: "1").map(\.normalized) == ["10a"])
  }

  @Test("Genau getippte Klasse entfällt")
  func exactClassOmitted() {
    #expect(TimetableEntrySuggestions.classes(in: sample, matching: "8B").isEmpty)
  }

  @Test("Höchstens acht Vorschläge")
  func limit() {
    let many = (1...12).map { entry(.monday, $0, "\($0)a", "Fach \($0)") }
    #expect(TimetableEntrySuggestions.classes(in: many, matching: "").count == 8)
    #expect(TimetableEntrySuggestions.subjects(in: many, forClass: nil, matching: "").count == 8)
  }

  @Test("Fächer der eingegebenen Klasse zuerst, dann die übrigen")
  func subjectsOfClassFirst() {
    // 8b: Englisch 2×, Deutsch 1×. Insgesamt: Englisch 4×, Deutsch 3×.
    let for10a = TimetableEntrySuggestions.subjects(in: sample, forClass: SchoolClass("10a"), matching: "")
    #expect(for10a.map(\.display) == ["Deutsch", "Englisch"])
    let none = TimetableEntrySuggestions.subjects(in: sample, forClass: nil, matching: "")
    #expect(none.map(\.display) == ["Englisch", "Deutsch"])
  }

  @Test("Fächer gefiltert, genau getipptes Fach entfällt")
  func subjectsFiltered() {
    #expect(
      TimetableEntrySuggestions.subjects(in: sample, forClass: nil, matching: "de").map(\.display)
        == ["Deutsch"])
    #expect(TimetableEntrySuggestions.subjects(in: sample, forClass: nil, matching: "deutsch ").isEmpty)
  }

  @Test("Angezeigt wird die häufigste Schreibweise eines Fachs")
  func mostCommonSpelling() {
    let entries = [
      entry(.monday, 1, "8b", "Mathe"), entry(.monday, 2, "8b", "mathe"), entry(.monday, 3, "8b", "Mathe"),
    ]
    #expect(
      TimetableEntrySuggestions.subjects(in: entries, forClass: nil, matching: "").map(\.display)
        == ["Mathe"])
  }
}

@Suite("Timetable Grid Navigation (FR-1.3)")
struct TimetableGridNavigationTests {
  private let days: [Weekday] = [.monday, .tuesday, .wednesday]
  private let periods = [1, 2, 3]

  @Test("Nächste Stunde am selben Tag")
  func nextPeriodSameDay() {
    let slot = TimetableGridNavigation.nextFreeSlot(
      after: .monday, period: 1, weekdays: days, periods: periods, isOccupied: { _, _ in false })
    #expect(slot == .init(weekday: .monday, period: 2))
  }

  @Test("Belegte Felder werden übersprungen, danach der nächste Tag ab der ersten Stunde")
  func skipsOccupiedAndWraps() {
    let occupied: Set<String> = ["1-3", "2-1"]
    let slot = TimetableGridNavigation.nextFreeSlot(
      after: .monday, period: 2, weekdays: days, periods: periods,
      isOccupied: { occupied.contains("\($0.rawValue)-\($1)") })
    #expect(slot == .init(weekday: .tuesday, period: 2))
  }

  @Test("Kein freies Feld mehr: nil")
  func noneLeft() {
    let slot = TimetableGridNavigation.nextFreeSlot(
      after: .tuesday, period: 3, weekdays: days, periods: periods,
      isOccupied: { day, _ in day == .wednesday })
    #expect(slot == nil)
  }

  @Test("Ausgangsfeld außerhalb des Rasters: weiter ab der nächsten größeren Stunde")
  func startOutsideGrid() {
    let slot = TimetableGridNavigation.nextFreeSlot(
      after: .monday, period: 0, weekdays: days, periods: periods, isOccupied: { _, _ in false })
    #expect(slot == .init(weekday: .monday, period: 1))
  }
}

@Suite("Timetable Entry Copy (FR-1.3)")
struct TimetableEntryCopyTests {
  private func entry(_ day: Weekday, _ period: Int, _ cls: String, _ variant: WeekVariant? = nil)
    -> TimetableEntry
  {
    TimetableEntry(
      weekVariant: variant, weekday: day, period: period, schoolClass: SchoolClass(cls),
      subject: Subject("Englisch"))
  }

  @Test("Freie Tage bekommen eine Kopie, belegte werden gemeldet, der eigene Tag entfällt")
  func copiesToFreeDays() {
    let source = entry(.monday, 2, "8b")
    let existing = [source, entry(.wednesday, 2, "9c")]
    let plan = TimetableEntryCopy.plan(
      copying: source, to: [.monday, .tuesday, .wednesday, .thursday], existing: existing)
    #expect(plan.additions == [entry(.tuesday, 2, "8b"), entry(.thursday, 2, "8b")])
    #expect(plan.occupied == [.wednesday])
  }

  @Test("A-Woche kollidiert nicht mit einem B-Eintrag, wohl aber mit einem Eintrag ohne Woche")
  func weekVariants() {
    let source = entry(.monday, 1, "7a", .a)
    let existing = [source, entry(.tuesday, 1, "9c", .b), entry(.wednesday, 1, "9c")]
    let plan = TimetableEntryCopy.plan(copying: source, to: [.tuesday, .wednesday], existing: existing)
    #expect(plan.additions == [entry(.tuesday, 1, "7a", .a)])
    #expect(plan.occupied == [.wednesday])
  }
}
