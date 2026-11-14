import Foundation
import Testing

@testable import FrontstageCore

struct PenNoteFitTests {
  let a4 = PageSize(width: 595, height: 842)

  @Test("Gleiche Seitengröße passt (ADR-0011)")
  func sameSizeFits() {
    #expect(PenNoteFit.evaluate(savedSize: a4, pageIndex: 0, pageCount: 2, currentSize: a4) == .fits)
  }
  @Test("Abweichung bis 1 Punkt gilt als gleich")
  func withinToleranceFits() {
    #expect(
      PenNoteFit.evaluate(
        savedSize: a4, pageIndex: 0, pageCount: 1, currentSize: PageSize(width: 595.9, height: 841.2))
        == .fits)
  }
  @Test("Andere Seitengröße meldet frühere Fassung")
  func differentSizeIsSizeChanged() {
    #expect(
      PenNoteFit.evaluate(
        savedSize: a4, pageIndex: 0, pageCount: 1, currentSize: PageSize(width: 842, height: 595))
        == .sizeChanged)
  }
  @Test("Seite gibt es nicht mehr")
  func pageBeyondCountIsMissing() {
    #expect(PenNoteFit.evaluate(savedSize: a4, pageIndex: 2, pageCount: 2, currentSize: nil) == .pageMissing)
  }
  @Test("Unbekannte gespeicherte Größe (0 × 0 oder nil) gilt als passend")
  func unknownSavedSizeFits() {
    #expect(PenNoteFit.evaluate(savedSize: nil, pageIndex: 0, pageCount: 1, currentSize: a4) == .fits)
    #expect(
      PenNoteFit.evaluate(
        savedSize: PageSize(width: 0, height: 0), pageIndex: 0, pageCount: 1, currentSize: a4) == .fits)
  }
}
