import Testing
@testable import FrontstageCore

@Suite("Normalized Rect") struct NormalizedRectTests {
  @Test("Zwei Punkte in beliebiger Richtung (FR-17.4)")
  func spansEitherDirection() throws {
    let r = try #require(NormalizedRect.spanning(from: (80, 60), to: (20, 20), in: (100, 100)))
    #expect(r == NormalizedRect(x: 0.2, y: 0.2, width: 0.6, height: 0.4))
  }

  @Test("Über den Rand begrenzt (FR-17.4)")
  func clampsToBounds() throws {
    let r = try #require(NormalizedRect.spanning(from: (-10, -10), to: (50, 150), in: (100, 100)))
    #expect(r == NormalizedRect(x: 0, y: 0, width: 0.5, height: 1))
  }

  @Test("Winzig → nil (FR-17.4)")
  func tinyIsNil() {
    #expect(NormalizedRect.spanning(from: (10, 10), to: (10.5, 40), in: (100, 100)) == nil)
  }

  @Test("Init begrenzt auf 0...1 (FR-17.4)")
  func initClamps() {
    let r = NormalizedRect(x: -1, y: 2, width: -3, height: 5)
    #expect(r.x == 0 && r.y == 1 && r.width == 0 && r.height == 1)
  }
}
