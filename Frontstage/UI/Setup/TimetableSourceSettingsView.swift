import FrontstageCore
import SwiftData
import SwiftUI

extension TimetableSourceError {
  /// Schlüssel des Fehlertexts in `Localizable.xcstrings` (Wortlaut ist offen; Platzhalter, unpersönliche Anrede).
  var settingsMessageKey: String {
    switch self {
    case .notConfigured: "timetableSource.error.notConfigured"
    case .invalidCredentials: "timetableSource.error.invalidCredentials"
    case .multipleSchoolsUnsupported: "timetableSource.error.multipleSchools"
    case .offline: "timetableSource.error.offline"
    case .server: "timetableSource.error.server"
    case .unexpectedResponse: "timetableSource.error.unexpected"
    }
  }
}

/// „Einrichten › Stundenplan-Quelle“ (FR-2, FR-13.1): Quelle wählen, bei Schulmanager Online anmelden,
/// jetzt importieren, abmelden. Eigenständige Ansicht als `Form`-Inhalt; Teilplan 04 hängt sie in Einrichten ein.
/// Systemstandard; Gestaltung (Wortlaut, Anordnung) ist offen.
///
/// Swift-Hinweis: `@Environment(Type.self)` liest ein `@Observable`-Objekt, das ein Elternteil mit
/// `.environment(objekt)` bereitgestellt hat. Fehlt es, bricht SwiftUI ab – die Ansicht verlangt es also.
/// Das Passwort lebt nur in `@State` dieser Ansicht und wird nach dem Speichern geleert.
struct TimetableSourceSettingsView: View {
  @Environment(TimetableSourceCoordinator.self) private var coordinator

  /// Dieselben Zugangsdaten und derselbe Dienst wie in `SourceCoordinatorHolder.live`.
  private let credentials: any CredentialStore = KeychainCredentialStore()

  @State private var kind: TimetableSourceKind = .manual
  @State private var hasCredentials = false
  @State private var username = ""
  @State private var password = ""
  @State private var isWorking = false
  @State private var errorMessageKey: String?
  @State private var errorServerStatus: Int?
  @State private var isShowingPreview = false

  init() {}

  var body: some View {
    Form {
      sourceSection
      if kind == .schulmanager {
        accountSection
        if hasCredentials { importSection }
      }
      Section {
        Text("timetableSource.unofficialNotice")
      }
    }
    .navigationTitle("timetableSource.title")
    .task { reload() }
    .sheet(isPresented: $isShowingPreview) { previewSheet }
  }

  // MARK: - Abschnitte

  private var sourceSection: some View {
    Section("timetableSource.source") {
      Picker("timetableSource.source", selection: kindBinding) {
        Text("timetableSource.source.manual").tag(TimetableSourceKind.manual)
        Text("timetableSource.source.schulmanager").tag(TimetableSourceKind.schulmanager)
      }
      .pickerStyle(.inline)
      .labelsHidden()
      .disabled(isWorking)
    }
  }

  @ViewBuilder private var accountSection: some View {
    Section {
      if hasCredentials {
        Label("timetableSource.signedIn", systemImage: "checkmark.circle")
        Button("timetableSource.signOut", role: .destructive) { signOut() }
          .disabled(isWorking)
      } else {
        Label("timetableSource.signedOut", systemImage: "person.crop.circle.badge.xmark")
        TextField("timetableSource.username", text: $username)
          .textContentType(.username)
          .autocorrectionDisabled()
          #if os(iOS)
            .textInputAutocapitalization(.never)
            .keyboardType(.emailAddress)
          #endif
        SecureField("timetableSource.password", text: $password)
          .textContentType(.password)
        Button("timetableSource.signIn") { Task { await signIn() } }
          .disabled(isWorking || username.isEmpty || password.isEmpty)
      }
      if isWorking { ProgressView() }
      if let errorMessageKey {
        errorLabel(key: errorMessageKey, serverStatus: errorServerStatus)
      }
    } header: {
      Text("timetableSource.account.title")
    } footer: {
      Text("timetableSource.credentialsNotice")
    }
  }

  @ViewBuilder private var importSection: some View {
    Section {
      if let fetchedAt = try? coordinator.repository.sourceFetchedAt() {
        Text("timetableSource.fetchedAt \(fetchedAt.formatted(date: .abbreviated, time: .shortened))")
      } else {
        Text("timetableSource.neverImported").foregroundStyle(.secondary)
      }
      if let error = coordinator.status.lastError {
        errorLabel(
          key: error.settingsMessageKey, serverStatus: serverStatus(of: error))
      }
      Button("timetableSource.importNow") { Task { await importNow() } }
        .disabled(isWorking || coordinator.isFetching)
      if coordinator.pendingPreview != nil {
        Text("timetableSource.preview.available")
        Button("timetableSource.preview.show") { isShowingPreview = true }
      }
    }
  }

  /// Fehler mit Symbol und Text, nie nur über Farbe.
  @ViewBuilder private func errorLabel(key: String, serverStatus: Int?) -> some View {
    Label {
      if let serverStatus {
        Text("timetableSource.error.server \(serverStatus)")
      } else {
        Text(LocalizedStringKey(key))
      }
    } icon: {
      Image(systemName: "exclamationmark.triangle")
    }
    .foregroundStyle(.red)
  }

  /// Vorschau als Sheet; ist sie inzwischen weg (übernommen oder verworfen), bleibt das Sheet leer und schließt sich.
  @ViewBuilder private var previewSheet: some View {
    if let preview = coordinator.pendingPreview {
      ImportPreviewView(preview: preview)
    }
  }

  // MARK: - Aktionen

  private var kindBinding: Binding<TimetableSourceKind> {
    Binding(
      get: { kind },
      set: { new in
        do {
          try coordinator.switchSource(to: new)
          kind = new
          errorMessageKey = nil
        } catch {
          setError("timetableSource.error.storage")
        }
      })
  }

  private func reload() {
    kind = (try? coordinator.repository.timetableSourceKind()) ?? .manual
    hasCredentials = (try? credentials.load()) != nil
  }

  /// Speichern erst nach erfolgreichem Probe-Import: speichern → abfragen → bei falschen Zugangsdaten wieder löschen.
  private func signIn() async {
    isWorking = true
    defer { isWorking = false }
    errorMessageKey = nil
    do {
      try credentials.save(SchulmanagerCredentials(username: username, password: password))
    } catch {
      return setError("timetableSource.error.keychain")
    }
    let attemptBefore = coordinator.status.lastAttemptAt
    await coordinator.refresh(.userRequest)
    let attempted = coordinator.status.lastAttemptAt != attemptBefore

    if !attempted {
      // Abfrage wurde nicht gestartet (zu kurzer Abstand oder läuft schon): nichts ist geprüft.
      try? credentials.delete()
      return setError("timetableSource.error.tooSoon")
    }
    if coordinator.status.lastError == .invalidCredentials {
      try? credentials.delete()
      return setError(TimetableSourceError.invalidCredentials.settingsMessageKey)
    }
    password = ""
    username = ""
    hasCredentials = true
    if coordinator.pendingPreview != nil { isShowingPreview = true }
  }

  private func importNow() async {
    isWorking = true
    defer { isWorking = false }
    await coordinator.refresh(.userRequest)
    if coordinator.pendingPreview != nil { isShowingPreview = true }
  }

  private func signOut() {
    do {
      try credentials.delete()
      hasCredentials = false
      errorMessageKey = nil
    } catch {
      setError("timetableSource.error.keychain")
    }
  }

  private func setError(_ key: String, serverStatus: Int? = nil) {
    errorMessageKey = key
    errorServerStatus = serverStatus
  }

  private func serverStatus(of error: TimetableSourceError) -> Int? {
    if case .server(let status) = error { return status }
    return nil
  }
}

#Preview {
  // Vorschau mit leerem Speicher im Arbeitsspeicher und ohne echte Quelle.
  let container = try! ModelContainerFactory.makeInMemoryContainer()
  let store = DataStore(modelContext: container.mainContext)
  let coordinator = TimetableSourceCoordinator(
    repository: store, makeSource: { _ in ManualTimetableSource() },
    statusStore: SourceStatusStore(defaults: UserDefaults(suiteName: "preview.timetableSource")!),
    pendingStore: PendingImportStore(
      directory: FileManager.default.temporaryDirectory.appendingPathComponent("preview-pending")))
  NavigationStack { TimetableSourceSettingsView() }
    .environment(coordinator)
}
