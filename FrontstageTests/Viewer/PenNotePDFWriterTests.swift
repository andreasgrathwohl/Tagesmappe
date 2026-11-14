import Foundation
import FrontstageCore
import PDFKit
import PencilKit
import Testing

@testable import Frontstage

@MainActor @Suite struct PenNotePDFWriterTests {
  private func note(_ drawing: PKDrawing) -> StoredPenNote {
    StoredPenNote(drawing: drawing, savedSize: .a4, updatedAt: Date(timeIntervalSince1970: 1_800_000_000))
  }

  @Test("ADR-0011: Seiten des Originals plus Striche als Ink-Anmerkungen")
  func writesInkAnnotations() throws {
    let doc = try MaterialDocumentLoader.makeDocument(from: TestDocuments.pdfData(pages: 2, size: .a4), kind: .pdf)
    let data = try #require(PenNotePDFWriter.makePDF(document: doc, notes: [1: note(TestDrawings.word)]))
    let out = try #require(PDFDocument(data: data))
    #expect(out.pageCount == 2)
    #expect(out.page(at: 0)?.annotations.isEmpty == true)
    let ink = try #require(out.page(at: 1)?.annotations.filter { $0.type == "Ink" })
    #expect(ink.count == TestDrawings.word.strokes.count)
  }

  @Test("Striche liegen innerhalb der Seite (Koordinaten umgerechnet)")
  func annotationsInsidePage() throws {
    let doc = try MaterialDocumentLoader.makeDocument(from: TestDocuments.pdfData(pages: 1, size: .a4), kind: .pdf)
    let data = try #require(PenNotePDFWriter.makePDF(document: doc, notes: [0: note(TestDrawings.twoWords)]))
    let page = try #require(PDFDocument(data: data)?.page(at: 0))
    let box = page.bounds(for: .mediaBox)
    let annotations = page.annotations.filter { $0.type == "Ink" }
    #expect(annotations.count == 2)
    for annotation in annotations {
      #expect(box.insetBy(dx: -0.5, dy: -0.5).contains(annotation.bounds))
    }
  }

  @Test("Bild als PDF-Seite mit Anmerkungen")
  func imageBecomesAnnotatedPage() throws {
    let doc = try MaterialDocumentLoader.makeDocument(from: TestDocuments.pngData(width: 200, height: 300), kind: .image)
    let data = try #require(PenNotePDFWriter.makePDF(document: doc, notes: [0: note(TestDrawings.word)]))
    let out = try #require(PDFDocument(data: data))
    #expect(out.pageCount == 1)
    #expect(out.page(at: 0)?.annotations.filter { $0.type == "Ink" }.count == 1)
  }

  @Test("Ohne Striche kein PDF (Entscheidung 5)")
  func noStrokesNoPDF() throws {
    let doc = try MaterialDocumentLoader.makeDocument(from: TestDocuments.pdfData(pages: 1, size: .a4), kind: .pdf)
    #expect(PenNotePDFWriter.makePDF(document: doc, notes: [:]) == nil)
    #expect(PenNotePDFWriter.makePDF(document: doc, notes: [0: note(PKDrawing())]) == nil)
  }

  @Test("Notiz auf einer Seite, die es nicht mehr gibt, wird nicht geschrieben")
  func missingPageIsSkipped() throws {
    let doc = try MaterialDocumentLoader.makeDocument(from: TestDocuments.pdfData(pages: 1, size: .a4), kind: .pdf)
    #expect(PenNotePDFWriter.makePDF(document: doc, notes: [5: note(TestDrawings.word)]) == nil)
  }

  @Test("Das übergebene Dokument bleibt unverändert")
  func sourceDocumentUntouched() throws {
    let doc = try MaterialDocumentLoader.makeDocument(from: TestDocuments.pdfData(pages: 2, size: .a4), kind: .pdf)
    _ = PenNotePDFWriter.makePDF(document: doc, notes: [1: note(TestDrawings.word)])
    #expect(doc.page(at: 1)?.annotations.isEmpty == true)
  }
}
