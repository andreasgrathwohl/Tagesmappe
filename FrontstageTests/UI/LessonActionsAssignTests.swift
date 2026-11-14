import Foundation
import FrontstageCore
import Testing

@testable import Frontstage

@MainActor @Suite struct LessonActionsAssignTests {
  private let data: DataStore
  private let storage = FakeStorage()
  private let penNotes = FakePenNoteRelocation()
  private let key: LessonKey
  private let actions: LessonActions

  init() throws {
    data = try makeStore()
    try Fixtures.seed(data, [Fixtures.entry(.tuesday, 5, "8b", "Englisch")])
    key = Fixtures.key(.tue17, "8b", "Englisch")
    actions = LessonActions(store: data, storage: storage, penNotes: penNotes)
  }

  private func names() throws -> [String] {
    try data.materialLinkItems(for: key).map(\.reference.displayName)
  }

  @Test("AK-4: zugeordnete Präsentation steht an der Unterrichtsstunde")
  func assignAddsLink() async throws {
    let items = try await actions.assign(
      fileURLs: [URL(filePath: "/Unterricht/Unit 4 – Präsentation.pptx")], to: key)
    #expect(try names() == ["Unit 4 – Präsentation.pptx"])
    #expect(items.count == 1)
    #expect(storage.assigned.count == 1)
  }

  @Test("AK-6: Lösung an Position 1")
  func reorderMovesSolutionFirst() async throws {
    let urls = ["Unit 4 – Präsentation", "Arbeitsblatt Vokabeln", "Lösung Vokabeln"].map {
      URL(filePath: "/Unterricht/\($0)")
    }
    try await actions.assign(fileURLs: urls, to: key)
    actions.reorder(key, fromOffsets: [2], toOffset: 0)
    #expect(try names() == ["Lösung Vokabeln", "Unit 4 – Präsentation", "Arbeitsblatt Vokabeln"])
  }

  @Test("Datei außerhalb der Freigaben legt nichts an")
  func assignOutsideGrantedFolderStoresNothing() async throws {
    let rejected = URL(filePath: "/Fremd/Datei.pdf")
    storage.rejectURLs = [rejected]
    await #expect(throws: AssignError.outsideGrantedFolders) {
      try await actions.assign(fileURLs: [rejected], to: key)
    }
    #expect(try names().isEmpty)
    #expect(storage.assigned.isEmpty)
  }

  @Test("Bricht bei der ersten ungültigen URL ab und behält Vorheriges")
  func assignStopsAtFirstInvalidURL() async throws {
    let rejected = URL(filePath: "/Fremd/Datei.pdf")
    storage.rejectURLs = [rejected]
    await #expect(throws: AssignError.outsideGrantedFolders) {
      try await actions.assign(
        fileURLs: [URL(filePath: "/Unterricht/A.pdf"), rejected, URL(filePath: "/Unterricht/B.pdf")],
        to: key)
    }
    #expect(try names() == ["A.pdf"])
  }

  private func linked() async throws -> MaterialLinkItem {
    try await actions.assign(fileURLs: [URL(filePath: "/Unterricht/Alt.pdf")], to: key)[0]
  }

  @Test("Neuverknüpfen außerhalb der Freigaben wird abgelehnt")
  func relinkOutsideGrantsThrows() async throws {
    let item = try await linked()
    let rejected = URL(filePath: "/Fremd/Neu.pdf")
    storage.rejectURLs = [rejected]
    #expect(throws: AssignError.outsideGrantedFolders) { try actions.relink(item, fileURL: rejected) }
  }

  @Test("Neuverknüpfen: Speichern gescheitert wird gemeldet, Verweis bleibt")
  func relinkSaveFailedIsReported() async throws {
    let item = try await linked()
    storage.relinkResultOverride = .saveFailed
    #expect(throws: AssignError.saveFailed) {
      try actions.relink(item, fileURL: URL(filePath: "/Unterricht/Neu.pdf"))
    }
    #expect(try data.materialLinkItems(for: key).map(\.reference) == [item.reference])
  }

  @Test("ADR-0011: nach Neuverknüpfen werden Notizen am alten Ort angeboten und mitgenommen")
  func relinkOffersToCarryNotes() async throws {
    let item = try await linked()
    penNotes.notesCountResult = 2
    let new = try actions.relink(item, fileURL: URL(filePath: "/Unterricht/Neu.pdf"))
    #expect(await actions.notesToCarry(from: item.reference) == 2)
    try await actions.carryNotes(from: item.reference, to: new)
    #expect(penNotes.movedNotes.map(\.1) == [new])
  }

  @Test("Entfernen löscht nur die Zuordnung")
  func removeDeletesLink() async throws {
    let item = try await linked()
    actions.remove(linkID: item.id)
    #expect(try names().isEmpty)
  }
}
