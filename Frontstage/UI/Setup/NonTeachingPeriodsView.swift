import FrontstageCore
import SwiftUI

/// Legt das View-Modell von „Unterrichtsfrei“ an; es entsteht je Datenort neu (`ScopedAppContent`).
struct NonTeachingPeriodsScreen: View {
  @Environment(AppEnvironment.self) private var environment

  var body: some View {
    NonTeachingPeriodsHost(environment: environment)
  }
}

private struct NonTeachingPeriodsHost: View {
  @State private var model: NonTeachingPeriodsViewModel

  init(environment: AppEnvironment) {
    _model = State(initialValue: NonTeachingPeriodsViewModel(environment: environment))
  }

  var body: some View { NonTeachingPeriodsView(model: model) }
}

/// „Einrichten › Unterrichtsfrei“ (FR-7): Zeiträume, je Zeitraum das Material ohne Stunde mit
/// „Zuordnen …“. Systemstandard (`List`, `DisclosureGroup`, `DatePicker`); Gestaltung ist offen.
struct NonTeachingPeriodsView: View {
  let model: NonTeachingPeriodsViewModel
  @Environment(AppEnvironment.self) private var environment

  @State private var isAdding = false
  @State private var assignTarget: AssignTarget?
  @State private var error: NonTeachingPeriodError?

  /// Material, das gerade einer Stunde zugeordnet wird, samt Zeitraum (für die Auswahl danach).
  private struct AssignTarget: Identifiable {
    let item: MaterialLinkItem
    let period: NonTeachingPeriod
    var id: UUID { item.id }
  }

  var body: some View {
    List {
      if model.periods.isEmpty {
        Text("setup.nonTeaching.empty").foregroundStyle(.secondary)
      }
      ForEach(model.periods, id: \.self) { period in
        periodRow(period)
      }
    }
    .themedBackground()
    .navigationTitle(Text("setup.nonTeaching.title"))
    .toolbar {
      ToolbarItem(placement: .primaryAction) {
        Button("setup.nonTeaching.add", systemImage: "plus") { isAdding = true }
      }
      ToolbarItem { HelpButton(topic: .nonTeachingDays) }
    }
    .sheet(isPresented: $isAdding) {
      AddPeriodSheet(model: model)
    }
    .sheet(item: $assignTarget) { target in
      AssignLessonSheet(
        item: target.item, lessons: model.assignableLessons(after: target.period)
      ) { lesson in
        model.actions.move(linkID: target.item.id, to: lesson.key)
        model.reload()
      }
    }
    .alert(
      Text("setup.nonTeaching.error.title"), isPresented: errorBinding, presenting: error ?? model.lastFailure
    ) { _ in
      Button("setup.nonTeaching.error.ok", role: .cancel) { model.lastFailure = nil }
    } message: { failure in
      switch failure {
      case .fromAfterTo: Text("setup.nonTeaching.error.fromAfterTo")
      case .saveFailed: Text("setup.nonTeaching.error.saveFailed")
      }
    }
    // Neuer Stand von diesem oder dem anderen Gerät → neu lesen.
    .onChange(of: environment.store.revision) { model.reload() }
  }

  private func periodRow(_ period: NonTeachingPeriod) -> some View {
    let orphans = model.cachedMaterialsWithoutLesson(in: period)
    return DisclosureGroup {
      ForEach(orphans) { item in
        HStack {
          Text(verbatim: item.reference.displayName)
          Spacer()
          Button("setup.nonTeaching.assign") {
            assignTarget = AssignTarget(item: item, period: period)
          }
          .frame(minHeight: 44)
        }
      }
      Button("setup.nonTeaching.remove", role: .destructive) { model.remove(period) }
        .frame(minHeight: 44)
      Text("setup.nonTeaching.removeNote").font(.footnote).foregroundStyle(.secondary)
    } label: {
      VStack(alignment: .leading) {
        Text(verbatim: period.title)
        Text(verbatim: Self.rangeText(period)).font(.footnote).foregroundStyle(.secondary)
        if !orphans.isEmpty {
          Text("setup.nonTeaching.materialCount \(orphans.count)").font(.footnote)
        }
      }
    }
  }

  private var errorBinding: Binding<Bool> {
    Binding(
      get: { error != nil || model.lastFailure != nil },
      set: { if !$0 { error = nil; model.lastFailure = nil } })
  }

  fileprivate static func date(_ day: CalendarDay) -> Date {
    Calendar.current.date(from: DateComponents(year: day.year, month: day.month, day: day.day)) ?? .now
  }

  private static func rangeText(_ period: NonTeachingPeriod) -> String {
    let style = Date.FormatStyle(date: .abbreviated, time: .omitted)
    let from = date(period.from).formatted(style)
    guard period.from != period.to else { return from }
    return "\(from) – \(date(period.to).formatted(style))"
  }
}

/// Eingabe eines neuen Zeitraums.
private struct AddPeriodSheet: View {
  let model: NonTeachingPeriodsViewModel
  @Environment(\.dismiss) private var dismiss

  @State private var from = Date.now
  @State private var to = Date.now
  @State private var title = ""
  @State private var error: NonTeachingPeriodError?

  var body: some View {
    NavigationStack {
      Form {
        DatePicker("setup.nonTeaching.from", selection: $from, displayedComponents: .date)
        DatePicker("setup.nonTeaching.to", selection: $to, displayedComponents: .date)
        TextField("setup.nonTeaching.name", text: $title)
        if let error {
          switch error {
          case .fromAfterTo:
            Text("setup.nonTeaching.error.fromAfterTo").foregroundStyle(.red)
          case .saveFailed:
            Text("setup.nonTeaching.error.saveFailed").foregroundStyle(.red)
          }
        }
      }
      .navigationTitle(Text("setup.nonTeaching.add"))
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("setup.nonTeaching.cancel") { dismiss() }
        }
        ToolbarItem(placement: .confirmationAction) {
          Button("setup.nonTeaching.save") { save() }
        }
      }
    }
  }

  private func save() {
    do throws(NonTeachingPeriodError) {
      try model.add(from: Self.day(from), to: Self.day(to), title: title)
      dismiss()
    } catch {
      self.error = error
    }
  }

  private static func day(_ date: Date) -> CalendarDay {
    let parts = Calendar.current.dateComponents([.year, .month, .day], from: date)
    return CalendarDay(year: parts.year ?? 1970, month: parts.month ?? 1, day: parts.day ?? 1)
  }
}
