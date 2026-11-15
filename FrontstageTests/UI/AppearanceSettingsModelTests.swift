import FrontstageCore
import Testing

@testable import Frontstage

/// „Einrichten › Erscheinungsbild“ (FR-16, FR-16.1).
@MainActor @Suite struct AppearanceSettingsModelTests {
  private let data: DataStore

  init() throws { data = try makeStore() }

  @Test("AK-52: voreingestellt warm mit Standardakzent")
  func loadsStandardWithoutRecord() throws {
    let model = AppearanceSettingsModel(store: data)
    #expect(model.theme == .standard)
    #expect(model.theme.baseTone == .warm && model.theme.accent == nil)
    #expect(model.isStandard)
    #expect(!model.saveFailed)
  }

  @Test("Öffnen schreibt nichts")
  func loadingDoesNotWrite() throws {
    let before = data.revision
    let model = AppearanceSettingsModel(store: data)
    model.reload()
    #expect(data.revision == before)
    #expect(model.isStandard)
  }

  @Test("AK-52: kühl wählen speichert")
  func setBaseToneSaves() throws {
    let model = AppearanceSettingsModel(store: data)
    model.setBaseTone(.cool)
    #expect(model.theme.baseTone == .cool)
    #expect(try data.theme().baseTone == .cool)
    #expect(!model.isStandard)
  }

  @Test("Farbwähler ändert nur die Vorschau, bis commitAccent")
  func previewAccentDoesNotSaveUntilCommit() throws {
    let model = AppearanceSettingsModel(store: data)
    let color = SRGBColor(hex: "#336699")!
    model.previewAccent(color)
    #expect(model.theme.accent?.color == color)
    #expect(try data.theme().accent == nil)
    model.commitAccent()
    #expect(try data.theme().accent?.color == color)
  }

  @Test("Übernehmen ohne Änderung schreibt nichts")
  func commitWithoutChangeDoesNotWrite() throws {
    let model = AppearanceSettingsModel(store: data)
    let before = data.revision
    model.commitAccent()
    #expect(data.revision == before)
  }

  @Test("Standardakzent verwenden löscht den Akzent")
  func useStandardAccentClears() throws {
    let model = AppearanceSettingsModel(store: data)
    model.previewAccent(SRGBColor(hex: "#336699")!)
    model.commitAccent()
    model.useStandardAccent()
    #expect(model.theme.accent == nil)
    #expect(try data.theme().accent == nil)
  }

  @Test("AK-53: Vorschau zeigt die abgedunkelte Fassung")
  func previewShowsAdjustedAccent() throws {
    let model = AppearanceSettingsModel(store: data)
    model.previewAccent(SRGBColor(hex: "#FFF3A0")!)
    #expect(model.resolved.colors(.light).accent.hex == "#6D6845")
    #expect(model.resolved.isAccentAdjusted(.light) && !model.resolved.isAccentAdjusted(.dark))
  }

  @Test("AK-54: Dunkel wählen speichert den Modus")
  func setAppearanceModeSaves() throws {
    let model = AppearanceSettingsModel(store: data)
    model.setAppearanceMode(.dark)
    #expect(model.theme.appearanceMode == .dark)
    #expect(try data.theme().appearanceMode == .dark)
  }

  @Test("Zurücksetzen schreibt den Standard")
  func resetToStandardSaves() throws {
    let model = AppearanceSettingsModel(store: data)
    model.setBaseTone(.petrol)
    model.setAppearanceMode(.dark)
    model.resetToStandard()
    #expect(model.isStandard)
    #expect(try data.theme() == .standard)
  }

  @Test("Abgleich vom anderen Gerät wird nach reload sichtbar")
  func reloadPicksUpExternalChange() throws {
    let model = AppearanceSettingsModel(store: data)
    try data.setTheme(Theme(baseTone: .cool, accent: nil, appearanceMode: .light))
    #expect(model.theme == .standard)
    model.reload()
    #expect(model.theme.baseTone == .cool && model.theme.appearanceMode == .light)
  }
}
