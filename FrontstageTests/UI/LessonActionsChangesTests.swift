import Foundation
import FrontstageCore
import Testing

@testable import Frontstage

/// FR-8 (Ausfall) und FR-9 (Vertretungsstunde).
@MainActor @Suite struct LessonActionsChangesTests {
  private let data: DataStore
  private let actions: LessonActions
  private let tue8b = Fixtures.key(.tue17, "8b", "Englisch")

  init() throws {
    data = try makeStore()
    try Fixtures.seed(data, [Fixtures.entry(.tuesday, 5, "8b", "Englisch")])
    actions = LessonActions(store: data, storage: FakeStorage())
  }

  @Test("AK-15: Ausfall markieren")
  func markCancelled() throws {
    #expect(actions.setCancelled(true, key: tue8b) == .changed)
    #expect(try data.scheduleChanges() == [.cancellation(tue8b, .manual)])
  }

  @Test("Doppelt markiert ergibt eine Abweichung")
  func markCancelledTwiceStoresOneChange() throws {
    #expect(actions.setCancelled(true, key: tue8b) == .changed)
    #expect(actions.setCancelled(true, key: tue8b) == .unchanged)
    #expect(try data.scheduleChanges().count == 1)
  }

  @Test("Ausfall von Hand aufheben")
  func unmarkManualCancellation() throws {
    _ = actions.setCancelled(true, key: tue8b)
    #expect(actions.setCancelled(false, key: tue8b) == .changed)
    #expect(try data.scheduleChanges().isEmpty)
    #expect(actions.setCancelled(false, key: tue8b) == .unchanged)
  }

  @Test("Ausfall aus der Quelle lässt sich nicht von Hand aufheben")
  func unmarkSourceCancellationIsRejected() throws {
    try data.replaceScheduleChanges([.cancellation(tue8b, .source)], sourceFetchedAt: nil)
    #expect(actions.setCancelled(false, key: tue8b) == .blockedBySource)
    #expect(try data.scheduleChanges().count == 1)
  }

  @Test("AK-16: Vertretungsstunde Mi 4. Stunde 6c Mathe")
  func addSubstituteLesson() throws {
    actions.addSubstituteLesson(
      date: .wed18, period: 4, schoolClass: SchoolClass("6c"), subject: Subject("Mathe"))
    #expect(
      try data.scheduleChanges() == [
        .substituteLesson(
          date: .wed18, period: 4, schoolClass: SchoolClass("6c"), subject: Subject("Mathe"),
          .manual)
      ])
  }

  @Test("Vertretung entfernen: von Hand ja, aus der Quelle nein")
  func removeSubstituteLessonOnlyManual() throws {
    actions.addSubstituteLesson(
      date: .wed18, period: 4, schoolClass: SchoolClass("6c"), subject: Subject("Mathe"))
    #expect(
      actions.removeSubstituteLesson(
        date: .wed18, period: 4, schoolClass: SchoolClass("6c"), subject: Subject("Mathe")))
    try data.replaceScheduleChanges(
      [
        .substituteLesson(
          date: .wed18, period: 4, schoolClass: SchoolClass("6c"), subject: Subject("Mathe"),
          .source)
      ], sourceFetchedAt: nil)
    #expect(
      !actions.removeSubstituteLesson(
        date: .wed18, period: 4, schoolClass: SchoolClass("6c"), subject: Subject("Mathe")))
    #expect(try data.scheduleChanges().count == 1)
  }
}
