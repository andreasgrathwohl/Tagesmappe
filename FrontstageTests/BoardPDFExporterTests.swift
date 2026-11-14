import Foundation
import FrontstageCore
import PDFKit
import PencilKit
import Testing

@testable import Frontstage

@Suite struct BoardPDFExporterTests {
  #if os(iOS)
    @Test("AK-34: zwei Seiten samt Hintergrund im PDF, Tafelbild unverändert")
    func pdfHasTwoPagesWithBackground() throws {
      let pages = [
        BoardPageSnapshot(background: .blank, backgroundImageData: nil, drawingData: PKDrawing().dataRepresentation()),
        BoardPageSnapshot(background: .grid, backgroundImageData: nil, drawingData: nil),
      ]
      let before = pages
      let doc = try #require(PDFDocument(data: try BoardPDFExporter.makePDF(pages: pages)))
      #expect(doc.pageCount == 2)
      #expect(doc.page(at: 0)?.bounds(for: .mediaBox).size == BoardPDFExporter.pageSize)
      let page = try #require(doc.page(at: 1))
      let grid = try #require(page.thumbnail(of: CGSize(width: 400, height: 225), for: .mediaBox).cgImage)
      #expect(TestImages.nonWhiteRatio(grid) > 0.01)  // Karos sind gezeichnet
      #expect(pages == before)
    }
  #endif

  @MainActor @Test("AK-34: Export lässt die gespeicherten Tafelseiten unverändert")
  func exportDoesNotTouchStore() throws {
    let (session, _) = try makeSession()
    try session.open(tue8b)
    try session.addPage(background: .grid)
    let before = session.pages
    _ = try BoardPDFExporter.makePDF(pages: session.pages)
    try session.close()
    try session.open(tue8b)
    #expect(session.pages == before)
  }
}
