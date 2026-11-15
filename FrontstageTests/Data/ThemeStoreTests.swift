import Foundation
import FrontstageCore
import SwiftData
import Testing

@testable import Frontstage

@MainActor @Suite struct ThemeStoreTests {
  private let early = Date(timeIntervalSince1970: 1_800_000_000)
  private let late = Date(timeIntervalSince1970: 1_800_003_600)

  private let petrolDark = Theme(
    baseTone: .petrol, accent: ThemeAccent(hex: "#C2410C"), appearanceMode: .dark)
  private let coolLight = Theme(baseTone: .cool, accent: nil, appearanceMode: .light)

  /// Legt einen Datensatz direkt an (wie ihn ein zweites Gerät nach dem Abgleich hinterlässt).
  @discardableResult
  private func insertRecord(
    _ theme: Theme, createdAt: Date, updatedAt: Date, in store: DataStore
  ) throws -> ThemeRecord {
    let record = ThemeRecord()
    record.apply(theme)
    record.createdAt = createdAt
    record.updatedAt = updatedAt
    store.modelContext.insert(record)
    try store.modelContext.save()
    return record
  }

  private func recordCount(_ store: DataStore) throws -> Int {
    try store.modelContext.fetchCount(FetchDescriptor<ThemeRecord>())
  }

  @Test("FR-16: ohne Datensatz gilt der Standard")
  func themeDefaultsToStandard() throws {
    let store = try makeStore()
    #expect(try store.theme() == .standard)
    #expect(try recordCount(store) == 0)
  }

  @Test("Speichern und Lesen ergibt dieselbe Wahl, ein Datensatz")
  func setThemeRoundTrips() throws {
    let store = try makeStore()
    try store.setTheme(petrolDark)
    try store.setTheme(coolLight)
    #expect(try store.theme() == coolLight)
    #expect(try recordCount(store) == 1)
  }

  @Test("Gleiche Wahl erneut speichern schreibt nichts")
  func unchangedThemeDoesNotSave() throws {
    let store = try makeStore()
    try store.setTheme(petrolDark)
    let revision = store.revision
    try store.setTheme(petrolDark)
    #expect(store.revision == revision)
  }

  @Test("Zwei Datensätze vor dem Zusammenführen: der zuletzt geänderte gilt")
  func themeReadsNewestBeforeMerge() throws {
    let store = try makeStore()
    try insertRecord(petrolDark, createdAt: early, updatedAt: early, in: store)
    try insertRecord(coolLight, createdAt: late, updatedAt: late, in: store)
    #expect(try store.theme() == coolLight)
  }

  @Test("Zusammenführen: ein Datensatz, Inhalt des zuletzt geänderten")
  func mergeDuplicatesKeepsNewestTheme() throws {
    let store = try makeStore()
    let oldest = try insertRecord(petrolDark, createdAt: early, updatedAt: early, in: store)
    try insertRecord(coolLight, createdAt: late, updatedAt: late, in: store)
    try store.mergeDuplicates()
    #expect(try recordCount(store) == 1)
    #expect(try store.theme() == coolLight)
    let remaining = try store.modelContext.fetch(FetchDescriptor<ThemeRecord>())
    #expect(remaining.first?.id == oldest.id)
    #expect(remaining.first?.updatedAt == late)
  }

  @Test("Nur das Erscheinungsbild doppelt: Zusammenführen läuft trotzdem")
  func themeMergeRunsWhenOtherPlansEmpty() throws {
    let store = try makeStore()
    try insertRecord(.standard, createdAt: early, updatedAt: early, in: store)
    try insertRecord(petrolDark, createdAt: late, updatedAt: late, in: store)
    try store.mergeDuplicates()
    #expect(try recordCount(store) == 1)
    #expect(try store.theme() == petrolDark)
  }

  @Test("Unbekannte Rohwerte ergeben den Standard des Felds")
  func unknownRawValuesFallBack() throws {
    let record = ThemeRecord()
    record.baseToneRaw = "neon"
    record.appearanceModeRaw = "sepia"
    record.accentHex = "kein-hex"
    #expect(record.makeTheme() == .standard)
    record.baseToneRaw = "cool"
    #expect(record.makeTheme() == Theme(baseTone: .cool, accent: nil, appearanceMode: .system))
  }
}
