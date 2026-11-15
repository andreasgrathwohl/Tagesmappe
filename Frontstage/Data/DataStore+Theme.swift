import Foundation
import FrontstageCore
import SwiftData

/// Erscheinungsbild als abgeglichener Datensatz (FR-16). Die Freischaltung (FR-13) wertet der Aufrufer
/// über `Theme.effective(isUnlocked:)` aus; gespeichert wird die Wahl immer.
extension DataStore {
  /// Kein Datensatz → `.standard`; mehrere (vor dem Zusammenführen) → der mit dem neuesten `updatedAt`.
  func theme() throws -> Theme {
    try themeRecords().max { $0.updatedAt < $1.updatedAt }?.makeTheme() ?? .standard
  }

  /// Schreibt in den ältesten Datensatz (legt ihn bei Bedarf an), `updatedAt = .now`, `saveAndBump()`.
  /// Gleicher Inhalt wie gespeichert → nichts schreiben.
  func setTheme(_ theme: Theme) throws {
    let records = try themeRecords()
    // Ohne Datensatz wird auch der Standard angelegt; sonst gilt: gleiche sichtbare Wahl → nichts schreiben.
    if !records.isEmpty, try self.theme() == theme { return }
    let record: ThemeRecord
    if let oldest = records.first {
      record = oldest
    } else {
      record = ThemeRecord()
      modelContext.insert(record)
    }
    record.apply(theme)
    record.updatedAt = .now
    try saveAndBump()
  }

  /// Sortiert nach (createdAt, id): der älteste zuerst, wie ihn das Zusammenführen behält.
  private func themeRecords() throws -> [ThemeRecord] {
    try modelContext.fetch(FetchDescriptor<ThemeRecord>()).sorted {
      ($0.createdAt, $0.id.uuidString) < ($1.createdAt, $1.id.uuidString)
    }
  }
}
