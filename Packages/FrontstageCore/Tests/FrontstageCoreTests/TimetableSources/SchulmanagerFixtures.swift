import Foundation

@testable import FrontstageCore

/// Erfundene Beispieldaten für die Schulmanager-Tests (keine echten Personen, Klassen oder Kennungen).
enum SchulmanagerFixtures {
  /// Eigene Test-Form, damit die Tests nicht an den vorläufigen Werten von `.recorded` hängen.
  static let shape = SchulmanagerAPIShape(
    host: "login.schulmanager-online.de", saltPath: "/api/get-salt", loginPath: "/api/login",
    callsPath: "/api/calls", teacherObjectPath: ["user", "associatedTeacher"], teacherIDPath: ["id"],
    lessonsModule: "schedules", lessonsEndpoint: "get-actual-lessons",
    teacherParameterKey: "teacher", passesWholeTeacherObject: true,
    classHoursModule: "schedules", classHoursEndpoint: "get-class-hours",
    classHoursParameters: ["scope": .string("all")], bundleVersion: nil)

  static func data(_ text: String) -> Data { Data(text.utf8) }

  static let loginResponse = """
    {"jwt":"jwt-beispiel","user":{"id":"U-1","associatedTeacher":{"id":"T-100","abbreviation":"XY"}}}
    """

  static let multipleAccountsResponse = """
    {"multipleAccounts":[{"institutionId":1},{"institutionId":2}]}
    """

  /// Vertretung: Fach Mathematik in 6c, die Lehrkraft T-100 übernimmt von T-200.
  static let substitutionElement = """
    {"date":"2026-11-17","classHour":{"id":"h3","number":"3"},"type":"changedLesson",
     "actualLesson":{"subject":{"name":"Mathematik","abbreviation":"M"},"teachers":[{"id":"T-100","abbreviation":"XY"}],"classes":[{"id":"c6","name":"6c"}],"studentGroups":[]},
     "originalLessons":[{"subject":{"name":"Mathematik","abbreviation":"M"},"teachers":[{"id":"T-200","abbreviation":"ZZ"}],"classes":[{"id":"c6","name":"6c"}],"studentGroups":[]}],
     "isCancelled":false,"isSubstitution":true,"isNew":false}
    """

  /// Ausfall: Deutsch in 8a und 8b gemeinsam, Lehrkraft T-100.
  static let cancelledElement = """
    {"date":"2026-11-18","classHour":{"id":"h2","number":2},"type":"cancelledLesson",
     "actualLesson":null,
     "originalLessons":[{"subject":{"name":"Deutsch","abbreviation":"D"},"teachers":[{"id":"T-100"}],"classes":[{"name":"8b"},{"name":"8a"}],"studentGroups":[]}],
     "isCancelled":true,"isSubstitution":false,"isNew":false}
    """

  static func calls(lessons: String, status: Int = 200, classHours: String = "[]") -> Data {
    data(
      """
      {"results":[{"status":\(status),"data":\(lessons)},{"status":200,"data":\(classHours)}]}
      """)
  }
}
