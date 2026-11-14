import FrontstageCore
import SwiftUI

/// Legt das View-Modell des Zeitraster-Editors an; es entsteht je Datenort neu (`ScopedAppContent`).
struct BellScheduleEditorScreen: View {
  @Environment(AppEnvironment.self) private var environment

  var body: some View {
    BellScheduleEditorHost(environment: environment)
  }
}

private struct BellScheduleEditorHost: View {
  @State private var model: BellScheduleEditorViewModel

  init(environment: AppEnvironment) {
    _model = State(initialValue: BellScheduleEditorViewModel(environment: environment))
  }

  var body: some View { BellScheduleEditorView(model: model) }
}

/// „Einrichten › Zeitraster“ (FR-1.2): je Stunde Beginn und Ende. Systemstandard (`List`, `DatePicker`);
/// Gestaltung ist offen.
struct BellScheduleEditorView: View {
  let model: BellScheduleEditorViewModel
  @Environment(AppEnvironment.self) private var environment

  /// Fehler einer Eingabe im Zeitfeld; das Feld liest weiter den gespeicherten Wert.
  @State private var inputError: BellScheduleError?

  private enum Edge { case start, end }

  var body: some View {
    List {
      Section {
        ForEach(model.periods, id: \.self) { period in
          if let range = model.schedule.periods[period] {
            row(period: period, range: range)
          }
        }
        if model.periods.isEmpty {
          Text("setup.bellSchedule.empty").foregroundStyle(.secondary)
        }
      }
      Section {
        Button("setup.bellSchedule.add") { model.addPeriod() }
          .disabled(!model.canAddPeriod)
        Button("setup.bellSchedule.removeLast", role: .destructive) { model.removeLastPeriod() }
          .disabled(model.periods.isEmpty)
      }
    }
    .navigationTitle(Text("setup.bellSchedule.title"))
    .alert(
      Text("setup.bellSchedule.error.title"), isPresented: errorBinding,
      presenting: inputError ?? model.lastFailure
    ) { _ in
      Button("setup.bellSchedule.error.ok", role: .cancel) {}
    } message: { error in
      switch error {
      case .endNotAfterStart: Text("setup.bellSchedule.error.endNotAfterStart")
      case .overlaps(let other): Text("setup.bellSchedule.error.overlaps \(other)")
      case .saveFailed: Text("setup.bellSchedule.error.saveFailed")
      }
    }
    // Neuer Stand von diesem oder dem anderen Gerät → neu lesen.
    .onChange(of: environment.store.revision) { model.reload() }
  }

  private func row(period: Int, range: ClosedRange<TimeOfDay>) -> some View {
    HStack {
      Text("setup.bellSchedule.period \(period)")
      Spacer()
      DatePicker(
        "setup.bellSchedule.start", selection: binding(period: period, range: range, edge: .start),
        displayedComponents: .hourAndMinute
      )
      .labelsHidden()
      DatePicker(
        "setup.bellSchedule.end", selection: binding(period: period, range: range, edge: .end),
        displayedComponents: .hourAndMinute
      )
      .labelsHidden()
    }
  }

  /// `Date` ↔ `TimeOfDay` gibt es nur hier. Eine abgelehnte Eingabe wird nicht übernommen: Das Feld liest
  /// weiter den gespeicherten Wert, und der Fehler erscheint im Hinweis.
  private func binding(period: Int, range: ClosedRange<TimeOfDay>, edge: Edge) -> Binding<Date> {
    Binding(
      get: { Self.date(for: edge == .start ? range.lowerBound : range.upperBound) },
      set: { newDate in
        let time = TimeOfDay(newDate, calendar: .current)
        do {
          switch edge {
          case .start: try model.set(period: period, start: time, end: range.upperBound)
          case .end: try model.set(period: period, start: range.lowerBound, end: time)
          }
        } catch {
          inputError = error
        }
      })
  }

  /// Heutiges Datum mit der Uhrzeit; nur die Uhrzeit wird angezeigt.
  private static func date(for time: TimeOfDay) -> Date {
    Calendar.current.date(
      bySettingHour: time.hour, minute: time.minute, second: 0, of: Date()) ?? Date()
  }

  private var errorBinding: Binding<Bool> {
    Binding(
      get: { inputError != nil || model.lastFailure != nil },
      set: {
        if !$0 {
          inputError = nil
          model.lastFailure = nil
        }
      })
  }
}
