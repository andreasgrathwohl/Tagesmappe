import Foundation
import FrontstageCore

/// Schmale Sicht der Oberfläche auf die Ablage; die Signaturen sind die von `StorageService`
/// (Teilplan 03). Mit ihr lassen sich die View-Modelle gegen eine Attrappe testen.
@MainActor protocol MaterialStorage: AnyObject {
  var grants: [FolderGrant] { get }
  /// Schlüssel: `MaterialReference.locationKey`.
  var availability: [String: MaterialAvailability] { get }
  func suggestedGrantName(for folderURL: URL) -> GrantNameSuggestion
  func addGrant(folderURL: URL, name: String) async throws -> FolderGrant
  func removeGrant(id: UUID)
  func reference(forPickedFile url: URL) -> MaterialReference?
  func relink(_ old: MaterialReference, toPickedFile url: URL) -> RelinkResult
  func refreshAvailability(for references: [MaterialReference])
  func open(_ reference: MaterialReference, anchor: HandOffAnchor) async -> OpenOutcome
  func openWithoutAutoSave(_ reference: MaterialReference, anchor: HandOffAnchor) async -> OpenOutcome
  func offerOpenWithoutAutoSave(now: ContinuousClock.Instant) -> MaterialReference?
  func didAssign(_ references: [MaterialReference]) async
  func prepareForTeaching(
    today: CalendarDay, timetable: Timetable, nonTeachingPeriods: [NonTeachingPeriod],
    changes: [ScheduleChange]) async
}

extension StorageService: MaterialStorage {}
