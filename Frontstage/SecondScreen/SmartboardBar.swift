#if os(iOS)
  import FrontstageCore
  import SwiftUI

  /// Smartboard-Leiste am Tablet (FR-11.4, FR-11.5): Vorschaubild, Umschalter und Verbindungsstand in einer Zeile.
  ///
  /// Swift-Hinweis: `@Environment(SecondScreenState.self)` holt ein `@Observable`-Objekt aus der Umgebung. Liest
  /// der `body` eine Eigenschaft daraus (hier `isConnected`, `content`), zeichnet SwiftUI die Leiste bei
  /// Änderung von selbst neu – so erscheint der Verbindungsstand ohne Zutun (AK-35).
  struct SmartboardBar: View {
    @Environment(SecondScreenState.self) private var state
    @State private var showHowTo = false

    /// Breite des Vorschaubilds in Punkten.
    private static let previewWidth: CGFloat = 160
    /// Feste virtuelle Breite, in der der Klassenbildschirm gezeichnet wird; so erscheinen Schriftgrößen im
    /// selben Verhältnis wie auf dem echten Bildschirm.
    private static let virtualWidth: CGFloat = 960

    var body: some View {
      HStack(spacing: 16) {
        preview
        switcher
        ClassroomControls()
        Spacer(minLength: 0)
        connectionStatus
      }
      .padding(.horizontal)
      .padding(.vertical, 8)
      .background(.bar)
      .sheet(isPresented: $showHowTo) { ConnectHowToView() }
    }

    // MARK: Vorschaubild

    /// Dieselbe Ansicht wie auf dem Bildschirm (kein Bildschirmfoto), verkleinert; auch ohne Bildschirm sichtbar.
    private var preview: some View {
      let ratio = state.screenAspectRatio
      let scale = Self.previewWidth / Self.virtualWidth
      let virtualHeight = Self.virtualWidth / ratio
      return SecondScreenRootView(state: state)
        .frame(width: Self.virtualWidth, height: virtualHeight)
        .scaleEffect(scale, anchor: .topLeading)
        .frame(width: Self.previewWidth, height: Self.previewWidth / ratio, alignment: .topLeading)
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(.separator))
        .allowsHitTesting(false)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(previewAccessibilityLabel)
    }

    private var previewAccessibilityLabel: String {
      let mode = String(localized: state.content.titleResource)
      let label = String(localized: "secondScreen.preview.accessibility \(mode)")
      guard !state.isConnected else { return label }
      return label + ", " + String(localized: "secondScreen.disconnected")
    }

    // MARK: Umschalter

    private var switcher: some View {
      let available = state.state.availableModes
      return Picker("secondScreen.picker", selection: selection) {
        ForEach(Self.modes, id: \.self) { mode in
          Text(mode.titleKey)
            .tag(mode)
            .disabled(!available.contains(mode))
        }
      }
      .pickerStyle(.segmented)
      .labelsHidden()
      .frame(maxWidth: 420)
    }

    private static let modes: [SecondScreenContent] = [.classScreen, .material, .board, .dark]

    private var selection: Binding<SecondScreenContent> {
      Binding(get: { state.content }, set: { state.select($0) })
    }

    // MARK: Verbindungsstand

    @ViewBuilder private var connectionStatus: some View {
      if state.isConnected {
        Label("secondScreen.connected", systemImage: "tv")
          .foregroundStyle(.secondary)
      } else {
        Text("secondScreen.disconnected")
          .foregroundStyle(.secondary)
        Button {
          showHowTo = true
        } label: {
          // Die Tippfläche eines Buttons ist sein Label: Rahmen und contentShape gehören deshalb
          // ins Label, damit die Fläche wirklich mindestens 44 pt hoch ist (accessibility.md › Control size).
          Text("secondScreen.howTo")
            .frame(minHeight: 44)
            .contentShape(Rectangle())
        }
      }
    }
  }

  extension SecondScreenContent {
    /// Beschriftung im Umschalter.
    fileprivate var titleKey: LocalizedStringKey {
      switch self {
      case .classScreen: "secondScreen.mode.classScreen"
      case .material: "secondScreen.mode.material"
      case .board: "secondScreen.mode.board"
      case .dark: "secondScreen.mode.dark"
      }
    }

    /// Dieselbe Beschriftung als `LocalizedStringResource`, um daraus einen `String` zu bilden.
    fileprivate var titleResource: LocalizedStringResource {
      switch self {
      case .classScreen: "secondScreen.mode.classScreen"
      case .material: "secondScreen.mode.material"
      case .board: "secondScreen.mode.board"
      case .dark: "secondScreen.mode.dark"
      }
    }
  }
#endif
