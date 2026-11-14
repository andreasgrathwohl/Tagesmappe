import FrontstageCore
import Foundation
import Testing

@testable import Frontstage

/// „Einrichten › Ablage“: Freigaben dieses Geräts und Abmelden von Microsoft (ADR-0012).
@MainActor @Suite struct StorageSettingsViewModelTests {
  private let store: DataStore
  private let storage = FakeStorage()

  init() throws {
    store = try makeStore()
    try Fixtures.seed(store, [Fixtures.entry(.tuesday, 2, "8b", "Englisch")])
  }

  private func makeModel(
    dataLocation: DataLocation = .iCloud, username: String? = "lehrkraft@example.com"
  ) -> StorageSettingsViewModel {
    StorageSettingsViewModel(
      environment: Fixtures.environment(store: store, storage: storage, dataLocation: dataLocation),
      account: MicrosoftAccount(signedInUsernameForTesting: username))
  }

  private func assign(grant: String, file: String, to key: LessonKey) throws {
    let reference = MaterialReference(
      folderGrantName: grant, relativePath: file, displayName: file, fileKind: .pdf)
    _ = try store.assignItem(reference, to: key, at: nil)
  }

  @Test("Fehlende Freigabe auf diesem Gerät wird gemeldet")
  func missingGrantListed() async throws {
    _ = try await storage.addGrant(folderURL: URL(filePath: "/tmp/Unterricht"), name: "Unterricht")
    try assign(grant: "Unterricht", file: "a.pdf", to: Fixtures.key(.tue17, "8b", "Englisch"))
    try assign(grant: "Klausuren", file: "b.pdf", to: Fixtures.key(.tue17, "8b", "Englisch"))
    let vm = makeModel()
    #expect(vm.grants.map(\.name) == ["Unterricht"])
    #expect(vm.missingOnThisDevice == ["Klausuren"])
  }

  @Test("Freigabe entfernen löscht keine Zuordnung")
  func removeGrantKeepsLinks() async throws {
    let key = Fixtures.key(.tue17, "8b", "Englisch")
    let grant = try await storage.addGrant(folderURL: URL(filePath: "/tmp/Unterricht"), name: "Unterricht")
    try assign(grant: "Unterricht", file: "a.pdf", to: key)
    let vm = makeModel()
    vm.remove(id: grant.id)
    #expect(vm.grants.isEmpty)
    #expect(try store.materialLinkItems(for: key).count == 1)
    #expect(vm.missingOnThisDevice == ["Unterricht"])
  }

  @Test("Gespiegelter Name wird vorgeschlagen (zweites Gerät)")
  func suggestsMirroredName() {
    storage.mirroredNames = ["Unterricht"]
    let suggestion = makeModel().suggestion(for: URL(filePath: "/tmp/Unterricht"))
    #expect(suggestion.name == "Unterricht")
    #expect(suggestion.matchesMirroredName)
  }

  @Test("Freigabe anlegen übernimmt sie in die Liste, ein belegter Name wird abgelehnt")
  func addGrantUpdatesListAndRejectsDuplicates() async throws {
    let vm = makeModel()
    try await vm.add(folderURL: URL(filePath: "/tmp/Unterricht"), name: " Unterricht ")
    #expect(vm.grants.map(\.name) == ["Unterricht"])
    await #expect(throws: FolderGrantError.nameInUse) {
      try await vm.add(folderURL: URL(filePath: "/tmp/Anderes"), name: "unterricht")
    }
  }

  @Test("ADR-0012: Abmelden bei Datenort OneDrive verlangt Bestätigung")
  func signOutWithOneDriveDataLocationRequiresConfirmation() async {
    let vm = makeModel(dataLocation: .oneDrive)
    #expect(vm.signOutImpact() == .stopsDataFolderSync)
    #expect(await vm.signOut(confirmed: false) == false)
    #expect(vm.isSignedIn)
    #expect(await vm.signOut(confirmed: true))
    #expect(!vm.isSignedIn)
  }

  @Test("Abmelden bei Datenort iCloud ohne Rückfrage")
  func signOutWithICloudNeedsNoConfirmation() async {
    let vm = makeModel(dataLocation: .iCloud)
    #expect(vm.signOutImpact() == .none)
    #expect(await vm.signOut(confirmed: false))
    #expect(!vm.isSignedIn)
  }
}
