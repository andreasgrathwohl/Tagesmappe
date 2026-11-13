import Foundation
import FrontstageCore
import SwiftData
import Testing

@testable import Frontstage

@MainActor @Suite struct SyncMergeTriggerTests {
  private let store: DataStore
  private let key = LessonKey(
    date: tue17, schoolClass: SchoolClass("8a"), subject: Subject("Englisch"), ordinal: 1)

  init() throws {
    store = try makeStore()
  }

  /// Legt denselben Ausfall zweimal an, wie nach dem Abgleich zweier Geräte.
  private func insertDuplicateCancellations() throws {
    store.insertChangeRecord(.cancellation(key, .manual))
    store.insertChangeRecord(.cancellation(key, .manual))
    try store.modelContext.save()
    #expect(try store.scheduleChanges().count == 2)
  }

  @Test("Fernänderung führt nach der Entprellzeit zusammen")
  func remoteChangeMergesAfterDebounce() async throws {
    try insertDuplicateCancellations()
    let trigger = SyncMergeTrigger(store: store, debounce: .milliseconds(50))
    trigger.remoteChangeReceived()
    trigger.remoteChangeReceived()
    try await Task.sleep(for: .milliseconds(300))
    #expect(try store.scheduleChanges().count == 1)
  }

  @Test("Fernänderung führt nicht vor Ablauf der Entprellzeit zusammen")
  func remoteChangeWaitsForDebounce() async throws {
    try insertDuplicateCancellations()
    let trigger = SyncMergeTrigger(store: store, debounce: .seconds(30))
    trigger.remoteChangeReceived()
    try await Task.sleep(for: .milliseconds(100))
    #expect(try store.scheduleChanges().count == 2)
    trigger.stop()
  }

  @Test("Vordergrund führt sofort zusammen")
  func becomingActiveMergesImmediately() throws {
    try insertDuplicateCancellations()
    let trigger = SyncMergeTrigger(store: store, debounce: .seconds(30))
    trigger.sceneDidBecomeActive()
    #expect(try store.scheduleChanges().count == 1)
  }

  @Test("Start führt einmal zusammen")
  func startMergesOnce() throws {
    try insertDuplicateCancellations()
    let trigger = SyncMergeTrigger(store: store, debounce: .seconds(30))
    trigger.start()
    #expect(try store.scheduleChanges().count == 1)
    trigger.stop()
  }
}
