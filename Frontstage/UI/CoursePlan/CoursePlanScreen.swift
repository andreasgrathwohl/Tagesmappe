import FrontstageCore
import SwiftUI

/// Wurzel des Bereichs „Jahresplan“ (FR-15): legt das Listenmodell an; es entsteht je Datenort neu
/// (`ScopedAppContent`). Muster wie `PreparationScreen`.
struct CoursePlanScreen: View {
  @Environment(DataStore.self) private var dataStore
  @Environment(AppEnvironment.self) private var environment

  var body: some View {
    CoursePlanHost(store: dataStore, today: environment.today())
  }
}

private struct CoursePlanHost: View {
  @State private var model: CoursePlanListModel
  private let store: DataStore

  init(store: DataStore, today: CalendarDay) {
    self.store = store
    _model = State(initialValue: CoursePlanListModel(store: store, today: today))
  }

  var body: some View {
    CoursePlanView(model: model, store: store)
      // Neuer Stand von diesem oder dem anderen Gerät → neu lesen.
      .onChange(of: store.revision) { model.reload() }
  }
}
