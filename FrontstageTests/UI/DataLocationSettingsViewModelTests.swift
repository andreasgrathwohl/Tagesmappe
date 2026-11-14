import Foundation
import FrontstageCore
import Testing

@testable import Frontstage

#if os(iOS)
  import UIKit
#else
  import AppKit
#endif

/// Attrappe des Controllers: wechselt nur, wenn nichts schiefgehen soll.
@MainActor private final class FakeDataLocationController: DataLocationControlling {
  var location: DataLocation = .iCloud
  var dataFolder: DataFolder?
  var isMoving = false
  var syncStatus: DataFolderSyncStatus?
  var verdict: PairingVerdict = .ok
  var error: (any Error)?
  private(set) var oneDriveCalls = 0
  private(set) var iCloudCalls = 0
  private(set) var syncNowCalls = 0

  func switchToOneDrive(anchor: AuthPresentationAnchor, expected: PairingPayload?) async throws
    -> PairingVerdict
  {
    oneDriveCalls += 1
    if let error { throw error }
    if verdict == .ok {
      location = .oneDrive
      syncStatus = DataFolderSyncStatus()
    }
    return verdict
  }

  func switchToICloud() async throws {
    iCloudCalls += 1
    if let error { throw error }
    location = .iCloud
    syncStatus = nil
  }

  func runSyncNow() async { syncNowCalls += 1 }
}

@MainActor private func makeAnchor() -> AuthPresentationAnchor {
  #if os(iOS)
    UIViewController()
  #else
    NSViewController()
  #endif
}

@MainActor @Suite struct DataLocationSettingsViewModelTests {
  @Test("FR-14: OneDrive wählen → Bestätigung → Wechsel")
  func choosingOneDriveConfirmsThenSwitches() async {
    let controller = FakeDataLocationController()
    let model = DataLocationSettingsViewModel(controller: controller, isOneDriveAvailable: true)

    model.choose(.oneDrive)
    #expect(model.pendingSwitch == .oneDrive)
    #expect(controller.oneDriveCalls == 0)

    await model.confirmSwitch(anchor: makeAnchor())
    #expect(controller.oneDriveCalls == 1)
    #expect(model.location == .oneDrive)
    #expect(model.pendingSwitch == nil)
    #expect(model.errorKey == nil)
  }

  @Test("Den aktuellen Datenort zu wählen fragt nicht nach")
  func choosingCurrentLocationDoesNothing() {
    let controller = FakeDataLocationController()
    let model = DataLocationSettingsViewModel(controller: controller, isOneDriveAvailable: true)
    model.choose(.iCloud)
    #expect(model.pendingSwitch == nil)
  }

  @Test("Abbrechen ändert nichts")
  func cancelKeepsLocation() {
    let controller = FakeDataLocationController()
    let model = DataLocationSettingsViewModel(controller: controller, isOneDriveAvailable: true)
    model.choose(.oneDrive)
    model.cancelSwitch()
    #expect(model.pendingSwitch == nil)
    #expect(model.location == .iCloud)
    #expect(controller.oneDriveCalls == 0)
  }

  @Test("Der Dialog leert pendingSwitch vor der Bestätigung – der Wechsel gilt trotzdem")
  func acceptedSwitchSurvivesDialogDismissal() async {
    let controller = FakeDataLocationController()
    let model = DataLocationSettingsViewModel(controller: controller, isOneDriveAvailable: true)
    model.choose(.oneDrive)
    model.acceptSwitch()
    model.dialogDismissed()
    await model.confirmSwitch(anchor: makeAnchor())
    #expect(controller.oneDriveCalls == 1)
  }

  @Test("Zurück auf iCloud wechselt über den Controller")
  func switchingBackToICloud() async {
    let controller = FakeDataLocationController()
    controller.location = .oneDrive
    controller.syncStatus = DataFolderSyncStatus()
    let model = DataLocationSettingsViewModel(controller: controller, isOneDriveAvailable: true)
    model.choose(.iCloud)
    await model.confirmSwitch(anchor: makeAnchor())
    #expect(controller.iCloudCalls == 1)
    #expect(model.location == .iCloud)
  }

  @Test("Zustimmung verweigert → Meldung, Datenort bleibt")
  func consentErrorSetsErrorKey() async {
    let controller = FakeDataLocationController()
    controller.error = DataLocationError.consentMissing
    let model = DataLocationSettingsViewModel(controller: controller, isOneDriveAvailable: true)
    model.choose(.oneDrive)
    await model.confirmSwitch(anchor: makeAnchor())
    #expect(model.errorKey == "setup.dataLocation.error.consent")
    #expect(model.location == .iCloud)
    #expect(model.pendingSwitch == nil)
  }

  @Test("Neuere App nötig → eigene Meldung, Datenort bleibt")
  func newerAppVerdictSetsErrorKey() async {
    let controller = FakeDataLocationController()
    controller.verdict = .needsNewerApp
    let model = DataLocationSettingsViewModel(controller: controller, isOneDriveAvailable: true)
    model.choose(.oneDrive)
    await model.confirmSwitch(anchor: makeAnchor())
    #expect(model.errorKey == "setup.dataLocation.error.newerApp")
    #expect(model.location == .iCloud)
  }

  @Test("Statuszeile je Zusammenfassung")
  func statusLineKeys() {
    let controller = FakeDataLocationController()
    let moment = Date(timeIntervalSince1970: 1_800_000_000)
    let model = DataLocationSettingsViewModel(
      controller: controller, isOneDriveAvailable: true, now: { moment })

    // iCloud: keine Zeile
    #expect(model.statusLine == nil)
    #expect(model.statusText == nil)

    controller.location = .oneDrive

    // Heute: nur die Uhrzeit, in der Formatierung des Geräts (kein festes „08:12“: CI läuft mit en_US)
    controller.syncStatus = DataFolderSyncStatus(phase: .idle, lastSuccess: moment)
    #expect(model.statusLine?.key == "sync.status.upToDate %@")
    #expect(model.statusLine?.argument == moment.formatted(date: .omitted, time: .shortened))

    // Anderer Tag: Datum und Uhrzeit
    let earlier = moment.addingTimeInterval(-3 * 86_400)
    controller.syncStatus = DataFolderSyncStatus(phase: .idle, lastSuccess: earlier)
    #expect(model.statusLine?.argument == earlier.formatted(date: .abbreviated, time: .shortened))

    controller.syncStatus = DataFolderSyncStatus(phase: .offline, pendingCount: 2)
    #expect(model.statusLine?.key == "sync.status.offline %lld")
    #expect(model.statusLine?.argument == "2")

    controller.syncStatus = DataFolderSyncStatus(phase: .idle, pendingCount: 4)
    #expect(model.statusLine?.key == "sync.status.pending %lld")
    #expect(model.statusLine?.argument == "4")

    controller.syncStatus = DataFolderSyncStatus(phase: .idle, waitingCount: 1)
    #expect(model.statusLine?.key == "sync.status.waiting %lld")

    controller.syncStatus = DataFolderSyncStatus(phase: .syncing)
    #expect(model.statusLine?.key == "sync.status.syncing")
    #expect(model.statusLine?.argument == nil)

    controller.syncStatus = DataFolderSyncStatus(phase: .signInRequired)
    #expect(model.statusLine?.key == "sync.status.signInRequired")
    #expect(model.needsSignIn)

    controller.syncStatus = DataFolderSyncStatus(phase: .failed)
    #expect(model.statusLine?.key == "sync.status.failed")
    #expect(!model.needsSignIn)

    controller.syncStatus = DataFolderSyncStatus(newerFormatCount: 1)
    #expect(model.statusLine?.key == "sync.status.needsNewerApp")

    controller.syncStatus = DataFolderSyncStatus()
    #expect(model.statusLine?.key == "sync.status.neverSynced")
  }

  @Test("Jetzt abgleichen stößt den Controller an")
  func syncNowCallsController() async {
    let controller = FakeDataLocationController()
    let model = DataLocationSettingsViewModel(controller: controller, isOneDriveAvailable: true)
    await model.syncNow()
    #expect(controller.syncNowCalls == 1)
  }
}
