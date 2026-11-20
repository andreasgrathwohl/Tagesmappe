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

/// „Einrichten › Stundenplan“ (FR-1, FR-1.1, FR-1.3): Wochenrhythmus, Bezugswoche und das Raster
/// Wochentag × Stunde; rechts der feste Bearbeitungsbereich für das gewählte Feld (UI-16).
///
/// Swift-Hinweis: `.inspector` ist ein Systembereich am Rand (iPadOS 17+, macOS 14+). Bei voller Breite steht er
/// als Spalte rechts, bei schmaler Breite (iPad hochkant, Split View) zeigt SwiftUI ihn von selbst als Blatt.
struct TimetableEditorView: View {
  let model: TimetableEditorViewModel
  @Environment(AppEnvironment.self) private var environment
  #if os(iOS)
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
  #endif

  /// Gewähltes Feld im Raster; `nil`: nichts gewählt.
  @State private var selection: TimetableSelection?
  /// Stehen im Bereich ungesicherte Eingaben? Dann fragt ein Wechsel der Auswahl nach.
  @State private var hasUnsavedChanges = false
  /// Gewünschte Auswahl, solange die Rückfrage „Änderungen verwerfen?“ offen ist.
  @State private var pendingSelection: TimetableSelection?
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
        Button("setup.timetable.add", systemImage: "plus") { selectFirstFreeSlot() }
      }
      ToolbarItem { HelpButton(topic: .timetable) }
    }
    .inspector(isPresented: inspectorBinding) {
      Group {
        if let current = selection {
          // Gleiche Identität (`nil`) für jedes freie Feld: Klasse und Fach bleiben beim Weiterwandern stehen.
          TimetableEntryEditor(
            model: model, selection: $selection, hasUnsavedChanges: $hasUnsavedChanges, start: current
          )
          .id(current.entry)
        } else {
          ContentUnavailableView("setup.timetable.selectCell", systemImage: "hand.tap")
        }
      }
      .inspectorColumnWidth(min: 320, ideal: 360, max: 440)
    }
    .confirmationDialog(
      Text("setup.timetable.discard.title"), isPresented: discardBinding, titleVisibility: .visible
    ) {
      Button("setup.timetable.discard.confirm", role: .destructive) {
        hasUnsavedChanges = false
        selection = pendingSelection
        pendingSelection = nil
      }
      Button("setup.timetable.discard.keep", role: .cancel) { pendingSelection = nil }
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
    // Neuer Stand von diesem oder dem anderen Gerät → neu lesen. Ist die gewählte Stunde dabei weggefallen
    // (etwa am anderen Gerät gelöscht), endet die Auswahl.
    .onChange(of: environment.store.revision) {
      model.reload()
      if let entry = selection?.entry, !model.allEntries.contains(entry) { selection = nil }
    }
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
              .accessibilityLabel(Text(verbatim: weekday.displayName))
              .accessibilityAddTraits(.isHeader)
          }
        }
        ForEach(model.gridPeriods, id: \.self) { period in
          GridRow {
            Text(verbatim: String(period)).font(.headline).foregroundStyle(.secondary)
              .accessibilityAddTraits(.isHeader)
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
    let freeSlot = TimetableSelection(weekday: weekday, period: period, entry: nil)
    return VStack(alignment: .leading, spacing: 4) {
      if entries.isEmpty {
        Button {
          select(freeSlot)
        } label: {
          Image(systemName: "plus").frame(minWidth: 72, minHeight: 44)
        }
        .buttonStyle(.borderless)
        .overlay { selectionRing(selection == freeSlot) }
        .accessibilityLabel(Text("setup.timetable.cell.free \(weekday.displayName) \(period)"))
        .accessibilityAddTraits(selection == freeSlot ? .isSelected : [])
      } else {
        ForEach(entries, id: \.self) { entry in
          Button {
            select(TimetableSelection(weekday: weekday, period: period, entry: entry))
          } label: {
            Text(verbatim: "\(entry.schoolClass.normalized) · \(entry.subject.display)")
              .frame(minWidth: 72, minHeight: 44, alignment: .leading)
          }
          .buttonStyle(.bordered)
          .overlay { selectionRing(selection?.entry == entry) }
          .accessibilityLabel(
            Text(
              "setup.timetable.cell.lesson \(weekday.displayName) \(period) \(entry.schoolClass.normalized) \(entry.subject.display)"
            )
          )
          .accessibilityAddTraits(selection?.entry == entry ? .isSelected : [])
        }
      }
    }
  }

  /// Rahmen um das gewählte Feld, in der Akzentfarbe; Auswahlradius 10 (UI-10).
  @ViewBuilder private func selectionRing(_ isSelected: Bool) -> some View {
    if isSelected {
      RoundedRectangle(cornerRadius: 10, style: .continuous)
        .strokeBorder(Color.accentColor, lineWidth: 3)
        .allowsHitTesting(false)
    }
  }

  // MARK: - Bereich

  /// Bei voller Breite steht der Bereich immer; bei schmaler Breite (als Blatt) nur, solange ein Feld gewählt
  /// ist. Schließt man das Blatt, endet die Auswahl.
  private var inspectorBinding: Binding<Bool> {
    Binding(
      get: {
        #if os(iOS)
          horizontalSizeClass != .compact || selection != nil
        #else
          true
        #endif
      },
      set: { if !$0 { selection = nil } })
  }

  /// Auswahl wechseln; stehen im Bereich ungesicherte Eingaben, fragt erst „Änderungen verwerfen?“.
  private func select(_ target: TimetableSelection) {
    guard target != selection else { return }
    // Zwischen freien Feldern bleiben die Eingaben erhalten (gleiche Identität), dort ist nichts zu verlieren.
    if hasUnsavedChanges, !(selection?.entry == nil && target.entry == nil) {
      pendingSelection = target
    } else {
      selection = target
    }
  }

  private var discardBinding: Binding<Bool> {
    Binding(get: { pendingSelection != nil }, set: { if !$0 { pendingSelection = nil } })
  }

  /// „+“ in der Werkzeugleiste: das erste freie Feld der Woche wählen.
  private func selectFirstFreeSlot() {
    let firstDay = model.weekdays.first ?? .monday
    let start = (model.gridPeriods.first ?? 1) - 1
    if let slot = model.nextFreeSlot(after: firstDay, period: start) {
      select(TimetableSelection(weekday: slot.weekday, period: slot.period, entry: nil))
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
