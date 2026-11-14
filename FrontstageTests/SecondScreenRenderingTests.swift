import Testing

@testable import Frontstage

@Suite struct SecondScreenRenderingTests {
  @Test("AK-40: ohne Kauf neutrale Fläche statt Klassenbildschirm, Material und Dunkel bleiben frei")
  func respectsUnlock() {
    #expect(SecondScreenRendering.resolve(.classScreen, isUnlocked: false) == .neutral)
    #expect(SecondScreenRendering.resolve(.material, isUnlocked: false) == .material)
    #expect(SecondScreenRendering.resolve(.board, isUnlocked: false) == .neutral)
    #expect(SecondScreenRendering.resolve(.dark, isUnlocked: false) == .dark)
    #expect(SecondScreenRendering.resolve(.classScreen, isUnlocked: true) == .classScreen)
    #expect(SecondScreenRendering.resolve(.board, isUnlocked: true) == .board)
  }
}
