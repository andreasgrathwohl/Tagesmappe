import FrontstageCore
import SwiftUI

/// Darstellung der Jahresplanung; reine Formatierung, keine Logik.
enum CoursePlanFormat {
  /// „2026/27“.
  static func yearTitle(_ startYear: Int) -> String {
    String(format: "%d/%02d", startYear, (startYear + 1) % 100)
  }

  /// „9.–13.11.“ bzw. „30.9.–4.10.“ (Montag bis Freitag der Woche).
  static func dateRange(_ week: TeachingWeek) -> String {
    let start = week.monday
    let end = week.monday.adding(days: 4)
    if start.month == end.month {
      return "\(start.day).–\(end.day).\(end.month)."
    }
    return "\(start.day).\(start.month).–\(end.day).\(end.month)."
  }

  /// Zeilentext „Woche 8 · KW 46 · 9.–13.11.“ für Überschriften und Menüeinträge.
  static func weekTitle(_ week: TeachingWeek) -> LocalizedStringKey {
    "coursePlan.week \(week.number) \(week.isoWeek.week) \(dateRange(week))"
  }

  static func kindKey(_ kind: AssessmentKind) -> LocalizedStringKey {
    switch kind {
    case .test: "assessment.kind.test"
    case .classTest: "assessment.kind.classTest"
    }
  }

  /// „Klassenarbeit: KA 1 (Di)“.
  static func assessmentLine(_ assessment: Assessment) -> String {
    let kind =
      switch assessment.kind {
      case .test: String(localized: "assessment.kind.test")
      case .classTest: String(localized: "assessment.kind.classTest")
      }
    var line = assessment.title.isEmpty ? kind : "\(kind): \(assessment.title)"
    if let day = assessment.day {
      let weekday = PreparationFormat.date(day).formatted(.dateTime.weekday(.abbreviated))
      line += " (\(weekday))"
    }
    return line
  }
}

/// Jahresplan (FR-15): links die Pläne je Schuljahr, rechts der gewählte Plan mit seinen Wochen.
/// Systemstandard (`NavigationSplitView`, `List`); der Aufbau der Wochenzeile ist eine offene
/// Gestaltungskategorie.
struct CoursePlanView: View {
  @Bindable var model: CoursePlanListModel
  let store: any CoursePlanStore
  /// Öffnet die Ansicht „Frühere Jahre“ (Aufgabe 14); ohne Ziel ist der Knopf inaktiv.
  var onShowEarlierYears: ((UUID) -> Void)?

  @Environment(\.showSetup) private var showSetup
  @State private var showNewPlan = false
  @State private var comparison: ComparisonRequest?

  /// Auslöser für das Sheet „Frühere Jahre“ (`UUID` ist nicht `Identifiable`).
  private struct ComparisonRequest: Identifiable {
    let id: UUID
  }

  init(
    model: CoursePlanListModel, store: any CoursePlanStore,
    onShowEarlierYears: ((UUID) -> Void)? = nil
  ) {
    self.model = model
    self.store = store
    self.onShowEarlierYears = onShowEarlierYears
  }

  var body: some View {
    if model.hasSchoolYear {
      split
    } else {
      ContentUnavailableView {
        Label("coursePlan.noSchoolYear", systemImage: "calendar.badge.exclamationmark")
      } actions: {
        Button("coursePlan.setupSchoolYear") { showSetup() }
      }
    }
  }

  private var split: some View {
    NavigationSplitView {
      sidebar
        .navigationTitle(Text("app.section.coursePlan"))
        .toolbar {
          ToolbarItem {
            Button("coursePlan.new", systemImage: "plus") { showNewPlan = true }
          }
        }
    } detail: {
      if let planID = model.selection {
        // Neue Identität je Plan: Notiz- und Sheet-Zustand beginnen frisch.
        CoursePlanDetailHost(
          planID: planID, store: store,
          onShowEarlierYears: { id in
            comparison = ComparisonRequest(id: id)
            onShowEarlierYears?(id)
          }
        )
        .id(planID)
      } else {
        ContentUnavailableView("coursePlan.select", systemImage: "calendar")
      }
    }
    .sheet(item: $comparison) { request in
      CoursePlanComparisonView(planID: request.id, store: store)
    }
    .sheet(isPresented: $showNewPlan) {
      NewCoursePlanSheet(options: model.newPlanOptions()) { subject, grade, startYear in
        model.create(subject: subject, grade: grade, startYear: startYear)
      }
    }
  }

  private var sidebar: some View {
    List(selection: $model.selection) {
      ForEach(model.groups, id: \.title) { group in
        Section {
          ForEach(group.plans) { plan in
            Text("coursePlan.row \(plan.key.subject.display) \(plan.key.gradeLevel.value)")
              .tag(plan.id)
          }
        } header: {
          Text(verbatim: group.title)
        }
      }
    }
    .overlay {
      if model.groups.isEmpty {
        ContentUnavailableView {
          Label("coursePlan.empty", systemImage: "calendar")
        } actions: {
          Button("coursePlan.new") { showNewPlan = true }
        }
      }
    }
  }
}

/// Legt das Modell des gewählten Plans an; es entsteht je Plan neu (`.id(planID)` am Aufrufer).
private struct CoursePlanDetailHost: View {
  @State private var model: CoursePlanEditorModel
  private let store: any CoursePlanStore
  private let onShowEarlierYears: ((UUID) -> Void)?
  private let planID: UUID

  init(planID: UUID, store: any CoursePlanStore, onShowEarlierYears: ((UUID) -> Void)?) {
    self.planID = planID
    self.store = store
    self.onShowEarlierYears = onShowEarlierYears
    _model = State(initialValue: CoursePlanEditorModel(planID: planID, store: store))
  }

  var body: some View {
    CoursePlanDetailView(model: model, planID: planID, onShowEarlierYears: onShowEarlierYears)
      // Neuer Stand von diesem oder dem anderen Gerät → neu lesen.
      .onChange(of: store.revision) { model.reload() }
  }
}

/// Der geöffnete Plan: Kopf, Jahresnotiz, Wochen je Halbjahr, nicht Zugeordnetes.
private struct CoursePlanDetailView: View {
  @Bindable var model: CoursePlanEditorModel
  let planID: UUID
  let onShowEarlierYears: ((UUID) -> Void)?

  @State private var sheet: PlanWeekSheetItem?
  @State private var copySource: CoursePlanSummary?
  @FocusState private var notesFocused: Bool

  var body: some View {
    Group {
      if let layout = model.layout, let key = model.key {
        list(layout: layout, key: key)
      } else {
        ContentUnavailableView("coursePlan.missing", systemImage: "questionmark.folder")
      }
    }
    .toolbar { toolbar }
    #if os(iOS)
      .navigationBarTitleDisplayMode(.inline)
    #endif
    .sheet(item: $sheet) { item in
      PlanWeekSheet(editor: item.editor)
    }
    .confirmationDialog(
      Text("coursePlan.copy"), isPresented: copyDialogShown, titleVisibility: .visible,
      presenting: copySource
    ) { source in
      Button("coursePlan.copy.action") { model.copy(from: source.id) }
      Button("coursePlan.cancel", role: .cancel) {}
    } message: { source in
      Text("coursePlan.copy.confirm \(CoursePlanFormat.yearTitle(source.key.startYear))")
    }
    // Die Jahresnotiz wird beim Verlassen des Felds und des Plans gespeichert, nicht je Tastendruck.
    .onDisappear { model.saveNotes() }
  }

  private var copyDialogShown: Binding<Bool> {
    Binding(get: { copySource != nil }, set: { if !$0 { copySource = nil } })
  }

  private func list(layout: PlanLayout, key: CoursePlanKey) -> some View {
    List {
      Section {
        VStack(alignment: .leading, spacing: 4) {
          Text(
            "coursePlan.title \(key.subject.display) \(key.gradeLevel.value) \(CoursePlanFormat.yearTitle(key.startYear))"
          )
          .font(.title2.bold())
          if !model.followingClasses.isEmpty {
            Text(
              "coursePlan.followedBy \(model.followingClasses.map(\.normalized).joined(separator: ", "))"
            )
            .foregroundStyle(.secondary)
          }
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
      }
      if let noticeKey = model.noticeKey {
        Section { notice(noticeKey) }
      }
      Section {
        TextField("coursePlan.notes", text: $model.notes, axis: .vertical)
          .lineLimit(2...6)
          .focused($notesFocused)
          .onChange(of: notesFocused) { _, focused in
            if !focused { model.saveNotes() }
          }
      } header: {
        Text("coursePlan.notes")
      }
      weeks(layout.first, title: "coursePlan.term.first")
      weeks(layout.second, title: "coursePlan.term.second")
      if !layout.unassignedWeeks.isEmpty || !layout.unassignedAssessments.isEmpty {
        unassigned(layout)
      }
    }
  }

  @ViewBuilder
  private func notice(_ key: String) -> some View {
    if let argument = model.noticeArgument {
      Text("coursePlan.copy.done \(argument)")
    } else {
      Text(LocalizedStringKey(key))
    }
  }

  @ViewBuilder
  private func weeks(_ entries: [PlanLayoutWeek], title: LocalizedStringKey) -> some View {
    if !entries.isEmpty {
      Section {
        ForEach(entries, id: \.week.monday) { entry in
          Button {
            sheet = PlanWeekSheetItem(editor: model.editor(for: entry.week))
          } label: {
            weekRow(entry)
          }
          .buttonStyle(.plain)
        }
      } header: {
        Text(title)
      }
    }
  }

  private func weekRow(_ entry: PlanLayoutWeek) -> some View {
    VStack(alignment: .leading, spacing: 2) {
      Text(CoursePlanFormat.weekTitle(entry.week))
        .font(.subheadline)
        .foregroundStyle(.secondary)
      if let topic = entry.planWeek?.topic {
        Text(verbatim: topic)
      }
      ForEach(entry.assessments, id: \.id) { assessment in
        Text(verbatim: CoursePlanFormat.assessmentLine(assessment))
          .font(.footnote)
      }
    }
    .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
    .contentShape(Rectangle())
  }

  private func unassigned(_ layout: PlanLayout) -> some View {
    Section {
      ForEach(layout.unassignedWeeks, id: \.id) { planWeek in
        HStack {
          Button {
            sheet = PlanWeekSheetItem(editor: model.editor(forUnassigned: planWeek))
          } label: {
            Text(verbatim: planWeek.topic ?? planWeek.notes ?? "")
              .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
              .contentShape(Rectangle())
          }
          .buttonStyle(.plain)
          Menu("coursePlan.assign") {
            ForEach(model.emptyWeeks(), id: \.monday) { week in
              Button {
                model.assign(planWeekID: planWeek.id, to: week)
              } label: {
                Text(CoursePlanFormat.weekTitle(week))
              }
            }
          }
          .disabled(model.emptyWeeks().isEmpty)
        }
      }
      ForEach(layout.unassignedAssessments, id: \.id) { assessment in
        HStack {
          Text(verbatim: CoursePlanFormat.assessmentLine(assessment))
            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
          Menu("coursePlan.assign") {
            ForEach(layout.first + layout.second, id: \.week.monday) { entry in
              Button {
                model.assign(assessmentID: assessment.id, to: entry.week)
              } label: {
                Text(CoursePlanFormat.weekTitle(entry.week))
              }
            }
          }
        }
      }
    } header: {
      Text("coursePlan.unassigned")
    }
  }

  @ToolbarContentBuilder
  private var toolbar: some ToolbarContent {
    ToolbarItem {
      Button("coursePlan.earlierYears", systemImage: "clock.arrow.circlepath") {
        onShowEarlierYears?(planID)
      }
      .disabled(onShowEarlierYears == nil || model.earlierPlans.isEmpty)
    }
    ToolbarItem {
      Menu("coursePlan.copy", systemImage: "doc.on.doc") {
        ForEach(model.earlierPlans) { plan in
          Button(CoursePlanFormat.yearTitle(plan.key.startYear)) { copySource = plan }
        }
      }
      .disabled(model.earlierPlans.isEmpty)
    }
  }
}
