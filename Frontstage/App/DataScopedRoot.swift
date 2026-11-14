import SwiftData
import SwiftUI

/// Alles, was einen `DataStore` hält, entsteht hier – mit `.id(generation)` beim Wechsel des Datenorts neu.
///
/// Swift-Hinweis: `@State` einer Ansicht unter `.id(x)` wird neu angelegt, sobald sich `x` ändert. So
/// entstehen nach einem Wechsel alle Dienste in der Closure auf dem neuen `DataStore`. Der Aufruf von
/// `controller.store` im `body` meldet die Ansicht außerdem für Änderungen des beobachtbaren Controllers an.
struct DataScopedRoot<Content: View>: View {
  let controller: DataLocationController
  private let content: (DataStore, ModelContainer) -> Content

  init(
    controller: DataLocationController,
    @ViewBuilder content: @escaping (DataStore, ModelContainer) -> Content
  ) {
    self.controller = controller
    self.content = content
  }

  var body: some View {
    content(controller.store, controller.container)
      .id(controller.generation)
  }
}
