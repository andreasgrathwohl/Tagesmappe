import Foundation
import Testing

@testable import FrontstageCore

@Suite("SchulmanagerResponseParser")
struct SchulmanagerResponseParserTests {
  private typealias F = SchulmanagerFixtures

  @Test("Salz als blanker String und als Objekt")
  func saltAcceptsBareStringAndObject() throws {
    #expect(try SchulmanagerResponseParser.salt(from: F.data("\"beispielsalz\"")) == "beispielsalz")
    #expect(
      try SchulmanagerResponseParser.salt(from: F.data("{\"salt\":\"beispielsalz\"}")) == "beispielsalz")
  }

  @Test func saltMissingThrows() {
    #expect(throws: TimetableSourceError.self) {
      try SchulmanagerResponseParser.salt(from: F.data("{\"other\":1}"))
    }
  }

  @Test func loginExtractsJwtAndTeacher() throws {
    let login = try SchulmanagerResponseParser.login(
      from: F.data(F.loginResponse), shape: F.shape)
    #expect(login.jwt == "jwt-beispiel")
    #expect(login.teacherID == "T-100")
    #expect(login.teacherObject[["abbreviation"]] == .string("XY"))
  }

  @Test("Mehrere Schulen werden nicht unterstützt (RISK-1)")
  func loginWithMultipleAccountsIsUnsupported() {
    #expect(throws: TimetableSourceError.multipleSchoolsUnsupported) {
      try SchulmanagerResponseParser.login(from: F.data(F.multipleAccountsResponse), shape: F.shape)
    }
  }

  @Test func loginWithoutTeacherObjectThrows() {
    #expect(throws: TimetableSourceError.self) {
      try SchulmanagerResponseParser.login(from: F.data("{\"jwt\":\"x\",\"user\":{}}"), shape: F.shape)
    }
  }

  @Test func loginAcceptsNumericTeacherID() throws {
    let json = "{\"jwt\":\"x\",\"user\":{\"associatedTeacher\":{\"id\":42}}}"
    let login = try SchulmanagerResponseParser.login(from: F.data(json), shape: F.shape)
    #expect(login.teacherID == "42")
  }

  @Test func parsesSubstitutionElement() throws {
    let data = F.calls(lessons: "[\(F.substitutionElement)]")
    let lessons = try SchulmanagerResponseParser.lessons(fromCalls: data, at: 0)
    #expect(lessons.count == 1)
    let lesson = lessons[0]
    #expect(lesson.date == d(2026, 11, 17))
    #expect(lesson.period == 3)
    #expect(lesson.type == .changedLesson)
    #expect(lesson.isSubstitution)
    #expect(!lesson.isCancelled)
    #expect(lesson.actual?.classNames == ["6c"])
    #expect(lesson.actual?.subjectName == "Mathematik")
    #expect(lesson.actual?.teacherIDs == ["T-100"])
    #expect(lesson.originals[0].teacherIDs == ["T-200"])
  }

  @Test func parsesCancelledElementWithSortedClasses() throws {
    let data = F.calls(lessons: "[\(F.cancelledElement)]")
    let lesson = try SchulmanagerResponseParser.lessons(fromCalls: data, at: 0)[0]
    #expect(lesson.type == .cancelledLesson)
    #expect(lesson.actual == nil)
    #expect(lesson.isCancelled)
    #expect(lesson.originals[0].classNames == ["8a", "8b"])
  }

  @Test func periodNumberAsIntOrString() throws {
    for number in ["3", "\"3\""] {
      let element = """
        {"date":"2026-11-17","classHour":{"number":\(number)},"type":"regularLesson",
         "actualLesson":{"subject":{"name":"Deutsch"},"teachers":[],"classes":[{"name":"9c"}]},
         "originalLessons":[]}
        """
      let lessons = try SchulmanagerResponseParser.lessons(
        fromCalls: F.calls(lessons: "[\(element)]"), at: 0)
      #expect(lessons[0].period == 3)
    }
  }

  @Test func subjectFallsBackToAbbreviation() throws {
    let element = """
      {"date":"2026-11-17","classHour":{"number":1},"type":"regularLesson",
       "actualLesson":{"subject":{"name":"","abbreviation":"E"},"teachers":[],"classes":[{"name":"9c"}]},
       "originalLessons":[]}
      """
    let lesson = try SchulmanagerResponseParser.lessons(
      fromCalls: F.calls(lessons: "[\(element)]"), at: 0)[0]
    #expect(lesson.actual?.subjectName == "E")
  }

  @Test func subjectMissingThrows() {
    let element = """
      {"date":"2026-11-17","classHour":{"number":1},"type":"regularLesson",
       "actualLesson":{"subject":{"name":"","abbreviation":""},"teachers":[],"classes":[{"name":"9c"}]},
       "originalLessons":[]}
      """
    #expect(throws: TimetableSourceError.self) {
      try SchulmanagerResponseParser.lessons(fromCalls: F.calls(lessons: "[\(element)]"), at: 0)
    }
  }

  @Test func unknownLessonTypeThrows() {
    let element = """
      {"date":"2026-11-17","classHour":{"number":1},"type":"somethingNew",
       "actualLesson":null,"originalLessons":[]}
      """
    #expect(throws: TimetableSourceError.self) {
      try SchulmanagerResponseParser.lessons(fromCalls: F.calls(lessons: "[\(element)]"), at: 0)
    }
  }

  @Test("Teilantwort mit Status ungleich 200: nichts wird gelesen (kein Teilimport)")
  func nonOkSubResultThrows() {
    let data = F.calls(lessons: "[\(F.substitutionElement)]", status: 500)
    #expect(throws: TimetableSourceError.self) {
      try SchulmanagerResponseParser.lessons(fromCalls: data, at: 0)
    }
  }

  @Test func missingSubResultThrows() {
    #expect(throws: TimetableSourceError.self) {
      try SchulmanagerResponseParser.lessons(fromCalls: F.calls(lessons: "[]"), at: 2)
    }
  }

  @Test func oneBadElementFailsTheWholeList() {
    let bad = "{\"date\":\"kaputt\",\"classHour\":{\"number\":1},\"type\":\"regularLesson\"}"
    #expect(throws: TimetableSourceError.self) {
      try SchulmanagerResponseParser.lessons(
        fromCalls: F.calls(lessons: "[\(F.substitutionElement),\(bad)]"), at: 0)
    }
  }

  @Test func eventWithoutSubjectIsKept() throws {
    let element = """
      {"date":"2026-11-17","classHour":{"number":4},"type":"event",
       "actualLesson":{"subject":null,"teachers":[],"classes":[]},"originalLessons":[]}
      """
    let lesson = try SchulmanagerResponseParser.lessons(
      fromCalls: F.calls(lessons: "[\(element)]"), at: 0)[0]
    #expect(lesson.type == .event)
    #expect(lesson.actual == nil)
  }

  @Test func classFallsBackToStudentGroup() throws {
    let element = """
      {"date":"2026-11-17","classHour":{"number":1},"type":"regularLesson",
       "actualLesson":{"subject":{"name":"Deutsch"},"teachers":[],"classes":[],"studentGroups":[{"name":"8b"}]},
       "originalLessons":[]}
      """
    let lesson = try SchulmanagerResponseParser.lessons(
      fromCalls: F.calls(lessons: "[\(element)]"), at: 0)[0]
    #expect(lesson.actual?.classNames == ["8b"])
  }

  @Test("Zeitraster aus der Quelle übernehmen (FR-1.2, Werte aus AK-42)")
  func parsesClassHours() throws {
    let hours = """
      [{"number":1,"from":"07:45:00","until":"08:30:00"},{"number":2,"from":"08:35:00","until":"09:20:00"}]
      """
    let bell = try SchulmanagerResponseParser.bellSchedule(
      fromCalls: F.calls(lessons: "[]", classHours: hours), at: 1)
    #expect(bell?.periods.count == 2)
    #expect(bell?.periods[2] == t(8, 35)...t(9, 20))
    #expect(bell?.periods[1] == t(7, 45)...t(8, 30))
  }

  @Test func classHoursAcceptShortTimeFormat() throws {
    let hours = "[{\"number\":\"1\",\"from\":\"07:45\",\"until\":\"08:30\"}]"
    let bell = try SchulmanagerResponseParser.bellSchedule(
      fromCalls: F.calls(lessons: "[]", classHours: hours), at: 1)
    #expect(bell?.periods[1] == t(7, 45)...t(8, 30))
  }

  @Test("Leere Stundenzeiten sind nichts Geliefertes: kein Zeitraster statt eines leeren (Q-16)")
  func emptyClassHoursYieldNoBellSchedule() throws {
    let bell = try SchulmanagerResponseParser.bellSchedule(
      fromCalls: F.calls(lessons: "[]", classHours: "[]"), at: 1)
    #expect(bell == nil)
  }

  @Test func malformedTimeThrows() {
    let hours = "[{\"number\":1,\"from\":\"8.35\",\"until\":\"09:20:00\"}]"
    #expect(throws: TimetableSourceError.self) {
      try SchulmanagerResponseParser.bellSchedule(
        fromCalls: F.calls(lessons: "[]", classHours: hours), at: 1)
    }
  }

  @Test func reversedTimeRangeThrows() {
    let hours = "[{\"number\":1,\"from\":\"09:00:00\",\"until\":\"08:00:00\"}]"
    #expect(throws: TimetableSourceError.self) {
      try SchulmanagerResponseParser.bellSchedule(
        fromCalls: F.calls(lessons: "[]", classHours: hours), at: 1)
    }
  }

  @Test func errorTextsNeverContainResponseValues() {
    let element = """
      {"date":"2026-11-17","classHour":{"number":1},"type":"geheimerTyp-Beispiel",
       "actualLesson":null,"originalLessons":[]}
      """
    do {
      _ = try SchulmanagerResponseParser.lessons(fromCalls: F.calls(lessons: "[\(element)]"), at: 0)
      Issue.record("Fehler erwartet")
    } catch let TimetableSourceError.unexpectedResponse(text) {
      #expect(!text.contains("geheimerTyp"))
    } catch {
      Issue.record("Falscher Fehler")
    }
  }
}
