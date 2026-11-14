import CoreGraphics
import Foundation
import Testing

@testable import Frontstage

@Suite("TemplateRenderer")
struct TemplateRendererTests {
  @Test("AK-38: Ausschnitt um Aufgabe 2 wird vergrößert Hintergrund; PDF in der Ablage unverändert")
  func cropIsRenderedEnlarged() throws {
    let url = try TestImages.writePDF(blackRectAt: CGRect(x: 0.1, y: 0.4, width: 0.3, height: 0.1))
    defer { try? FileManager.default.removeItem(at: url) }
    let before = try Data(contentsOf: url)
    let jpeg = try TemplateRenderer.renderPDFPage(
      at: url, pageIndex: 0, crop: CGRect(x: 0.1, y: 0.4, width: 0.3, height: 0.1))
    let image = try #require(TestImages.decode(jpeg))
    #expect(image.width == 2400)
    #expect(image.height == 1350)
    #expect(TestImages.isDark(image, atY: 0.5))  // Der Ausschnitt füllt die Mitte.
    #expect(try Data(contentsOf: url) == before)
  }

  @Test("Ganze Seite: Mitte bleibt hell, Ränder weiß eingepasst")
  func wholePageIsLetterboxed() throws {
    // Schwarzes Rechteck nur am oberen Seitenrand: die Mitte der Fläche bleibt hell.
    let url = try TestImages.writePDF(blackRectAt: CGRect(x: 0.4, y: 0.02, width: 0.2, height: 0.05))
    defer { try? FileManager.default.removeItem(at: url) }
    let jpeg = try TemplateRenderer.renderPDFPage(at: url, pageIndex: 0, crop: nil)
    let image = try #require(TestImages.decode(jpeg))
    #expect(image.width == 2400)
    #expect(image.height == 1350)
    #expect(TestImages.gray(image, atX: 0.5, y: 0.5) > 240)  // Mitte hell
    #expect(TestImages.gray(image, atX: 0.05, y: 0.5) > 240)  // Linker Rand weiß (Seite A4 hoch ist schmaler)
    #expect(TestImages.gray(image, atX: 0.5, y: 0.045) < 64)  // Das Rechteck oben ist da.
  }

  @Test("Ungültige Seitenzahl wirft")
  func invalidPageThrows() throws {
    let url = try TestImages.writePDF(blackRectAt: .zero)
    defer { try? FileManager.default.removeItem(at: url) }
    #expect(throws: TemplateRendererError.self) {
      try TemplateRenderer.renderPDFPage(at: url, pageIndex: 3, crop: nil)
    }
  }

  @Test("Eine Datei, die kein PDF ist, wirft")
  func unreadablePDFThrows() throws {
    let url = FileManager.default.temporaryDirectory.appendingPathComponent("not-\(UUID().uuidString).pdf")
    try Data("kein pdf".utf8).write(to: url)
    defer { try? FileManager.default.removeItem(at: url) }
    #expect(throws: TemplateRendererError.unreadable) {
      try TemplateRenderer.renderPDFPage(at: url, pageIndex: 0, crop: nil)
    }
  }

  @Test("Bild: ganz und als Ausschnitt immer 2400 × 1350")
  func imageIsRenderedToBoardSize() throws {
    let url = FileManager.default.temporaryDirectory.appendingPathComponent("bars-\(UUID().uuidString).jpg")
    try TestImages.threeBars().write(to: url)
    defer { try? FileManager.default.removeItem(at: url) }
    let whole = try #require(TestImages.decode(try TemplateRenderer.renderImage(at: url, crop: nil)))
    #expect(whole.width == 2400)
    #expect(whole.height == 1350)
    #expect(TestImages.isDark(whole, atY: 0.5))
    let cropped = try #require(
      TestImages.decode(try TemplateRenderer.renderImage(at: url, crop: CGRect(x: 0, y: 0.45, width: 1, height: 0.1))))
    #expect(cropped.width == 2400)
    #expect(cropped.height == 1350)
    #expect(TestImages.isDark(cropped, atY: 0.5))
  }

  @Test("Seitenzahl und Vorschau eines PDF")
  func pageCountAndPreview() throws {
    let url = try TestImages.writePDF(blackRectAt: .zero)
    defer { try? FileManager.default.removeItem(at: url) }
    #expect(TemplateRenderer.pageCount(ofPDFAt: url) == 1)
    let preview = try #require(TestImages.decode(try TemplateRenderer.previewPDFPage(at: url, pageIndex: 0, maxSide: 400)))
    #expect(preview.height == 400)
    #expect(preview.width < preview.height)  // A4 hoch
  }
}
