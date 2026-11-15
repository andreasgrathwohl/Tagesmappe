import Testing
@testable import FrontstageCore

private func c(_ hex: String) -> SRGBColor { SRGBColor(hex: hex)! }

@Suite("Theme Contrast") struct ContrastAdjusterTests {
  private let lightSurfaces = [c("#FBF8F2"), c("#ECE5D8")]

  @Test("Ausreichende Farbe bleibt unverändert") func unchangedWhenSufficient() {
    let tint = c("#0E6B7A").mixed(over: c("#FBF8F2"), percent: 14)
    let surfaces = lightSurfaces + [tint]
    let result = ContrastAdjuster.adjusted(c("#0E6B7A"), against: surfaces, minimum: 4.5, direction: .darken)
    #expect(result == c("#0E6B7A"))
  }

  @Test("AK-53: helles Gelb wird hell auf #6D6845 abgedunkelt") func darkensLightYellow() {
    let surfaces = [c("#FBF8F2"), c("#ECE5D8"), c("#FFF3A0").mixed(over: c("#FBF8F2"), percent: 14)]
    let result = ContrastAdjuster.adjusted(c("#FFF3A0"), against: surfaces, minimum: 4.5, direction: .darken)
    #expect(result.hex == "#6D6845")
    #expect(result.minimumContrast(against: surfaces) >= 4.5)
  }

  @Test("Dunkler Akzent wird dunkel aufgehellt, knapp über dem Ziel") func lightensDarkAccent() {
    let accent = c("#0E1B2A")
    let surfaces = [c("#17130E"), c("#2F2921"), accent.mixed(over: c("#17130E"), percent: 22)]
    let result = ContrastAdjuster.adjusted(accent, against: surfaces, minimum: 4.5, direction: .lighten)
    let ratio = result.minimumContrast(against: surfaces)
    #expect(ratio >= 4.5 && ratio < 4.7)
  }

  @Test("Systemblau hell: knapp über 4,5:1, Farbton bleibt (Blau größter Kanal)") func adjustsSystemBlue() {
    let blue = c("#0088FF")
    let surfaces = lightSurfaces + [blue.mixed(over: c("#FBF8F2"), percent: 14)]
    let result = ContrastAdjuster.adjusted(blue, against: surfaces, minimum: 4.5, direction: .darken)
    let ratio = result.minimumContrast(against: surfaces)
    #expect(ratio >= 4.5 && ratio < 4.6)
    #expect(result.blue > result.red && result.blue > result.green)
  }

  @Test("Unerreichbares Ziel endet bei Schwarz bzw. Weiß") func impossibleTargetEndsAtBlackOrWhite() {
    let darkened = ContrastAdjuster.adjusted(c("#FFF3A0"), against: lightSurfaces, minimum: 30, direction: .darken)
    #expect(darkened.hex == "#000000")
    let lightened = ContrastAdjuster.adjusted(c("#0E1B2A"), against: [c("#17130E")], minimum: 30, direction: .lighten)
    #expect(lightened.hex == "#FFFFFF")
  }
}
