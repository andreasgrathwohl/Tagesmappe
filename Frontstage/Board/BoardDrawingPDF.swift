import CoreTransferable
import Foundation
import UniformTypeIdentifiers

/// Das Tafelbild als PDF für den Teilen-Dialog (`ShareLink`, FR-12.4).
///
/// Swift-Hinweis: `Transferable` sagt dem Teilen-Dialog, wie aus dem Wert eine Datei wird. Die Datei entsteht erst,
/// wenn die Lehrkraft ein Ziel wählt; sie liegt nur im temporären Ordner (keine Ordnerfreigabe, keine Daten im Speicher
/// der App).
struct BoardDrawingPDF: Transferable, Sendable {
  let pages: [BoardPageSnapshot]
  /// Dateiname einschließlich `.pdf`.
  let fileName: String

  static var transferRepresentation: some TransferRepresentation {
    FileRepresentation(exportedContentType: .pdf) { value in
      SentTransferredFile(try value.writeTemporaryFile())
    }
  }

  /// Schreibt das PDF in einen frischen Unterordner des temporären Ordners (damit der Dateiname erhalten bleibt).
  func writeTemporaryFile() throws -> URL {
    let folder = FileManager.default.temporaryDirectory
      .appendingPathComponent(UUID().uuidString, isDirectory: true)
    try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    let url = folder.appendingPathComponent(Self.safeName(fileName))
    try BoardPDFExporter.makePDF(pages: pages).write(to: url, options: .atomic)
    return url
  }

  /// Ersetzt Zeichen, die in Dateinamen nicht erlaubt sind.
  static func safeName(_ name: String) -> String {
    let cleaned = String(name.map { "/:\\".contains($0) ? "-" : $0 })
    return cleaned.isEmpty ? "Tafelbild.pdf" : cleaned
  }
}
