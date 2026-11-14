import Foundation
import FrontstageCore
import PencilKit
import Testing

@testable import Frontstage

@MainActor struct ViewerModelTests {
  @Test("Ein Bild wird ein Dokument mit genau einer Seite (FR-6)")
  func imageBecomesOnePageDocument() throws {
    let doc = try MaterialDocumentLoader.makeDocument(from: TestDocuments.pngData(width: 800, height: 600), kind: .image)
    #expect(doc.pageCount == 1)
  }

  @Test("Andere Dateiarten werden nicht in der Anzeige geöffnet")
  func presentationIsUnsupported() {
    #expect(throws: MaterialDocumentLoader.LoadError.unsupportedKind) {
      try MaterialDocumentLoader.makeDocument(from: Data(), kind: .presentation)
    }
  }

  @Test("Review Focus 7: unlesbare Daten – Anzeige meldet nicht verfügbar, Notizen unberührt")
  func unreadableDataFailsWithoutTouchingNotes() async throws {
    let (model, files, _) = try await TestViewer.make(kind: .pdf, data: Data("kein PDF".utf8), notePages: [0])
    await model.load()
    #expect(model.phase == .unavailable)
    #expect(await files.writeCount == 0)
  }

  @Test("Verweis löst nicht auf → nicht verfügbar, Zweitbildschirm bleibt beim Klassenbildschirm")
  func loadFailureSetsUnavailable() async throws {
    let (model, _, screen) = try await TestViewer.make(kind: .pdf, readError: StubError.unresolvable)
    await model.load()
    #expect(model.phase == .unavailable)
    #expect(screen.state.mode == .classScreen)
  }

  @Test("AK-23: Öffnen zeigt Seite 1 mit vorhandenen Notizen auf dem Zweitbildschirm")
  func openingPresentsMaterialWithNotes() async throws {
    let (model, _, screen) = try await TestViewer.make(
      kind: .pdf, data: TestDocuments.pdfData(pages: 2, size: .a4), notePages: [0])
    await model.load()
    #expect(model.phase == .ready)
    #expect(screen.state.mode == .material)
    #expect(screen.material?.pageIndex == 0)
    #expect(screen.material?.drawings[0]?.strokes.count == TestDrawings.word.strokes.count)
  }

  @Test("ADR-0011: geänderte Seitengröße und fehlende Seite werden gemeldet, nicht verworfen")
  func reportsOutdatedAndMissingPages() async throws {
    let (model, files, _) = try await TestViewer.make(
      kind: .pdf, data: TestDocuments.pdfData(pages: 2, size: .a4),
      notes: [0: PageSize(width: 842, height: 595), 4: .a4])
    await model.load()
    #expect(model.outdatedPages == [0])
    #expect(model.missingPages == [4])
    #expect(await files.writeCount == 0)
  }

  @Test("AK-13, AK-23: Schließen speichert sofort, schreibt das Notiz-PDF und gibt den Zweitbildschirm frei")
  func closeFlushesWritesPDFAndReturnsToClassScreen() async throws {
    let (model, files, screen) = try await TestViewer.make(
      kind: .pdf, data: TestDocuments.pdfData(pages: 1, size: .a4), saveDelay: .seconds(60))
    await model.load()
    model.drawingChanged(TestDrawings.word, pageIndex: 0)
    await model.close()
    #expect(await files.writeCount == 1)
    #expect(await files.pdfWriteCount == 1)
    #expect(screen.state.mode == .classScreen)
    #expect(screen.material == nil)
  }

  @Test("Nur ansehen (z. B. am Mac): kein Notiz-PDF beim Schließen (Entscheidung 5)")
  func viewingOnlyWritesNoPDF() async throws {
    let (model, files, _) = try await TestViewer.make(
      kind: .pdf, data: TestDocuments.pdfData(pages: 1, size: .a4), notePages: [0], existingPDF: true)
    await model.load()
    await model.close()
    #expect(await files.pdfWriteCount == 0)
  }

  @Test("Ersatz im Datenort: kein Notiz-PDF, Hinweis über notesLocation")
  func fallbackWritesNoPDF() async throws {
    let (model, files, _) = try await TestViewer.make(
      kind: .pdf, data: TestDocuments.pdfData(pages: 1, size: .a4), notWritable: true)
    await model.load()
    model.drawingChanged(TestDrawings.word, pageIndex: 0)
    await model.close()
    #expect(model.notesLocation == .appDataFallback)
    #expect(await files.pdfWriteCount == 0)
  }
}
