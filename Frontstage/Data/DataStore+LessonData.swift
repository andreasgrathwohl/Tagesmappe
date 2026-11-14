import Foundation
import FrontstageCore
import SwiftData

/// Stundenangaben und Tafelseiten je Unterrichtsstunde (FR-11.1, FR-12.1, FR-12.2).
/// Zeichnen, Kamera und Vorlage baut Teilplan 07; hier liegt nur die Ablage.
///
/// Swift-Hinweis: Wie in `DataStore+MaterialLinks` wird vollständig geladen und im Speicher gefiltert
/// (kleine Mengen), statt `#Predicate` auf einem Textformat zu bauen.
extension DataStore {
  // MARK: - Stundenangaben (FR-11.1)

  /// Ohne Datensatz: leere Angaben.
  func lessonInfo(for key: LessonKey) throws -> LessonInfo {
    try infoRecords(for: key).first?.makeInfo() ?? LessonInfo()
  }

  /// Normalisiert und schreibt. Zwei Geräte können je einen Datensatz angelegt haben: Der älteste
  /// wird beschrieben (das Zusammenführen räumt die übrigen auf), sonst entsteht ein neuer.
  func setLessonInfo(_ info: LessonInfo, for key: LessonKey) throws {
    let record: LessonInfoRecord
    if let existing = try infoRecords(for: key).first {
      record = existing
    } else {
      record = LessonInfoRecord(lessonKeyText: key.storageText)
      modelContext.insert(record)
    }
    record.apply(info, now: .now)
    try saveAndBump()
  }

  // MARK: - Tafelseiten (FR-12.1, FR-12.2)

  /// Sortiert nach (position, createdAt, id).
  func boardPages(for key: LessonKey) throws -> [BoardPageRecord] {
    let text = key.storageText
    return try modelContext.fetch(FetchDescriptor<BoardPageRecord>())
      .filter { $0.lessonKeyText == text }
      .sorted {
        if $0.position != $1.position { return $0.position < $1.position }
        if $0.createdAt != $1.createdAt { return $0.createdAt < $1.createdAt }
        return $0.id.uuidString < $1.id.uuidString
      }
  }

  /// Hängt die Seite ans Ende an (`position` = größte vorhandene + 1).
  @discardableResult
  func addBoardPage(
    for key: LessonKey, background: BoardBackground, backgroundImageData: Data? = nil
  ) throws -> BoardPageRecord {
    let last = try boardPages(for: key).map(\.position).max() ?? -1
    let page = BoardPageRecord(
      lessonKeyText: key.storageText, position: last + 1, backgroundRaw: background.rawValue)
    modelContext.insert(page)
    page.backgroundImageData = backgroundImageData
    try saveAndBump()
    return page
  }

  func setBoardPageBackground(
    _ page: BoardPageRecord, background: BoardBackground, imageData: Data?
  ) throws {
    page.background = background
    page.backgroundImageData = imageData
    page.updatedAt = .now
    try saveAndBump()
  }

  func saveBoardPageDrawing(_ page: BoardPageRecord, drawingData: Data) throws {
    page.drawingData = drawingData
    page.updatedAt = .now
    try saveAndBump()
  }

  /// Die übrigen Positionen bleiben; die Sortierung trägt Lücken.
  func deleteBoardPage(_ page: BoardPageRecord) throws {
    modelContext.delete(page)
    try saveAndBump()
  }

  /// Entfernt alle Tafelseiten der Stunde.
  func deleteBoardDrawing(for key: LessonKey) throws {
    let pages = try boardPages(for: key)
    guard !pages.isEmpty else { return }
    for page in pages { modelContext.delete(page) }
    try saveAndBump()
  }

  /// Stunden mit mindestens einer Tafelseite (für „letztes Tafelbild“, FR-12.3). Texte, die sich
  /// nicht als Schlüssel lesen lassen, werden übergangen.
  func lessonKeysWithBoardPages() throws -> Set<LessonKey> {
    Set(
      try modelContext.fetch(FetchDescriptor<BoardPageRecord>()).compactMap {
        LessonKey(storageText: $0.lessonKeyText)
      })
  }

  // MARK: - Hilfen

  /// Älteste zuerst (createdAt, dann id).
  private func infoRecords(for key: LessonKey) throws -> [LessonInfoRecord] {
    let text = key.storageText
    return try modelContext.fetch(FetchDescriptor<LessonInfoRecord>())
      .filter { $0.lessonKeyText == text }
      .sorted {
        if $0.createdAt != $1.createdAt { return $0.createdAt < $1.createdAt }
        return $0.id.uuidString < $1.id.uuidString
      }
  }
}
