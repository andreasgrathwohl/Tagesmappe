import FrontstageCore
import SwiftUI

/// Datumsdarstellung der Vorbereiten-Ansichten (Systemformat, deutsche Ausgabe über das Gebietsschema).
enum PreparationFormat {
  static func date(_ day: CalendarDay) -> Date {
    Calendar.current.date(from: DateComponents(year: day.year, month: day.month, day: day.day)) ?? .now
  }

  static func shortDate(_ day: CalendarDay) -> String {
    date(day).formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated))
  }

  static func longDate(_ day: CalendarDay) -> String {
    date(day).formatted(.dateTime.weekday(.wide).day().month(.wide))
  }

  static func weekRange(from start: CalendarDay) -> String {
    let format = Date.FormatStyle.dateTime.day().month(.abbreviated)
    return "\(date(start).formatted(format)) – \(date(start.adding(days: 6)).formatted(format))"
  }
}

/// Hinweis nach einer Aktion im Vorbereiten-Bereich.
enum PreparationNotice: Equatable {
  case outsideGrantedFolders
  case saveFailed
  case noNextLesson
  case blockedBySource
  case copied(Int)

  var message: Text {
    switch self {
    case .outsideGrantedFolders: Text("preparation.outsideGrants")
    case .saveFailed: Text("preparation.saveFailed")
    case .noNextLesson: Text("preparation.noNextLesson")
    case .blockedBySource: Text("preparation.blockedBySource")
    case .copied(let count): Text("preparation.copied \(count)")
    }
  }

  init(_ error: AssignError) {
    switch error {
    case .outsideGrantedFolders: self = .outsideGrantedFolders
    case .saveFailed: self = .saveFailed
    }
  }
}

/// Alert für `PreparationNotice`; bei „außerhalb freigegebener Ordner“ mit Knopf „Ordner freigeben“,
/// der nach Einrichten springt (`showSetup` setzt `RootView`).
private struct PreparationNoticeAlert: ViewModifier {
  @Binding var notice: PreparationNotice?
  @Environment(\.showSetup) private var showSetup

  func body(content: Content) -> some View {
    content.alert(
      notice?.message ?? Text(verbatim: ""),
      isPresented: Binding(
        get: { notice != nil },
        set: { if !$0 { notice = nil } }),
      presenting: notice
    ) { notice in
      if notice == .outsideGrantedFolders {
        Button("preparation.grantFolder") { showSetup() }
      }
      Button("preparation.ok", role: .cancel) {}
    }
  }
}

extension View {
  func preparationNotice(_ notice: Binding<PreparationNotice?>) -> some View {
    modifier(PreparationNoticeAlert(notice: notice))
  }
}

/// Legt das View-Modell des Vorbereitens an; es entsteht je Datenort neu (`DataScopedRoot`).
struct PreparationScreen: View {
  @Environment(AppEnvironment.self) private var environment

  var body: some View {
    PreparationHost(environment: environment)
  }
}

private struct PreparationHost: View {
  @State private var model: PreparationViewModel

  init(environment: AppEnvironment) {
    _model = State(initialValue: PreparationViewModel(environment: environment))
  }

  var body: some View { PreparationView(model: model) }
}

/// Vorbereiten (FR-3, FR-7): links die Woche, rechts die Einzelheiten der gewählten Stunde.
/// Systemstandard (`NavigationSplitView`, `List`); der Aufbau der Woche ist eine offene Gestaltungskategorie.
struct PreparationView: View {
  @Bindable var model: PreparationViewModel

  @State private var notice: PreparationNotice?
  @State private var assignTarget: MaterialLinkItem?
  @State private var showSubstitute = false

  init(model: PreparationViewModel) {
    self.model = model
  }

  var body: some View {
    NavigationSplitView {
      week
        .navigationTitle(Text(verbatim: PreparationFormat.weekRange(from: model.weekStart)))
        .toolbar { toolbar }
    } detail: {
      if let key = model.selection {
        // Neue Identität je Stunde: Felder und Dialoge des Details beginnen frisch (`onDisappear` speichert).
        LessonDetailView(key: key, model: model)
          .id(key.storageText)
      } else {
        ContentUnavailableView("preparation.selectLesson", systemImage: "tray.full")
      }
    }
    // Neuer Stand von diesem oder dem anderen Gerät → neu lesen.
    .onChange(of: model.actions.store.revision) { model.reload() }
    // Die Auswahl gehört zur angezeigten Woche.
    .onChange(of: model.weekStart) { model.selection = nil }
    .preparationNotice($notice)
    .sheet(isPresented: $showSubstitute) {
      SubstituteLessonSheet(model: model)
    }
    .sheet(item: $assignTarget) { item in
      AssignLessonSheet(item: item, lessons: model.upcomingLessons(days: 14)) { lesson in
        model.actions.move(linkID: item.id, to: lesson.key)
        model.reload()
      }
    }
  }

  // MARK: Woche

  @ToolbarContentBuilder private var toolbar: some ToolbarContent {
    ToolbarItemGroup(placement: .primaryAction) {
      Button("preparation.previousWeek", systemImage: "chevron.left") { model.showPreviousWeek() }
      Button("preparation.thisWeek") { model.showThisWeek() }
      Button("preparation.nextWeek", systemImage: "chevron.right") { model.showNextWeek() }
      Button("preparation.substitute", systemImage: "plus") { showSubstitute = true }
    }
    ToolbarItem { HelpButton(topic: .preparation) }
  }

  private var week: some View {
    List(selection: $model.selection) {
      if !model.weekAssessments.isEmpty {
        Section {
          ForEach(model.weekAssessments, id: \.assessment.id) { planned in
            weekAssessmentRow(planned)
          }
        } header: {
          Text("preparation.weekAssessments")
        }
      }
      ForEach(model.days) { day in
        Section {
          dayContent(day)
          ForEach(day.materialsWithoutLesson) { item in
            HStack {
              Text(verbatim: item.reference.displayName)
              Spacer()
              Button("dayView.assign") { assignTarget = item }
                .frame(minHeight: 44)
            }
          }
        } header: {
          Text(verbatim: PreparationFormat.longDate(day.date))
        }
      }
    }
    .themedBackground()
  }

  /// Ein Leistungsnachweis der Woche mit Klasse-unabhängiger Angabe: Art, Titel, Fach und Jahrgang, ggf. Tag.
  private func weekAssessmentRow(_ planned: PlannedAssessment) -> some View {
    VStack(alignment: .leading, spacing: 2) {
      Text(verbatim: "\(PlanHintLabel.kindName(planned.assessment.kind)): \(planned.assessment.title)")
      Text("preparation.weekAssessmentPlan \(planned.key.subject.display) \(planned.key.gradeLevel.value)")
        .font(.subheadline).foregroundStyle(.secondary)
      if let day = planned.assessment.day {
        Text(verbatim: PreparationFormat.shortDate(day))
          .font(.subheadline).foregroundStyle(.secondary)
      }
    }
    .frame(minHeight: 44, alignment: .leading)
    .accessibilityElement(children: .combine)
  }

  @ViewBuilder private func dayContent(_ day: PreparationDay) -> some View {
    switch day.content {
    case .nonTeachingDay(let title):
      Label(title, systemImage: "sun.max").foregroundStyle(.secondary)
    case .noLessons:
      Text("preparation.noLessons").foregroundStyle(.secondary)
    case .rows(let rows):
      ForEach(rows) { row in
        if case .lesson(let lesson) = row {
          LessonWeekRow(lesson: lesson)
            .tag(lesson.lesson.key)
            .modifier(
              MaterialDropTarget(
                key: lesson.lesson.key, actions: model.actions,
                onError: { notice = PreparationNotice($0) }))
        }
      }
    }
  }
}

/// Eine Unterrichtsstunde in der Woche: Stunde, Klasse, Fach, Zahl des Materials und Thema.
private struct LessonWeekRow: View {
  let lesson: LessonRow

  private var isCancelled: Bool {
    if case .cancelled = lesson.status { return true }
    return false
  }

  var body: some View {
    HStack(spacing: 12) {
      Text("dayView.period \(lesson.lesson.period)")
        .font(.headline)
        .frame(minWidth: 72, alignment: .leading)
      VStack(alignment: .leading, spacing: 2) {
        Text(verbatim: "\(lesson.lesson.key.schoolClass.normalized) · \(lesson.lesson.key.subject.display)")
          .strikethrough(isCancelled)
        if let topic = lesson.info.topic {
          Text(verbatim: topic).font(.subheadline).foregroundStyle(.secondary).lineLimit(1)
        }
        if let hint = lesson.planHint {
          PlanHintLabel(markers: hint.markers)
        }
        if isCancelled {
          // Symbol und Text, nie nur Farbe.
          Label(
            LocalizedStringKey(DayStatement.cancellation.labelKey),
            systemImage: DayStatement.cancellation.symbolName
          )
          .font(.subheadline)
        }
      }
      Spacer(minLength: 8)
      if !lesson.materials.isEmpty {
        Label {
          Text(verbatim: String(lesson.materials.count))
        } icon: {
          Image(systemName: "paperclip")
        }
        .foregroundStyle(.secondary)
        .accessibilityLabel(Text("preparation.materialCount \(lesson.materials.count)"))
      }
    }
    .frame(minHeight: 44)
  }
}
