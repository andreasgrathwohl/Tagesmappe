import Foundation
import FrontstageCore
import Observation

/// Schmale Sicht auf den Controller für Tests.
@MainActor protocol DataLocationControlling: PairingControlling {
  var isMoving: Bool { get }
  /// Stand des Abgleichs; nil bei iCloud.
  var syncStatus: DataFolderSyncStatus? { get }
  func runSyncNow() async
}

extension DataLocationController: DataLocationControlling {
  var syncStatus: DataFolderSyncStatus? { folderSync?.status }

  func runSyncNow() async { await folderSync?.runCycle() }
}

/// Zustand und Logik von „Einrichten › Datenort“ (FR-14): Wahl, Bestätigung vor dem Umzug, Fehlermeldung,
/// Zeile „Stand des Abgleichs“. Die Ansicht enthält keine eigene Logik.
///
/// Swift-Hinweis: `@Observable` verfolgt gelesene Eigenschaften. `location` und `isMoving` sind berechnet und
/// lesen aus dem (selbst beobachtbaren) Controller; SwiftUI baut die Ansicht daher bei Änderungen dort neu auf.
@MainActor @Observable final class DataLocationSettingsViewModel {
  /// Vom Nutzer gewählt, aber noch nicht bestätigt; steuert den Bestätigungsdialog.
  var pendingSwitch: DataLocation?
  /// Schlüssel der Fehlermeldung in `Localizable.xcstrings`; nil = kein Fehler.
  var errorKey: String?
  var isShowingPairing = false

  let isOneDriveAvailable: Bool

  @ObservationIgnored private let controller: any DataLocationControlling
  @ObservationIgnored private let now: () -> Date
  /// Vom Dialog bestätigtes Ziel. Der Dialog schließt sich, sobald der Knopf gedrückt ist, und leert dabei
  /// `pendingSwitch`, noch bevor die asynchrone Bestätigung läuft; deshalb wird das Ziel hier gemerkt.
  @ObservationIgnored private var acceptedSwitch: DataLocation?

  init(
    controller: any DataLocationControlling, isOneDriveAvailable: Bool,
    now: @escaping () -> Date = { .now }
  ) {
    self.controller = controller
    self.isOneDriveAvailable = isOneDriveAvailable
    self.now = now
  }

  var location: DataLocation { controller.location }
  var isMoving: Bool { controller.isMoving }

  /// Ungleich dem aktuellen Datenort → Bestätigung anfordern.
  func choose(_ location: DataLocation) {
    errorKey = nil
    guard location != controller.location else {
      pendingSwitch = nil
      return
    }
    pendingSwitch = location
  }

  /// Synchron aus der Dialog-Aktion aufrufen, bevor die asynchrone Bestätigung startet.
  func acceptSwitch() {
    acceptedSwitch = pendingSwitch
  }

  /// Der Dialog wurde geschlossen (Abbrechen, Tippen daneben oder nach der Bestätigung).
  func dialogDismissed() {
    pendingSwitch = nil
  }

  func cancelSwitch() {
    pendingSwitch = nil
    acceptedSwitch = nil
  }

  func confirmSwitch(anchor: AuthPresentationAnchor) async {
    let target = acceptedSwitch ?? pendingSwitch
    acceptedSwitch = nil
    pendingSwitch = nil
    guard let target else { return }
    errorKey = nil
    do {
      switch target {
      case .oneDrive:
        let verdict = try await controller.switchToOneDrive(anchor: anchor, expected: nil)
        if verdict != .ok { errorKey = Self.errorKey(for: verdict) }
      case .iCloud:
        try await controller.switchToICloud()
      }
    } catch {
      errorKey = Self.errorKey(for: error)
    }
  }

  // MARK: - Abgleich

  /// Die Anmeldung bei Microsoft ist abgelaufen; der Datenort gilt trotzdem weiter.
  var needsSignIn: Bool { controller.syncStatus?.summary == .signInRequired }

  /// Holt Anmeldung und Zustimmung nach. Der Controller kehrt früh zurück, weil der Datenordner schon gilt.
  func signIn(anchor: AuthPresentationAnchor) async {
    errorKey = nil
    do {
      let verdict = try await controller.switchToOneDrive(anchor: anchor, expected: nil)
      if verdict != .ok { errorKey = Self.errorKey(for: verdict) }
    } catch {
      errorKey = Self.errorKey(for: error)
    }
  }

  func syncNow() async {
    await controller.runSyncNow()
  }

  /// Schlüssel + Argument für die Zeile „Stand des Abgleichs“; nil bei iCloud.
  var statusLine: (key: String, argument: String?)? {
    guard let status = controller.syncStatus else { return nil }
    switch status.summary {
    case .signInRequired: return ("sync.status.signInRequired", nil)
    case .needsNewerApp: return ("sync.status.needsNewerApp", nil)
    case .offline(let pending): return ("sync.status.offline %lld", String(pending))
    case .failed: return ("sync.status.failed", nil)
    case .syncing: return ("sync.status.syncing", nil)
    case .waiting(let count): return ("sync.status.waiting %lld", String(count))
    case .pending(let count): return ("sync.status.pending %lld", String(count))
    case .upToDate(let date): return ("sync.status.upToDate %@", formatted(date))
    case .neverSynced: return ("sync.status.neverSynced", nil)
    }
  }

  /// Fertiger Text der Statuszeile in der Sprache der App; nil bei iCloud.
  var statusText: String? {
    guard let line = statusLine else { return nil }
    // Der Schlüssel enthält den Platzhalter und ist zugleich der Eintrag in `Localizable.xcstrings`.
    let format = NSLocalizedString(line.key, comment: "Stand des Abgleichs")
    guard let argument = line.argument else { return format }
    if line.key.hasSuffix("%lld"), let number = Int(argument) {
      return String(format: format, number)
    }
    return String(format: format, argument)
  }

  /// Heute: nur die Uhrzeit, sonst Datum und Uhrzeit.
  private func formatted(_ date: Date) -> String {
    if Calendar.current.isDate(date, inSameDayAs: now()) {
      return date.formatted(date: .omitted, time: .shortened)
    }
    return date.formatted(date: .abbreviated, time: .shortened)
  }

  // MARK: - Fehler

  private static func errorKey(for error: any Error) -> String {
    switch error as? DataLocationError {
    case .consentMissing: return "setup.dataLocation.error.consent"
    case .notSignedIn: return "setup.dataLocation.error.notSignedIn"
    case .offline: return "setup.dataLocation.error.offline"
    case .moveFailed, .none: return "setup.dataLocation.error.failed"
    }
  }

  private static func errorKey(for verdict: PairingVerdict) -> String {
    verdict == .needsNewerApp ? "setup.dataLocation.error.newerApp" : "setup.dataLocation.error.failed"
  }
}
