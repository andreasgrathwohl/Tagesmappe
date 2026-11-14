import Foundation
import FrontstageCore
import Testing

@testable import Frontstage

/// FR-3.2 (Übernehmen in eine gewählte Stunde), FR-3.3 (Schieben), FR-8 (Weiterreichen).
@MainActor @Suite struct LessonActionsMoveTests {
  private let data: DataStore
  private let storage = FakeStorage()
  private let penNotes = FakePenNoteRelocation()
  private let actions: LessonActions

  // 8a Englisch Di 2. Std; 8b Englisch Mi 3. Std und Di 5. Std; 8b Mathe Fr 4. Std
  private let tue8a = Fixtures.key(.tue17, "8a", "Englisch")
  private let tue8b = Fixtures.key(.tue17, "8b", "Englisch")
  private let wed8b = Fixtures.key(.wed18, "8b", "Englisch")
  private let thu8b = Fixtures.key(.thu19, "8b", "Englisch")
  private let fri8bMathe = Fixtures.key(CalendarDay(year: 2026, month: 11, day: 20), "8b", "Mathe")

  init() throws {
    data = try makeStore()
    try Fixtures.seed(
      data,
      [
        Fixtures.entry(.tuesday, 2, "8a", "Englisch"),
        Fixtures.entry(.tuesday, 5, "8b", "Englisch"),
        Fixtures.entry(.wednesday, 3, "8b", "Englisch"),
        Fixtures.entry(.thursday, 1, "8b", "Englisch"),
        Fixtures.entry(.friday, 4, "8b", "Mathe"),
      ])
    actions = LessonActions(store: data, storage: storage, penNotes: penNotes)
  }

  @discardableResult
  private func assign(_ names: [String], to key: LessonKey) throws -> [MaterialLinkItem] {
    try names.map {
      try data.assignItem(Fixtures.reference($0, .pdf), to: key, at: nil)
    }
  }

  @Test("AK-7: Für 8b übernehmen in die gewählte Mi 3. Stunde – zwei Zuordnungen, keine Dateien")
  func copyToChosenLesson() throws {
    try assign(["Arbeitsblatt.pdf", "Folien.pdf"], to: tue8a)
    #expect(actions.copyTargetClasses(for: tue8a) == [SchoolClass("8b")])
    let choices = actions.copyTargetLessons(for: SchoolClass("8b"), from: tue8a)
    #expect(Array(choices.map(\.key).prefix(2)) == [tue8b, wed8b])  // Liste zur Wahl, kein automatisches Ziel
    #expect(actions.copyLinks(from: tue8a, to: wed8b) == 2)
    #expect(
      try data.materialLinkItems(for: wed8b).map(\.reference)
        == data.materialLinkItems(for: tue8a).map(\.reference))
    #expect(try data.materialLinkItems(for: tue8a).count == 2)
    #expect(storage.pickedFileCalls == 0)
  }

  @Test("Ausgefallene Stunde ist nicht wählbar")
  func cancelledLessonIsNotACopyTarget() throws {
    try data.markCancelled(wed8b)
    let choices = actions.copyTargetLessons(for: SchoolClass("8b"), from: tue8a)
    #expect(!choices.map(\.key).contains(wed8b))
    #expect(choices.map(\.key).contains(thu8b))
  }

  @Test("AK-8: X steht am Donnerstag, nicht mehr am Dienstag")
  func moveToNextLesson() throws {
    let x = try assign(["X.pdf"], to: tue8b)[0]
    #expect(actions.moveToNextLesson(linkID: x.id) == wed8b)
    #expect(actions.moveToNextLesson(linkID: x.id) == thu8b)
    #expect(try data.materialLinkItems(for: thu8b).map(\.id) == [x.id])  // dieselbe Zuordnung
    #expect(try data.materialLinkItems(for: tue8b).isEmpty)
  }

  @Test("AK-15: Weiterreichen nach Ausfall")
  func passOnAfterCancellation() throws {
    try assign(["X.pdf"], to: tue8b)
    try data.markCancelled(tue8b)
    try data.markCancelled(wed8b)
    #expect(actions.passOnAll(from: tue8b) == thu8b)
    #expect(try data.materialLinkItems(for: thu8b).count == 1)
  }

  @Test("Ohne nächste Stunde bleibt das Material")
  func moveToNextLessonWithoutTargetKeepsLink() throws {
    let x = try assign(["X.pdf"], to: tue8b)[0]
    try data.addNonTeachingPeriod(
      NonTeachingPeriod(from: .wed18, to: CalendarDay(year: 2026, month: 12, day: 31), title: "Ferien"))
    #expect(actions.moveToNextLesson(linkID: x.id) == nil)
    #expect(try data.materialLinkItems(for: tue8b).map(\.id) == [x.id])
    #expect(penNotes.moves.isEmpty)
  }

  @Test("ADR-0011: Schieben und Weiterreichen melden die Umzüge für die Notiz-Dateien, Übernehmen nicht")
  func movesAreReportedForPenNotes() throws {
    let x = try assign(["X.pdf"], to: tue8b)[0]
    _ = actions.copyLinks(from: tue8b, to: wed8b)
    #expect(penNotes.moves.isEmpty)  // FR-6.1: Übernehmen ohne Notizen
    _ = actions.moveToNextLesson(linkID: x.id)
    #expect(penNotes.moves == [PenNoteMove(reference: x.reference, from: tue8b, to: wed8b)])
  }

  @Test("Weiterreichen meldet je Zuordnung einen Umzug, Reihenfolge bleibt")
  func passOnReportsEachLink() throws {
    let items = try assign(["A.pdf", "B.pdf"], to: tue8b)
    #expect(actions.passOnAll(from: tue8b) == wed8b)
    #expect(try data.materialLinkItems(for: wed8b).map(\.reference.displayName) == ["A.pdf", "B.pdf"])
    #expect(
      penNotes.moves
        == items.map { PenNoteMove(reference: $0.reference, from: tue8b, to: wed8b) })
  }

  @Test("FR-7: Material ohne Stunde einer gewählten Stunde zuordnen meldet den Umzug nur mit altem Schlüssel")
  func moveOrphanedLinkToChosenLesson() throws {
    let orphan = try assign(["Y.pdf"], to: Fixtures.key(.tue17, "8b", "Franzoesisch"))[0]
    actions.move(linkID: orphan.id, to: tue8b)
    #expect(try data.materialLinkItems(for: tue8b).map(\.id) == [orphan.id])
    #expect(
      penNotes.moves == [
        PenNoteMove(
          reference: orphan.reference, from: Fixtures.key(.tue17, "8b", "Franzoesisch"), to: tue8b)
      ])
  }
}
