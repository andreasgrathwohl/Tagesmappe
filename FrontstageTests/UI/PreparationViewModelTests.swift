import Foundation
import FrontstageCore
import Testing

@testable import Frontstage

/// Vorbereiten-Logik: Woche Montag bis Freitag, Zuordnen wirkt in der Tagesansicht.
@MainActor @Suite struct PreparationViewModelTests {
  private let data: DataStore
  private let storage = FakeStorage()

  init() throws {
    data = try makeStore()
  }

  private let mon16 = Fixtures.referenceWeekA

  private func makeModel(today: CalendarDay = Fixtures.tue17) -> PreparationViewModel {
    PreparationViewModel(environment: Fixtures.environment(store: data, storage: storage, today: today))
  }

  private func lessonRows(_ content: DayContent) -> [LessonRow] {
    guard case .rows(let rows) = content else { return [] }
    return rows.compactMap { row in
      if case .lesson(let lesson) = row { return lesson }
      return nil
    }
  }

  @Test("Woche beginnt am Montag")
  func weekStartsMonday() {
    let prep = makeModel(today: Fixtures.tue17)
    #expect(prep.weekStart == mon16)
    #expect(prep.days.map(\.date) == (0..<5).map { mon16.adding(days: $0) })
  }

  @Test("Wochenwechsel um sieben Tage, zurück zur laufenden Woche")
  func weekNavigation() {
    let prep = makeModel()
    prep.showNextWeek()
    #expect(prep.weekStart == mon16.adding(days: 7))
    prep.showPreviousWeek()
    prep.showPreviousWeek()
    #expect(prep.weekStart == mon16.adding(days: -7))
    prep.showThisWeek()
    #expect(prep.weekStart == mon16)
  }

  @Test("Samstag erscheint nur mit Stunde oder Material")
  func weekendOnlyWithEntries() throws {
    try Fixtures.seed(data, [Fixtures.entry(.tuesday, 2, "8b", "Englisch")])
    #expect(makeModel().days.count == 5)
    _ = try data.assignItem(
      Fixtures.reference("Samstag.pdf", .pdf), to: Fixtures.key(mon16.adding(days: 5), "8b", "Englisch"),
      at: nil)
    let prep = makeModel()
    #expect(prep.days.count == 6)
    #expect(prep.days.last?.materialsWithoutLesson.map(\.reference.displayName) == ["Samstag.pdf"])
  }

  @Test("AK-4: zugeordnet im Vorbereiten, sichtbar in der Tagesansicht")
  func preparationAssignShowsInDayView() async throws {
    try Fixtures.seed(data, [Fixtures.entry(.tuesday, 2, "8b", "Englisch")])
    let env = Fixtures.environment(store: data, storage: storage, today: mon16)
    let prep = PreparationViewModel(environment: env)
    let key = try #require(lessonRows(prep.days[1].content).first?.lesson.key)
    try await prep.actions.assign(
      fileURLs: [URL(filePath: "/Unterricht/Unit 4 – Präsentation.pptx")], to: key)
    prep.reload()
    #expect(lessonRows(prep.days[1].content).first?.materials.count == 1)

    let dayVM = DayViewModel(environment: env)
    dayVM.day = Fixtures.tue17
    dayVM.reload()
    #expect(
      lessonRows(dayVM.content).first { $0.lesson.period == 2 }?.materials.map(\.item.reference.displayName)
        == ["Unit 4 – Präsentation.pptx"])
  }

  @Test("AK-14: Ferientag mit Material ohne Stunde in der Woche")
  func weekShowsMaterialWithoutLesson() throws {
    try Fixtures.seed(data, [Fixtures.entry(.tuesday, 2, "8b", "Englisch")])
    try data.addNonTeachingPeriod(
      NonTeachingPeriod(
        from: CalendarDay(year: 2026, month: 11, day: 2), to: CalendarDay(year: 2026, month: 11, day: 6),
        title: "Herbstferien"))
    _ = try data.assignItem(
      Fixtures.reference("Arbeitsblatt Vokabeln", .pdf), to: Fixtures.key(.nov3, "8b", "Englisch"),
      at: nil)
    let prep = makeModel(today: CalendarDay(year: 2026, month: 11, day: 2))
    #expect(prep.days[1].content == .nonTeachingDay(title: "Herbstferien"))
    #expect(prep.days[1].materialsWithoutLesson.map(\.reference.displayName) == ["Arbeitsblatt Vokabeln"])
  }

  @Test("Zuordnungsziele: Stunden ab heute ohne Ausfälle")
  func upcomingLessonsSkipCancelled() throws {
    try Fixtures.seed(
      data,
      [Fixtures.entry(.tuesday, 2, "8b", "Englisch"), Fixtures.entry(.wednesday, 1, "9c", "Englisch")])
    try data.markCancelled(Fixtures.key(.wed18, "9c", "Englisch"))
    let lessons = makeModel().upcomingLessons(days: 3)
    #expect(lessons.map(\.period) == [2])
    #expect(lessons.first?.key.date == Fixtures.tue17)
  }
}
