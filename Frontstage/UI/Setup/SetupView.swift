import FrontstageCore
import SwiftUI

/// Bereich „Einrichten“. Systemstandard (`Form`); Gestaltung ist offen.
///
/// Der Rahmen steht **außerhalb** von `DataScopedRoot` (Entscheidung Bündel A/B): `DataLocationSettingsView`
/// mit dem Kopplungs-Sheet (QR) hält seinen Zustand in der Ansicht und im `DataLocationController`, so
/// dass ein Wechsel des Datenorts das Sheet mitten im Koppeln nicht abreißt. Alles, was an Daten hängt,
/// öffnet sich als Ziel mit eigenem `ScopedAppContent` und wird beim Wechsel neu aufgebaut.
///
/// Ablage und Stundenplan-Quelle folgen nach dem Datenort und öffnen sich als Ziel mit eigenem Datenbezug.
/// Die Ansicht der Stundenplan-Quelle ist selbst ein `Form` und deshalb ein `NavigationLink`-Ziel.
struct SetupView: View {
  let dataLocation: DataLocationController
  let account: MicrosoftAccount
  let services: ScopedServicesHolder
  @State private var restoreFailed = false

  var body: some View {
    NavigationStack {
      Form {
        Section {
          NavigationLink("setup.timetable.title") {
            scoped { TimetableEditorScreen() }
          }
          NavigationLink("setup.bellSchedule.title") {
            scoped { BellScheduleEditorScreen() }
          }
          NavigationLink("setup.nonTeaching.title") {
            scoped { NonTeachingPeriodsScreen() }
          }
        }
        DataLocationSettingsView(
          controller: dataLocation, isOneDriveAvailable: account.isConfigured,
          accountUsername: { account.signedInUsername })
        Section {
          NavigationLink("setup.storage.title") {
            scoped { StorageSettingsScreen(account: account) }
          }
          NavigationLink("timetableSource.title") {
            scoped { TimetableSourceSettingsView() }
          }
        }
        Section {
          Button("purchase.restore") {
            Task {
              do {
                try await ClassroomServices.shared.unlock.restore()
                restoreFailed = false
              } catch {
                restoreFailed = true
              }
            }
          }
          if restoreFailed {
            Text("purchase.restore.failed")
              .foregroundStyle(.red)
          }
        } header: {
          Text("setup.purchase.title")
        } footer: {
          Text("purchase.offer.note")
        }
      }
      .navigationTitle(Text("app.section.setup"))
    }
  }

  private func scoped<Content: View>(@ViewBuilder _ content: @escaping () -> Content) -> some View {
    ScopedAppContent(controller: dataLocation, services: services, content: content)
  }
}
