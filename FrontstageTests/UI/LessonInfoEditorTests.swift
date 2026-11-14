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
}
