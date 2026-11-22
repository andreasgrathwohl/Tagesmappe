import Foundation
import FrontstageCore

@testable import Frontstage

/// Attrappe der Ablage für die View-Modell-Tests. Daten laufen immer über den echten `DataStore`;
/// die Attrappe ersetzt nur Ordnerfreigaben, Öffnen und Neu verknüpfen.
@MainActor final class FakeStorage: MaterialStorage {
  var grants: [FolderGrant] = []
  var availability: [String: MaterialAvailability] = [:]
  /// Diese URLs gelten als „außerhalb aller Freigaben“.
  var rejectURLs: Set<URL> = []
  /// Erzwingt das Ergebnis von `relink` (z. B. `.saveFailed`).
  var relinkResultOverride: RelinkResult?
  var openOutcome: OpenOutcome = .handedOff
  /// Simuliert das Warten von `open` (in Teilplan 03 bis zu 120 s).
  var openDelay: Duration?
  /// Gespiegelte Freigabe-Namen für `suggestedGrantName`.
  var mirroredNames: Set<String> = []

  private(set) var pickedFileCalls = 0
  private(set) var opened: [MaterialReference] = []
  private(set) var assigned: [[MaterialReference]] = []
  private(set) var preparedDays: [CalendarDay] = []
  /// Orte, für die gerade ein `open` wartet.
  private var pendingOpenKeys: Set<String> = []

  func suggestedGrantName(for folderURL: URL) -> GrantNameSuggestion {
    FolderGrantNaming.suggestion(
      folderName: folderURL.lastPathComponent, localGrantNames: Set(grants.map(\.name)),
      mirroredNames: mirroredNames)
  }

  func addGrant(folderURL: URL, name: String) async throws -> FolderGrant {
    if grants.contains(where: { $0.name.lowercased() == name.lowercased() }) {
      throw FolderGrantError.nameInUse
    }
    let grant = FolderGrant(id: UUID(), name: name, bookmark: Data(), displayPath: folderURL.path)
    grants.append(grant)
    return grant
  }

  func removeGrant(id: UUID) {
    grants.removeAll { $0.id == id }
  }

  func reference(forPickedFile url: URL) -> MaterialReference? {
    pickedFileCalls += 1
    guard url.isFileURL, !rejectURLs.contains(url) else { return nil }
    return Fixtures.reference(
      url.lastPathComponent, MaterialFileKind(fileExtension: url.pathExtension))
  }

  /// Vorschlag für die Lösung (FR-6.3), von Tests gesetzt.
  var solutionSuggestion: MaterialReference?

  func suggestedSolution(for sheet: MaterialReference) -> MaterialReference? {
    solutionSuggestion
  }

  func relink(_ old: MaterialReference, toPickedFile url: URL) -> RelinkResult {
    if let override = relinkResultOverride { return override }
    guard !rejectURLs.contains(url), let new = reference(forPickedFile: url) else {
      return .outsideGrants
    }
    return .relinked(new)
  }

  func refreshAvailability(for references: [MaterialReference]) {}

  func open(_ reference: MaterialReference, anchor: HandOffAnchor) async -> OpenOutcome {
    let key = reference.locationKey
    // Wie in Teilplan 03: Wartet für diesen Ort schon ein Aufruf, öffnet dieser von selbst.
    if pendingOpenKeys.contains(key) { return .waitingForDownload }
    opened.append(reference)
    if let delay = openDelay {
      pendingOpenKeys.insert(key)
      defer { pendingOpenKeys.remove(key) }
      try? await Task.sleep(for: delay)
    }
    return openOutcome
  }

  func openWithoutAutoSave(_ reference: MaterialReference, anchor: HandOffAnchor) async -> OpenOutcome {
    await open(reference, anchor: anchor)
  }

  func offerOpenWithoutAutoSave(now: ContinuousClock.Instant) -> MaterialReference? { nil }

  func didAssign(_ references: [MaterialReference]) async {
    assigned.append(references)
  }

  func prepareForTeaching(
    today: CalendarDay, timetable: Timetable, nonTeachingPeriods: [NonTeachingPeriod],
    changes: [ScheduleChange]
  ) async {
    preparedDays.append(today)
  }
}

/// Zeichnet die Aufrufe der Naht auf; `notesCountResult` steuert das Angebot beim Neu verknüpfen.
@MainActor final class FakePenNoteRelocation: PenNoteFileRelocating {
  private(set) var moves: [PenNoteMove] = []
  var notesCountResult = 0
  /// Wird von `moveNotes` geworfen, falls gesetzt.
  var moveNotesError: (any Error)?
  private(set) var movedNotes: [(MaterialReference, MaterialReference)] = []
  private(set) var retryCalls = 0

  func linksMoved(_ moves: [PenNoteMove]) {
    self.moves.append(contentsOf: moves)
  }

  func retryPending() async { retryCalls += 1 }

  func notesCount(beside old: MaterialReference) async -> Int { notesCountResult }

  func moveNotes(from old: MaterialReference, to new: MaterialReference) async throws {
    if let error = moveNotesError { throw error }
    movedNotes.append((old, new))
  }
}
