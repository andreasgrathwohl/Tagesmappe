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

  /// Derselbe Text als `String`, für die Ansage an VoiceOver.
  var localizedMessage: String {
    switch self {
    case .emptyClass: String(localized: "setup.timetable.error.emptyClass")
    case .emptySubject: String(localized: "setup.timetable.error.emptySubject")
    case .invalidPeriod: String(localized: "setup.timetable.error.invalidPeriod")
    case .duplicate: String(localized: "setup.timetable.error.duplicate")
    case .saveFailed: String(localized: "setup.timetable.error.saveFailed")
    }
  }
}

/// Sagt eine Rückmeldung für VoiceOver an; sie steht im Formular sonst weiter unten, außer Hörweite.
@MainActor private func announce(_ text: String) {
  AccessibilityNotification.Announcement(text).post()
}

/// Gewähltes Feld im Raster des Stundenplan-Editors: Wochentag, Stunde und – wenn dort schon eine Stunde
/// steht – deren Eintrag.
struct TimetableSelection: Hashable {
  var weekday: Weekday
  var period: Int
  /// `nil`: freies Feld, es wird eine neue Stunde angelegt.
  var entry: TimetableEntry?
}

/// Bearbeitungsbereich des Stundenplan-Editors (UI-16): steht als Spalte rechts neben dem Raster, bei schmaler
/// Breite als Blatt (System-Inspector). Eine feste Stunde anlegen oder ändern: Klasse, Fach, Wochentag, Stunde
/// und – bei zwei Wochenvarianten – „gilt für: beide / A / B“.
///
/// Schnelles Eintragen (FR-1.3): Unter Klasse und Fach stehen Vorschläge aus dem Stundenplan; ein Tipp setzt nur
/// das Feld. Beim Anlegen sichert „Sichern und nächste“ und wählt das nächste freie Feld; Klasse und Fach bleiben
/// stehen, damit eine Doppelstunde ein Tipp ist. Beim Ändern lässt sich die Stunde auf andere Tage übernehmen.
///
/// Der Eltern-Aufruf setzt `.id(selection.entry)`: Wählt man eine andere gesicherte Stunde, beginnt der Bereich
/// neu; zwischen freien Feldern bleiben Klasse und Fach stehen, nur Tag und Stunde folgen der Auswahl.
///
/// Swift-Hinweis: `@FocusState` hält, welches Textfeld die Tastatur hat; setzt man den Wert, springt der Fokus.
struct TimetableEntryEditor: View {
  let model: TimetableEditorViewModel
  @Binding var selection: TimetableSelection?
  /// Meldet dem Raster, ob ungesicherte Eingaben im Bereich stehen; dann fragt ein Wechsel der Auswahl nach.
  @Binding var hasUnsavedChanges: Bool
  /// Die Auswahl, mit der der Bereich angelegt wurde (bestimmt „neu“ oder „ändern“).
  private let editing: TimetableEntry?

  @State private var className: String
  @State private var subjectName: String
  @State private var weekday: Weekday
  @State private var period: Int
  @State private var variant: WeekVariant?
  @State private var error: TimetableEditError?
  /// Zuletzt mit „Sichern und nächste“ gesicherte Stunde, als Rückmeldung im Bereich.
  @State private var lastSaved: TimetableEntry?
  @FocusState private var focusedField: Field?
  /// Tage, auf die die gesicherte Stunde übernommen werden soll (nur beim Ändern).
  @State private var copyDays: Set<Weekday> = []
  @State private var copyResult: TimetableEntryCopy.Plan?
  @State private var isConfirmingDelete = false

  private enum Field { case schoolClass, subject }

  init(
    model: TimetableEditorViewModel, selection: Binding<TimetableSelection?>,
    hasUnsavedChanges: Binding<Bool>, start: TimetableSelection
  ) {
    self.model = model
    _selection = selection
    _hasUnsavedChanges = hasUnsavedChanges
    editing = start.entry
    _className = State(initialValue: start.entry?.schoolClass.normalized ?? "")
    _subjectName = State(initialValue: start.entry?.subject.display ?? "")
    _weekday = State(initialValue: start.entry?.weekday ?? start.weekday)
    _period = State(initialValue: start.entry?.period ?? start.period)
    _variant = State(initialValue: model.initialVariant(editing: start.entry))
  }

  var body: some View {
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
      } header: {
        header
      }
      Section {
        Picker("setup.timetable.entry.weekday", selection: weekdayBinding) {
          ForEach(Weekday.allCases, id: \.self) { Text(verbatim: $0.displayName).tag($0) }
        }
        Picker("setup.timetable.entry.period", selection: periodBinding) {
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
      Section {
        // Return bzw. Enter löst den Hauptknopf aus (Tastatur am Mac und am iPad).
        if editing == nil {
          Button("setup.timetable.entry.saveAndNext") { saveAndNext() }
            .buttonStyle(.borderedProminent)
            .keyboardShortcut(.defaultAction)
          Button("setup.timetable.entry.save") { save() }
        } else {
          Button("setup.timetable.entry.save") { save() }
            .buttonStyle(.borderedProminent)
            .keyboardShortcut(.defaultAction)
        }
      } footer: {
        if let lastSaved {
          Text(
            "setup.timetable.entry.saved \(lastSaved.weekday.displayName) \(lastSaved.period) \(lastSaved.schoolClass.normalized) \(lastSaved.subject.display)"
          )
        }
      }
      if let editing {
        copySection(editing)
        Section {
          Button("setup.timetable.entry.delete", role: .destructive) { isConfirmingDelete = true }
            .confirmationDialog(
              Text("setup.timetable.entry.delete.title"), isPresented: $isConfirmingDelete,
              titleVisibility: .visible
            ) {
              Button("setup.timetable.entry.delete.confirm", role: .destructive) {
                hasUnsavedChanges = false
                model.delete(editing)
                selection = nil
              }
              Button("setup.timetable.entry.cancel", role: .cancel) {}
            }
        }
      }
    }
    // Ungesichertes nicht still verlieren: Wechsel im Raster fragt nach, das Blatt (schmale Breite) lässt sich
    // dann nicht wegwischen.
    .onChange(of: isDirty, initial: true) { _, dirty in hasUnsavedChanges = dirty }
    .onDisappear { hasUnsavedChanges = false }
    .interactiveDismissDisabled(isDirty)
    .onChange(of: error) { _, new in
      if let new { announce(new.localizedMessage) }
    }
    // Ein anderes freies Feld gewählt (Tipp ins Raster): Tag und Stunde folgen, Klasse und Fach bleiben.
    .onChange(of: selection) { _, new in
      guard let new, new.entry == nil, editing == nil else { return }
      weekday = new.weekday
      period = new.period
    }
  }

  /// Ungesicherte Eingaben: beim Ändern jede Abweichung von der gesicherten Stunde; beim Anlegen Klasse oder Fach,
  /// die nicht schon so gesichert wurden (nach „Sichern und nächste“ stehen sie absichtlich noch da).
  private var isDirty: Bool {
    let schoolClass = SchoolClass(className)
    let subject = Subject(subjectName)
    if let editing {
      return schoolClass != editing.schoolClass || subject.normalized != editing.subject.normalized
        || weekday != editing.weekday || period != editing.period
        || (model.weekVariantCount == 2 && variant != editing.weekVariant)
    }
    if let lastSaved {
      return schoolClass != lastSaved.schoolClass || subject.normalized != lastSaved.subject.normalized
    }
    return !schoolClass.normalized.isEmpty || !subject.normalized.isEmpty
  }

  /// „Montag, 4. Stunde“ und die Uhrzeit aus dem Zeitraster.
  private var header: some View {
    VStack(alignment: .leading, spacing: 2) {
      Text("setup.timetable.entry.heading \(weekday.displayName) \(period)")
        .font(.headline)
        .foregroundStyle(.primary)
      if let time = model.timeText(period: period) {
        Text(verbatim: time)
      }
    }
    .textCase(nil)
  }

  /// Auswahl der Stunden; eine vorhandene Stunde außerhalb des Zeitrasters bleibt wählbar.
  private var periods: [Int] {
    Set(model.periodChoices).union([period]).sorted()
  }

  /// Tag und Stunde im Bereich ändern: Bei einer neuen Stunde wandert die Auswahl im Raster mit.
  private var weekdayBinding: Binding<Weekday> {
    Binding(
      get: { weekday },
      set: {
        weekday = $0
        followInGrid()
      })
  }

  private var periodBinding: Binding<Int> {
    Binding(
      get: { period },
      set: {
        period = $0
        followInGrid()
      })
  }

  private func followInGrid() {
    guard editing == nil else { return }
    selection = TimetableSelection(weekday: weekday, period: period, entry: nil)
  }

  // MARK: - Übernehmen auf andere Tage

  /// „Auf andere Tage übernehmen“: Tage als Knöpfe zum An- und Abwählen, dann ein Knopf zum Übernehmen. Übernommen
  /// wird die gesicherte Stunde (`editing`), nicht ungesicherte Änderungen im Bereich.
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
      let result = try model.copy(editing, to: copyDays)
      copyResult = result
      copyDays = []
      error = nil
      announce(String(localized: "setup.timetable.entry.copy.result \(result.additions.count)"))
    } catch {
      self.error = error
    }
  }

  // MARK: - Sichern

  /// Sichern; danach ist die gesicherte Stunde im Raster gewählt (der Bereich beginnt mit ihr neu).
  private func save() {
    guard let saved = store() else { return }
    hasUnsavedChanges = false
    announce(savedText(saved))
    selection = TimetableSelection(weekday: saved.weekday, period: saved.period, entry: saved)
  }

  /// Sichern, dann das nächste freie Feld wählen; Klasse und Fach bleiben stehen. Ist keins mehr frei, wird die
  /// gesicherte Stunde gewählt.
  private func saveAndNext() {
    guard let saved = store() else { return }
    guard let next = model.nextFreeSlot(after: saved.weekday, period: saved.period) else {
      hasUnsavedChanges = false
      announce(savedText(saved))
      selection = TimetableSelection(weekday: saved.weekday, period: saved.period, entry: saved)
      return
    }
    lastSaved = saved
    announce(savedText(saved))
    weekday = next.weekday
    period = next.period
    selection = TimetableSelection(weekday: next.weekday, period: next.period, entry: nil)
    focusedField = .schoolClass
  }

  private func savedText(_ entry: TimetableEntry) -> String {
    String(
      localized:
        "setup.timetable.entry.saved \(entry.weekday.displayName) \(entry.period) \(entry.schoolClass.normalized) \(entry.subject.display)"
    )
  }

  /// Sichert die Eingabe; `nil` bei Fehler (dann steht er im Bereich).
  private func store() -> TimetableEntry? {
    let entry = TimetableEntry(
      weekVariant: model.weekVariantCount == 2 ? variant : nil, weekday: weekday, period: period,
      schoolClass: SchoolClass(className), subject: Subject(subjectName))
    do throws(TimetableEditError) {
      try model.save(entry, replacing: editing)
      error = nil
      // Bei einer Variante speichert das Modell ohne A/B; so gespeichert wird die Stunde auch gewählt.
      return model.weekVariantCount == 2 ? entry : TimetableEntry(
        weekday: entry.weekday, period: entry.period, schoolClass: entry.schoolClass, subject: entry.subject)
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
