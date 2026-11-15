import Testing
@testable import FrontstageCore

private func c(_ hex: String) -> SRGBColor { SRGBColor(hex: hex)! }

@Suite("Theme Color") struct SRGBColorTests {
  @Test("Hex lesen und schreiben") func parsesAndFormatsHex() {
    #expect(SRGBColor(hex: "#0E6B7A") == SRGBColor(red: 14, green: 107, blue: 122))
    #expect(SRGBColor(hex: "0e6b7a")?.hex == "#0E6B7A")
    #expect(SRGBColor(hex: "#0E6B7") == nil && SRGBColor(hex: "#GGGGGG") == nil && SRGBColor(hex: "") == nil)
    #expect(SRGBColor(hex: "+0E6B7A") == nil)
  }

  @Test("Schwarz/Weiß: Leuchtdichte 0 und 1, Kontrast 21:1, symmetrisch") func blackWhiteContrast() {
    let black = c("#000000"), white = c("#FFFFFF")
    #expect(black.relativeLuminance == 0)
    #expect(abs(white.relativeLuminance - 1) < 1e-12)
    #expect(abs(SRGBColor.contrastRatio(black, white) - 21) < 1e-9)
    #expect(SRGBColor.contrastRatio(black, white) == SRGBColor.contrastRatio(white, black))
  }

  @Test("UI-8: warmer Text auf Grund 16,3:1 hell und 16,2:1 dunkel") func warmTextContrast() {
    #expect(abs(SRGBColor.contrastRatio(c("#1F1A14"), c("#FBF8F2")) - 16.29) < 0.01)
    #expect(abs(SRGBColor.contrastRatio(c("#F5EFE5"), c("#17130E")) - 16.16) < 0.01)
  }

  @Test("UI-9: Standard-Tönung #DAE4E1 hell und #273A38 dunkel (deckend, halb aufrunden)") func standardTint() {
    #expect(c("#0E6B7A").mixed(over: c("#FBF8F2"), percent: 14).hex == "#DAE4E1")
    #expect(c("#5FC2CF").mixed(over: c("#17130E"), percent: 22).hex == "#273A38")
    #expect(c("#0E6B7A").mixed(over: c("#FBF8F2"), percent: 14).alpha == 1)
  }

  @Test("Ungünstigste Fläche zählt, leere Liste ergibt unendlich") func minimumContrastWorstSurface() {
    let text = c("#1F1A14")
    let surfaces = [c("#FBF8F2"), c("#4A4A4A")]
    #expect(text.minimumContrast(against: surfaces) == SRGBColor.contrastRatio(text, c("#4A4A4A")))
    #expect(text.minimumContrast(against: []) == .infinity)
  }

  @Test("Deckkraft ändert Hex und Kontrast nicht") func alphaIgnoredInContrast() {
    let faint = c("#0E6B7A").withAlpha(0.2)
    #expect(faint.alpha == 0.2)
    #expect(faint.hex == "#0E6B7A")
    #expect(faint.relativeLuminance == c("#0E6B7A").relativeLuminance)
  }
}
