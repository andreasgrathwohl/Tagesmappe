import FrontstageCore
import SwiftUI

extension Weekday {
  /// Ausgeschriebener Name in der Sprache des Geräts. `weekdaySymbols` beginnt mit Sonntag (Index 0).
  var displayName: String { Calendar.current.weekdaySymbols[rawValue % 7] }

  /// Kurzname für die Zeilen- und Spaltenköpfe des Rasters.
  var shortName: String { Calendar.current.shortWeekdaySymbols[rawValue % 7] }
}

extension TimetableEditError {
  /// Schlüssel des Fehlertexts in `Localizable.xcstrings`.
  var messageKey: LocalizedStringKey {
    switch self {
    case .emptyClass: "setup.timetable.error.emptyClass"
    case .emptySubject: "setup.timetable.error.emptySubject"
    case .invalidPeriod: "setup.timetable.error.invalidPeriod"
    case .duplicate: "setup.timetable.error.duplicate"
    case .saveFailed: "setup.timetable.error.saveFailed"
    }
  }
}

/// Eine feste Stunde anlegen oder ändern: Klasse, Fach, Wochentag, Stunde und – bei zwei
/// Wochenvarianten – „gilt für: beide / A / B“. Systemstandard; Gestaltung ist offen.
struct TimetableEntrySheet: View {
  let model: TimetableEditorViewModel
  /// `nil`: neue Stunde.
  let editing: TimetableEntry?

  @Environment(\.dismiss) private var dismiss
  @State private var className: String
  @State private var subjectName: String
  @State private var weekday: Weekday
  @State private var period: Int
  @State private var variant: WeekVariant?
  @State private var error: TimetableEditError?

  /// `weekday` und `period` sind die Vorgabe beim Tipp auf ein leeres Feld.
  init(model: TimetableEditorViewModel, editing: TimetableEntry?, weekday: Weekday, period: Int) {
    self.model = model
    self.editing = editing
    _className = State(initialValue: editing?.schoolClass.normalized ?? "")
    _subjectName = State(initialValue: editing?.subject.display ?? "")
    _weekday = State(initialValue: editing?.weekday ?? weekday)
    _period = State(initialValue: editing?.period ?? period)
    _variant = State(initialValue: editing?.weekVariant ?? (model.weekVariantCount == 2 ? model.shownVariant : nil))
  }

  var body: some View {
    NavigationStack {
      Form {
        Section {
          TextField("setup.timetable.entry.class", text: $className)
            #if os(iOS)
              .textInputAutocapitalization(.never)
            #endif
          TextField("setup.timetable.entry.subject", text: $subjectName)
        }
        Section {
          Picker("setup.timetable.entry.weekday", selection: $weekday) {
            ForEach(Weekday.allCases, id: \.self) { Text(verbatim: $0.displayName).tag($0) }
          }
          Picker("setup.timetable.entry.period", selection: $period) {
            ForEach(periods, id: \.self) { Text(verbatim: String($0)).tag($0) }
          }
          if model.weekVariantCount == 2 {
            // `WeekVariant?` als Auswahlwert: `nil` ist „beide Wochen“.
            Picker("setup.timetable.entry.appliesTo", selection: $variant) {
              Text("setup.timetable.variant.both").tag(WeekVariant?.none)
              Text("setup.timetable.variant.a").tag(WeekVariant?.some(.a))
              Text("setup.timetable.variant.b").tag(WeekVariant?.some(.b))
            }
          }
        }
        if let error {
          Section { Text(error.messageKey).foregroundStyle(.red) }
        }
        if let editing {
          Section {
            Button("setup.timetable.entry.delete", role: .destructive) {
              model.delete(editing)
              dismiss()
            }
          }
        }
      }
      // Explizit `LocalizedStringKey`: ein Ternär zweier Literale würde sonst als `String` (nicht lokalisiert) gelesen.
      .navigationTitle(
        Text(
          editing == nil
            ? LocalizedStringKey("setup.timetable.entry.titleNew")
            : LocalizedStringKey("setup.timetable.entry.titleEdit")))
      #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
      #endif
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("setup.timetable.entry.cancel") { dismiss() }
        }
        ToolbarItem(placement: .confirmationAction) {
          Button("setup.timetable.entry.save") { save() }
        }
      }
    }
  }

  /// Auswahl der Stunden; eine vorhandene Stunde außerhalb des Zeitrasters bleibt wählbar.
  private var periods: [Int] {
    Set(model.periodChoices).union([period]).sorted()
  }

  private func save() {
    let entry = TimetableEntry(
      weekVariant: model.weekVariantCount == 2 ? variant : nil, weekday: weekday, period: period,
      schoolClass: SchoolClass(className), subject: Subject(subjectName))
    do {
      try model.save(entry, replacing: editing)
      dismiss()
    } catch {
      self.error = error
    }
  }
}
