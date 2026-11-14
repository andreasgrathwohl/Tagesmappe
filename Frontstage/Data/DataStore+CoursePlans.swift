import Foundation
import FrontstageCore
import SwiftData

/// Schuljahre und Jahrespläne (FR-15). Nach außen gehen nur Werte, nie SwiftData-Objekte.
///
/// Swift-Hinweis: Wie in den übrigen `DataStore`-Erweiterungen wird vollständig geladen und im
/// Speicher gefiltert (kleine Mengen). Jede Schreibmethode speichert genau einmal über `saveAndBump()`.
extension DataStore {
  // MARK: - Schuljahre (FR-15.1)

  func schoolYears() throws -> [SchoolYear] {
    try schoolYearRecordsByStartYear().map { $0.year }
  }

  func saveSchoolYear(_ year: SchoolYear) throws {
    if let issue = year.issue(among: try schoolYears()) {
      throw CoursePlanError.invalidSchoolYear(issue)
    }
    let record: SchoolYearRecord
    if let existing = try schoolYearRecordsByStartYear().first(where: { $0.year.startYear == year.startYear })?
      .record
    {
      record = existing
    } else {
      record = SchoolYearRecord()
      modelContext.insert(record)
    }
    record.apply(year)
    try saveAndBump()
  }

  func removeSchoolYear(startYear: Int) throws {
    let matches = try allSchoolYearRecords().filter { $0.makeSchoolYear()?.startYear == startYear }
    guard !matches.isEmpty else { return }
    for record in matches { modelContext.delete(record) }
    try saveAndBump()
  }

  func setGradeOverride(_ grade: GradeLevel?, for schoolClass: SchoolClass, startYear: Int) throws {
    guard
      let entry = try schoolYearRecordsByStartYear().first(where: { $0.year.startYear == startYear })
    else { throw CoursePlanError.schoolYearMissing(startYear: startYear) }
    var year = entry.year
    if let grade {
      year.gradeOverrides[schoolClass.normalized] = grade.value
    } else {
      year.gradeOverrides.removeValue(forKey: schoolClass.normalized)
    }
    entry.record.apply(year)
    try saveAndBump()
  }

  // MARK: - Stundenplan als Auswahl

  func timetableClasses() throws -> [SchoolClass] {
    guard let timetable = try timetable() else { return [] }
    return Set(timetable.entries.map(\.schoolClass)).sorted { $0.normalized < $1.normalized }
  }

  func timetableSubjects() throws -> [Subject] {
    guard let timetable = try timetable() else { return [] }
    return Set(timetable.entries.map(\.subject)).sorted { $0.normalized < $1.normalized }
  }

  func teachingWeeks(startYear: Int) throws -> [TeachingWeek] {
    guard let year = try schoolYears().first(where: { $0.startYear == startYear }) else { return [] }
    return TeachingWeekCalculator.weeks(of: year, nonTeachingPeriods: try nonTeachingPeriods())
  }

  // MARK: - Jahrespläne lesen

  func coursePlanSummaries() throws -> [CoursePlanSummary] {
    try allCoursePlanRecords().compactMap { record in
      record.key.map { CoursePlanSummary(id: record.id, key: $0) }
    }
    .sorted { lhs, rhs in
      if lhs.key.startYear != rhs.key.startYear { return lhs.key.startYear > rhs.key.startYear }
      if lhs.key.subject.normalized != rhs.key.subject.normalized {
        return lhs.key.subject.normalized < rhs.key.subject.normalized
      }
      if lhs.key.gradeLevel != rhs.key.gradeLevel { return lhs.key.gradeLevel < rhs.key.gradeLevel }
      return lhs.id.uuidString < rhs.id.uuidString
    }
  }

  func coursePlan(id: UUID) throws -> CoursePlanContent? {
    guard let record = try coursePlanRecord(id: id) else { return nil }
    return content(of: record)  // nil bei unlesbarem Schlüssel (Jahrgang außerhalb 1...13)
  }

  // MARK: - Jahrespläne schreiben

  func createCoursePlan(_ key: CoursePlanKey) throws -> UUID {
    // Vor dem Zusammenführen kann es zwei Pläne mit gleichem Schlüssel geben; der älteste gilt.
    if let existing = try allCoursePlanRecords().first(where: { $0.key == key }) {
      return existing.id
    }
    let record = CoursePlanRecord()
    modelContext.insert(record)
    record.subjectText = key.subject.display
    record.gradeLevel = key.gradeLevel.value
    record.startYear = key.startYear
    try saveAndBump()
    return record.id
  }

  func setPlanNote(_ notes: String?, planID: UUID) throws {
    let plan = try requireCoursePlanRecord(planID)
    let trimmed = notes?.trimmingCharacters(in: .whitespacesAndNewlines)
    plan.notes = (trimmed?.isEmpty ?? true) ? nil : trimmed
    try saveAndBump()
  }

  func savePlanWeek(_ week: PlanWeek, planID: UUID) throws {
    let plan = try requireCoursePlanRecord(planID)
    let existing = (plan.planWeeks ?? []).first { $0.id == week.id }
    if week.isEmpty {
      // Leere Planwochen werden nicht gespeichert (RISK-10).
      guard let existing else { return }
      modelContext.delete(existing)
      try saveAndBump()
      return
    }
    var stamped = week
    stamped.updatedAt = .now
    if let existing {
      existing.apply(stamped)
    } else {
      let record = PlanWeekRecord()
      modelContext.insert(record)
      record.id = week.id
      record.coursePlan = plan
      record.apply(stamped)
    }
    try saveAndBump()
  }

  func assignPlanWeek(id: UUID, to monday: CalendarDay) throws {
    guard let record = try planWeekRecord(id: id), let plan = record.coursePlan else {
      throw CoursePlanError.planMissing(id)
    }
    let occupied = (plan.planWeeks ?? []).contains { other in
      let week = other.makePlanWeek()
      return other.id != id && week.monday == monday && !week.isEmpty
    }
    if occupied { throw CoursePlanError.weekOccupied }
    var week = record.makePlanWeek()
    week.monday = monday
    week.updatedAt = .now
    record.apply(week)
    try saveAndBump()
  }

  func saveAssessment(_ assessment: Assessment, planID: UUID) throws {
    let plan = try requireCoursePlanRecord(planID)
    if let day = assessment.day {
      // Ein Tag braucht eine bekannte Unterrichtswoche, in der er Unterrichtstag ist.
      guard let monday = assessment.monday,
        let week = try teachingWeeks(startYear: plan.startYear).first(where: { $0.monday == monday }),
        PlanLayouter.isValidDay(day, for: week)
      else { throw CoursePlanError.dayNotInWeek }
    }
    var stamped = assessment
    stamped.updatedAt = .now
    if let existing = try assessmentRecord(id: assessment.id) {
      existing.apply(stamped)
    } else {
      let record = AssessmentRecord()
      modelContext.insert(record)
      record.id = assessment.id
      record.coursePlan = plan
      record.apply(stamped)
    }
    try saveAndBump()
  }

  func removeAssessment(id: UUID) throws {
    guard let record = try assessmentRecord(id: id) else { return }
    modelContext.delete(record)
    try saveAndBump()
  }

  func assignAssessment(id: UUID, to week: TeachingWeek) throws {
    guard let record = try assessmentRecord(id: id), let assessment = record.makeAssessment() else {
      return
    }
    var assigned = PlanLayouter.assign(assessment, to: week)
    assigned.updatedAt = .now
    record.apply(assigned)
    try saveAndBump()
  }

  func copyCoursePlan(from sourceID: UUID, to targetID: UUID) throws -> CopyResult {
    let sourceRecord = try requireCoursePlanRecord(sourceID)
    let targetRecord = try requireCoursePlanRecord(targetID)
    guard let source = content(of: sourceRecord) else { throw CoursePlanError.planMissing(sourceID) }
    guard let target = content(of: targetRecord) else { throw CoursePlanError.planMissing(targetID) }
    // Beide Schuljahre müssen da sein; sonst gäbe es keine Wochen zum Ausrichten.
    let years = try schoolYears()
    for startYear in [source.key.startYear, target.key.startYear]
    where !years.contains(where: { $0.startYear == startYear }) {
      throw CoursePlanError.schoolYearMissing(startYear: startYear)
    }
    let nextPosition = (target.planWeeks.map(\.position).max() ?? -1) + 1
    let now = Date.now
    let result = CoursePlanCopier.copy(
      sourceWeeks: try teachingWeeks(startYear: source.key.startYear),
      sourcePlanWeeks: source.planWeeks, sourceAssessments: source.assessments,
      sourceNote: source.notes,
      targetWeeks: try teachingWeeks(startYear: target.key.startYear),
      targetPlanWeeks: target.planWeeks, targetAssessments: target.assessments,
      targetNote: target.notes,
      nextUnassignedPosition: nextPosition, now: now, makeID: { UUID() })

    for week in result.planWeeks {
      let record = PlanWeekRecord()
      modelContext.insert(record)
      record.id = week.id
      record.coursePlan = targetRecord
      record.apply(week)
    }
    for assessment in result.assessments {
      let record = AssessmentRecord()
      modelContext.insert(record)
      record.id = assessment.id
      record.coursePlan = targetRecord
      record.apply(assessment)
    }
    if let note = result.planNote { targetRecord.notes = note }
    try saveAndBump()
    return result
  }

  func classes(following key: CoursePlanKey) throws -> [SchoolClass] {
    guard let timetable = try timetable() else { return [] }
    let overrides =
      try schoolYears().first(where: { $0.startYear == key.startYear })?.gradeOverrides ?? [:]
    let matching = timetable.entries.filter { $0.subject == key.subject }.map(\.schoolClass)
    return Set(matching)
      .filter { GradeLevel.resolve($0, overrides: overrides) == key.gradeLevel }
      .sorted { $0.normalized < $1.normalized }
  }

  // MARK: - Hinweise für Vorbereiten und Tagesansicht (FR-15.5, FR-15.6)

  func lessonPlanHint(for lesson: Lesson) throws -> LessonPlanHint? {
    LessonPlanHinter.hint(
      for: lesson, schoolYears: try schoolYears(), plans: try coursePlanSnapshotEntries())
  }

  func plannedAssessments(inWeekOf monday: CalendarDay) throws -> [PlannedAssessment] {
    LessonPlanHinter.assessments(inWeekOf: monday, plans: try coursePlanSnapshotEntries())
  }

  // MARK: - Hilfen

  /// Alle lesbaren Jahrespläne mit Inhalt, als Eingabe der Hinweisrechnung.
  private func coursePlanSnapshotEntries() throws -> [CoursePlanSnapshotEntry] {
    try allCoursePlanRecords().compactMap { record in
      guard let plan = content(of: record) else { return nil }
      return CoursePlanSnapshotEntry(
        id: plan.id, key: plan.key, planWeeks: plan.planWeeks, assessments: plan.assessments)
    }
  }

  /// Der Datensatz als Wert; unlesbare Planwochen und Leistungsnachweise entfallen. `nil`, wenn der
  /// Schlüssel nicht lesbar ist.
  private func content(of record: CoursePlanRecord) -> CoursePlanContent? {
    guard let key = record.key else { return nil }
    let weeks = (record.planWeeks ?? []).map { $0.makePlanWeek() }
      .sorted { ($0.position, $0.id.uuidString) < ($1.position, $1.id.uuidString) }
    let assessments = (record.assessments ?? [])
      .sorted { ($0.createdAt, $0.id.uuidString) < ($1.createdAt, $1.id.uuidString) }
      .compactMap { $0.makeAssessment() }
    return CoursePlanContent(
      id: record.id, key: key, notes: record.notes, planWeeks: weeks, assessments: assessments)
  }

  /// Älteste zuerst, damit bei doppeltem Schlüssel (vor dem Zusammenführen) der älteste gilt.
  private func allCoursePlanRecords() throws -> [CoursePlanRecord] {
    try modelContext.fetch(FetchDescriptor<CoursePlanRecord>())
      .sorted { ($0.createdAt, $0.id.uuidString) < ($1.createdAt, $1.id.uuidString) }
  }

  private func coursePlanRecord(id: UUID) throws -> CoursePlanRecord? {
    try modelContext.fetch(FetchDescriptor<CoursePlanRecord>()).first { $0.id == id }
  }

  private func requireCoursePlanRecord(_ id: UUID) throws -> CoursePlanRecord {
    guard let record = try coursePlanRecord(id: id) else { throw CoursePlanError.planMissing(id) }
    return record
  }

  private func planWeekRecord(id: UUID) throws -> PlanWeekRecord? {
    try modelContext.fetch(FetchDescriptor<PlanWeekRecord>()).first { $0.id == id }
  }

  private func assessmentRecord(id: UUID) throws -> AssessmentRecord? {
    try modelContext.fetch(FetchDescriptor<AssessmentRecord>()).first { $0.id == id }
  }

  private func allSchoolYearRecords() throws -> [SchoolYearRecord] {
    try modelContext.fetch(FetchDescriptor<SchoolYearRecord>())
      .sorted { ($0.createdAt, $0.id.uuidString) < ($1.createdAt, $1.id.uuidString) }
  }

  /// Lesbare Schuljahre nach `startYear` aufsteigend; bei doppeltem Startjahr (vor dem
  /// Zusammenführen) zählt der älteste Datensatz.
  private func schoolYearRecordsByStartYear() throws -> [(year: SchoolYear, record: SchoolYearRecord)] {
    var seen = Set<Int>()
    var result: [(year: SchoolYear, record: SchoolYearRecord)] = []
    for record in try allSchoolYearRecords() {
      guard let year = record.makeSchoolYear(), seen.insert(year.startYear).inserted else { continue }
      result.append((year, record))
    }
    return result.sorted { $0.year.startYear < $1.year.startYear }
  }
}
