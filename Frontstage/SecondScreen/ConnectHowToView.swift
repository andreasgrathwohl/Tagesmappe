#if os(iOS)
  import SwiftUI

  /// Anleitung zum Verbinden eines Bildschirms (FR-11.6): AirPlay in drei Schritten, Kabel, Hinweis auf die
  /// automatische Erkennung. Es gibt keine Schnittstelle, das Kontrollzentrum zu öffnen; die Anleitung beschreibt
  /// den Weg nur. Schließt sich von selbst, sobald ein Bildschirm verbunden ist.
  struct ConnectHowToView: View {
    @Environment(SecondScreenState.self) private var state
    @Environment(\.dismiss) private var dismiss

    var body: some View {
      NavigationStack {
        List {
          Section("secondScreen.howTo.airplay") {
            step(1, "secondScreen.howTo.step1")
            step(2, "secondScreen.howTo.step2")
            step(3, "secondScreen.howTo.step3")
          }
          Section("secondScreen.howTo.cable") {
            Text("secondScreen.howTo.cableText")
          }
          Section {
            Text("secondScreen.howTo.autoDetect").foregroundStyle(.secondary)
          }
        }
        .navigationTitle(Text("secondScreen.howTo.title"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
          ToolbarItem(placement: .confirmationAction) {
            Button("viewer.done") { dismiss() }
          }
        }
      }
      // Verbindung hergestellt → Anleitung wird überflüssig.
      .onChange(of: state.isConnected, initial: true) { _, connected in
        if connected { dismiss() }
      }
    }

    private func step(_ number: Int, _ text: LocalizedStringKey) -> some View {
      HStack(alignment: .firstTextBaseline, spacing: 12) {
        Text(verbatim: "\(number).").monospacedDigit().foregroundStyle(.secondary)
        Text(text)
      }
    }
  }
#endif
