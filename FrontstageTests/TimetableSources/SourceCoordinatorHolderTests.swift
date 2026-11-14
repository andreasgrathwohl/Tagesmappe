import Foundation
import FrontstageCore
import Testing

@testable import Frontstage

@MainActor @Suite("SourceCoordinatorHolder")
struct SourceCoordinatorHolderTests {
  /// Koordinator mit Test-Ablage (eigene UserDefaults-Suite, temporärer Ordner) statt `live`.
  private func makeHolder() -> SourceCoordinatorHolder {
    SourceCoordinatorHolder { store in
      let suite = "holder-tests-\(UUID().uuidString)"
      let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent("holder-tests-\(UUID().uuidString)")
      return TimetableSourceCoordinator(
        repository: store,
        makeSource: { _ in ManualTimetableSource() },
        credentials: InMemoryCredentialStore(),
        statusStore: SourceStatusStore(defaults: UserDefaults(suiteName: suite)!),
        pendingStore: PendingImportStore(directory: directory))
    }
  }

  @Test("Gleicher DataStore → derselbe Koordinator; neuer DataStore → neuer")
  func holderCachesPerStore() throws {
    let holder = makeHolder()
    let first = try makeStore()
    let second = try makeStore()

    let a = holder.coordinator(for: first)
    #expect(holder.coordinator(for: first) === a)

    let b = holder.coordinator(for: second)
    #expect(b !== a)
    #expect(holder.coordinator(for: second) === b)
  }

  @Test("Nach Wechsel des Datenorts liest der Koordinator den neuen Stundenplan")
  func coordinatorFollowsStore() throws {
    let holder = makeHolder()
    let first = try makeStore()
    let second = try makeStore()
    try second.replaceTimetable(
      entries: [
        TimetableEntry(
          weekday: .monday, period: 1, schoolClass: SchoolClass("8b"), subject: Subject("Englisch"))
      ],
      manuallyEdited: [], weekVariantCount: 1, referenceWeekA: nil, bellSchedule: nil)

    #expect(try holder.coordinator(for: first).repository.timetable() == nil)
    let timetable = try holder.coordinator(for: second).repository.timetable()
    #expect(timetable?.entries.count == 1)
  }
}
