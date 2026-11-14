import Testing

@testable import FrontstageCore

@Suite("SchulmanagerChangeExtractor")
struct SchulmanagerChangeExtractorTests {
  private func info(_ subject: String, _ cls: String, _ teacher: String) -> SchulmanagerLessonInfo {
    SchulmanagerLessonInfo(subjectName: subject, classNames: [cls], teacherIDs: [teacher])
  }

  private func lesson(
    _ day: CalendarDay, _ period: Int, _ type: SchulmanagerLessonType, actual: SchulmanagerLessonInfo?,
    originals: [SchulmanagerLessonInfo]
  ) -> SchulmanagerLesson {
    SchulmanagerLesson(
      date: day, period: period, type: type, actual: actual, originals: originals,
      isCancelled: type == .cancelledLesson, isSubstitution: type == .changedLesson)
  }

  @Test("Vertretung 3. Stunde 6c (AK-21)")
  func substitutionBecomesSubstitute() {
    let l = lesson(
      d(2026, 11, 17), 3, .changedLesson, actual: info("Mathematik", "6c", "T-100"),
      originals: [info("Mathematik", "6c", "T-200")])
    #expect(
      SchulmanagerChangeExtractor.changes(in: [l], teacherID: "T-100") == [
        .substitute(
          date: d(2026, 11, 17), period: 3, schoolClass: SchoolClass("6c"), subject: Subject("Mathematik"))
      ])
  }

  @Test("Eigene ausgefallene Stunde")
  func cancelledOwnLessonBecomesCancelled() {
    let l = lesson(
      d(2026, 11, 17), 4, .cancelledLesson, actual: nil, originals: [info("Englisch", "9c", "T-100")])
    #expect(
      SchulmanagerChangeExtractor.changes(in: [l], teacherID: "T-100") == [
        .cancelled(
          date: d(2026, 11, 17), period: 4, schoolClass: SchoolClass("9c"), subject: Subject("Englisch"))
      ])
  }

  @Test("Raumwechsel ist keine Abweichung")
  func roomChangeIsNoChange() {
    let l = lesson(
      d(2026, 11, 17), 2, .changedLesson, actual: info("Englisch", "8b", "T-100"),
      originals: [info("Englisch", "8b", "T-100")])
    #expect(SchulmanagerChangeExtractor.changes(in: [l], teacherID: "T-100").isEmpty)
  }

  @Test("Abgegebene Stunde gilt als ausgefallen")
  func lessonGivenAwayIsCancelled() {
    let l = lesson(
      d(2026, 11, 17), 2, .changedLesson, actual: info("Deutsch", "7a", "T-200"),
      originals: [info("Deutsch", "7a", "T-100")])
    #expect(
      SchulmanagerChangeExtractor.changes(in: [l], teacherID: "T-100") == [
        .cancelled(
          date: d(2026, 11, 17), period: 2, schoolClass: SchoolClass("7a"), subject: Subject("Deutsch"))
      ])
  }

  @Test("Fremder Ausfall wird ignoriert")
  func foreignCancellationIsIgnored() {
    let l = lesson(
      d(2026, 11, 17), 4, .cancelledLesson, actual: nil, originals: [info("Englisch", "9c", "T-200")])
    #expect(SchulmanagerChangeExtractor.changes(in: [l], teacherID: "T-100").isEmpty)
  }

  @Test("Gemeinsame Stunde zweier Klassen ergibt je Klasse einen Ausfall, ohne Doppelte")
  func sharedLessonYieldsOneCancellationPerClass() {
    let shared = SchulmanagerLessonInfo(
      subjectName: "Deutsch", classNames: ["8a", "8b"], teacherIDs: ["T-100"])
    let l = lesson(d(2026, 11, 18), 2, .cancelledLesson, actual: nil, originals: [shared, shared])
    #expect(SchulmanagerChangeExtractor.changes(in: [l, l], teacherID: "T-100").count == 2)
  }
}
