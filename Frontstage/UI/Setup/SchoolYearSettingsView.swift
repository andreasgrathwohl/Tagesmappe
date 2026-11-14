import FrontstageCore
import SwiftUI

/// Legt das Modell von „Einrichten › Schuljahre“ an; es entsteht je Datenort neu (`ScopedAppContent`).
struct SchoolYearSettingsScreen: View {
  @Environment(DataStore.self) private var dataStore
  @Environment(AppEnvironment.self) private var environment

  var body: some View {
    SchoolYearSettingsHost(dataStore: dataStore, today: environment.today())
  }
}

private struct SchoolYearSettingsHost: View {
  @State private var model: SchoolYearSettingsModel
  private let dataStore: DataStore

  init(dataStore: DataStore, today: CalendarDay) {
    self.dataStore = dataStore
    _model = State(initialValue: SchoolYearSettingsModel(store: dataStore, today: today))
  }

  var body: some View {
    SchoolYearSettingsView(model: model)
      // Neuer Stand von diesem oder dem anderen Gerät → neu lesen.
      .onChange(of: dataStore.revision) { model.reload() }
  }
}

/// „Einrichten › Schuljahre“ (FR-15.1): Liste der Schuljahre, Bearbeiten im Sheet.
/// Systemstandard (`List`, `Form`, `DatePicker`, `Picker`); Gestaltung ist offen.
struct SchoolYearSettingsView: View {
  @Bindable var model: SchoolYearSettingsModel

  var body: some View {
    List {
      Section {
        ForEach(model.years, id: \.startYear) { year in
          Button {
            model.edit(startYear: year.startYear)
          } label: {
            VStack(alignment: .leading) {
              Text(verbatim: year.title)
              Text(verbatim: Self.rangeText(year)).font(.footnote).foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
          }
          .buttonStyle(.plain)
          .swipeActions {
            Button("setup.schoolYears.remove", role: .destructive) {
              model.remove(startYear: year.startYear)
            }
          }
        }
      } footer: {
        Text("setup.schoolYears.removeHint")
      }
    }
    .navigationTitle(Text("setup.schoolYears.title"))
    .toolbar {
      ToolbarItem(placement: .primaryAction) {
        Button("setup.schoolYears.add", systemImage: "plus") { model.newYear() }
      }
    }
    .sheet(isPresented: isEditing) {
      SchoolYearEditSheet(model: model)
    }
  }

  private var isEditing: Binding<Bool> {
    Binding(
      get: { model.draft != nil },
      set: { if !$0 { model.cancelDraft() } })
  }

  private static func rangeText(_ year: SchoolYear) -> String {
    let style = Date.FormatStyle(date: .abbreviated, time: .omitted)
    let from = SchoolYearDates.date(year.firstDay).formatted(style)
    let to = SchoolYearDates.date(year.lastDay).formatted(style)
    return "\(from) – \(to)"
  }
}

/// Umrechnung zwischen `CalendarDay` und dem `Date` der `DatePicker`.
private enum SchoolYearDates {
  static func date(_ day: CalendarDay) -> Date {
    Calendar.current.date(from: DateComponents(year: day.year, month: day.month, day: day.day)) ?? .now
  }

  static func day(_ date: Date) -> CalendarDay {
    CalendarDay(date, calendar: .current)
  }
}

/// Bearbeiten und Neuanlegen eines Schuljahrs.
private struct SchoolYearEditSheet: View {
  let model: SchoolYearSettingsModel

  var body: some View {
    NavigationStack {
      Form {
        Section {
          DatePicker(
            "setup.schoolYears.firstDay", selection: dayBinding(\.firstDay),
            displayedComponents: .date)
          DatePicker(
            "setup.schoolYears.secondTerm", selection: dayBinding(\.secondTermStart),
            displayedComponents: .date)
          DatePicker(
            "setup.schoolYears.lastDay", selection: dayBinding(\.lastDay),
            displayedComponents: .date)
        } footer: {
          Text("setup.schoolYears.holidaysHint")
        }
        if let key = model.issueKey {
          Section { issueText(key).foregroundStyle(.red) }
        }
        gradeSection
      }
      .navigationTitle(Text(verbatim: model.draft?.title ?? ""))
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("setup.schoolYears.cancel") { model.cancelDraft() }
        }
        ToolbarItem(placement: .confirmationAction) {
          Button("setup.schoolYears.save") { model.saveDraft() }
        }
      }
    }
  }

  @ViewBuilder private var gradeSection: some View {
    if let startYear = model.draft?.startYear {
      let classes = model.classesNeedingGrade(startYear: startYear)
      if !classes.isEmpty {
        Section {
          ForEach(classes, id: \.schoolClass) { entry in
            Picker(selection: gradeBinding(for: entry.schoolClass, startYear: startYear)) {
              Text("setup.schoolYears.grade.none").tag(GradeLevel?.none)
              ForEach(1...13, id: \.self) { value in
                Text(verbatim: String(value)).tag(GradeLevel(value))
              }
            } label: {
              Text(verbatim: entry.schoolClass.normalized.uppercased())
            }
          }
        } header: {
          Text("setup.schoolYears.grades")
        }
      }
    }
  }

  @ViewBuilder private func issueText(_ key: String) -> some View {
    switch key {
    case "setup.schoolYears.error.order":
      Text("setup.schoolYears.error.order")
    case "setup.schoolYears.error.secondTerm":
      Text("setup.schoolYears.error.secondTerm")
    case "setup.schoolYears.error.overlap %@":
      Text("setup.schoolYears.error.overlap \(model.issueOverlapTitle ?? "")")
    default:
      Text("setup.schoolYears.error.save")
    }
  }

  private func dayBinding(_ keyPath: WritableKeyPath<SchoolYear, CalendarDay>) -> Binding<Date> {
    Binding(
      get: {
        model.draft.map { SchoolYearDates.date($0[keyPath: keyPath]) } ?? .now
      },
      set: { newValue in
        model.draft?[keyPath: keyPath] = SchoolYearDates.day(newValue)
      })
  }

  private func gradeBinding(for schoolClass: SchoolClass, startYear: Int) -> Binding<GradeLevel?> {
    Binding(
      get: {
        model.classesNeedingGrade(startYear: startYear).first { $0.schoolClass == schoolClass }?.grade
      },
      set: { model.setGrade($0, for: schoolClass, startYear: startYear) })
  }
}
