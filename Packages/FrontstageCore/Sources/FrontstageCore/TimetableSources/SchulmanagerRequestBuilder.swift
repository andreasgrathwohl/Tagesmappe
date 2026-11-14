import Foundation

/// Baut die Anfrage-Bodies für Salt, Login und Abfrage. Reine Datenumwandlung, kein Netz.
public enum SchulmanagerRequestBuilder {
  /// Body für die Salt-Abfrage.
  public static func saltBody(username: String) throws -> Data {
    try encode(
      .object([
        "emailOrUsername": .string(username),
        "mobileApp": .bool(false),
        "institutionId": .null,
      ]))
  }

  /// Body für die Anmeldung; `hash` ist das abgeleitete Passwort (PBKDF2, in der App berechnet).
  public static func loginBody(username: String, password: String, hash: String) throws -> Data {
    try encode(
      .object([
        "emailOrUsername": .string(username),
        "password": .string(password),
        "hash": .string(hash),
        "mobileApp": .bool(false),
        "institutionId": .null,
      ]))
  }

  /// Ein POST mit zwei Teilaufrufen: [0] Stunden im Zeitraum, [1] Stundenzeiten.
  /// Das Token gehört in die Kopfzeile `Authorization`, nie in den Body.
  public static func callsBody(
    shape: SchulmanagerAPIShape, login: SchulmanagerLogin, range: ClosedRange<CalendarDay>
  ) throws -> Data {
    let teacher: JSONValue =
      shape.passesWholeTeacherObject ? login.teacherObject : .string(login.teacherID)
    let lessonRequest: JSONValue = .object([
      "moduleName": .string(shape.lessonsModule),
      "endpointName": .string(shape.lessonsEndpoint),
      "parameters": .object([
        shape.teacherParameterKey: teacher,
        "start": .string(range.lowerBound.storageText),
        "end": .string(range.upperBound.storageText),
      ]),
    ])
    let classHoursRequest: JSONValue = .object([
      "moduleName": .string(shape.classHoursModule),
      "endpointName": .string(shape.classHoursEndpoint),
      "parameters": .object(shape.classHoursParameters),
    ])
    var body: [String: JSONValue] = ["requests": .array([lessonRequest, classHoursRequest])]
    if let version = shape.bundleVersion { body["bundleVersion"] = .string(version) }
    return try encode(.object(body))
  }

  private static func encode(_ value: JSONValue) throws -> Data {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys]
    return try encoder.encode(value)
  }
}
