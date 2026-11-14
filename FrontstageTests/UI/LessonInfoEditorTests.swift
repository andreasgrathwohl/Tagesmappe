import Foundation
import FrontstageCore
import Testing

@testable import Frontstage

/// Stundenangaben bearbeiten (FR-11.1, FR-13).
@MainActor @Suite struct LessonInfoEditorTests {
  private let data: DataStore
  private let key = Fixtures.key(.tue17, "8b", "Englisch")

  init() throws {
    data = try makeStore()
    try Fixtures.seed(data, [Fixtures.entry(.tuesday, 2, "8b", "Englisch")])
  }

  @Test("Leere Felder werden nil")
  func emptyFieldsBecomeNil() throws {
    let editor = LessonInfoEditor(key: key, store: data)
    editor.topic = "Unit 4 – Wortschatz"
    editor.toPrepare = "  "
    editor.save()
    #expect(
      try data.lessonInfo(for: key)
        == LessonInfo(topic: "Unit 4 – Wortschatz", toPrepare: nil, homework: nil))
  }

  @Test("Gespeicherte Angaben füllen den Editor, Leerraum wird getrimmt")
  func loadsAndTrims() throws {
    try data.setLessonInfo(LessonInfo(topic: "Thema", homework: "Seite 12"), for: key)
    let editor = LessonInfoEditor(key: key, store: data)
    #expect(editor.topic == "Thema")
    #expect(editor.toPrepare == "")
    #expect(editor.homework == "Seite 12")
    editor.homework = "  Seite 13  \n"
    editor.save()
    #expect(try data.lessonInfo(for: key).homework == "Seite 13")
  }

  @Test("Unveränderter Editor schreibt nichts und überschreibt keinen neueren Stand")
  func unchangedSaveWritesNothing() throws {
    let editor = LessonInfoEditor(key: key, store: data)
    let before = data.revision
    editor.save()
    #expect(data.revision == before)
    #expect(try data.lessonInfo(for: key) == LessonInfo())

    // Anderes Gerät ändert das Thema; der veraltete Editor darf es nicht zurückschreiben.
    try data.setLessonInfo(LessonInfo(topic: "Neu"), for: key)
    editor.save()
    #expect(try data.lessonInfo(for: key).topic == "Neu")
  }

  @Test("Unbearbeiteter Editor übernimmt neuen Stand, bearbeiteter behält seinen")
  func reloadsOnlyWhenUnedited() throws {
    let editor = LessonInfoEditor(key: key, store: data)
    try data.setLessonInfo(LessonInfo(topic: "Remote"), for: key)
    editor.reloadIfUnedited()
    #expect(editor.topic == "Remote")

    editor.homework = "Lokal"
    try data.setLessonInfo(LessonInfo(topic: "Remote 2"), for: key)
    editor.reloadIfUnedited()
    #expect(editor.topic == "Remote")
    #expect(editor.homework == "Lokal")
  }
}
