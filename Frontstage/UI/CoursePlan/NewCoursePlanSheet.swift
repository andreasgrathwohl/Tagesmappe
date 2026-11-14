import FrontstageCore
import SwiftUI

/// „Neuer Jahresplan“ (FR-15.2): Fach, Jahrgang und Schuljahr wählen. Die Auswahl stammt aus dem
/// Stundenplan und aus „Einrichten › Schuljahre“; freie Eingabe gibt es nicht.
struct NewCoursePlanSheet: View {
  let options: (subjects: [Subject], grades: [GradeLevel], startYears: [Int])
  let onCreate: (Subject, GradeLevel, Int) -> Void

  @Environment(\.dismiss) private var dismiss
  @State private var subject: Subject?
  @State private var grade: GradeLevel?
  @State private var startYear: Int?

  init(
    options: (subjects: [Subject], grades: [GradeLevel], startYears: [Int]),
    onCreate: @escaping (Subject, GradeLevel, Int) -> Void
  ) {
    self.options = options
    self.onCreate = onCreate
    _subject = State(initialValue: options.subjects.first)
    _grade = State(initialValue: options.grades.first)
    // Vorgabe: das jüngste Schuljahr der Liste (die Liste ist aufsteigend sortiert).
    _startYear = State(initialValue: options.startYears.last)
  }

  var body: some View {
    NavigationStack {
      Form {
        Picker("coursePlan.subject", selection: $subject) {
          ForEach(options.subjects, id: \.normalized) { item in
            Text(verbatim: item.display).tag(Optional(item))
          }
        }
        Picker("coursePlan.grade", selection: $grade) {
          ForEach(options.grades, id: \.value) { item in
            Text(verbatim: String(item.value)).tag(Optional(item))
          }
        }
        Picker("coursePlan.schoolYear", selection: $startYear) {
          ForEach(options.startYears, id: \.self) { year in
            Text(verbatim: CoursePlanFormat.yearTitle(year)).tag(Optional(year))
          }
        }
      }
      .navigationTitle(Text("coursePlan.new"))
      #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
      #endif
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("coursePlan.cancel") { dismiss() }
        }
        ToolbarItem(placement: .confirmationAction) {
          Button("coursePlan.create") {
            if let subject, let grade, let startYear {
              onCreate(subject, grade, startYear)
              dismiss()
            }
          }
          .disabled(subject == nil || grade == nil || startYear == nil)
        }
      }
    }
    #if os(macOS)
      .frame(minWidth: 360, minHeight: 240)
    #endif
  }
}
