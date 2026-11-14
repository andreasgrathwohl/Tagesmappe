import FrontstageCore
import SwiftUI

/// „Einrichten › Datenort“ (FR-14): iCloud oder OneDrive, Stand des Abgleichs, Koppeln.
/// Systemstandard; Gestaltung (Wortlaut, Ort der Statuszeile, Wahl beim ersten Start) ist offen.
/// Zur Einbindung als Abschnitt in einem `Form`, vor „Ablage“.
struct DataLocationSettingsView: View {
  private let controller: DataLocationController
  private let accountUsername: () -> String?
  @State private var model: DataLocationSettingsViewModel
  @State private var holder = AnchorHolder()

  init(
    controller: DataLocationController, isOneDriveAvailable: Bool,
    accountUsername: @escaping () -> String?
  ) {
    self.controller = controller
    self.accountUsername = accountUsername
    _model = State(
      initialValue: DataLocationSettingsViewModel(
        controller: controller, isOneDriveAvailable: isOneDriveAvailable))
  }

  var body: some View {
    Section {
      Picker("setup.dataLocation.title", selection: locationBinding) {
        Text("setup.dataLocation.iCloud").tag(DataLocation.iCloud)
        if model.isOneDriveAvailable || model.location == .oneDrive {
          Text("setup.dataLocation.oneDrive").tag(DataLocation.oneDrive)
        }
      }
      .pickerStyle(.inline)
      .disabled(model.isMoving)

      if model.isMoving {
        ProgressView()
      }

      if model.location == .oneDrive {
        oneDriveDetails
      }

      if let errorKey = model.errorKey {
        Text(LocalizedStringKey(errorKey))
          .foregroundStyle(.red)
      }

      Button("setup.dataLocation.pair") { model.isShowingPairing = true }
        .disabled(model.isMoving)
      .background(AnchorReader(holder: holder).frame(width: 0, height: 0))
      .confirmationDialog(
        "setup.dataLocation.confirm.title", isPresented: confirmationBinding, titleVisibility: .visible
      ) {
        Button("setup.dataLocation.confirm.action") {
          model.acceptSwitch()
          guard let anchor = holder.anchor else { return }
          Task { await model.confirmSwitch(anchor: anchor) }
        }
        Button("setup.dataLocation.confirm.cancel", role: .cancel) { model.cancelSwitch() }
      } message: {
        Text("setup.dataLocation.confirm.message")
      }
      .sheet(isPresented: $model.isShowingPairing) {
        PairingSheet(controller: controller, accountUsername: accountUsername)
      }
    } header: {
      Text("setup.dataLocation.title")
    } footer: {
      VStack(alignment: .leading, spacing: 4) {
        Text("setup.dataLocation.footer")
        if !model.isOneDriveAvailable {
          Text("setup.dataLocation.oneDriveUnavailable")
        }
      }
    }
  }

  @ViewBuilder private var oneDriveDetails: some View {
    LabeledContent("setup.dataLocation.folder") {
      VStack(alignment: .trailing) {
        Text(maskedAccount)
        Text(verbatim: "Apps/Frontstage").foregroundStyle(.secondary)
      }
    }
    if let text = model.statusText {
      Text(text).foregroundStyle(.secondary)
    }
    if model.needsSignIn {
      Button("setup.dataLocation.signIn") {
        guard let anchor = holder.anchor else { return }
        Task { await model.signIn(anchor: anchor) }
      }
    }
    Button("setup.dataLocation.syncNow") { Task { await model.syncNow() } }
      .disabled(model.isMoving)
  }

  /// Gekürztes Konto (`m…@example.com`), damit die Zeile keinen vollständigen Namen zeigt.
  private var maskedAccount: String {
    let name = controller.dataFolder?.accountUsername ?? accountUsername() ?? ""
    return PairingPayload.maskedAccount(name)
  }

  private var locationBinding: Binding<DataLocation> {
    Binding(get: { model.location }, set: { model.choose($0) })
  }

  private var confirmationBinding: Binding<Bool> {
    Binding(
      get: { model.pendingSwitch != nil },
      set: { if !$0 { model.dialogDismissed() } })
  }
}
