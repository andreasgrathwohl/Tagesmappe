import Foundation
import FrontstageCore
import Observation
import OSLog
import PDFKit

/// Zustand der Lösungsspalte (FR-6.3, UI-17): lädt die Lösung nur lesend und blättert gekoppelt mit dem Blatt.
///
/// Bewusst ohne `SecondScreenState`: Die Lösung darf nie auf den Zweitbildschirm gelangen – wer sie nicht kennt,
/// kann sie dort auch nicht zeigen.
@MainActor @Observable final class SolutionPaneModel {
  enum Phase: Equatable {
    case loading
    case ready
    case unavailable
  }

  private(set) var phase: Phase = .loading
  /// Rohdaten der Lösung (PDF oder Bild) für `PDFDisplayView`.
  private(set) var documentData: Data?
  private(set) var pageCount = 0
  /// Gezeigte Seite der Lösung, ab 0.
  private(set) var pageIndex = 0
  /// Folgt dem Blättern im Blatt (Vorgabe an).
  private(set) var isCoupled = true
  /// Zuletzt gemeldete Seite des Blatts; gilt auch, wenn das Blatt blättert, während die Lösung noch lädt.
  @ObservationIgnored private var lastSheetPage = 0

  let reference: MaterialReference
  private let fileReader: any MaterialFileReading

  private static let logger = Logger(
    subsystem: Bundle.main.bundleIdentifier ?? "com.example.frontstage", category: "SolutionPaneModel")

  init(reference: MaterialReference, fileReader: any MaterialFileReading) {
    self.reference = reference
    self.fileReader = fileReader
  }

  /// Liest die Lösung; scheitert das, bleibt das Blatt unberührt und die Spalte meldet „nicht verfügbar“.
  func load() async {
    phase = .loading
    do {
      let data = try await fileReader.readData(for: reference)
      let document = try MaterialDocumentLoader.makeDocument(from: data, kind: reference.fileKind)
      documentData = data
      pageCount = document.pageCount
      pageIndex = isCoupled
        ? SolutionPaging.coupledPage(sheetPage: lastSheetPage, solutionPageCount: pageCount)
        : min(pageIndex, max(pageCount - 1, 0))
      phase = .ready
    } catch {
      Self.logger.error("Lösung nicht lesbar: \(String(describing: error), privacy: .public)")
      documentData = nil
      pageCount = 0
      phase = .unavailable
    }
  }

  /// Das Blatt hat geblättert; gekoppelt zieht die Lösung nach.
  func sheetPageChanged(to sheetPage: Int) {
    lastSheetPage = sheetPage
    guard isCoupled else { return }
    pageIndex = SolutionPaging.coupledPage(sheetPage: sheetPage, solutionPageCount: pageCount)
  }

  /// Eigenes Blättern in der Lösung; löst die Kopplung.
  func goToPage(_ index: Int) {
    isCoupled = false
    pageIndex = SolutionPaging.coupledPage(sheetPage: index, solutionPageCount: pageCount)
  }

  /// Kopplung umschalten; beim Einschalten springt die Lösung auf die Seite des Blatts.
  func toggleCoupling(sheetPage: Int) {
    isCoupled.toggle()
    if isCoupled { sheetPageChanged(to: sheetPage) }
  }
}
