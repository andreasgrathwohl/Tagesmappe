import Foundation
import FrontstageCore
import Observation

/// Logik eines geöffneten Jahresplans (FR-15.2 bis FR-15.4): Wochenraster, Jahresnotiz, Zuweisen
/// nicht zugeordneter Einträge, frühere Jahre und Übernahme des Vorjahresplans.
///
/// Swift-Hinweis: `@Observable` ersetzt `ObservableObject`; die Ansicht liest die Eigenschaften
/// direkt. Das Modell hält nur Werte; jede Änderung lädt `layout` neu.
@MainActor @Observable final class CoursePlanEditorModel {
  private let planID: UUID
  private let store: any CoursePlanStore

  private(set) var key: CoursePlanKey?
  /// `nil`, solange nicht geladen (oder der Plan fehlt).
  private(set) var layout: PlanLayout?
  /// Klassen, für die der Plan gilt („gilt für 8a, 8b“).
  private(set) var followingClasses: [SchoolClass] = []
  /// Jahresnotiz; die Ansicht schreibt hinein, `saveNotes()` speichert.
  var notes: String = ""
  /// Zuletzt gelesener gespeicherter Stand der Jahresnotiz. Weicht `notes` davon ab, tippt die
  /// Lehrkraft gerade: `reload()` überschreibt den Entwurf dann nicht.
  private var savedNotes: String = ""
  /// Frühere Jahre desselben Fachs und Jahrgangs, neuestes zuerst.
  private(set) var earlierPlans: [CoursePlanSummary] = []
  /// Schlüssel einer Meldung (`Localizable.xcstrings`), z. B. `coursePlan.copy.done %lld`.
  private(set) var noticeKey: String?
  private(set) var noticeArgument: Int?

  /// Für die Eingabe der Zeit in Sheets; Tests setzen eine feste Uhr.
  private let now: @MainActor () -> Date

  init(planID: UUID, store: any CoursePlanStore, now: @escaping @MainActor () -> Date = { Date() }) {
    self.planID = planID
    self.store = store
    self.now = now
    reload()
  }

  /// Liest den Stand neu (auch nach Änderungen vom anderen Gerät).
  func reload() {
    guard let content = try? store.coursePlan(id: planID) else {
      key = nil
      layout = nil
      return
    }
    key = content.key
    let stored = content.notes ?? ""
    // Ungespeicherte Eingabe nicht verwerfen (ein Neuladen kommt z. B. vom Ordnerabgleich, während das
    // Feld den Fokus hat). Ohne eigene Änderung gilt der gespeicherte Stand, auch vom anderen Gerät.
    if notes == savedNotes { notes = stored }
    savedNotes = stored
    let weeks = (try? store.teachingWeeks(startYear: content.key.startYear)) ?? []
    layout = PlanLayouter.layout(
      weeks: weeks, planWeeks: content.planWeeks, assessments: content.assessments)
    followingClasses = (try? store.classes(following: content.key)) ?? []
    let summaries = (try? store.coursePlanSummaries()) ?? []
    let earlierKeys = CoursePlanHistory.earlier(than: content.key, among: summaries.map(\.key))
    earlierPlans = earlierKeys.compactMap { earlier in
      summaries.first { $0.key == earlier }
    }
  }

  /// Speichert die Jahresnotiz; leer (nach Trimmen) löscht sie. Ohne Änderung wird nichts
  /// geschrieben (kein unnötiges Neuladen aller Ansichten, kein Speichern).
  func saveNotes() {
    let trimmed = notes.trimmingCharacters(in: .whitespacesAndNewlines)
    guard trimmed != savedNotes else {
      // Nur Leerraum geändert: Feld auf den gespeicherten Stand zurücksetzen.
      notes = savedNotes
      return
    }
    do {
      try store.setPlanNote(trimmed.isEmpty ? nil : trimmed, planID: planID)
      // Gespeichert: Feld und gespeicherter Stand stimmen überein, `reload()` übernimmt künftig wieder.
      notes = trimmed
      savedNotes = trimmed
    } catch {
      noticeKey = "coursePlan.error.save"
      noticeArgument = nil
    }
    reload()
  }

  /// Sheet für eine Unterrichtswoche (mit oder ohne vorhandene Planwoche).
  func editor(for week: TeachingWeek) -> PlanWeekEditor {
    let entries = (layout?.first ?? []) + (layout?.second ?? [])
    let entry = entries.first { $0.week == week }
    return PlanWeekEditor(
      planID: planID, store: store, week: week, planWeek: entry?.planWeek,
      assessments: entry?.assessments ?? [], now: now, onChange: { [weak self] in self?.reload() })
  }

  /// Sheet für eine nicht zugeordnete Planwoche; ihre Leistungsnachweise sind die mit gleichem Montag.
  /// Ohne Montag lassen sich keine Leistungsnachweise eintragen (`canAddAssessments`).
  func editor(forUnassigned week: PlanWeek) -> PlanWeekEditor {
    let related = (layout?.unassignedAssessments ?? []).filter {
      week.monday != nil && $0.monday == week.monday
    }
    return PlanWeekEditor(
      planID: planID, store: store, week: nil, planWeek: week, assessments: related, now: now,
      onChange: { [weak self] in self?.reload() })
  }

  /// Ziele für „Zuweisen“: Unterrichtswochen ohne Planwoche, in Reihenfolge des Schuljahrs.
  func emptyWeeks() -> [TeachingWeek] {
    guard let layout else { return [] }
    return (layout.first + layout.second).filter { $0.planWeek == nil }.map(\.week)
  }

  func assign(planWeekID: UUID, to week: TeachingWeek) {
    clearNotice()
    do {
      try store.assignPlanWeek(id: planWeekID, to: week.monday)
    } catch CoursePlanError.weekOccupied {
      noticeKey = "coursePlan.error.weekOccupied"
    } catch {
      noticeKey = "coursePlan.error.save"
    }
    reload()
  }

  func assign(assessmentID: UUID, to week: TeachingWeek) {
    clearNotice()
    do {
      try store.assignAssessment(id: assessmentID, to: week)
    } catch {
      noticeKey = "coursePlan.error.save"
    }
    reload()
  }

  /// Übernimmt den Plan eines früheren Jahres (FR-15.4); die Meldung nennt die Zahl der Einträge ohne Woche.
  func copy(from sourceID: UUID) {
    clearNotice()
    do {
      let result = try store.copyCoursePlan(from: sourceID, to: planID)
      noticeKey = "coursePlan.copy.done %lld"
      noticeArgument = result.unassignedCount
    } catch {
      noticeKey = "coursePlan.error.copy"
    }
    reload()
  }

  private func clearNotice() {
    noticeKey = nil
    noticeArgument = nil
  }
}
