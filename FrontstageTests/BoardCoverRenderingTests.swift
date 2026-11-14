import FrontstageCore
import PencilKit
import SwiftUI
import Testing

@testable import Frontstage

@Suite struct BoardCoverRenderingTests {
  @MainActor @Test("AK-39: Zweitbildschirm zeigt nur Zeile 1, Tablet alle drei durchscheinend")
  func coverHidesOnSecondScreenOnly() throws {
    let page = BoardPageSnapshot(background: .image, backgroundImageData: TestImages.threeBars(), drawingData: nil)
    let cover = BoardCover(revealedFraction: 0.35)
    let second = try #require(render(page, cover: cover, audience: .secondScreen))
    let tablet = try #require(render(page, cover: cover, audience: .tablet))
    #expect(TestImages.isDark(second, atY: 0.20))  // Zeile 1 sichtbar
    #expect(TestImages.isUniform(second, from: 0.36, to: 1.0))  // Zeilen 2 und 3 deckend verdeckt
    #expect(TestImages.isUniform(tablet, from: 0.36, to: 1.0) == false)  // am Tablet scheinen Zeilen 2 und 3 durch
  }

  @MainActor @Test("FR-12.7: ohne Abdeckung sind alle drei Zeilen am Zweitbildschirm sichtbar")
  func noCoverShowsEverything() throws {
    let page = BoardPageSnapshot(background: .image, backgroundImageData: TestImages.threeBars(), drawingData: nil)
    let second = try #require(render(page, cover: nil, audience: .secondScreen))
    #expect(TestImages.isDark(second, atY: 0.50))
    #expect(TestImages.isDark(second, atY: 0.80))
  }

  /// Rendert die Seite 800 × 450 in Pixeln (Maßstab 1). Zeichnen ist aus, damit keine `PenCanvas` entsteht.
  @MainActor private func render(
    _ page: BoardPageSnapshot, cover: BoardCover?, audience: BoardCover.Audience
  ) -> CGImage? {
    let view = BoardPageSurface(
      page: page, drawing: .constant(PKDrawing()), isEditable: false, cover: cover, audience: audience,
      preloadedImage: page.backgroundImageData.flatMap { BoardPageRenderer.decodeImage($0) }
    )
    .frame(width: 800, height: 450)
    let renderer = ImageRenderer(content: view)
    renderer.scale = 1
    return renderer.cgImage
  }
}
