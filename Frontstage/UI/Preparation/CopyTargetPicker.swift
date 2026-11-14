import FrontstageCore
import SwiftUI

/// „Für andere Klasse übernehmen“ (FR-3.2): erst die Klasse, dann die Zielstunde wählen. Erst die Wahl
/// der Lehrkraft ruft `copyLinks(from:to:)`; ein automatisches Ziel gibt es nicht.
struct CopyTargetPicker: View {
  let source: LessonKey
  let actions: LessonActions
  /// Meldet die Zahl der neu angelegten Zuordnungen.
  let onDone: (Int) -> Void

  @Environment(\.dismiss) private var dismiss

  init(source: LessonKey, actions: LessonActions, onDone: @escaping (Int) -> Void) {
    self.source = source
    self.actions = actions
    self.onDone = onDone
  }

  var body: some View {
    NavigationStack {
      let classes = actions.copyTargetClasses(for: source)
      List {
        if classes.isEmpty {
          Text("lesson.copy.noClasses").foregroundStyle(.secondary)
        }
        ForEach(classes, id: \.self) { schoolClass in
          NavigationLink(value: schoolClass) {
            Text(verbatim: schoolClass.normalized).frame(minHeight: 44, alignment: .leading)
          }
        }
      }
      .navigationTitle(Text("lesson.copy.class"))
      // Swift-Hinweis: `navigationDestination(for:)` ordnet einem Wert (hier der Klasse) die Zielansicht zu.
      .navigationDestination(for: SchoolClass.self) { schoolClass in
        lessonList(for: schoolClass)
      }
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("lesson.copy.cancel") { dismiss() }
        }
      }
    }
  }

  private func lessonList(for schoolClass: SchoolClass) -> some View {
    let lessons = actions.copyTargetLessons(for: schoolClass, from: source)
    return List {
      if lessons.isEmpty {
        Text("lesson.copy.empty").foregroundStyle(.secondary)
      }
      ForEach(lessons, id: \.key) { lesson in
        Button {
          let count = actions.copyLinks(from: source, to: lesson.key)
          onDone(count)
          dismiss()
        } label: {
          Text(
            "dayView.assign.lesson \(PreparationFormat.shortDate(lesson.key.date)) \(lesson.period) \(lesson.key.schoolClass.normalized) \(lesson.key.subject.display)"
          )
          .frame(minHeight: 44, alignment: .leading)
        }
      }
    }
    .navigationTitle(Text("lesson.copy.lesson"))
  }
}
