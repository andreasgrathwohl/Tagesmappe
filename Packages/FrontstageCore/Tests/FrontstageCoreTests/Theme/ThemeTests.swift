import Testing
@testable import FrontstageCore

@Suite("Theme Values") struct ThemeTests {
  @Test("FR-16: Standard ist warm, Standard-Akzent, wie das System") func standardTheme() {
    #expect(Theme.standard.baseTone == .warm)
    #expect(Theme.standard.accent == nil)
    #expect(Theme.standard.appearanceMode == .system)
    #expect(Theme.standard.isStandard)
    #expect(!Theme(baseTone: .cool, accent: nil, appearanceMode: .system).isStandard)
  }

  @Test("Rohwerte laut Glossar") func rawValuesFollowGlossary() {
    #expect(BaseTone.allCases.map(\.rawValue) == ["warm", "system", "cool", "petrol"])
    #expect(AppearanceMode.allCases.map(\.rawValue) == ["system", "light", "dark"])
    #expect(ThemeAccent(hex: "#0E6B7A")?.hex == "#0E6B7A")
    #expect(ThemeAccent(hex: "kaputt") == nil)
  }

  @Test("FR-13: ohne Kauf gilt der Standard, mit Kauf die Wahl") func effectiveWithoutUnlockIsStandard() {
    let cool = Theme(baseTone: .cool, accent: ThemeAccent(hex: "#FFF3A0"), appearanceMode: .dark)
    #expect(cool.effective(isUnlocked: false) == .standard)
    #expect(cool.effective(isUnlocked: true) == cool)
  }
}
