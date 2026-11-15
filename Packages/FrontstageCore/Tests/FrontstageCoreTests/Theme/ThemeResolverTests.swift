import Testing
@testable import FrontstageCore

@Suite("Theme Resolver") struct ThemeResolverTests {
  @Test("UI-9: Standard warm – Tönung, Akzent unverändert, Kontraste wie gemessen") func standardWarmMatchesDesign() {
    let r = ThemeResolver.resolve(.standard)
    let l = r.colors(.light), d = r.colors(.dark)
    #expect(l.accentTint.hex == "#DAE4E1" && d.accentTint.hex == "#273A38")
    #expect(l.accent.hex == "#0E6B7A" && d.accent.hex == "#5FC2CF")
    #expect(abs(SRGBColor.contrastRatio(l.accent, l.accentTint) - 4.76) < 0.02)
    #expect(abs(SRGBColor.contrastRatio(d.accent, d.accentTint) - 5.81) < 0.05)
    #expect(abs(SRGBColor.contrastRatio(l.text, l.accentTint) - 13.3) < 0.05)
    #expect(abs(SRGBColor.contrastRatio(d.text, d.accentTint) - 10.5) < 0.05)
    #expect(!r.isAccentAdjusted(.light) && !r.isAccentAdjusted(.dark))
  }

  @Test("UI-11: Signalsymbole in jedem Grundton wie beschlossen") func signalsMatchUI11ForEveryBaseTone() {
    for tone in BaseTone.allCases {
      let r = ThemeResolver.resolve(Theme(baseTone: tone, accent: nil, appearanceMode: .system))
      #expect(r.colors(.light).cancellationSymbol.hex == "#ED372D", "\(tone)")
      #expect(r.colors(.light).unavailableSymbol.hex == "#B86B00", "\(tone)")
      #expect(r.colors(.dark).cancellationSymbol.hex == "#FF453A", "\(tone)")
      #expect(r.colors(.dark).unavailableSymbol.hex == "#FF9F0A", "\(tone)")
    }
  }

  @Test("AK-53: gelber Akzent hell abgedunkelt (#6D6845), dunkel unverändert") func yellowAccentAdjustedInLightOnly() {
    let r = ThemeResolver.resolve(Theme(baseTone: .warm, accent: ThemeAccent(hex: "#FFF3A0"), appearanceMode: .system))
    #expect(r.colors(.light).accent.hex == "#6D6845" && r.isAccentAdjusted(.light))
    #expect(r.colors(.dark).accent.hex == "#FFF3A0" && !r.isAccentAdjusted(.dark))
    #expect(r.colors(.light).accentTint.hex == "#FCF7E7")
  }

  @Test("FR-16.1: eigener Akzent verschiebt keine Signalfarbe") func customAccentDoesNotMoveSignals() {
    for tone in BaseTone.allCases {
      let plain = ThemeResolver.resolve(Theme(baseTone: tone, accent: nil, appearanceMode: .system))
      for hex in ["#FFF3A0", "#FF3B30"] {
        let custom = ThemeResolver.resolve(Theme(baseTone: tone, accent: ThemeAccent(hex: hex), appearanceMode: .system))
        for v in ThemeVariant.allCases {
          #expect(custom.colors(v).cancellationSymbol == plain.colors(v).cancellationSymbol, "\(tone) \(hex)")
          #expect(custom.colors(v).unavailableSymbol == plain.colors(v).unavailableSymbol, "\(tone) \(hex)")
        }
      }
    }
  }

  @Test("FR-16.1: jeder Grundton, jede Variante, extreme Akzente erreichen die Ziele") func everyBaseToneMeetsFR161() {
    let accents: [ThemeAccent?] = [nil] + ["#FFFFFF", "#000000", "#FFF3A0", "#FF3B30", "#0088FF"].map { ThemeAccent(hex: $0) }
    for tone in BaseTone.allCases {
      for accent in accents {
        let r = ThemeResolver.resolve(Theme(baseTone: tone, accent: accent, appearanceMode: .system))
        for v in ThemeVariant.allCases {
          let c = r.colors(v)
          let accentTarget = v.isHighContrast ? 7.0 : 4.5
          let signalTarget = v.isHighContrast ? 4.5 : 3.0
          #expect(c.accent.minimumContrast(against: [c.background, c.selection, c.accentTint]) >= accentTarget,
                  "Akzent \(tone) \(accent?.hex ?? "Standard") \(v)")
          let std = v.isDark ? ThemeResolver.standardAccentDark : ThemeResolver.standardAccentLight
          let percent = v.isDark ? ThemeResolver.tintPercentDark : ThemeResolver.tintPercentLight
          let surfaces = [c.background, c.selection, std.mixed(over: c.background, percent: percent)]
          #expect(c.cancellationSymbol.minimumContrast(against: surfaces) >= signalTarget, "Entfällt \(tone) \(v)")
          #expect(c.unavailableSymbol.minimumContrast(against: surfaces) >= signalTarget, "Nicht verfügbar \(tone) \(v)")
        }
      }
    }
  }

  @Test("Kontrast erhöhen: Akzent ≥ 7:1, Haarlinie doppelt deckend") func highContrastRaisesTargets() {
    let r = ThemeResolver.resolve(.standard)
    #expect(abs(r.colors(.lightHighContrast).hairline.alpha - 0.44) < 1e-9)
    #expect(r.colors(.darkHighContrast).hairline.alpha == 1.0)
    #expect(r.colors(.lightHighContrast).background == r.colors(.light).background)
    #expect(r.colors(.darkHighContrast).text == r.colors(.dark).text)
    let hc = r.colors(.lightHighContrast)
    #expect(hc.accent.minimumContrast(against: [hc.background, hc.selection, hc.accentTint]) >= 7)
  }

  @Test("UI-12: Gelb und dunkles Wort fest, etwa 11:1") func nowColorsAreFixed() {
    let r = ThemeResolver.resolve(Theme(baseTone: .petrol, accent: ThemeAccent(hex: "#FF3B30"), appearanceMode: .dark))
    for v in ThemeVariant.allCases {
      #expect(r.colors(v).nowFill.hex == "#FFC94A")
      #expect(r.colors(v).nowText.hex == "#1F1A14")
      #expect(SRGBColor.contrastRatio(r.colors(v).nowFill, r.colors(v).nowText) > 11)
    }
  }

  @Test("UI-8: Paletten aus DESIGN.md; nur System nutzt Systemfarben") func palettesFromDesign() {
    func resolved(_ t: BaseTone) -> ResolvedTheme {
      ThemeResolver.resolve(Theme(baseTone: t, accent: nil, appearanceMode: .system))
    }
    #expect(resolved(.cool).colors(.light).background.hex == "#F7F9FC")
    #expect(resolved(.petrol).colors(.dark).selection.hex == "#15292C")
    let h = resolved(.warm).colors(.light).hairline
    #expect(h.red == 92 && h.green == 72 && h.blue == 48 && h.alpha == 0.22)
    for t in BaseTone.allCases { #expect(resolved(t).usesSystemNeutrals == (t == .system)) }
  }
}
