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
    .themedBackground()
    .navigationTitle("timetableSource.title")
    .toolbar { ToolbarItem { HelpButton(topic: .schulmanager) } }
    .task { reload() }
    .sheet(isPresented: $isShowingPreview) { previewSheet }
    // Fällt die Vorschau weg, während das Sheet offen ist (Abfrage ohne Unterschied, Datenort-Wechsel),
    // schließen; ein leeres Sheet hätte am Mac keinen Knopf zum Schließen.
    .onChange(of: coordinator.pendingPreview == nil) { _, isGone in
      if isGone { isShowingPreview = false }
    }
    // Der Koordinator löscht Zugangsdaten nach falschen Zugangsdaten oder mehreren Schulen auch bei einer
    // Abfrage im Hintergrund; dann den Schlüsselbund neu lesen.
    .onChange(of: coordinator.credentialsRevision) { reload() }
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
      } else if !hasCredentials, let error = coordinator.status.lastError, error.discardsCredentials {
        // Abmeldung durch den Koordinator (etwa mehrere Schulen bei der Abfrage am Morgen): Grund zeigen.
        errorLabel(key: error.settingsMessageKey, serverStatus: nil)
      }
    } header: {
      Text("timetableSource.account.title")
    } footer: {
      Text("timetableSource.credentialsNotice")
    }
  }

  @ViewBuilder private var importSection: some View {
    Section {
      // `revision` mitlesen: Kommt der Stand per Abgleich vom anderen Gerät, zeichnet SwiftUI neu.
      let _ = coordinator.repository.revision
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

  /// Vorschau als Sheet; fällt sie weg, schließt `onChange` oben das Sheet (bis dahin bleibt es leer).
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

  /// Speichern erst nach erfolgreichem Probe-Import: speichern → abfragen → bei falschen Zugangsdaten oder
  /// mehreren Schulen löscht der Koordinator sie wieder (Nachtrag 1); Netz- und Serverfehler behalten sie.
  private func signIn() async {
    errorMessageKey = nil
    // Läuft schon eine Abfrage (etwa beim Aktivieren), würde `refresh` sofort zurückkehren: nichts speichern.
    guard !coordinator.isFetching else { return setError("timetableSource.error.busy") }
    isWorking = true
    defer { isWorking = false }
    do {
      try credentials.save(SchulmanagerCredentials(username: username, password: password))
    } catch {
      return setError("timetableSource.error.keychain")
    }
    defer { coordinator.noteCredentialsChanged() }
    let attemptBefore = coordinator.status.lastAttemptAt
    let failuresBefore = coordinator.status.consecutiveFailures
    await coordinator.refresh(.userRequest)
    let attempted = coordinator.status.lastAttemptAt != attemptBefore

    if !attempted {
      // Abfrage wurde nicht gestartet: nichts ist geprüft. Entweder scheiterte schon das Lesen des
      // Datenspeichers (dann steht ein neuer Fehler im Status) oder der Abstand war zu kurz.
      try? credentials.delete()
      if coordinator.status.consecutiveFailures > failuresBefore,
        let error = coordinator.status.lastError
      {
        return setError(error.settingsMessageKey, serverStatus: serverStatus(of: error))
      }
      return setError("timetableSource.error.tooSoon")
    }
    if let error = coordinator.status.lastError, error.discardsCredentials {
      // Gelöscht hat der Koordinator schon; hier nur die Meldung.
      return setError(error.settingsMessageKey)
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
      coordinator.noteCredentialsChanged()
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
    credentials: KeychainCredentialStore(service: "preview.timetableSource"),
    statusStore: SourceStatusStore(defaults: UserDefaults(suiteName: "preview.timetableSource")!),
    pendingStore: PendingImportStore(
      directory: FileManager.default.temporaryDirectory.appendingPathComponent("preview-pending")))
  NavigationStack { TimetableSourceSettingsView() }
    .environment(coordinator)
}
