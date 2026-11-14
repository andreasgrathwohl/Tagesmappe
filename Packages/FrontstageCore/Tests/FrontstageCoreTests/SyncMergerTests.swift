import Foundation
import Testing
@testable import FrontstageCore

@Suite("SyncMergerTests")
struct SyncMergerTests {
  let t1 = Date(timeIntervalSince1970: 1_000)
  let t2 = Date(timeIntervalSince1970: 2_000)
  let t3 = Date(timeIntervalSince1970: 3_000)

  /// Feste UUID aus einer Ziffer; Zeichenketten sortieren wie die Ziffern.
  func id(_ n: Int) -> UUID { UUID(uuidString: "00000000-0000-0000-0000-00000000000\(n)")! }

  func link(_ n: Int, _ created: Date, key: String = "k", file: String? = "f") -> MaterialLinkSnapshot {
    MaterialLinkSnapshot(id: id(n), lessonKeyText: key, fileIdentity: file, createdAt: created)
  }

  func note(_ n: Int, link: Int?, page: Int, created: Date, updated: Date) -> PenNoteSnapshot {
    PenNoteSnapshot(id: id(n), linkID: link.map(id), pageIndex: page, createdAt: created, updatedAt: updated)
  }

  func tt(_ n: Int, active: Bool, _ created: Date) -> TimetableSnapshot {
    TimetableSnapshot(id: id(n), isActive: active, createdAt: created)
  }

  func eSnap(_ n: Int, tt: Int?, _ e: TimetableEntry, _ created: Date) -> TimetableEntrySnapshot {
    TimetableEntrySnapshot(id: id(n), timetableID: tt.map(id), entry: e, createdAt: created)
  }

  @Test("Nebenläufigkeit: doppelte Datei in derselben Stunde → ältere bleibt, Stiftnotizen wandern")
  func mergesDuplicateLinksAndMovesPenNotes() {
    let snapshot = SyncSnapshot(
      links: [link(1, t1), link(2, t2)],
      penNotes: [note(5, link: 2, page: 1, created: t2, updated: t2)])
    let plan = SyncMerger.plan(for: snapshot)
    #expect(plan.deletions == [id(2)])
    #expect(plan.penNoteLinkChanges == [id(5): id(1)])
  }

  @Test("Nebenläufigkeit: beide Zuordnungen haben Seite 1 – älteste Notiz bleibt, jüngste Zeichnung gilt")
  func mergesPenNotesOnSamePageKeepingLatestDrawing() {
    let snapshot = SyncSnapshot(
      links: [link(1, t1), link(2, t2)],
      penNotes: [
        note(4, link: 1, page: 0, created: t1, updated: t1),
        note(5, link: 2, page: 0, created: t2, updated: t3),
      ])
    let plan = SyncMerger.plan(for: snapshot)
    #expect(plan.deletions == [id(2), id(5)])
    #expect(plan.penNoteLinkChanges.isEmpty)
    #expect(plan.penNoteDrawingSources == [id(4): id(5)])
  }

  @Test("Verschiedene Dateien in derselben Stunde bleiben beide")
  func keepsDifferentFilesInSameLesson() {
    let snapshot = SyncSnapshot(links: [link(1, t1, file: "a"), link(2, t2, file: "b")])
    #expect(SyncMerger.plan(for: snapshot).isEmpty)
  }

  @Test("Zuordnung ohne abgeglichenen Verweis wird nie zusammengeführt")
  func ignoresLinksWithoutFileIdentity() {
    let snapshot = SyncSnapshot(links: [link(1, t1, file: nil), link(2, t2, file: nil)])
    #expect(SyncMerger.plan(for: snapshot).isEmpty)
  }

  @Test("Doppelte Stundenangaben: ältester Datensatz, je Feld der jüngste Stand")
  func mergesLessonInfosPerField() {
    let snapshot = SyncSnapshot(lessonInfos: [
      LessonInfoSnapshot(id: id(1), lessonKeyText: "k", createdAt: t1, fieldUpdatedAt: [.topic: t1, .toPrepare: t3]),
      LessonInfoSnapshot(id: id(2), lessonKeyText: "k", createdAt: t2, fieldUpdatedAt: [.topic: t2, .homework: t2]),
    ])
    let plan = SyncMerger.plan(for: snapshot)
    #expect(plan.deletions == [id(2)])
    #expect(plan.lessonInfoFieldSources == [id(1): [.topic: id(2), .homework: id(2)]])
  }

  @Test("Doppelter Ausfall derselben Stunde wird eins; Hand und Quelle bleiben getrennt")
  func mergesScheduleChangesByValueIncludingOrigin() {
    let key = LessonKey(date: d(2026, 11, 18), schoolClass: SchoolClass("8b"), subject: Subject("Englisch"), ordinal: 1)
    let snapshot = SyncSnapshot(scheduleChanges: [
      ScheduleChangeSnapshot(id: id(1), change: .cancellation(key, .manual), createdAt: t1),
      ScheduleChangeSnapshot(id: id(2), change: .cancellation(key, .manual), createdAt: t2),
      ScheduleChangeSnapshot(id: id(3), change: .cancellation(key, .source), createdAt: t3),
    ])
    #expect(SyncMerger.plan(for: snapshot).deletions == [id(2)])
  }

  @Test("Doppelte Vertretungsstunde wird eins")
  func mergesDuplicateSubstituteLessons() {
    let change = ScheduleChange.substituteLesson(
      date: d(2026, 11, 18), period: 4, schoolClass: SchoolClass("6c"), subject: Subject("Mathe"), .manual)
    let snapshot = SyncSnapshot(scheduleChanges: [
      ScheduleChangeSnapshot(id: id(1), change: change, createdAt: t1),
      ScheduleChangeSnapshot(id: id(2), change: change, createdAt: t2),
    ])
    #expect(SyncMerger.plan(for: snapshot).deletions == [id(2)])
  }

  @Test("Doppelter unterrichtsfreier Zeitraum wird eins")
  func mergesDuplicateNonTeachingPeriods() {
    let period = NonTeachingPeriod(from: d(2026, 11, 2), to: d(2026, 11, 6), title: "Herbstferien")
    let snapshot = SyncSnapshot(nonTeachingPeriods: [
      NonTeachingPeriodSnapshot(id: id(1), period: period, createdAt: t1),
      NonTeachingPeriodSnapshot(id: id(2), period: period, createdAt: t2),
    ])
    #expect(SyncMerger.plan(for: snapshot).deletions == [id(2)])
  }

  @Test("Review Focus 1: zwei aktive Stundenpläne – ältester bleibt, Einträge wandern, Dubletten verschwinden")
  func mergesDuplicateActiveTimetables() {
    let tue = entry(.tuesday, 2, "8b", "Englisch")
    let thu = entry(.thursday, 3, "8b", "Englisch")
    let snapshot = SyncSnapshot(
      timetables: [tt(1, active: true, t1), tt(2, active: true, t2)],
      entries: [eSnap(3, tt: 1, tue, t1), eSnap(4, tt: 2, tue, t2), eSnap(5, tt: 2, thu, t2)])
    let plan = SyncMerger.plan(for: snapshot)
    #expect(plan.deletions == [id(2), id(4)])
    #expect(plan.entryTimetableChanges == [id(5): id(1)])
  }

  @Test("Inaktive Stundenpläne werden nicht angefasst")
  func ignoresInactiveTimetables() {
    let tue = entry(.tuesday, 2, "8b", "Englisch")
    let snapshot = SyncSnapshot(
      timetables: [tt(1, active: true, t1), tt(2, active: false, t2)],
      entries: [eSnap(3, tt: 1, tue, t1), eSnap(4, tt: 2, tue, t2)])
    #expect(SyncMerger.plan(for: snapshot).isEmpty)
  }

  @Test("Gleichstand der Anlagezeit: kleinere UUID bleibt")
  func breaksTiesByUUID() {
    let key = LessonKey(date: d(2026, 11, 18), schoolClass: SchoolClass("8b"), subject: Subject("Englisch"), ordinal: 1)
    let snapshot = SyncSnapshot(scheduleChanges: [
      ScheduleChangeSnapshot(id: id(7), change: .cancellation(key, .manual), createdAt: t1),
      ScheduleChangeSnapshot(id: id(3), change: .cancellation(key, .manual), createdAt: t1),
    ])
    #expect(SyncMerger.plan(for: snapshot).deletions == [id(7)])
  }

  @Test("Bereinigter Bestand ergibt leeren Plan")
  func cleanSnapshotYieldsEmptyPlan() {
    let snapshot = SyncSnapshot(
      timetables: [tt(1, active: true, t1)],
      entries: [eSnap(2, tt: 1, entry(.monday, 1, "8b", "Mathe"), t1)],
      links: [link(3, t1)],
      penNotes: [note(4, link: 3, page: 0, created: t1, updated: t1)])
    #expect(SyncMerger.plan(for: snapshot).isEmpty)
    #expect(SyncMerger.plan(for: SyncSnapshot()).isEmpty)
  }
}
