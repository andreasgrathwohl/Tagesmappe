import FrontstageCore
import SwiftUI

/// Legt das View-Modell von „Ablage“ an; es entsteht je Datenort neu (`ScopedAppContent`), weil die
/// Freigaben zum `StorageService` dieses Datenorts gehören.
struct StorageSettingsScreen: View {
  @Environment(AppEnvironment.self) private var environment
  let account: MicrosoftAccount

  var body: some View {
    StorageSettingsHost(environment: environment, account: account)
  }
}

private struct StorageSettingsHost: View {
  @State private var model: StorageSettingsViewModel

  init(environment: AppEnvironment, account: MicrosoftAccount) {
    _model = State(initialValue: StorageSettingsViewModel(environment: environment, account: account))
  }

  var body: some View { StorageSettingsView(model: model) }
}

/// „Einrichten › Ablage“ (FR-3): Ordner freigeben, fehlende Freigaben dieses Geräts nachholen,
/// Microsoft an- und abmelden. Systemstandard (`Form`, `fileImporter`, `confirmationDialog`);
/// Wortlaut und Anordnung sind offen.
///
/// Swift-Hinweis: `fileImporter` liefert URLs mit Zugriffsrecht außerhalb der Sandbox
/// (security-scoped). Das Bookmark entsteht in `FolderGrantStore.add` innerhalb des Zugriffsfensters.
struct StorageSettingsView: View {
  let model: StorageSettingsViewModel

  /// Vorbelegter Name der nächsten Freigabe: bei „Hier freigeben“ der fehlende gespiegelte Name.
  @State private var requestedName: String?
  @State private var isPickingFolder = false
  @State private var pending: PendingGrant?
  @State private var errorKey: String?
  @State private var isConfirmingSignOut = false
  @State private var isWorking = false
  @State private var holder = AnchorHolder()

  var body: some View {
    Form {
      grantsSection
      if !model.missingOnThisDevice.isEmpty { missingSection }
      if model.isConfigured { microsoftSection }
      if let errorKey {
        Section { Text(LocalizedStringKey(errorKey)).foregroundStyle(.red) }
      }
    }
    .themedBackground()
    .navigationTitle("setup.storage.title")
    .toolbar { ToolbarItem { HelpButton(topic: .storage) } }
    .background(AnchorReader(holder: holder).frame(width: 0, height: 0))
    .task { model.reload() }
    .fileImporter(
      isPresented: $isPickingFolder, allowedContentTypes: [.folder], allowsMultipleSelection: false
    ) { result in
      handlePicked(result)
    }
    .sheet(item: $pending) { grant in
      NameSheet(grant: grant) { name in
        Task { await add(folderURL: grant.folderURL, name: name) }
      }
    }
    .confirmationDialog(
      "setup.microsoft.signOut.title", isPresented: $isConfirmingSignOut, titleVisibility: .visible
    ) {
      Button("setup.microsoft.signOut.confirm", role: .destructive) {
        Task { _ = await model.signOut(confirmed: true) }
      }
      Button("setup.microsoft.signOut.cancel", role: .cancel) {}
    } message: {
      Text("setup.microsoft.signOut.warning")
    }
  }

  // MARK: Abschnitte

  private var grantsSection: some View {
    Section {
      ForEach(model.grants) { grant in
        VStack(alignment: .leading, spacing: 2) {
          Text(grant.name)
          Text(grant.displayPath).font(.caption).foregroundStyle(.secondary)
          if let path = grant.oneDrivePath {
            Text(verbatim: "OneDrive: \(path)").font(.caption).foregroundStyle(.secondary)
          }
        }
        .swipeActions {
          Button("setup.storage.remove", role: .destructive) { model.remove(id: grant.id) }
        }
        // Am Mac ist Wischen kaum zu finden: dieselbe Aktion im Kontextmenü (Rechtsklick bzw. langes Drücken).
        .contextMenu {
          Button("setup.storage.remove", systemImage: "trash", role: .destructive) {
            model.remove(id: grant.id)
          }
        }
      }
      Button("setup.storage.addFolder") {
        requestedName = nil
        isPickingFolder = true
      }
    } header: {
      Text("setup.storage.title")
    } footer: {
      Text("setup.storage.footer")
    }
  }

  private var missingSection: some View {
    Section {
      ForEach(model.missingOnThisDevice, id: \.self) { name in
        LabeledContent(name) {
          Button("setup.storage.shareHere") {
            requestedName = name
            isPickingFolder = true
          }
        }
      }
    } header: {
      Text("setup.storage.missing.title")
    } footer: {
      Text("setup.storage.missing.footer")
    }
  }

  private var microsoftSection: some View {
    Section {
      if let username = model.signedInUsername {
        LabeledContent("setup.microsoft.account") { Text(PairingPayload.maskedAccount(username)) }
        Button("setup.microsoft.signOut") {
          if model.signOutImpact() == .stopsDataFolderSync {
            isConfirmingSignOut = true
          } else {
            Task { _ = await model.signOut(confirmed: true) }
          }
        }
      } else {
        Button("setup.microsoft.signIn") { signIn() }
          .disabled(isWorking)
      }
    } header: {
      Text("setup.microsoft.title")
    }
  }

  // MARK: Aktionen

  private func handlePicked(_ result: Result<[URL], any Error>) {
    guard case .success(let urls) = result, let url = urls.first else { return }
    errorKey = nil
    let suggestion = model.suggestion(for: url)
    // Ein fehlender gespiegelter Name hat Vorrang vor dem Ordnernamen.
    if let requestedName {
      pending = PendingGrant(folderURL: url, name: requestedName, matchesMirroredName: true)
    } else {
      pending = PendingGrant(
        folderURL: url, name: suggestion.name, matchesMirroredName: suggestion.matchesMirroredName)
    }
  }

  private func add(folderURL: URL, name: String) async {
    do {
      try await model.add(folderURL: folderURL, name: name)
    } catch FolderGrantError.nameInUse {
      errorKey = "setup.storage.error.nameInUse"
    } catch FolderGrantError.accessDenied {
      errorKey = "setup.storage.error.accessDenied"
    } catch {
      errorKey = "setup.storage.error.failed"
    }
  }

  private func signIn() {
    guard let anchor = holder.anchor else { return }
    errorKey = nil
    isWorking = true
    Task {
      defer { isWorking = false }
      do {
        try await model.signIn(anchor: anchor)
      } catch MicrosoftAccountError.cancelled {
        // Abbruch durch die Lehrkraft ist kein Fehler.
      } catch MicrosoftAccountError.offline {
        errorKey = "setup.microsoft.error.offline"
      } catch {
        errorKey = "setup.microsoft.error.failed"
      }
    }
  }
}

/// Gewählter Ordner, dessen Name noch bestätigt wird.
private struct PendingGrant: Identifiable {
  let id = UUID()
  let folderURL: URL
  var name: String
  let matchesMirroredName: Bool
}

/// Fragt den Namen der Freigabe ab; vorbelegt mit dem Vorschlag.
private struct NameSheet: View {
  let grant: PendingGrant
  let onSave: (String) -> Void
  @State private var name: String
  @Environment(\.dismiss) private var dismiss

  init(grant: PendingGrant, onSave: @escaping (String) -> Void) {
    self.grant = grant
    self.onSave = onSave
    _name = State(initialValue: grant.name)
  }

  var body: some View {
    NavigationStack {
      Form {
        Section {
          TextField("setup.storage.name", text: $name)
        } footer: {
          if grant.matchesMirroredName { Text("setup.storage.name.mirrored") }
        }
      }
      .navigationTitle("setup.storage.addFolder")
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("setup.storage.cancel") { dismiss() }
        }
        ToolbarItem(placement: .confirmationAction) {
          Button("setup.storage.save") {
            onSave(name)
            dismiss()
          }
          .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
      }
    }
  }
}
