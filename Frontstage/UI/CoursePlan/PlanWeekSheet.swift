import FrontstageCore
import SwiftUI

/// Träger für `.sheet(item:)`: jedes Sheet bekommt einen frischen Editor und eine eigene Kennung.
struct PlanWeekSheetItem: Identifiable {
  let id = UUID()
  let editor: PlanWeekEditor
}

/// Eine Planwoche bearbeiten: Thema, Notizen und Leistungsnachweise (FR-15.2).
/// Systemstandard (`Form`, `Picker`, `TextField`); Gestaltung ist offen.
struct PlanWeekSheet: View {
  @Bindable var editor: PlanWeekEditor
  @Environment(\.dismiss) private var dismiss

  init(editor: PlanWeekEditor) {
    self.editor = editor
  }

  var body: some View {
    NavigationStack {
      Form {
        Section {
          TextField("coursePlan.topic", text: $editor.topic, axis: .vertical)
          TextField("coursePlan.weekNotes", text: $editor.notes, axis: .vertical)
            .lineLimit(3...8)
        }
        Section {
          ForEach(editor.assessments, id: \.id) { assessment in
            AssessmentRow(
              assessment: assessment, days: editor.selectableDays,
              onCommit: { editor.updateAssessment($0) },
              onRemove: { editor.removeAssessment(id: assessment.id) })
            .swipeActions {
              Button("coursePlan.assessment.remove", role: .destructive) {
                editor.removeAssessment(id: assessment.id)
              }
            }
          }
          if editor.canAddAssessments {
            Button("coursePlan.assessment.add") {
              editor.addAssessment(kind: .test, title: "", day: nil)
            }
          } else {
            Text("coursePlan.assessment.needsWeek").foregroundStyle(.secondary)
          }
        } header: {
          Text("coursePlan.assessments")
        }
        if let key = editor.errorKey {
          Section { Text(LocalizedStringKey(key)).foregroundStyle(.red) }
        }
      }
      .navigationTitle(title)
      #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
      #endif
      .toolbar {
        ToolbarItem(placement: .confirmationAction) {
          Button("coursePlan.done") { dismiss() }
        }
      }
    }
    // Gespeichert wird beim Schließen – ob über „Fertig“ oder durch Wegwischen des Sheets.
    .onDisappear { editor.save() }
    #if os(macOS)
      .frame(minWidth: 420, minHeight: 360)
    #endif
  }

  private var title: Text {
    if let week = editor.week {
      Text(CoursePlanFormat.weekTitle(week))
    } else {
      Text("coursePlan.unassigned")
    }
  }
}

/// Zeile eines Leistungsnachweises. Der Entwurf liegt lokal und wird bei jeder Änderung (Art, Titel, Tag)
/// zurückgeschrieben – so geht ein getippter Titel auch beim Wegwischen des Sheets nicht verloren.
/// Löschen geht per Wischgeste (iOS) und über den Papierkorb-Knopf (auch Mac, wo `swipeActions` fehlt).
private struct AssessmentRow: View {
  let days: [CalendarDay]
  let onCommit: (Assessment) -> Void
  let onRemove: () -> Void
  @State private var draft: Assessment

  init(
    assessment: Assessment, days: [CalendarDay],
    onCommit: @escaping (Assessment) -> Void, onRemove: @escaping () -> Void
  ) {
    self.days = days
    self.onCommit = onCommit
    self.onRemove = onRemove
    _draft = State(initialValue: assessment)
  }

  var body: some View {
    VStack(alignment: .leading) {
      Picker("coursePlan.assessment.kind", selection: $draft.kind) {
        ForEach(AssessmentKind.allCases, id: \.self) { kind in
          Text(CoursePlanFormat.kindKey(kind)).tag(kind)
        }
      }
      TextField("coursePlan.assessment.title", text: $draft.title)
      if !days.isEmpty {
        Picker("coursePlan.assessment.day", selection: $draft.day) {
          Text("coursePlan.assessment.noDay").tag(CalendarDay?.none)
          ForEach(days, id: \.self) { day in
            Text(verbatim: PreparationFormat.shortDate(day)).tag(Optional(day))
          }
        }
      }
      Button(role: .destructive, action: onRemove) {
        Label("coursePlan.assessment.remove", systemImage: "trash")
      }
      .buttonStyle(.borderless)
    }
    .onChange(of: draft.kind) { onCommit(draft) }
    .onChange(of: draft.title) { onCommit(draft) }
    .onChange(of: draft.day) { onCommit(draft) }
  }
}
