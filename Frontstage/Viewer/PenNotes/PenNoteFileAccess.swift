import Foundation
import FrontstageCore

/// Zugang der Anzeige zu den Notiz-Dateien neben einem Dokument (ADR-0011). Die Umsetzung über die Ablage ist
/// `StoragePenNoteFiles`; Tests nehmen `InMemoryPenNoteFiles`. Alle Datei-Arbeit läuft außerhalb des Hauptthreads.
///
/// Die werfenden Methoden werfen ausschließlich `PenNoteWriteError` (Swift kann das in einer `async`-Kette über
/// den Ablage-Zugang hinweg nicht im Typ ausdrücken; Aufrufer fangen `PenNoteWriteError`).
protocol PenNoteFileAccessing: Sendable {
  func read(_ reference: MaterialReference, key: LessonKey) async -> PenNoteFileRead
  /// Liest die Platte neu und behält fremde Seiten; liefert den geschriebenen Stand.
  func write(_ file: PenNoteFile, changedPages: Set<Int>, reference: MaterialReference, key: LessonKey)
    async throws -> PenNoteFile
  func writePDF(_ data: Data, reference: MaterialReference, key: LessonKey) async throws
  func removePDF(reference: MaterialReference, key: LessonKey) async throws
  /// `nil` = Ort löst auf diesem Gerät nicht auf.
  func existingNotesPaths(for reference: MaterialReference) async -> [String]?
  /// Führt einen Plan aus; `source` und `target` können in verschiedenen Freigaben liegen.
  func apply(
    _ plan: PenNoteRelocationPlan, from source: MaterialReference, to target: MaterialReference,
    combine: @escaping @Sendable (Data, Data) -> Data
  ) async throws
}

/// Umsetzung über die Ablage: je Aufruf ein Zugang zum Ordner des Dokuments, die Arbeit selbst macht
/// `PenNoteFileStore` im `body` (außerhalb des Hauptthreads).
///
/// Swift-Hinweis: Eine `@MainActor`-Klasse ist automatisch `Sendable`; sie hält nur die Ablage, die ihrerseits
/// am Hauptakteur hängt. Die Protokoll-Methoden sind `async` und springen dafür bei Bedarf auf den Hauptakteur.
@MainActor final class StoragePenNoteFiles: PenNoteFileAccessing {
  private let storage: StorageService

  init(storage: StorageService) {
    self.storage = storage
  }

  func read(_ reference: MaterialReference, key: LessonKey) async -> PenNoteFileRead {
    do {
      return try await storage.withDocumentLocation(for: reference) { url in
        PenNoteFileStore().read(documentURL: url, key: key)
      }
    } catch StorageReadError.unresolvable {
      // Der Ordner des Dokuments löst auf diesem Gerät nicht auf: keine Notizen bekannt.
      return .none
    } catch {
      return .blocked(.notDownloaded)
    }
  }

  func write(_ file: PenNoteFile, changedPages: Set<Int>, reference: MaterialReference, key: LessonKey)
    async throws -> PenNoteFile
  {
    do {
      return try await storage.withDocumentLocation(for: reference) { url in
        try PenNoteFileStore().write(file, changedPages: changedPages, documentURL: url, key: key)
      }
    } catch {
      throw Self.writeError(error)
    }
  }

  func writePDF(_ data: Data, reference: MaterialReference, key: LessonKey) async throws {
    do {
      try await storage.withDocumentLocation(for: reference) { url in
        try PenNoteFileStore().writePDF(data, documentURL: url, key: key)
      }
    } catch {
      throw Self.writeError(error)
    }
  }

  func removePDF(reference: MaterialReference, key: LessonKey) async throws {
    do {
      try await storage.withDocumentLocation(for: reference) { url in
        try PenNoteFileStore().removePDF(documentURL: url, key: key)
      }
    } catch {
      throw Self.writeError(error)
    }
  }

  func existingNotesPaths(for reference: MaterialReference) async -> [String]? {
    try? await storage.withDocumentLocation(for: reference) { url in
      PenNoteFileStore().existingNotesPaths(documentURL: url)
    }
  }

  func apply(
    _ plan: PenNoteRelocationPlan, from source: MaterialReference, to target: MaterialReference,
    combine: @escaping @Sendable (Data, Data) -> Data
  ) async throws {
    do {
      try await storage.withDocumentLocations(for: source, and: target) { sourceURL, targetURL in
        try PenNoteFileStore().apply(
          plan, sourceDocumentURL: sourceURL, targetDocumentURL: targetURL, combine: combine)
      }
    } catch {
      throw Self.writeError(error)
    }
  }

  /// `PenNoteWriteError` bleibt; jeder andere Fehler (z. B. nicht auflösbarer Ort) → `.failed`.
  nonisolated private static func writeError(_ error: Error) -> PenNoteWriteError {
    (error as? PenNoteWriteError) ?? .failed
  }
}
