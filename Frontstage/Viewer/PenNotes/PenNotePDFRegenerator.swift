import Foundation
import FrontstageCore
import OSLog
import PencilKit

/// Erzeugt das Notiz-PDF einer Stunde neu, ohne dass die Anzeige offen ist – nach dem Zusammenführen von
/// Notizen beim Schieben oder Neu verknüpfen (`PenNoteFileService.PDFMaker`, ADR-0011, Entscheidung 8).
///
/// Liest das Dokument nur lesend, die Notizen aus der Notiz-Datei und schreibt das PDF neben das Dokument.
/// Ohne Striche wird ein vorhandenes Notiz-PDF entfernt. Fehler werden nur protokolliert: Maßgeblich ist die
/// Notiz-Datei, das PDF entsteht beim nächsten Schließen der Anzeige ohnehin neu, falls es fehlt.
enum PenNotePDFRegenerator {
  private static let logger = Logger(
    subsystem: Bundle.main.bundleIdentifier ?? "com.example.frontstage", category: "PenNotes")

  static func regenerate(
    reference: MaterialReference, key: LessonKey, reader: any MaterialFileReading,
    files: any PenNoteFileAccessing
  ) async {
    do {
      let data = try await reader.readData(for: reference)
      let document = try MaterialDocumentLoader.makeDocument(from: data, kind: reference.fileKind)
      guard case .notes(let file, _) = await files.read(reference, key: key) else { return }
      var notes: [Int: StoredPenNote] = [:]
      for page in file.pages {
        guard let drawing = try? PKDrawing(data: page.drawing) else { continue }
        let size = page.width > 0 && page.height > 0 ? PageSize(width: page.width, height: page.height) : nil
        notes[page.index] = StoredPenNote(drawing: drawing, savedSize: size, updatedAt: page.updatedAt)
      }
      if let pdf = PenNotePDFWriter.makePDF(document: document, notes: notes) {
        try await files.writePDF(pdf, reference: reference, key: key)
      } else {
        try await files.removePDF(reference: reference, key: key)
      }
    } catch {
      logger.error("Notiz-PDF konnte nicht neu erzeugt werden")
    }
  }
}
