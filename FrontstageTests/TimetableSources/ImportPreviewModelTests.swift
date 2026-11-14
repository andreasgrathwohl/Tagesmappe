import Foundation
import FrontstageCore
import Testing

@testable import Frontstage

@Suite("Vorschau des Import-Abgleichs")
struct ImportPreviewModelTests {
  private func entry(_ period: Int, _ subject: String, weekday: Weekday = .monday) -> TimetableEntry {
    TimetableEntry(
      weekday: weekday, period: period, schoolClass: SchoolClass("8b"), subject: Subject(subject))
  }

  private func preview(diff: ImportDiff, bellChanged: Bool = false) -> ImportPreview {
    let snapshot = SourceSnapshot(
      kind: .schulmanager, fetchedAt: Date(timeIntervalSince1970: 1_800_000_000),
      range: CalendarDay(year: 2026, month: 11, day: 2)...CalendarDay(year: 2026, month: 11, day: 20),
      timetable: .noLessonsInRange, bellSchedule: nil, changes: [])
    return ImportPreview(snapshot: snapshot, diff: diff, bellScheduleChanged: bellChanged)
  }

  @Test("Konflikt startet mit eigener Fassung (AK-3)")
  func conflictsDefaultToMine() {
    let diff = ImportDiff(manualConflicts: [(mine: entry(1, "Mathe"), source: entry(1, "Physik"))])
    let model = ImportPreviewModel(preview: preview(diff: diff))
    #expect(model.acceptedFromSource.isEmpty)
  }

  @Test("Wahl der Quelle wird festgehalten und lässt sich zurücknehmen")
  func choosingSourceIsRecorded() {
    let mine = entry(1, "Mathe")
    let source = entry(1, "Physik")
    var model = ImportPreviewModel(
      preview: preview(diff: ImportDiff(manualConflicts: [(mine: mine, source: source)])))
    model.choose(source: true, for: mine)
    #expect(model.acceptedFromSource == [source])
    model.choose(source: false, for: mine)
    #expect(model.acceptedFromSource.isEmpty)
  }

  @Test("Wahl für einen unbekannten Konflikt ändert nichts")
  func choosingUnknownConflictIsIgnored() {
    var model = ImportPreviewModel(preview: preview(diff: ImportDiff()))
    model.choose(source: true, for: entry(5, "Kunst"))
    #expect(model.acceptedFromSource.isEmpty)
  }

  @Test("Gruppen übernehmen den Inhalt des Abgleichs")
  func groupsKeepDiffContents() {
    let diff = ImportDiff(
      added: [entry(2, "Deutsch")],
      changed: [(old: entry(3, "Kunst"), new: entry(3, "Musik"))],
      manualConflicts: [(mine: entry(1, "Mathe"), source: entry(1, "Physik"))],
      removed: [])
    let model = ImportPreviewModel(preview: preview(diff: diff, bellChanged: true))
    #expect(model.added.count == 1)
    #expect(model.changed.count == 1)
    #expect(model.conflicts.count == 1)
    #expect(model.removed.isEmpty)
    #expect(model.bellScheduleChanged)
    #expect(model.fetchedAt == Date(timeIntervalSince1970: 1_800_000_000))
    #expect(!model.isEmpty)
  }

  @Test("Ohne Unterschiede und ohne neues Zeitraster ist die Vorschau leer")
  func emptyDiffIsEmpty() {
    #expect(ImportPreviewModel(preview: preview(diff: ImportDiff())).isEmpty)
  }
}
