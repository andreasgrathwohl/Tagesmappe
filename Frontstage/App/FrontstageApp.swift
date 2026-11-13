import SwiftData
import SwiftUI

// Platzhalter – Teilplan 04 ersetzt den Inhalt durch RootView und übernimmt die Verdrahtung in AppEnvironment.
@main
struct FrontstageApp: App {
  private let container: ModelContainer
  private let store: DataStore
  private let trigger: SyncMergeTrigger
  // Swift-Hinweis: `@Environment(\.scenePhase)` liefert den Lebenszyklus der Szene (aktiv, inaktiv, Hintergrund).
  @Environment(\.scenePhase) private var scenePhase

  /// `App.init` läuft auf dem Hauptakteur (`App` ist `@MainActor`), daher darf hier `mainContext` gelesen werden.
  init() {
    let container: ModelContainer
    do {
      container = try ModelContainerFactory.makeDefault()
    } catch {
      fatalError("Der Datenspeicher konnte nicht geöffnet werden: \(error)")
    }
    let store = DataStore(modelContext: container.mainContext)
    let trigger = SyncMergeTrigger(store: store)
    self.container = container
    self.store = store
    self.trigger = trigger
    trigger.start()
  }

  var body: some Scene {
    WindowGroup {
      // Ein Zeichenketten-Literal ist hier ein LocalizedStringKey und wird in Localizable.xcstrings nachgeschlagen.
      Text("app.placeholder.title")
        .environment(store)
    }
    .modelContainer(container)
    .onChange(of: scenePhase) { _, newPhase in
      if newPhase == .active { trigger.sceneDidBecomeActive() }
    }
  }
}
