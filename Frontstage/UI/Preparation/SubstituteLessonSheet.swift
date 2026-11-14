import FrontstageCore
import SwiftUI

/// Vertretungsstunde von Hand anlegen (FR-9): Datum, Stunde, Klasse, Fach; Herkunft `.manual`.
struct SubstituteLessonSheet: View {
  let model: PreparationViewModel

  @Environment(\.dismiss) private var dismiss
  @State private var date: Date
  @State private var period: Int
  @State private var className = ""
  @State private var subjectName = ""
  private let periods: [Int]

  init(model: PreparationViewModel) {
    self.model = model
    _date = State(initialValue: PreparationFormat.date(model.weekStart))
    // Stunden aus dem Zeitraster; ohne Zeitraster 1–10.
    let bell = (try? model.actions.store.timetable())?.bellSchedule.periods.keys.sorted() ?? []
    let list = bell.isEmpty ? Array(1...10) : bell
    self.periods = list
    _period = State(initialValue: list.first ?? 1)
  }

  private var isValid: Bool {
    !SchoolClass(className).normalized.isEmpty && !Subject(subjectName).normalized.isEmpty
  }

  var body: some View {
    NavigationStack {
      Form {
        DatePicker("preparation.substitute.date", selection: $date, displayedComponents: .date)
        Picker("preparation.substitute.period", selection: $period) {
          ForEach(periods, id: \.self) { Text(verbatim: String($0)).tag($0) }
        }
        TextField("preparation.substitute.class", text: $className)
        TextField("preparation.substitute.subject", text: $subjectName)
      }
      .navigationTitle(Text("preparation.substitute.title"))
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("preparation.substitute.cancel") { dismiss() }
        }
        ToolbarItem(placement: .confirmationAction) {
          Button("preparation.substitute.add") {
            model.actions.addSubstituteLesson(
              date: CalendarDay(date, calendar: .current), period: period,
              schoolClass: SchoolClass(className), subject: Subject(subjectName))
            model.reload()
            dismiss()
          }
          .disabled(!isValid)
        }
      }
    }
  }
}
