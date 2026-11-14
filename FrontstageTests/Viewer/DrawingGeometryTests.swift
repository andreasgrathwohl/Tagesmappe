import Foundation
import FrontstageCore
import PDFKit
import PencilKit
import Testing

@testable import Frontstage

@MainActor struct DrawingGeometryTests {
  @Test("Umrechnung in Seitenkoordinaten und zurück verliert nichts")
  func roundTripKeepsBounds() {
    let d = TestDrawings.line(from: CGPoint(x: 100, y: 100), to: CGPoint(x: 300, y: 200))
    let page = PageSize(width: 595, height: 842)
    let view = CGSize(width: 1190, height: 1684)
    let back = DrawingGeometry.toViewSpace(DrawingGeometry.toPageSpace(d, viewSize: view, pageSize: page), viewSize: view, pageSize: page)
    #expect(abs(back.bounds.minX - d.bounds.minX) < 0.5 && abs(back.bounds.maxY - d.bounds.maxY) < 0.5)
  }
  @Test("Halbe Darstellungsgröße halbiert die Lage")
  func scalesToSmallerView() {
    let d = TestDrawings.line(from: CGPoint(x: 100, y: 100), to: CGPoint(x: 300, y: 300))
    let v = DrawingGeometry.toViewSpace(d, viewSize: CGSize(width: 297.5, height: 421), pageSize: PageSize(width: 595, height: 842))
    #expect(abs(v.bounds.midX - d.bounds.midX / 2) < 1)
  }
  @Test("Seitengröße berücksichtigt Drehung um 90°")
  func pageSizeAppliesRotation() {
    let page = TestDocuments.page(width: 595, height: 842, rotation: 90)
    #expect(DrawingGeometry.pageSize(of: page) == PageSize(width: 842, height: 595))
  }
  @Test("Oben links der Seite wird oben links der mediaBox im PDF (y nach oben)")
  func pdfTransformFlipsY() {
    let page = TestDocuments.page(width: 595, height: 842, rotation: 0)
    let p = CGPoint(x: 10, y: 20).applying(DrawingGeometry.pdfTransform(for: page))
    #expect(abs(p.x - 10) < 0.01 && abs(p.y - 822) < 0.01)
  }
  @Test("Gedrehte Seite: Punkt landet in der ungedrehten mediaBox")
  func pdfTransformHandlesRotation() {
    let page = TestDocuments.page(width: 595, height: 842, rotation: 90)
    let p = CGPoint(x: 0, y: 0).applying(DrawingGeometry.pdfTransform(for: page))
    #expect(page.bounds(for: .mediaBox).insetBy(dx: -0.01, dy: -0.01).contains(p))
  }
}
