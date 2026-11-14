import Foundation
import FrontstageCore
import Observation

/// Bearbeiten einer Planwoche samt ihrer Leistungsnachweise (Sheet, FR-15.2).
///
/// Hält nur Werte; jede Änderung geht über den `CoursePlanStore` und meldet sich danach über
/// `onChange`, damit das Elternmodell sein `layout` neu lädt.
@MainActor @Observable final class PlanWeekEditor {
  /// Die Unterrichtswoche; `nil` bei einer nicht zugeordneten Planwoche.
  let week: TeachingWeek?
  var topic: String
  var notes: String
  private(set) var assessments: [Assessment]
  /// Schlüssel einer Fehlermeldung (`Localizable.xcstrings`); `nil` ohne Meldung.
  private(set) var errorKey: String?

  private let planID: UUID
  private let store: any CoursePlanStore
  /// Montag der Woche, auch bei einer nicht zugeordneten Planwoche mit Montag ohne Unterrichtswoche.
  private let monday: CalendarDay?
  private var planWeek: PlanWeek?
  /// Kennungen der Leistungsnachweise dieses Sheets. Bei einer Planwoche ohne Montag lassen sie sich
  /// nicht über den Montag finden, daher merkt sich der Editor die eigenen.
  private var assessmentIDs: Set<UUID>
  private let now: @MainActor () -> Date
  private let onChange: @MainActor () -> Void

  init(
    planID: UUID, store: any CoursePlanStore, week: TeachingWeek?, planWeek: PlanWeek?,
    assessments: [Assessment], now: @escaping @MainActor () -> Date = { Date() },
    onChange: @escaping @MainActor () -> Void = {}
  ) {
    self.planID = planID
    self.store = store
    self.week = week
    self.monday = week?.monday ?? planWeek?.monday
    self.planWeek = planWeek
    self.topic = planWeek?.topic ?? ""
    self.notes = planWeek?.notes ?? ""
    self.assessments = assessments
    self.assessmentIDs = Set(assessments.map(\.id))
    self.now = now
    self.onChange = onChange
  }

  /// Tage, an denen ein Leistungsnachweis stehen kann (leer bei nicht zugeordneter Woche).
  var selectableDays: [CalendarDay] { week?.teachingDays ?? [] }

  /// Thema und Notizen speichern; sind beide leer, löscht der Store die Planwoche.
  ///
  /// Unverändert (nach Trimmen) wird nichts geschrieben: Ein Speichern ohne Änderung bekäme einen neuen
  /// Zeitstempel und gewänne im Abgleich (letzter Schreiber gewinnt) gegen eine echte Änderung vom
  /// anderen Gerät – oder schriebe ein inzwischen veraltetes Thema zurück.
  func save() {
    errorKey = nil
    let saved = PlanWeek(
      id: planWeek?.id ?? UUID(), monday: monday, position: planWeek?.position ?? week?.number ?? 0,
      topic: topic, notes: notes, updatedAt: now())
    // `PlanWeek` normalisiert Thema und Notizen; ohne Planwoche sind beide `nil`.
    guard saved.topic != planWeek?.topic || saved.notes != planWeek?.notes else { return }
    do {
      try store.savePlanWeek(saved, planID: planID)
      // Nach dem Löschen einer leeren Woche beginnt ein späteres Speichern wieder mit neuer id.
      planWeek = saved.isEmpty ? nil : saved
      onChange()
    } catch {
      errorKey = "coursePlan.error.save"
    }
  }

  /// Legt einen Leistungsnachweis an. Ein Tag, der kein Unterrichtstag der Woche ist, entfällt.
  ///
  /// Gibt es in diesem Sheet schon einen gleichen Leistungsnachweis ohne Titel (gleiche Art, gleicher Tag),
  /// entsteht kein zweiter: Beide hätten denselben fachlichen Schlüssel, und das Zusammenführen
  /// (`CoursePlanMerger`) löschte einen davon wieder – ein Platzhalter verschwände unerwartet.
  func addAssessment(kind: AssessmentKind, title: String, day: CalendarDay?) {
    let validDay = day.flatMap { selectableDays.contains($0) ? $0 : nil }
    if Self.isBlank(title),
      assessments.contains(where: { $0.kind == kind && $0.day == validDay && Self.isBlank($0.title) })
    {
      return
    }
    let assessment = Assessment(
      id: UUID(), monday: monday, day: validDay, kind: kind, title: title, updatedAt: now())
    persist(assessment)
  }

  func updateAssessment(_ assessment: Assessment) {
    var updated = assessment
    updated.updatedAt = now()
    if let day = updated.day, !selectableDays.contains(day) { updated.day = nil }
    persist(updated)
  }

  func removeAssessment(id: UUID) {
    errorKey = nil
    do {
      try store.removeAssessment(id: id)
      refreshAssessments()
      onChange()
    } catch {
      errorKey = "coursePlan.error.save"
    }
  }

  private func persist(_ assessment: Assessment) {
    errorKey = nil
    do {
      try store.saveAssessment(assessment, planID: planID)
      assessmentIDs.insert(assessment.id)
      refreshAssessments()
      onChange()
    } catch {
      errorKey = "coursePlan.error.save"
    }
  }

  /// Liest die Leistungsnachweise dieser Woche aus dem Store; Reihenfolge wie im Layout.
  /// Ohne Montag gelten die in diesem Sheet bekannten Kennungen.
  private func refreshAssessments() {
    guard let content = try? store.coursePlan(id: planID) else { return }
    let ids = assessmentIDs
    let mine = content.assessments.filter { assessment in
      if let monday { return assessment.monday == monday }
      return ids.contains(assessment.id)
    }
    assessments = mine.sorted { lhs, rhs in
      switch (lhs.day, rhs.day) {
      case let (l?, r?) where l != r: return l < r
      case (_?, nil): return true
      case (nil, _?): return false
      default: break
      }
      if lhs.title != rhs.title { return lhs.title < rhs.title }
      return lhs.id.uuidString < rhs.id.uuidString
    }
  }

  private static func isBlank(_ text: String) -> Bool {
    text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
  }
}
