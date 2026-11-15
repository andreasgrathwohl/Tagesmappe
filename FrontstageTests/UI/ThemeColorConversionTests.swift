import CoreGraphics
import FrontstageCore
import SwiftUI
import Testing

@testable import Frontstage

@Suite struct ThemeColorConversionTests {
  private func cg(_ name: CFString, _ r: CGFloat, _ g: CGFloat, _ b: CGFloat) -> CGColor {
    CGColor(colorSpace: CGColorSpace(name: name)!, components: [r, g, b, 1])!
  }

  @Test("sRGB-Rot aus CGColor ergibt #FF0000")
  func srgbRedConverts() {
    #expect(SRGBColor(cgColor: cg(CGColorSpace.sRGB, 1, 0, 0)).hex == "#FF0000")
  }

  @Test("Display-P3-Grün außerhalb von sRGB wird begrenzt, nie außerhalb 0...255")
  func p3IsClamped() {
    let color = SRGBColor(cgColor: cg(CGColorSpace.displayP3, 0, 1, 0))
    #expect((0...255).contains(color.red))
    #expect((0...255).contains(color.green))
    #expect((0...255).contains(color.blue))
    #expect(color.green == 255)
    #expect(color.red == 0)
  }

  @Test("Gelb #FFC94A über CGColor hin und zurück bleibt gleich")
  func roundTripKeepsHex() throws {
    let original = try #require(SRGBColor(hex: "#FFC94A"))
    let cgColor = cg(
      CGColorSpace.sRGB, CGFloat(original.red) / 255, CGFloat(original.green) / 255,
      CGFloat(original.blue) / 255)
    #expect(SRGBColor(cgColor: cgColor) == original)
  }

  @Test("Hell/Dunkel: system → nil, light → .light, dark → .dark")
  func appearanceModeMapsToColorScheme() {
    #expect(AppearanceMode.system.colorScheme == nil)
    #expect(AppearanceMode.light.colorScheme == .light)
    #expect(AppearanceMode.dark.colorScheme == .dark)
  }
}
