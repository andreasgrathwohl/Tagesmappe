#if os(iOS)
  import FrontstageCore
  import SwiftUI

  /// Einhängepunkt in der Smartboard-Leiste für die Knöpfe des Klassenbildschirms (FR-11.2, FR-11.3).
  ///
  /// Timer und Arbeitsform sind bezahlte Funktionen (FR-13) und werden nur am Tablet bedient, nie am
  /// Zweitbildschirm. Ohne Kauf steht statt der Knöpfe ein kompakter Hinweis, der das Kaufangebot öffnet.
  ///
  /// Swift-Hinweis: `@Bindable` macht aus einem `@Observable`-Objekt Bindings (`$session.timerMinutes`); das
  /// Objekt selbst kommt per `@Environment` und ist deshalb noch kein Binding-Träger.
  struct ClassroomControls: View {
    @Environment(Unlock.self) private var unlock
    @Environment(LessonSessionState.self) private var session
    @Environment(DataStore.self) private var store: DataStore?
    @State private var showOffer = false

    /// Meldet die laufende Stunde jede Minute selbst, nicht erst über den Klassenbildschirm: Der läuft nur, solange
    /// der Zweitbildschirm ihn zeigt. Sonst hinge die Arbeitsform an einer veralteten Stunde (FR-11.3).
    ///
    /// Swift-Hinweis: `TimelineView(.everyMinute)` zeichnet zu jeder vollen Minute neu; `.onChange(…, initial: true)`
    /// läuft außerhalb des Zeichnens und darf daher Zustand ändern.
    var body: some View {
      TimelineView(.everyMinute) { context in
        HStack(spacing: 16) {
          controls
          HelpButton(topic: .classScreen)
        }
        .onChange(of: runningKey(at: context.date), initial: true) { _, key in
          session.lessonDidChange(to: key)
        }
      }
    }

    private func runningKey(at date: Date) -> LessonKey? {
      store.flatMap { RunningLesson.key(in: $0, at: date) }
    }

    @ViewBuilder private var controls: some View {
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
      @Bindable var session = session
      HStack(spacing: 8) {
        Text("timer.title").font(.headline)
        switch session.timer.state {
        case .idle:
          Stepper("timer.minutes \(session.timerMinutes)", value: $session.timerMinutes, in: 1...60)
            .fixedSize()
          Button("timer.start") { session.startTimer(minutes: session.timerMinutes, now: .now) }
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
      HStack(spacing: 8) {
        Text("workMode.title").font(.headline)
        Picker("workMode.title", selection: workModeBinding) {
          Text("workMode.none").tag(WorkMode?.none)
          ForEach(WorkMode.allCases, id: \.self) { mode in
            Text(label(for: mode)).tag(WorkMode?.some(mode))
          }
        }
        .labelsHidden()
      }
    }

    /// Schreibt die Wahl an die Stunde, die **jetzt** läuft – auch wenn der Minutentakt sie noch nicht gemeldet hat.
    private var workModeBinding: Binding<WorkMode?> {
      Binding(
        get: { session.workMode },
        set: { session.selectWorkMode($0, for: runningKey(at: .now)) })
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
