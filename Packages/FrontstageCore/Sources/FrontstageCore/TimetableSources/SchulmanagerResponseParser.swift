import Foundation

/// Eine Unterrichtsstunde, wie Schulmanager sie meldet (Fach, Klassen, Lehrkräfte).
public struct SchulmanagerLessonInfo: Hashable, Sendable {
  public var subjectName: String
  /// Sortierte Klassennamen (Ersatz: Gruppennamen, wenn keine Klasse genannt ist).
  public var classNames: [String]
  public var teacherIDs: [String]

  public init(subjectName: String, classNames: [String], teacherIDs: [String]) {
    self.subjectName = subjectName
    self.classNames = classNames
    self.teacherIDs = teacherIDs
  }
}

public enum SchulmanagerLessonType: String, Sendable {
  case regularLesson, cancelledLesson, changedLesson, event
}

/// Eine datierte Stunde aus `get-actual-lessons`.
public struct SchulmanagerLesson: Hashable, Sendable {
  public var date: CalendarDay
  public var period: Int
  public var type: SchulmanagerLessonType
  public var actual: SchulmanagerLessonInfo?
  public var originals: [SchulmanagerLessonInfo]
  public var isCancelled: Bool
  public var isSubstitution: Bool

  public init(
    date: CalendarDay, period: Int, type: SchulmanagerLessonType, actual: SchulmanagerLessonInfo?,
    originals: [SchulmanagerLessonInfo], isCancelled: Bool, isSubstitution: Bool
  ) {
    self.date = date
    self.period = period
    self.type = type
    self.actual = actual
    self.originals = originals
    self.isCancelled = isCancelled
    self.isSubstitution = isSubstitution
  }
}

/// Ergebnis der Anmeldung. Das Token lebt nur im Speicher eines Imports.
public struct SchulmanagerLogin: Sendable {
  public var jwt: String
  public var teacherObject: JSONValue
  public var teacherID: String

  public init(jwt: String, teacherObject: JSONValue, teacherID: String) {
    self.jwt = jwt
    self.teacherObject = teacherObject
    self.teacherID = teacherID
  }
}

/// Liest die Antworten von Schulmanager. Jede Abweichung vom erwarteten Aufbau ist ein Fehler
/// (`unexpectedResponse`), damit nie ein Teilimport entsteht. Fehlertexte nennen nur Feldnamen,
/// nie Werte aus der Antwort (kein Token, keine Namen).
public enum SchulmanagerResponseParser {
  /// Salz als blanker JSON-String oder als `{"salt": …}`.
  public static func salt(from data: Data) throws -> String {
    let root = try decode(data)
    switch root {
    case .string(let salt) where !salt.isEmpty: return salt
    case .object(let object):
      if case .string(let salt)? = object["salt"], !salt.isEmpty { return salt }
    default: break
    }
    throw fail("Salt fehlt")
  }

  public static func login(from data: Data, shape: SchulmanagerAPIShape) throws -> SchulmanagerLogin {
    let root = try decode(data)
    guard case .object(let object) = root else { throw fail("Anmeldeantwort ist kein Objekt") }
    guard case .string(let jwt)? = object["jwt"], !jwt.isEmpty else {
      if object["multipleAccounts"] != nil { throw TimetableSourceError.multipleSchoolsUnsupported }
      throw fail("Anmeldeantwort ohne Token")
    }
    guard let teacher = root[shape.teacherObjectPath], case .object = teacher else {
      throw fail("Lehrer-Objekt fehlt")
    }
    guard let id = teacher[shape.teacherIDPath].flatMap(text) else { throw fail("Lehrer-ID fehlt") }
    return SchulmanagerLogin(jwt: jwt, teacherObject: teacher, teacherID: id)
  }

  /// Stunden aus dem Teilergebnis `index` einer Abfrage.
  public static func lessons(fromCalls data: Data, at index: Int) throws -> [SchulmanagerLesson] {
    guard case .array(let elements) = try callData(data, at: index) else {
      throw fail("Stunden sind keine Liste")
    }
    return try elements.map(lesson)
  }

  /// Zeitraster aus dem Teilergebnis `index` einer Abfrage.
  /// Eine leere Liste ist nichts Geliefertes (etwa unbelegte Parameter für Lehrkräfte, Q-16): dann `nil`,
  /// damit ein von Hand gepflegtes Zeitraster nicht durch ein leeres ersetzt wird.
  public static func bellSchedule(fromCalls data: Data, at index: Int) throws -> BellSchedule? {
    guard case .array(let elements) = try callData(data, at: index) else {
      throw fail("Stundenzeiten sind keine Liste")
    }
    guard !elements.isEmpty else { return nil }
    var periods: [Int: ClosedRange<TimeOfDay>] = [:]
    for element in elements {
      guard let number = element[["number"]].flatMap(integer),
        let from = element[["from"]].flatMap(timeText).flatMap(time),
        let until = element[["until"]].flatMap(timeText).flatMap(time), from <= until
      else { throw fail("Stundenzeit unvollständig oder ungültig") }
      periods[number] = from...until
    }
    return BellSchedule(periods: periods)
  }

  // MARK: - Teilantworten

  private static func callData(_ data: Data, at index: Int) throws -> JSONValue {
    let root = try decode(data)
    guard case .array(let results)? = root[["results"]], results.indices.contains(index) else {
      throw fail("Teilantwort \(index) fehlt")
    }
    let result = results[index]
    guard case .number(let status)? = result[["status"]], status == 200,
      let payload = result[["data"]]
    else { throw fail("Teilantwort \(index) ohne Status 200") }
    return payload
  }

  private static func lesson(_ element: JSONValue) throws -> SchulmanagerLesson {
    guard case .string(let dateText)? = element[["date"]],
      let date = CalendarDay(storageText: String(dateText.prefix(10)))
    else { throw fail("Datum fehlt oder ist ungültig") }
    guard let period = element[["classHour", "number"]].flatMap(integer) else {
      throw fail("Stundennummer fehlt")
    }
    guard case .string(let typeText)? = element[["type"]],
      let type = SchulmanagerLessonType(rawValue: typeText)
    else { throw fail("Unbekannter Stundentyp") }

    var actual: SchulmanagerLessonInfo?
    var originals: [SchulmanagerLessonInfo] = []
    if type == .event {
      // Ereignisse tragen oft kein Fach; sie zählen nicht als Unterricht.
      actual = element[["actualLesson"]].flatMap { try? info($0) }
    } else {
      if let node = element[["actualLesson"]], node != .null { actual = try info(node) }
      if case .array(let nodes)? = element[["originalLessons"]] { originals = try nodes.map(info) }
    }
    return SchulmanagerLesson(
      date: date, period: period, type: type, actual: actual, originals: originals,
      isCancelled: bool(element[["isCancelled"]]),
      isSubstitution: bool(element[["isSubstitution"]]))
  }

  private static func info(_ node: JSONValue) throws -> SchulmanagerLessonInfo {
    let name = node[["subject", "name"]].flatMap(text) ?? ""
    let abbreviation = node[["subject", "abbreviation"]].flatMap(text) ?? ""
    let subject = !name.isEmpty ? name : abbreviation
    guard !subject.isEmpty else { throw fail("Fach fehlt") }

    var classNames = names(node[["classes"]])
    if classNames.isEmpty { classNames = names(node[["studentGroups"]]) }

    var teacherIDs: [String] = []
    if case .array(let teachers)? = node[["teachers"]] {
      teacherIDs = teachers.compactMap { $0[["id"]].flatMap(text) }
    }
    return SchulmanagerLessonInfo(
      subjectName: subject, classNames: classNames.sorted(), teacherIDs: teacherIDs)
  }

  // MARK: - Hilfen

  private static func decode(_ data: Data) throws -> JSONValue {
    do { return try JSONDecoder().decode(JSONValue.self, from: data) } catch {
      throw fail("Antwort ist kein gültiges JSON")
    }
  }

  private static func fail(_ reason: String) -> TimetableSourceError { .unexpectedResponse(reason) }

  private static func names(_ node: JSONValue?) -> [String] {
    guard case .array(let items)? = node else { return [] }
    return items.compactMap { item in
      guard case .string(let name)? = item[["name"]], !name.isEmpty else { return nil }
      return name
    }
  }

  private static func bool(_ node: JSONValue?) -> Bool {
    if case .bool(let value)? = node { return value }
    return false
  }

  /// Text oder ganze Zahl als Text (IDs kommen je nach Konto als Zahl oder Text).
  private static func text(_ node: JSONValue) -> String? {
    switch node {
    case .string(let value): return value.isEmpty ? nil : value
    case .number(let value):
      return value == value.rounded() && abs(value) < 1e15 ? String(Int(value)) : nil
    default: return nil
    }
  }

  /// Zahl oder Text mit ganzer Zahl (B5: `classHour.number` kann beides sein).
  private static func integer(_ node: JSONValue) -> Int? {
    switch node {
    case .number(let value): return value == value.rounded() && abs(value) < 1e9 ? Int(value) : nil
    case .string(let value): return Int(value.trimmingCharacters(in: .whitespaces))
    default: return nil
    }
  }

  private static func timeText(_ node: JSONValue) -> String? {
    if case .string(let value) = node { return value }
    return nil
  }

  /// `HH:MM:SS` oder `HH:MM`; Sekunden werden abgeschnitten.
  private static func time(_ text: String) -> TimeOfDay? {
    let parts = text.split(separator: ":", omittingEmptySubsequences: false)
    guard parts.count == 2 || parts.count == 3,
      parts.allSatisfy({ $0.count == 2 && $0.allSatisfy { $0.isASCII && $0.isNumber } }),
      let hour = Int(parts[0]), let minute = Int(parts[1]),
      (0...23).contains(hour), (0...59).contains(minute)
    else { return nil }
    if parts.count == 3 {
      guard let second = Int(parts[2]), (0...59).contains(second) else { return nil }
    }
    return TimeOfDay(hour: hour, minute: minute)
  }
}
