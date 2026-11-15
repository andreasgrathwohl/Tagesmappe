import Foundation
import FrontstageCore
import Testing

@testable import Frontstage

/// Auswahl, „Jetzt“ und Tageswechsel der Tagesansicht (UI-3, UI-12).
@MainActor @Suite struct DayViewSelectionTests {
  /// Veränderbare Uhr und veränderbarer „heute“-Tag für die Tests.
  @MainActor final class Clock {
    var now: Date
    var today: CalendarDay
    init(today: CalendarDay, _ hour: Int, _ minute: Int) {
      self.today = today
      now = Fixtures.date(today, hour, minute)
    }
    func set(_ hour: Int, _ minute: Int) { now = Fixtures.date(today, hour, minute) }
  }

  private let data: DataStore
  private let storage = FakeStorage()

  init() throws {
    data = try makeStore()
    try Fixtures.seed(
      data,
      [
        Fixtures.entry(.tuesday, 1, "8b", "Englisch"),
        Fixtures.entry(.tuesday, 2, "9c", "Deutsch"),
        Fixtures.entry(.tuesday, 3, "7a", "Mathe"),
        Fixtures.entry(.wednesday, 1, "8b", "Englisch"),
        Fixtures.entry(.wednesday, 2, "9c", "Deutsch"),
      ])
  }

  private func makeModel(_ clock: Clock) -> DayViewModel {
    let environment = AppEnvironment(
      store: data, storage: storage, today: { clock.today }, now: { clock.now })
    return DayViewModel(environment: environment)
  }

  private func key(_ day: CalendarDay, _ cls: String, _ subject: String) -> LessonKey {
    Fixtures.key(day, cls, subject)
  }

  @Test("UI-3: Öffnen um 8:40 wählt die 2. Stunde")
  func openingSelectsRunningLesson() throws {
    let vm = makeModel(Clock(today: .tue17, 8, 40))
    #expect(vm.selection == key(.tue17, "9c", "Deutsch"))
    #expect(vm.selectedRow?.lesson.period == 2)
  }

  @Test("Stundenwechsel: tick um 9:45 wählt die 3. Stunde")
  func tickFollowsLessonChange() throws {
    let clock = Clock(today: .tue17, 8, 40)
    let vm = makeModel(clock)
    clock.set(9, 45)
    vm.tick()
    #expect(vm.selection == key(.tue17, "7a", "Mathe"))
    #expect(vm.runningLessonKey == key(.tue17, "7a", "Mathe"))
  }

  @Test("Handauswahl bleibt über tick und reload")
  func manualSelectionSurvivesTickAndReload() throws {
    let clock = Clock(today: .tue17, 8, 40)
    let vm = makeModel(clock)
    vm.selection = key(.tue17, "8b", "Englisch")
    clock.set(9, 45)
    vm.tick()
    #expect(vm.selection == key(.tue17, "8b", "Englisch"))
    vm.reload()
    #expect(vm.selection == key(.tue17, "8b", "Englisch"))
    // „Jetzt“ folgt trotzdem der Uhr.
    #expect(vm.runningLessonKey == key(.tue17, "7a", "Mathe"))
  }

  @Test("Nächster Tag wählt die erste Stunde, Heute wieder die laufende")
  func dayChangeResetsSelection() throws {
    let vm = makeModel(Clock(today: .tue17, 8, 40))
    vm.selection = key(.tue17, "7a", "Mathe")
    vm.showNextDay()
    #expect(vm.selection == key(.wed18, "8b", "Englisch"))
    #expect(vm.runningLessonKey == nil)
    vm.showToday()
    #expect(vm.selection == key(.tue17, "9c", "Deutsch"))
  }

  @Test("Neuer Kalendertag beim Aktivwerden: zurück zu heute und Automatik")
  func newCalendarDayResetsSelection() throws {
    let clock = Clock(today: .tue17, 8, 40)
    let vm = makeModel(clock)
    vm.selection = key(.tue17, "7a", "Mathe")
    // Gleicher Tag: Handauswahl bleibt.
    vm.sceneDidBecomeActive()
    #expect(vm.selection == key(.tue17, "7a", "Mathe"))
    // Über Nacht: Mittwoch, 8:40.
    clock.today = .wed18
    clock.set(8, 40)
    vm.sceneDidBecomeActive()
    #expect(vm.day == .wed18)
    #expect(vm.selection == key(.wed18, "9c", "Deutsch"))
  }

  @Test("UI-12: runningLessonKey nur heute und nur während der Stunde")
  func runningLessonOnlyTodayDuringLesson() throws {
    let clock = Clock(today: .tue17, 8, 32)
    let vm = makeModel(clock)
    // Pause zwischen 1. und 2. Stunde.
    #expect(vm.runningLessonKey == nil)
    clock.set(8, 40)
    vm.tick()
    #expect(vm.runningLessonKey == key(.tue17, "9c", "Deutsch"))
    vm.showNextDay()
    #expect(vm.runningLessonKey == nil)
  }
}
