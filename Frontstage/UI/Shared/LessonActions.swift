import Foundation
import FrontstageCore
import OSLog

/// Fehler beim Zuordnen aus der Ablage; Datenfehler werden protokolliert und als `.saveFailed` gemeldet.
enum AssignError: Error, Equatable {
  /// Die Datei liegt in keinem freigegebenen Ordner dieses Geräts.
  case outsideGrantedFolders
  /// Speichern gescheitert; beim Neu verknüpfen ist nichts geändert.
  case saveFailed
}

/// Aktionen an den Zuordnungen einer Unterrichtsstunde: zuordnen, ordnen, neu verknüpfen, entfernen.
/// Die Struktur hält keinen Zustand; die Ansichten lesen nach jeder Aktion über `store.revision` neu.
@MainActor struct LessonActions {
  private static let logger = Logger(
    subsystem: Bundle.main.bundleIdentifier ?? "com.example.frontstage", category: "LessonActions")

  let store: any PreparationStore
  let storage: any MaterialStorage
  let penNotes: any PenNoteFileRelocating

  init(
    store: any PreparationStore, storage: any MaterialStorage,
    penNotes: any PenNoteFileRelocating = NoPenNoteFileRelocation()
  ) {
    self.store = store
    self.storage = storage
    self.penNotes = penNotes
  }

  /// Je URL ein Verweis, hinten angehängt; bricht bei der ersten ungültigen URL ab, ohne vorher
  /// Angelegtes zurückzunehmen. Danach `storage.didAssign` (Bereithalten, Teilplan 03) für alles,
  /// was angelegt wurde.
  ///
  /// Swift-Hinweis: `throws(AssignError)` ist ein typisierter Fehler; der Aufrufer kennt den
  /// genauen Typ, und `catch` braucht kein Casting.
  @discardableResult
  func assign(fileURLs: [URL], to key: LessonKey) async throws(AssignError) -> [MaterialLinkItem] {
    var created: [MaterialLinkItem] = []
    var failure: AssignError?
    for url in fileURLs {
      guard let reference = storage.reference(forPickedFile: url) else {
        failure = .outsideGrantedFolders
        break
      }
      do {
        created.append(try store.assignItem(reference, to: key, at: nil))
      } catch {
        Self.logger.error("Zuordnen gescheitert: \(String(describing: error), privacy: .public)")
        failure = .saveFailed
        break
      }
    }
    if !created.isEmpty {
      await storage.didAssign(created.map(\.reference))
    }
    if let failure { throw failure }
    return created
  }

  /// Ordnet die Zuordnungen einer Stunde um; Semantik wie `Array.move(fromOffsets:toOffset:)`.
  func reorder(_ key: LessonKey, fromOffsets: IndexSet, toOffset: Int) {
    do {
      try store.moveLinks(in: key, fromOffsets: fromOffsets, toOffset: toOffset)
    } catch {
      Self.logger.error("Umordnen gescheitert: \(String(describing: error), privacy: .public)")
    }
  }

  /// Neu verknüpfen (ADR-0003): ersetzt den Ort an allen Zuordnungen mit demselben alten Ort
  /// (`StorageService.relink`). Liefert den neuen Verweis.
  @discardableResult
  func relink(_ item: MaterialLinkItem, fileURL: URL) throws(AssignError) -> MaterialReference {
    switch storage.relink(item.reference, toPickedFile: fileURL) {
    case .relinked(let new): return new
    case .outsideGrants: throw .outsideGrantedFolders
    case .saveFailed: throw .saveFailed
    }
  }

  /// ADR-0011: Zahl der Stunden mit Notizen am alten Ort (0 = kein Angebot).
  func notesToCarry(from old: MaterialReference) async -> Int {
    await penNotes.notesCount(beside: old)
  }

  /// ADR-0011: Notizen vom alten Ort neben die neue Datei mitnehmen.
  func carryNotes(from old: MaterialReference, to new: MaterialReference) async throws {
    try await penNotes.moveNotes(from: old, to: new)
  }

  /// Entfernt eine Zuordnung (die Datei selbst bleibt unberührt).
  func remove(linkID: UUID) {
    do {
      try store.removeLink(id: linkID)
    } catch {
      Self.logger.error("Entfernen gescheitert: \(String(describing: error), privacy: .public)")
    }
  }
}
