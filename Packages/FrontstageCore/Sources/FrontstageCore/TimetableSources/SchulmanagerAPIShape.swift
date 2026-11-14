import Foundation

/// Pfade, Schlüssel und Aufrufnamen der inoffiziellen Schulmanager-Online-Schnittstelle
/// (FR-13.1: inoffiziell, ohne Gewähr). Eigener Typ, damit Tests eine eigene Form übergeben können
/// und eine Änderung der Schnittstelle an genau einer Stelle nachgezogen wird.
public struct SchulmanagerAPIShape: Sendable {
  /// Einziger Fremd-Host (NFR-2).
  public var host: String
  public var saltPath: String
  public var loginPath: String
  public var callsPath: String
  /// Pfad zum Objekt der Lehrkraft in der Login-Antwort.
  public var teacherObjectPath: [String]
  /// Pfad zur ID der Lehrkraft, relativ zum Lehrer-Objekt.
  public var teacherIDPath: [String]
  public var lessonsModule: String
  public var lessonsEndpoint: String
  /// Schlüssel in `parameters`, der die Lehrkraft trägt.
  public var teacherParameterKey: String
  /// `true`: das ganze Lehrer-Objekt wird übergeben, sonst nur die ID.
  public var passesWholeTeacherObject: Bool
  public var classHoursModule: String
  public var classHoursEndpoint: String
  public var classHoursParameters: [String: JSONValue]
  /// `nil`: das Feld `bundleVersion` wird weggelassen.
  public var bundleVersion: String?

  public init(
    host: String, saltPath: String, loginPath: String, callsPath: String,
    teacherObjectPath: [String], teacherIDPath: [String],
    lessonsModule: String, lessonsEndpoint: String,
    teacherParameterKey: String, passesWholeTeacherObject: Bool,
    classHoursModule: String, classHoursEndpoint: String,
    classHoursParameters: [String: JSONValue], bundleVersion: String?
  ) {
    self.host = host
    self.saltPath = saltPath
    self.loginPath = loginPath
    self.callsPath = callsPath
    self.teacherObjectPath = teacherObjectPath
    self.teacherIDPath = teacherIDPath
    self.lessonsModule = lessonsModule
    self.lessonsEndpoint = lessonsEndpoint
    self.teacherParameterKey = teacherParameterKey
    self.passesWholeTeacherObject = passesWholeTeacherObject
    self.classHoursModule = classHoursModule
    self.classHoursEndpoint = classHoursEndpoint
    self.classHoursParameters = classHoursParameters
    self.bundleVersion = bundleVersion
  }

  /// Vorläufige Werte. Die Prüfung mit einem echten Lehrerkonto (Q-16, Aufgabe 1) steht aus: Was für
  /// Eltern- und Schülerkonten dokumentiert ist, gilt hier als Annahme; Lehrer-spezifische Werte
  /// (B1–B4, B8, B10) sind Platzhalter und müssen nach dem Prüfschritt ersetzt werden.
  /// Quellen: rwunsch/schulmanager-online-hass (MIT), `const.py`, `api.py`,
  /// `documentation/Schedules_API_Documentation.md`.
  public static let recorded = SchulmanagerAPIShape(
    host: "login.schulmanager-online.de",  // belegt (const.py)
    saltPath: "/api/get-salt",  // belegt in const.py; Authentication_Guide nennt /api/salt (B9 offen)
    loginPath: "/api/login",  // belegt
    callsPath: "/api/calls",  // belegt
    teacherObjectPath: ["user", "associatedTeacher"],  // unbelegt, Q-16 offen (B1)
    teacherIDPath: ["id"],  // unbelegt, Q-16 offen (B2)
    lessonsModule: "schedules",  // belegt für Schüler; Lehrer unbelegt (B3)
    lessonsEndpoint: "get-actual-lessons",  // belegt für Schüler; Lehrer unbelegt (B3)
    teacherParameterKey: "teacher",  // unbelegt, Q-16 offen (B4); bei Schülern "student"
    passesWholeTeacherObject: true,  // unbelegt, Q-16 offen (B4); bei Schülern das ganze Objekt
    classHoursModule: "schedules",  // belegt für Schüler (B8)
    classHoursEndpoint: "get-class-hours",  // belegt für Schüler (B8)
    classHoursParameters: [:],  // unbelegt, Q-16 offen (B8); bei Schülern {"classId": …}
    bundleVersion: nil  // unbelegt, Q-16 offen (B10)
  )
}
