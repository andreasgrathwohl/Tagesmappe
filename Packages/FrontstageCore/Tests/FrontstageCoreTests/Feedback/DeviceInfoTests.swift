import Testing
@testable import FrontstageCore

enum FeedbackFixtures {
  static let info = DeviceInfo(appVersion: "0.1.0", build: "1", systemName: "iPadOS", systemVersion: "26.1",
                               modelIdentifier: "iPad14,5", dataLocation: .iCloud, theme: .standard,
                               isUnlocked: false, languageCode: "de")
}

@Suite("Device Info") struct DeviceInfoTests {
  @Test("Zeilen wörtlich, ohne Namen (FR-17.3)")
  func reportLines() {
    #expect(FeedbackFixtures.info.reportLines == [
      "App: Frontstage 0.1.0 (1)", "System: iPadOS 26.1", "Gerät: iPad14,5", "Datenort: iCloud",
      "Erscheinungsbild: warm, Standardakzent, wie das System", "Kauf: nein", "Sprache: de",
    ])
  }

  @Test("Eigener Akzent und dunkel (FR-17.3)")
  func customAccentLine() {
    var info = FeedbackFixtures.info
    info.theme = Theme(baseTone: .cool, accent: ThemeAccent(hex: "#FFF3A0"), appearanceMode: .dark)
    info.dataLocation = .oneDrive
    info.isUnlocked = true
    #expect(info.reportLines[3] == "Datenort: OneDrive")
    #expect(info.reportLines[4] == "Erscheinungsbild: kühl, Akzent #FFF3A0, dunkel")
    #expect(info.reportLines[5] == "Kauf: ja")
  }

  @Test("Grundtöne und Modi (FR-17.3)")
  func toneAndModeWords() {
    var info = FeedbackFixtures.info
    info.theme = Theme(baseTone: .petrol, accent: nil, appearanceMode: .light)
    #expect(info.reportLines[4] == "Erscheinungsbild: Petrol, Standardakzent, hell")
    info.theme = Theme(baseTone: .system, accent: nil, appearanceMode: .system)
    #expect(info.reportLines[4] == "Erscheinungsbild: System, Standardakzent, wie das System")
  }
}
