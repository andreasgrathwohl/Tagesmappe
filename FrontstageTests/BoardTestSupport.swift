import Foundation
import FrontstageCore
import PencilKit

@testable import Frontstage

/// Stunden für die Tafel-Tests: Di 8b, Mi 8b (dieselbe Klasse und dasselbe Fach), Di 8a (andere Klasse).
let tue8b = LessonKey(date: tue17, schoolClass: SchoolClass("8b"), subject: Subject("Englisch"), ordinal: 1)
let wed8b = LessonKey(date: wed18, schoolClass: SchoolClass("8b"), subject: Subject("Englisch"), ordinal: 1)
let tue8a = LessonKey(date: tue17, schoolClass: SchoolClass("8a"), subject: Subject("Englisch"), ordinal: 1)

/// Eine Tafel-Sitzung über einem In-Memory-Store und einem frischen Zweitbildschirm-Zustand.
@MainActor func makeSession() throws -> (BoardSession, SecondScreenState) {
  let screen = SecondScreenState()
  let session = BoardSession(store: BoardStore(store: try makeStore()), secondScreen: screen)
  return (session, screen)
}
