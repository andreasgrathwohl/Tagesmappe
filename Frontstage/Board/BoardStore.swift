import Foundation
import FrontstageCore

/// Tafelseiten je Unterrichtsstunde speichern: dünne Hülle über dem einzigen Datenzugang `DataStore`
/// (FR-12.1, FR-12.2, FR-12.3). Sortierung, Speichern und Schlüssel-Rückwandlung liegen im `DataStore`.
@MainActor struct BoardStore {
  let store: DataStore

  init(store: DataStore) {
    self.store = store
  }

  /// Die Seiten der Stunde, sortiert nach (position, createdAt, id).
  func pages(for key: LessonKey) throws -> [BoardPageRecord] {
    try store.boardPages(for: key)
  }

  /// Hängt eine neue Seite ans Ende an; die vorhandenen bleiben unverändert.
  @discardableResult
  func addPage(
    for key: LessonKey, background: BoardBackground, backgroundImageData: Data? = nil
  ) throws -> BoardPageRecord {
    try store.addBoardPage(for: key, background: background, backgroundImageData: backgroundImageData)
  }

  func setBackground(_ background: BoardBackground, imageData: Data?, of page: BoardPageRecord) throws {
    try store.setBoardPageBackground(page, background: background, imageData: imageData)
  }

  func saveDrawing(_ data: Data, to page: BoardPageRecord) throws {
    try store.saveBoardPageDrawing(page, drawingData: data)
  }

  /// Entfernt alle Seiten dieser Unterrichtsstunde.
  func deleteBoardDrawing(for key: LessonKey) throws {
    try store.deleteBoardDrawing(for: key)
  }

  /// FR-12.3: Schlüssel der letzten früheren Stunde derselben Klasse und desselben Fachs mit Tafelseiten.
  func previousBoardDrawingKey(before key: LessonKey) throws -> LessonKey? {
    BoardHistory.previousLessonKey(before: key, among: Array(try store.lessonKeysWithBoardPages()))
  }
}
