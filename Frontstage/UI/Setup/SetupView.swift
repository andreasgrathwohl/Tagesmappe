import FrontstageCore
import SwiftUI

/// Bereich „Einrichten“. Systemstandard (`Form`); Gestaltung ist offen.
///
/// Der Rahmen steht **außerhalb** von `DataScopedRoot` (Entscheidung Bündel A/B): `DataLocationSettingsView`
/// mit dem Kopplungs-Sheet (QR) hält seinen Zustand in der Ansicht und im `DataLocationController`, so
/// dass ein Wechsel des Datenorts das Sheet mitten im Koppeln nicht abreißt. Alles, was an Daten hängt,
/// öffnet sich als Ziel mit eigenem `ScopedAppContent` und wird beim Wechsel neu aufgebaut.
///
/// Aufgaben 12–14 hängen hier Zeitraster, Unterrichtsfrei, Ablage und Stundenplan-Quelle ein; der
/// Datenort steht laut Plan vor „Ablage“.
struct SetupView: View {
  let dataLocation: DataLocationController
  let account: MicrosoftAccount
  let services: ScopedServicesHolder

  var body: some View {
    NavigationStack {
      Form {
        Section {
          NavigationLink("setup.timetable.title") {
            scoped { TimetableEditorScreen() }
          }
        }
        // Zeitraster und Unterrichtsfrei: Aufgabe 12.
        DataLocationSettingsView(
          controller: dataLocation, isOneDriveAvailable: account.isConfigured,
          accountUsername: { account.signedInUsername })
        // Ablage (Aufgabe 14) und Stundenplan-Quelle (Aufgabe 14): folgen hier, ebenfalls über `scoped`.
      }
      .navigationTitle(Text("app.section.setup"))
    }
  }

  private func scoped<Content: View>(@ViewBuilder _ content: @escaping () -> Content) -> some View {
    ScopedAppContent(controller: dataLocation, services: services, content: content)
  }
}
