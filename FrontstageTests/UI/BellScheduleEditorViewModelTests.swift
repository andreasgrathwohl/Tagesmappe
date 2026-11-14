import FrontstageCore
import Testing

@testable import Frontstage

/// Zeitraster bearbeiten (FR-1.2).
@MainActor @Suite struct BellScheduleEditorViewModelTests {
  private let store: DataStore
  private let storage = FakeStorage()

  init() throws {
    store = try makeStore()
  }

  private func makeModel() -> BellScheduleEditorViewModel {
    BellScheduleEditorViewModel(environment: Fixtures.environment(store: store, storage: storage))
  }

  @Test("AK-42: 2. Stunde auf 8:35–9:20")
  func setSecondPeriod() throws {
    let vm = makeModel()
    try vm.set(period: 2, start: .init(hour: 8, minute: 35), end: .init(hour: 9, minute: 20))
    #expect(
      try store.timetable()?.bellSchedule.periods[2]
        == TimeOfDay(hour: 8, minute: 35)...TimeOfDay(hour: 9, minute: 20))
  }

  @Test("Ende vor Beginn wird abgelehnt")
  func endBeforeStartRejected() {
    let vm = makeModel()
    #expect(throws: BellScheduleError.endNotAfterStart) {
      try vm.set(period: 1, start: .init(hour: 9, minute: 0), end: .init(hour: 8, minute: 0))
    }
    #expect(vm.schedule.periods.isEmpty)
  }

  @Test("Überschneidung mit der 1. Stunde wird abgelehnt")
  func overlapRejected() throws {
    let vm = makeModel()
    try vm.set(period: 1, start: .init(hour: 7, minute: 45), end: .init(hour: 8, minute: 30))
    #expect(throws: BellScheduleError.overlaps(period: 1)) {
      try vm.set(period: 2, start: .init(hour: 8, minute: 20), end: .init(hour: 9, minute: 5))
    }
    #expect(vm.schedule.periods[2] == nil)
  }

  @Test("Aneinanderstoßende Stunden sind erlaubt")
  func touchingPeriodsAllowed() throws {
    let vm = makeModel()
    try vm.set(period: 1, start: .init(hour: 8, minute: 0), end: .init(hour: 8, minute: 45))
    try vm.set(period: 2, start: .init(hour: 8, minute: 45), end: .init(hour: 9, minute: 30))
    #expect(vm.periods == [1, 2])
  }

  @Test("Stunde hinzufügen: leer → 1. Stunde 8:00–8:45, dann 5 min Pause")
  func addPeriod() throws {
    let vm = makeModel()
    vm.addPeriod()
    #expect(vm.schedule.periods[1] == TimeOfDay(hour: 8, minute: 0)...TimeOfDay(hour: 8, minute: 45))
    vm.addPeriod()
    #expect(vm.schedule.periods[2] == TimeOfDay(hour: 8, minute: 50)...TimeOfDay(hour: 9, minute: 35))
    #expect(try store.timetable()?.bellSchedule.periods.count == 2)
  }

  @Test("Letzte Stunde entfernen")
  func removeLast() {
    let vm = makeModel()
    vm.addPeriod()
    vm.addPeriod()
    vm.removeLastPeriod()
    #expect(vm.periods == [1])
    vm.removeLastPeriod()
    vm.removeLastPeriod()
    #expect(vm.periods.isEmpty)
  }

  @Test("Keine weitere Stunde, wenn sie nicht mehr vor Mitternacht endet")
  func addPeriodStopsAtMidnight() throws {
    let vm = makeModel()
    try vm.set(period: 1, start: .init(hour: 22, minute: 0), end: .init(hour: 23, minute: 30))
    #expect(!vm.canAddPeriod)
    vm.addPeriod()
    #expect(vm.periods == [1])
  }
}
