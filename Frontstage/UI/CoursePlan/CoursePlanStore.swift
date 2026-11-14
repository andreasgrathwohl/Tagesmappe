import Foundation
import FrontstageCore

/// Fehler der Jahresplanung, die die Oberfläche anzeigen kann.
enum CoursePlanError: Error, Equatable {
  /// Das Schuljahr ist in sich oder gegenüber den anderen Schuljahren ungültig.
  case invalidSchoolYear(SchoolYearIssue)
  /// Für dieses Startjahr gibt es kein Schuljahr.
  case schoolYearMissing(startYear: Int)
  /// Es gibt keinen Jahresplan oder keine Planwoche mit dieser id.
  case planMissing(UUID)
  /// Die Zielwoche hat schon eine nicht leere Planwoche.
  case weekOccupied
  /// Der Tag ist kein Unterrichtstag der Woche des Leistungsnachweises.
  case dayNotInWeek
}

/// Ein Jahresplan mit Inhalt, als Werte für die Oberfläche (kein SwiftData-Objekt).
struct CoursePlanContent: Hashable, Sendable {
  let id: UUID
  let key: CoursePlanKey
  var notes: String?
  var planWeeks: [PlanWeek]
  var assessments: [Assessment]
}

/// Ein Jahresplan für die Liste.
struct CoursePlanSummary: Identifiable, Hashable, Sendable {
  let id: UUID
  let key: CoursePlanKey
}

/// Schnittstelle der Jahresplanung zwischen Oberfläche und Datenhaltung. Die Oberfläche sieht nur
/// Werte; so lässt sie sich mit einem Fake testen.
@MainActor protocol CoursePlanStore: AnyObject {
  var revision: Int { get }
  /// Nach `startYear` aufsteigend.
  func schoolYears() throws -> [SchoolYear]
  /// Fügt nach `startYear` ein oder ersetzt; Prüfung ergibt `invalidSchoolYear`.
  func saveSchoolYear(_ year: SchoolYear) throws
  /// Die Jahrespläne bleiben stehen.
  func removeSchoolYear(startYear: Int) throws
  func setGradeOverride(_ grade: GradeLevel?, for schoolClass: SchoolClass, startYear: Int) throws
  /// Klassen des aktiven Stundenplans, sortiert.
  func timetableClasses() throws -> [SchoolClass]
  func timetableSubjects() throws -> [Subject]
  /// Leer ohne Schuljahr.
  func teachingWeeks(startYear: Int) throws -> [TeachingWeek]
  /// Nach `startYear` absteigend, dann Fach, dann Jahrgang.
  func coursePlanSummaries() throws -> [CoursePlanSummary]
  func coursePlan(id: UUID) throws -> CoursePlanContent?
  /// Gibt es den Schlüssel schon, kommt dessen id zurück.
  func createCoursePlan(_ key: CoursePlanKey) throws -> UUID
  func setPlanNote(_ notes: String?, planID: UUID) throws
  /// Fügt nach `id` ein oder ersetzt; eine leere Planwoche wird gelöscht.
  func savePlanWeek(_ week: PlanWeek, planID: UUID) throws
  /// Zielwoche mit nicht leerer Planwoche ergibt `weekOccupied`.
  func assignPlanWeek(id: UUID, to monday: CalendarDay) throws
  /// `day` muss Unterrichtstag der Woche sein, sonst `dayNotInWeek`.
  func saveAssessment(_ assessment: Assessment, planID: UUID) throws
  func removeAssessment(id: UUID) throws
  func assignAssessment(id: UUID, to week: TeachingWeek) throws
  /// Quell- und Zielwochen kommen aus den Schuljahren; fehlt eins, ergibt das `schoolYearMissing`.
  func copyCoursePlan(from sourceID: UUID, to targetID: UUID) throws -> CopyResult
  /// Klassen des Stundenplans mit diesem Fach und Jahrgang („gilt für 8a, 8b“).
  func classes(following key: CoursePlanKey) throws -> [SchoolClass]
}

extension DataStore: CoursePlanStore {}
