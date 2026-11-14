import Foundation
import FrontstageCore
import SwiftData
import Testing

@testable import Frontstage

#if os(iOS)
  import UIKit
#else
  import AppKit
#endif

/// Attrappe der Anmeldung: Zustimmung und Ablehnung lassen sich nachstellen, ohne MSAL.
@MainActor private final class FakeDataLocationAccount: DataLocationAccount {
  var signedInUsername: String? = "max@example.com"
  var isSignedIn: Bool { signedInUsername != nil }
  /// Gesetzt: `requestScopes` wirft diesen Fehler (Zustimmung abgelehnt).
  var consentError: (any Error)?
  private(set) var requestedScopes: [[String]] = []

  func signIn(anchor: AuthPresentationAnchor) async throws {
    signedInUsername = "max@example.com"
  }

  func requestScopes(_ scopes: [String], anchor: AuthPresentationAnchor) async throws {
    requestedScopes.append(scopes)
    if let consentError { throw consentError }
  }
}

@MainActor private func makeAnchor() -> AuthPresentationAnchor {
  #if os(iOS)
    UIViewController()
  #else
    NSViewController()
  #endif
}

/// Ein Testgerät: In-Memory-Container je Datenort, eigene Einstellungen, eigenes Buch.
@MainActor private struct Device {
  let controller: DataLocationController
  let settings: DataLocationSettings
  let ledger: LedgerStore
  let account: FakeDataLocationAccount
}

@MainActor private func makeDevice(
  _ name: String, remote: InMemoryRemoteDataFolder, account: FakeDataLocationAccount = .init()
) -> Device {
  let defaults = UserDefaults(suiteName: "test-\(UUID().uuidString)")!
  let settings = DataLocationSettings(defaults: defaults)
  let ledger = LedgerStore(
    fileURL: FileManager.default.temporaryDirectory.appending(path: "ledger-\(UUID().uuidString).json"))
  let controller = DataLocationController(
    settings: settings, account: account,
    makeContainer: { _ in try ModelContainerFactory.makeInMemoryContainer() },
    makeRemote: { remote }, ledgerStore: ledger, deviceID: name,
    removeOneDriveStore: {})
  return Device(controller: controller, settings: settings, ledger: ledger, account: account)
}

@MainActor @Suite struct DataLocationControllerTests {
  let remote = InMemoryRemoteDataFolder()
  let di8b = LessonKey(date: tue17, schoolClass: SchoolClass("8b"), subject: Subject("Englisch"), ordinal: 1)

  /// Stundenplan der Fixture B (Klasse 8b) und eine Zuordnung am Di 17.11.
  private func seed(_ device: Device, material: String = "Vokabeln.pdf") throws {
    for entry in fixtureB.entries { try device.controller.store.addEntry(entry) }
    try device.controller.store.assign(reference(material), to: di8b)
  }

  @Test("FR-14: Wechsel auf OneDrive nimmt alle Daten mit und schreibt sie in den Datenordner")
  func switchToOneDriveMovesAllData() async throws {
    let device = makeDevice("mac", remote: remote)
    try seed(device)
    let linkID = try #require(try device.controller.store.links(for: di8b).first).id

    let verdict = try await device.controller.switchToOneDrive(anchor: makeAnchor())

    #expect(verdict == .ok)
    #expect(device.controller.location == .oneDrive)
    #expect(device.controller.folderSync != nil)
    #expect(device.controller.generation == 1)
    #expect(!device.controller.isMoving)
    #expect(try device.controller.store.links(for: di8b).count == 1)
    #expect(device.settings.location == .oneDrive)
    #expect(device.settings.dataFolder?.folderItemID == InMemoryRemoteDataFolder.appFolderID)
    #expect(device.account.requestedScopes == [MicrosoftAccount.dataLocationScopes])
    let paths = await remote.paths
    #expect(paths.contains("MaterialLink/\(linkID.uuidString).json"))
    #expect(paths.contains(RemoteLayout.libraryPath))
  }

  @Test("Review Focus 5: Beitreten – Stand im Datenordner gewinnt, nur lokal Vorhandenes kommt dazu")
  func joiningFilledFolderKeepsFolderState() async throws {
    let mac = makeDevice("mac", remote: remote)
    try seed(mac)
    // Das iPad hat denselben Bestand (gleiche Kennungen), ändert aber einen Namen und legt eine Zuordnung an.
    let ipad = makeDevice("ipad", remote: remote)
    let copy = try RecordCodec.exportAll(from: mac.controller.store.modelContext)
    try ipad.controller.store.applyExternalChanges { context in
      for record in copy {
        try RecordCodec.upsert(
          record.payload, id: record.id, attachmentData: record.attachmentData, into: context)
      }
    }
    let localLink = try #require(try ipad.controller.store.links(for: di8b).first)
    localLink.displayName = "Lokal.pdf"
    try ipad.controller.store.saveAndBump()
    try ipad.controller.store.assign(reference("NurLokal.pdf"), to: di8b)

    _ = try await mac.controller.switchToOneDrive(anchor: makeAnchor())
    _ = try await ipad.controller.switchToOneDrive(anchor: makeAnchor())

    let names = try ipad.controller.store.links(for: di8b).map(\.displayName)
    #expect(Set(names) == ["Vokabeln.pdf", "NurLokal.pdf"])
    #expect(names.count == 2)
  }

  @Test("Wechsel zurück auf iCloud übernimmt die Daten, der Datenordner bleibt unberührt")
  func switchToICloudKeepsFolderFiles() async throws {
    let device = makeDevice("mac", remote: remote)
    try seed(device)
    _ = try await device.controller.switchToOneDrive(anchor: makeAnchor())
    let pathsBefore = await remote.paths

    try await device.controller.switchToICloud()

    #expect(device.controller.location == .iCloud)
    #expect(device.controller.folderSync == nil)
    #expect(device.controller.generation == 2)
    #expect(try device.controller.store.links(for: di8b).map(\.displayName) == ["Vokabeln.pdf"])
    #expect(device.settings.location == .iCloud)
    #expect(device.settings.dataFolder == nil)
    #expect(device.ledger.ledger == nil)
    #expect(await remote.paths == pathsBefore)
  }

  @Test("Zustimmung abgelehnt → Datenort bleibt iCloud, nichts geändert")
  func consentDeniedKeepsLocation() async throws {
    let account = FakeDataLocationAccount()
    account.consentError = MicrosoftAccountError.cancelled
    let device = makeDevice("mac", remote: remote, account: account)
    try seed(device)

    do {
      _ = try await device.controller.switchToOneDrive(anchor: makeAnchor())
      Issue.record("Der Wechsel hätte scheitern müssen")
    } catch {
      #expect(error as? DataLocationError == .consentMissing)
    }

    #expect(device.controller.location == .iCloud)
    #expect(device.controller.generation == 0)
    #expect(!device.controller.isMoving)
    #expect(device.settings.location == .iCloud)
    #expect(device.settings.dataFolder == nil)
    #expect(try device.controller.store.links(for: di8b).count == 1)
    #expect(await remote.paths.isEmpty)
  }

  @Test("Kennung und Anlagezeit bleiben beim Umzug erhalten")
  func moveKeepsIDsAndCreatedAt() async throws {
    let device = makeDevice("mac", remote: remote)
    try seed(device)
    let link = try #require(try device.controller.store.links(for: di8b).first)
    let id = link.id
    let created = Date(timeIntervalSince1970: 1_700_000_000)
    link.createdAt = created
    try device.controller.store.saveAndBump()

    _ = try await device.controller.switchToOneDrive(anchor: makeAnchor())

    let moved = try #require(try device.controller.store.links(for: di8b).first)
    #expect(moved.id == id)
    #expect(moved.createdAt == created)
  }
}
