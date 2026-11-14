import Foundation
import FrontstageCore

/// Eine bewegte Zuordnung: dieselbe Datei wechselt von einer Stunde in eine andere.
struct PenNoteMove: Hashable, Sendable {
  let reference: MaterialReference
  let from: LessonKey
  let to: LessonKey
}

/// Naht zu Teilplan 06 (Stiftnotizen neben dem Dokument, ADR-0011). 04 ruft sie, 06 setzt die Umsetzung.
@MainActor protocol PenNoteFileRelocating: AnyObject {
  /// Nach Schieben, Weiterreichen oder Zuordnen von Material ohne Stunde: Notiz-Datei und Notiz-PDF umbenennen.
  /// Synchron: die Umsetzung merkt sich den Umzug dauerhaft und führt ihn selbst aus (Teilplan 06).
  func linksMoved(_ moves: [PenNoteMove])
  /// Ausstehende Umbenennungen nachholen (Aktivwerden, vor dem Öffnen der Anzeige).
  func retryPending() async
  /// Nach Neu verknüpfen: Zahl der Unterrichtsstunden mit Notizen am alten Ort; 0 = nichts anzubieten.
  func notesCount(beside old: MaterialReference) async -> Int
  /// Notizen vom alten Ort neben die neue Datei verschieben.
  func moveNotes(from old: MaterialReference, to new: MaterialReference) async throws
}

/// Vorgabe bis Teilplan 06: tut nichts, bietet nichts an.
@MainActor final class NoPenNoteFileRelocation: PenNoteFileRelocating {
  func linksMoved(_ moves: [PenNoteMove]) {}
  func retryPending() async {}
  func notesCount(beside old: MaterialReference) async -> Int { 0 }
  func moveNotes(from old: MaterialReference, to new: MaterialReference) async throws {}
}
