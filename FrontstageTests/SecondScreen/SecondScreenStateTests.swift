import Foundation
import FrontstageCore
import Testing

@testable import Frontstage

@MainActor struct SecondScreenStateTests {
  let presentation = MaterialPresentation(
    linkID: UUID(), documentData: Data(), kind: .pdf, pageIndex: 0, visibleRect: nil, drawings: [:])

  @Test("Material öffnen und schließen (AK-23)")
  func openAndClose() {
    let m = SecondScreenState()
    m.openMaterial(presentation)
    #expect(m.state.mode == .material && m.material != nil)
    m.closeMaterial()
    #expect(m.state.mode == .classScreen && m.material == nil)
  }

  @Test("Verbinden lässt den aktuellen Modus stehen (Review Focus 1)")
  func connectingKeepsCurrentMode() {
    let m = SecondScreenState()
    m.openMaterial(presentation)
    m.displayConnected(aspectRatio: 16.0 / 9.0)
    #expect(m.isConnected && m.state.mode == .material)
  }

  @Test("Trennen behält Zustand und Zeichnungen (Review Focus 2)")
  func disconnectKeepsStateAndDrawings() {
    let m = SecondScreenState()
    m.openMaterial(presentation)
    m.updateDrawing(TestDrawings.word, pageIndex: 0)
    m.displayDisconnected()
    #expect(!m.isConnected && m.state.mode == .material)
    #expect(m.material?.drawings[0]?.strokes.count == TestDrawings.word.strokes.count)
  }

  @Test("Seitenwechsel und Zoom werden übertragen")
  func showPageUpdatesPresentation() {
    let m = SecondScreenState()
    m.openMaterial(presentation)
    m.showPage(1, visibleRect: CGRect(x: 0, y: 0, width: 200, height: 100))
    #expect(m.material?.pageIndex == 1 && m.material?.visibleRect?.width == 200)
  }

  @Test("Bildformat des Bildschirms wird übernommen, Vorgabe 16:9")
  func aspectRatio() {
    let m = SecondScreenState()
    #expect(abs(m.screenAspectRatio - 16.0 / 9.0) < 0.001)
    m.displayConnected(aspectRatio: 4.0 / 3.0)
    #expect(abs(m.screenAspectRatio - 4.0 / 3.0) < 0.001)
    m.displayConnected(aspectRatio: 0)
    #expect(abs(m.screenAspectRatio - 4.0 / 3.0) < 0.001)
  }

  @Test("Bildformat-Update hebt Dunkel nicht auf (FR-11.4)")
  func ratioUpdateKeepsDark() {
    let m = SecondScreenState()
    m.toggleDark()
    #expect(m.state.mode == .dark)
    m.updateAspectRatio(4.0 / 3.0)
    #expect(m.state.mode == .dark)
    #expect(abs(m.screenAspectRatio - 4.0 / 3.0) < 0.001)
    m.updateAspectRatio(.nan)
    #expect(abs(m.screenAspectRatio - 4.0 / 3.0) < 0.001)
  }

  @Test("Tafel wählbar nur mit Unterrichtsstunde")
  func boardRequiresLesson() {
    let m = SecondScreenState()
    m.select(.board)
    #expect(m.state.mode == .classScreen)
    m.setBoardLesson(TestKeys.tue8aEnglish)
    m.select(.board)
    #expect(m.state.mode == .board)
    m.setBoardLesson(nil)
    #expect(m.state.mode == .classScreen)
  }

  @Test("Zeichnung ohne offenes Material wird ignoriert")
  func drawingWithoutMaterialIsIgnored() {
    let m = SecondScreenState()
    m.updateDrawing(TestDrawings.word, pageIndex: 0)
    #expect(m.material == nil)
  }
}
