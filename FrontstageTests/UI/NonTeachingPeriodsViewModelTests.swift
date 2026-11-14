import FrontstageCore
import Testing

@testable import Frontstage

/// Unterrichtsfreie Zeiträume und Material ohne Stunde (FR-7).
@MainActor @Suite struct NonTeachingPeriodsViewModelTests {
  private let store: DataStore
  private let storage = FakeStorage()
  private let vm: NonTeachingPeriodsViewModel

  private let day2 = CalendarDay(year: 2026, month: 11, day: 2)
  private let day6 = CalendarDay(year: 2026, month: 11, day: 6)
  private let day10 = CalendarDay(year: 2026, month: 11, day: 10)
  private var nov3Key: LessonKey { Fixtures.key(.nov3, "8b", "Englisch") }

  init() throws {
    store = try makeStore()
    // 8b Englisch dienstags 2. Stunde; der 3.11. liegt in den geplanten Ferien.
    try Fixtures.seed(store, [Fixtures.entry(.tuesday, 2, "8b", "Englisch")])
    vm = NonTeachingPeriodsViewModel(environment: Fixtures.environment(store: store, storage: storage))
  }

  @Test("AK-14: Material in den Herbstferien bleibt und lässt sich verschieben")
  func holidayMaterialCanBeMoved() throws {
    _ = try store.assignItem(Fixtures.reference("Arbeitsblatt Vokabeln", .pdf), to: nov3Key, at: nil)
    try vm.add(from: day2, to: day6, title: "Herbstferien")
    let orphan = vm.materialsWithoutLesson(in: vm.periods[0])
    #expect(orphan.map(\.reference.displayName) == ["Arbeitsblatt Vokabeln"])
    vm.actions.move(linkID: orphan[0].id, to: Fixtures.key(day10, "8b", "Englisch"))
    #expect(vm.materialsWithoutLesson(in: vm.periods[0]).isEmpty)
    #expect(try store.materialLinkItems(for: Fixtures.key(day10, "8b", "Englisch")).count == 1)
  }

  @Test("Von nach Bis wird abgelehnt")
  func fromAfterToRejected() {
    #expect(throws: NonTeachingPeriodError.fromAfterTo) {
      try vm.add(from: day6, to: day2, title: "Falsch")
    }
    #expect(vm.periods.isEmpty)
  }

  @Test("Zeitraum entfernen löscht kein Material")
  func removeKeepsLinks() throws {
    _ = try store.assignItem(Fixtures.reference("Arbeitsblatt Vokabeln", .pdf), to: nov3Key, at: nil)
    try vm.add(from: day2, to: day6, title: "Herbstferien")
    vm.remove(vm.periods[0])
    #expect(vm.periods.isEmpty)
    #expect(try store.materialLinkItems(for: nov3Key).count == 1)
  }

  @Test("Zeiträume sind nach Beginn sortiert, ein leerer Titel wird zum Standardtitel")
  func sortedWithDefaultTitle() throws {
    try vm.add(from: day10, to: day10, title: "  ")
    try vm.add(from: day2, to: day6, title: "Herbstferien")
    #expect(vm.periods.map(\.from) == [day2, day10])
    #expect(!vm.periods[1].title.isEmpty)
  }
}
