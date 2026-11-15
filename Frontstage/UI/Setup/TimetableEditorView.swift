import FrontstageCore
import SwiftUI

/// Legt das View-Modell des Stundenplan-Editors an; es entsteht je Datenort neu (`ScopedAppContent`).
struct TimetableEditorScreen: View {
  @Environment(AppEnvironment.self) private var environment

  var body: some View {
    TimetableEditorHost(environment: environment)
  }
}

private struct TimetableEditorHost: View {
  @State private var model: TimetableEditorViewModel

  init(environment: AppEnvironment) {
    _model = State(initialValue: TimetableEditorViewModel(environment: environment))
  }

  var body: some View { TimetableEditorView(model: model) }
}

/// Ziel des Sheets: Feld, auf das getippt wurde, und ggf. die zu ändernde Stunde.
private struct EntryTarget: Identifiable {
  let id = UUID()
  let entry: TimetableEntry?
  let weekday: Weekday
  let period: Int
}

/// „Einrichten › Stundenplan“ (FR-1, FR-1.1): Wochenrhythmus, Bezugswoche und das Raster
/// Wochentag × Stunde. Systemstandard (`List`, `Grid`, `Picker`); Gestaltung ist offen.
struct TimetableEditorView: View {
  let model: TimetableEditorViewModel
  @Environment(AppEnvironment.self) private var environment

  @State private var target: EntryTarget?
  /// Anzahl der B-Einträge, die beim Wechsel auf eine Woche wegfielen; zeigt die Rückfrage.
  @State private var pendingReduction: Int?

  var body: some View {
    List {
      rhythmSection
      Section {
        grid
      } header: {
        if model.weekVariantCount == 2 {
          Picker("setup.timetable.shown", selection: shownBinding) {
            Text("setup.timetable.variant.a").tag(WeekVariant.a)
            Text("setup.timetable.variant.b").tag(WeekVariant.b)
          }
          .pickerStyle(.segmented)
          .textCase(nil)
        }
      } footer: {
        Text("setup.timetable.grid.footer")
      }
    }
    .themedBackground()
    .navigationTitle(Text("setup.timetable.title"))
    .toolbar {
      ToolbarItem(placement: .primaryAction) {
        Button("setup.timetable.add", systemImage: "plus") {
          target = EntryTarget(entry: nil, weekday: .monday, period: model.periodChoices.first ?? 1)
        }
      }
    }
    .sheet(item: $target) { target in
      TimetableEntrySheet(
        model: model, editing: target.entry, weekday: target.weekday, period: target.period)
    }
    .confirmationDialog(
      Text("setup.timetable.reduce.title \(pendingReduction ?? 0)"), isPresented: pendingBinding,
      titleVisibility: .visible
    ) {
      Button("setup.timetable.reduce.confirm", role: .destructive) {
        _ = model.setWeekVariantCount(1, confirmed: true)
      }
      Button("setup.timetable.reduce.cancel", role: .cancel) {}
    } message: {
      Text("setup.timetable.reduce.message")
    }
    .alert(
      Text("setup.timetable.error.title"), isPresented: failureBinding, presenting: model.lastFailure
    ) { _ in
      Button("setup.timetable.error.ok", role: .cancel) {}
    } message: { failure in
      Text(failure.messageKey)
    }
    // Neuer Stand von diesem oder dem anderen Gerät → neu lesen.
    .onChange(of: environment.store.revision) { model.reload() }
  }

  // MARK: - Rhythmus

  private var rhythmSection: some View {
    Section {
      Picker("setup.timetable.weekVariants", selection: variantCountBinding) {
        Text("setup.timetable.weekVariants.one").tag(1)
        Text("setup.timetable.weekVariants.two").tag(2)
      }
      if model.weekVariantCount == 2 {
        DatePicker(
          "setup.timetable.referenceWeek", selection: referenceWeekBinding, displayedComponents: .date)
        Text("setup.timetable.referenceWeek.current \(PreparationFormat.weekRange(from: model.referenceWeekA))")
          .font(.footnote)
          .foregroundStyle(.secondary)
      }
    } footer: {
      if model.weekVariantCount == 2 {
        Text("setup.timetable.referenceWeek.footer")
      }
    }
  }

  // MARK: - Raster

  private var grid: some View {
    // Swift-Hinweis: `Grid` (iOS 16+) richtet Zellen in Zeilen und Spalten aus; `GridRow` ist eine Zeile.
    ScrollView(.horizontal) {
      Grid(alignment: .topLeading, horizontalSpacing: 12, verticalSpacing: 8) {
        GridRow {
          Text(verbatim: "")
          ForEach(model.weekdays, id: \.self) { weekday in
            Text(verbatim: weekday.shortName).font(.headline)
          }
        }
        ForEach(model.gridPeriods, id: \.self) { period in
          GridRow {
            Text(verbatim: String(period)).font(.headline).foregroundStyle(.secondary)
            ForEach(model.weekdays, id: \.self) { weekday in
              cell(weekday: weekday, period: period)
            }
          }
        }
      }
      .padding(.vertical, 4)
    }
  }

  private func cell(weekday: Weekday, period: Int) -> some View {
    let entries = model.entries(weekday: weekday, period: period)
    return VStack(alignment: .leading, spacing: 4) {
      if entries.isEmpty {
        Button {
          target = EntryTarget(entry: nil, weekday: weekday, period: period)
        } label: {
          Image(systemName: "plus").frame(minWidth: 72, minHeight: 44)
        }
        .buttonStyle(.borderless)
        .accessibilityLabel(Text("setup.timetable.add"))
      } else {
        ForEach(entries, id: \.self) { entry in
          Button {
            target = EntryTarget(entry: entry, weekday: weekday, period: period)
          } label: {
            Text(verbatim: "\(entry.schoolClass.normalized) · \(entry.subject.display)")
              .frame(minWidth: 72, minHeight: 44, alignment: .leading)
          }
          .buttonStyle(.bordered)
        }
      }
    }
  }

  // MARK: - Bindungen

  private var shownBinding: Binding<WeekVariant> {
    Binding(get: { model.shownVariant }, set: { model.shownVariant = $0 })
  }

  /// Wechsel auf eine Variante mit B-Einträgen fragt vorher nach; das Modell ändert dann nichts.
  private var variantCountBinding: Binding<Int> {
    Binding(
      get: { model.weekVariantCount },
      set: { newValue in
        if let affected = model.setWeekVariantCount(newValue, confirmed: false) {
          pendingReduction = affected
        }
      })
  }

  private var referenceWeekBinding: Binding<Date> {
    Binding(
      get: { PreparationFormat.date(model.referenceWeekA) },
      set: { model.setReferenceWeek(containing: CalendarDay($0, calendar: .current)) })
  }

  private var pendingBinding: Binding<Bool> {
    Binding(get: { pendingReduction != nil }, set: { if !$0 { pendingReduction = nil } })
  }

  private var failureBinding: Binding<Bool> {
    Binding(get: { model.lastFailure != nil }, set: { if !$0 { model.lastFailure = nil } })
  }
}
