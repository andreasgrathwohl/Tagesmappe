import CoreGraphics
import FrontstageCore
import SwiftUI

/// Ziel des Links „Erscheinungsbild“; holt `DataStore` aus der Umgebung und legt das Modell an
/// (Muster `SchoolYearSettingsScreen`).
struct AppearanceSettingsScreen: View {
  @Environment(DataStore.self) private var dataStore

  var body: some View {
    AppearanceSettingsHost(dataStore: dataStore)
  }
}

private struct AppearanceSettingsHost: View {
  @State private var model: AppearanceSettingsModel
  private let dataStore: DataStore

  init(dataStore: DataStore) {
    self.dataStore = dataStore
    _model = State(initialValue: AppearanceSettingsModel(store: dataStore))
  }

  var body: some View {
    AppearanceSettingsView(model: model)
      // Neuer Stand von diesem oder dem anderen Gerät → neu lesen.
      .onChange(of: dataStore.revision) { model.reload() }
  }
}

/// „Einrichten › Erscheinungsbild“ (FR-16). Systemstandard (`Form`, `Picker`, `ColorPicker`).
/// Ohne Kauf zeigt das Tor das Kaufangebot; die gespeicherte Wahl bleibt unberührt (FR-13).
struct AppearanceSettingsView: View {
  @Bindable var model: AppearanceSettingsModel
  @Environment(Unlock.self) private var unlock

  var body: some View {
    Form {
      if !unlock.isUnlocked {
        Section { Text("setup.appearance.locked").foregroundStyle(.secondary) }
      }
      PaidGate(feature: .appearance) {
        Section {
          Picker("setup.appearance.baseTone", selection: baseToneBinding) {
            ForEach(BaseTone.allCases, id: \.self) { tone in
              Text(Self.title(tone)).tag(tone)
            }
          }
          .pickerStyle(.inline)
        } header: {
          Text("setup.appearance.baseTone")
        }

        Section {
          ColorPicker(
            "setup.appearance.accent", selection: accentBinding, supportsOpacity: false)
          if model.theme.accent != nil {
            Button("setup.appearance.accent.standard") { model.useStandardAccent() }
          }
        } header: {
          Text("setup.appearance.accent")
        }

        Section {
          ThemePreview(resolved: model.resolved)
        } header: {
          Text("setup.appearance.preview")
        }

        Section {
          Picker("setup.appearance.mode", selection: modeBinding) {
            ForEach(AppearanceMode.allCases, id: \.self) { mode in
              Text(Self.title(mode)).tag(mode)
            }
          }
          .pickerStyle(.segmented)
        } header: {
          Text("setup.appearance.mode")
        }

        if !model.isStandard {
          Section {
            Button("setup.appearance.reset") { model.resetToStandard() }
          }
        }
        if model.saveFailed {
          Section { Text("setup.appearance.saveFailed").foregroundStyle(.red) }
        }
      }
    }
    .themedBackground()
    .navigationTitle(Text("setup.appearance.title"))
    .toolbar { ToolbarItem { HelpButton(topic: .appearance) } }
    // Swift-Hinweis: `.task(id:)` startet neu, sobald sich der Wert ändert, und bricht den alten Lauf ab –
    // das ergibt das Entprellen: gespeichert wird erst, wenn der Farbwähler 300 ms Ruhe hat.
    .task(id: model.theme.accent) {
      do { try await Task.sleep(for: .milliseconds(300)) } catch { return }
      model.commitAccent()
    }
  }

  private var baseToneBinding: Binding<BaseTone> {
    Binding(get: { model.theme.baseTone }, set: { model.setBaseTone($0) })
  }

  private var modeBinding: Binding<AppearanceMode> {
    Binding(get: { model.theme.appearanceMode }, set: { model.setAppearanceMode($0) })
  }

  /// Ohne eigene Wahl zeigt der Farbwähler den Standardakzent (hell).
  private var accentBinding: Binding<CGColor> {
    Binding(
      get: {
        let c = model.theme.accent?.color ?? ThemeResolver.standardAccentLight
        return CGColor(
          srgbRed: CGFloat(c.red) / 255, green: CGFloat(c.green) / 255, blue: CGFloat(c.blue) / 255,
          alpha: 1)
      },
      set: { model.previewAccent(SRGBColor(cgColor: $0)) })
  }

  private static func title(_ tone: BaseTone) -> LocalizedStringKey {
    switch tone {
    case .warm: "setup.appearance.baseTone.warm"
    case .system: "setup.appearance.baseTone.system"
    case .cool: "setup.appearance.baseTone.cool"
    case .petrol: "setup.appearance.baseTone.petrol"
    }
  }

  private static func title(_ mode: AppearanceMode) -> LocalizedStringKey {
    switch mode {
    case .system: "setup.appearance.mode.system"
    case .light: "setup.appearance.mode.light"
    case .dark: "setup.appearance.mode.dark"
    }
  }
}
