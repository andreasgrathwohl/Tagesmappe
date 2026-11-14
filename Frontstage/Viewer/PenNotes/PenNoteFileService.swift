import Foundation
import FrontstageCore
import OSLog
import PencilKit

/// Nimmt die Stiftnotizen mit, wenn eine Datei in eine andere Stunde geschoben, weitergereicht oder auf eine
/// andere Datei neu verknüpft wird (ADR-0011, AK-22). Setzt die Naht `PenNoteFileRelocating` aus Teilplan 04 um.
///
/// Umbenennungen laufen über die Warteliste: erst dauerhaft vermerken, dann ausführen, bei Misserfolg im
/// nächsten Durchgang nachholen. Die Planung der Dateioperationen (`PenNoteRelocation`) ist reine Logik im
/// Kern; ausgeführt wird sie über `PenNoteFileAccessing` außerhalb des Hauptthreads.
///
/// Swift-Hinweis: `Task {}` in einer `@MainActor`-Klasse erbt den Hauptakteur. `running` merkt sich den
/// laufenden Durchgang, damit nie zwei gleichzeitig dieselben Dateien umbenennen.
@MainActor final class PenNoteFileService: PenNoteFileRelocating {
  /// Erzeugt das Notiz-PDF der Stunde neu (nach dem Zusammenführen); Umsetzung in `ScopedServicesHolder`.
  typealias PDFMaker = @Sendable (MaterialReference, LessonKey) async -> Void

  private let files: any PenNoteFileAccessing
  private let pending: PendingPenNoteMoves
  private let makePDF: PDFMaker
  private var running: Task<Void, Never>?

  private static let logger = Logger(
    subsystem: Bundle.main.bundleIdentifier ?? "com.example.frontstage", category: "PenNotes")

  init(files: any PenNoteFileAccessing, pending: PendingPenNoteMoves, makePDF: @escaping PDFMaker) {
    self.files = files
    self.pending = pending
    self.makePDF = makePDF
  }

  // MARK: - Schieben und Weiterreichen

  func linksMoved(_ moves: [PenNoteMove]) {
    guard !moves.isEmpty else { return }
    // Zuerst dauerhaft vermerken, dann ausführen.
    pending.append(moves)
    Task { await retryPending() }
  }

  func retryPending() async {
    // Läuft schon ein Durchgang, auf sein Ende warten und danach selbst einen starten: Der Aufrufer darf
    // erst zurückkehren, wenn auch seine Einträge abgearbeitet sind.
    while let current = running { await current.value }
    let task = Task { await self.runPass() }
    running = task
    await task.value
    running = nil
  }

  private func runPass() async {
    for entry in pending.load() {
      guard let from = LessonKey(storageText: entry.fromKeyText), let to = LessonKey(storageText: entry.toKeyText)
      else {
        // Nicht lesbarer Schlüssel: nie ausführbar.
        pending.remove(entry)
        continue
      }
      let reference = entry.reference
      // Ort nicht erreichbar: abbrechen, der Rest bleibt in der Reihenfolge stehen.
      guard let existing = await files.existingNotesPaths(for: reference) else { return }
      // Aus den vorhandenen Pfaden planen: ein halb ausgeführter früherer Versuch ergibt nur noch den Rest.
      let plan = PenNoteRelocation.planMove(
        documentFileName: Self.fileName(of: reference), from: from, to: to, existing: existing)
      do {
        try await files.apply(plan, from: reference, to: reference, combine: Self.combineDrawings)
      } catch PenNoteWriteError.notWritable {
        // Die Notizen dieser Zuordnung liegen dann ohnehin im Ersatz, der mit der Zuordnung wandert.
        pending.remove(entry)
        continue
      } catch {
        Self.logger.error("Umbenennen der Notiz-Datei zurückgestellt")
        return
      }
      pending.remove(entry)
      await regeneratePDFs(plan.regeneratePDFFor, for: reference)
    }
  }

  // MARK: - Neu verknüpfen

  func notesCount(beside old: MaterialReference) async -> Int {
    guard let paths = await files.existingNotesPaths(for: old) else { return 0 }
    return paths.filter { path in
      guard path.contains("/"), let name = path.split(separator: "/").last else { return false }
      return PenNoteFileLayout.lessonKey(fromLessonFileName: String(name)) != nil
    }.count
  }

  func moveNotes(from old: MaterialReference, to new: MaterialReference) async throws {
    guard let atOld = await files.existingNotesPaths(for: old),
      let atNew = await files.existingNotesPaths(for: new)
    else { throw PenNoteWriteError.failed }
    let plan = PenNoteRelocation.planRelink(
      oldDocumentFileName: Self.fileName(of: old), existingAtOld: atOld,
      newDocumentFileName: Self.fileName(of: new), existingAtNew: atNew)
    try await files.apply(plan, from: old, to: new, combine: Self.combineDrawings)
    await regeneratePDFs(plan.regeneratePDFFor, for: new)
  }

  // MARK: - Hilfen

  private func regeneratePDFs(_ keyTexts: [String], for reference: MaterialReference) async {
    for text in keyTexts {
      if let key = LessonKey(storageText: text) { await makePDF(reference, key) }
    }
  }

  private static func fileName(of reference: MaterialReference) -> String {
    reference.relativePath.split(separator: "/").last.map(String.init) ?? reference.relativePath
  }

  /// Hängt die Striche von `b` an die von `a` (Entscheidung 8: nichts geht verloren). Ist eine Seite nicht
  /// lesbar, bleibt die andere.
  nonisolated private static let combineDrawings: @Sendable (Data, Data) -> Data = { a, b in
    guard let first = try? PKDrawing(data: a) else { return b }
    guard let second = try? PKDrawing(data: b) else { return a }
    return first.appending(second).dataRepresentation()
  }
}
