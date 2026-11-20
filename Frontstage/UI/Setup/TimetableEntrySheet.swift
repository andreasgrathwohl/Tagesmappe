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
///
/// Schnelles Eintragen (FR-1.3): Unter Klasse und Fach stehen Vorschläge aus dem Stundenplan; ein Tipp setzt nur
/// das Feld. Beim Anlegen sichert „Sichern und nächste“ und springt zum nächsten freien Feld; Klasse und Fach
/// bleiben stehen, damit eine Doppelstunde ein Tipp ist.
///
/// Swift-Hinweis: `@FocusState` hält, welches Textfeld die Tastatur hat; setzt man den Wert, springt der Fokus.
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
  /// Zuletzt mit „Sichern und nächste“ gesicherte Stunde, als Rückmeldung im Blatt.
  @State private var lastSaved: TimetableEntry?
  @FocusState private var focusedField: Field?
  /// Tage, auf die die gesicherte Stunde übernommen werden soll (nur beim Ändern).
  @State private var copyDays: Set<Weekday> = []
  @State private var copyResult: TimetableEntryCopy.Plan?

  private enum Field { case schoolClass, subject }

  /// `weekday` und `period` sind die Vorgabe beim Tipp auf ein leeres Feld.
  init(model: TimetableEditorViewModel, editing: TimetableEntry?, weekday: Weekday, period: Int) {
    self.model = model
    self.editing = editing
    _className = State(initialValue: editing?.schoolClass.normalized ?? "")
    _subjectName = State(initialValue: editing?.subject.display ?? "")
    _weekday = State(initialValue: editing?.weekday ?? weekday)
    _period = State(initialValue: editing?.period ?? period)
    _variant = State(initialValue: model.initialVariant(editing: editing))
  }

  var body: some View {
    NavigationStack {
      Form {
        Section {
          TextField("setup.timetable.entry.class", text: $className)
            #if os(iOS)
              .textInputAutocapitalization(.never)
            #endif
            .focused($focusedField, equals: .schoolClass)
            .submitLabel(.next)
            .onSubmit { focusedField = .subject }
          SuggestionRow(labels: model.classSuggestions(matching: className).map(\.normalized)) {
            className = $0
            focusedField = .subject
          }
          TextField("setup.timetable.entry.subject", text: $subjectName)
            .focused($focusedField, equals: .subject)
            .submitLabel(editing == nil ? .next : .done)
            .onSubmit {
              if editing == nil { saveAndNext() } else { save() }
            }
          SuggestionRow(
            labels: model.subjectSuggestions(forClass: className, matching: subjectName).map(\.display)
          ) { subjectName = $0 }
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
        if editing == nil {
          Section {
            Button("setup.timetable.entry.saveAndNext") { saveAndNext() }
          } footer: {
            if let lastSaved {
              Text(
                "setup.timetable.entry.saved \(lastSaved.weekday.displayName) \(lastSaved.period) \(lastSaved.schoolClass.normalized) \(lastSaved.subject.display)"
              )
            }
          }
        }
        if let editing {
          copySection(editing)
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
    if store() != nil { dismiss() }
  }

  /// „Auf andere Tage übernehmen“: Tage als Knöpfe zum An- und Abwählen, dann ein Knopf zum Übernehmen. Übernommen
  /// wird die gesicherte Stunde (`editing`), nicht ungesicherte Änderungen im Blatt.
  private func copySection(_ editing: TimetableEntry) -> some View {
    Section {
      HStack(spacing: 8) {
        ForEach(model.weekdays.filter { $0 != editing.weekday }, id: \.self) { day in
          let isOn = copyDays.contains(day)
          // Swift-Hinweis: Zwei Knopfstile in einem Ternär sind verschiedene Typen; darum zwei Zweige.
          Group {
            if isOn {
              Button { copyDays.remove(day) } label: { Text(verbatim: day.shortName) }
                .buttonStyle(.borderedProminent)
            } else {
              Button { copyDays.insert(day) } label: { Text(verbatim: day.shortName) }
                .buttonStyle(.bordered)
            }
          }
          .accessibilityLabel(Text(verbatim: day.displayName))
          .accessibilityAddTraits(isOn ? .isSelected : [])
        }
      }
      Button("setup.timetable.entry.copy") { copy(editing) }
        .disabled(copyDays.isEmpty)
    } header: {
      Text("setup.timetable.entry.copy.header")
    } footer: {
      if let copyResult {
        VStack(alignment: .leading, spacing: 4) {
          Text("setup.timetable.entry.copy.result \(copyResult.additions.count)")
          if !copyResult.occupied.isEmpty {
            Text(
              "setup.timetable.entry.copy.occupied \(copyResult.occupied.map(\.shortName).formatted(.list(type: .and)))"
            )
          }
        }
      } else {
        Text("setup.timetable.entry.copy.footer")
      }
    }
  }

  private func copy(_ editing: TimetableEntry) {
    do throws(TimetableEditError) {
      copyResult = try model.copy(editing, to: copyDays)
      copyDays = []
      error = nil
    } catch {
      self.error = error
    }
  }

  /// Sichern, dann zum nächsten freien Feld; ist keins mehr frei, schließt das Blatt.
  private func saveAndNext() {
    guard let saved = store() else { return }
    guard let next = model.nextFreeSlot(after: saved.weekday, period: saved.period) else {
      return dismiss()
    }
    lastSaved = saved
    weekday = next.weekday
    period = next.period
    focusedField = .schoolClass
  }

  /// Sichert die Eingabe; `nil` bei Fehler (dann steht er im Blatt).
  private func store() -> TimetableEntry? {
    let entry = TimetableEntry(
      weekVariant: model.weekVariantCount == 2 ? variant : nil, weekday: weekday, period: period,
      schoolClass: SchoolClass(className), subject: Subject(subjectName))
    do throws(TimetableEditError) {
      try model.save(entry, replacing: editing)
      error = nil
      return entry
    } catch {
      self.error = error
      return nil
    }
  }
}

/// Waagerechte Zeile antippbarer Vorschläge; leer ohne Vorschläge. Eigener Knopfstil, damit in einer
/// `Form`-Zeile jeder Knopf einzeln reagiert (mit dem Standardstil löst ein Tipp in die Zeile alle aus).
private struct SuggestionRow: View {
  let labels: [String]
  let pick: (String) -> Void

  var body: some View {
    if !labels.isEmpty {
      ScrollView(.horizontal, showsIndicators: false) {
        HStack(spacing: 8) {
          ForEach(labels, id: \.self) { label in
            Button { pick(label) } label: { Text(verbatim: label) }
              .buttonStyle(.bordered)
          }
        }
      }
      .accessibilityElement(children: .contain)
      .accessibilityLabel(Text("setup.timetable.entry.suggestions"))
    }
  }
}
