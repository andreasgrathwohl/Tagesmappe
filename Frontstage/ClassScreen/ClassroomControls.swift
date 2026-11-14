#if os(iOS)
  import FrontstageCore
  import SwiftUI

  /// Einhängepunkt in der Smartboard-Leiste für die Knöpfe des Klassenbildschirms (FR-11.2, FR-11.3).
  ///
  /// Timer und Arbeitsform sind bezahlte Funktionen (FR-13) und werden nur am Tablet bedient, nie am
  /// Zweitbildschirm. Ohne Kauf steht statt der Knöpfe ein kompakter Hinweis, der das Kaufangebot öffnet.
  ///
  /// Swift-Hinweis: `@Bindable` macht aus einem `@Observable`-Objekt Bindings (`$session.workMode`); das
  /// Objekt selbst kommt per `@Environment` und ist deshalb noch kein Binding-Träger.
  struct ClassroomControls: View {
    @Environment(Unlock.self) private var unlock
    @Environment(LessonSessionState.self) private var session
    /// Zuletzt verwendete Dauer; lebt nur, solange die Leiste lebt (flüchtig, kein Speichern).
    @State private var minutes = 5
    @State private var showOffer = false

    var body: some View {
      if unlock.isUnlocked {
        HStack(spacing: 16) {
          PaidGate(feature: .timer) { timerControls }
          PaidGate(feature: .workMode) { workModePicker }
        }
      } else {
        Button {
          showOffer = true
        } label: {
          Label("controls.locked", systemImage: "lock")
        }
        .sheet(isPresented: $showOffer) { PurchaseOfferView() }
      }
    }

    // MARK: Timer

    @ViewBuilder private var timerControls: some View {
      HStack(spacing: 8) {
        Text("timer.title").font(.headline)
        switch session.timer.state {
        case .idle:
          Stepper("timer.minutes \(minutes)", value: $minutes, in: 1...60)
            .fixedSize()
          Button("timer.start") { session.startTimer(minutes: minutes, now: .now) }
            .buttonStyle(.borderedProminent)
        case .running:
          Button("timer.pause") { session.pauseTimer(now: .now) }
          Button("timer.stop", role: .destructive) { session.stopTimer() }
        case .paused:
          Button("timer.resume") { session.resumeTimer(now: .now) }
          Button("timer.stop", role: .destructive) { session.stopTimer() }
        }
      }
    }

    // MARK: Arbeitsform

    private var workModePicker: some View {
      @Bindable var session = session
      return HStack(spacing: 8) {
        Text("workMode.title").font(.headline)
        Picker("workMode.title", selection: $session.workMode) {
          Text("workMode.none").tag(WorkMode?.none)
          ForEach(WorkMode.allCases, id: \.self) { mode in
            Text(label(for: mode)).tag(WorkMode?.some(mode))
          }
        }
        .labelsHidden()
      }
    }

    private func label(for mode: WorkMode) -> LocalizedStringKey {
      switch mode {
      case .individual: "workMode.individual"
      case .pairs: "workMode.pairs"
      case .groups: "workMode.groups"
      }
    }
  }
#endif
