import Foundation

/// Ein Jahresplan mit seinen Einträgen, wie ihn die Hinweisrechnung braucht.
public struct CoursePlanSnapshotEntry: Sendable {
  public let id: UUID
  public let key: CoursePlanKey
  public let planWeeks: [PlanWeek]
  public let assessments: [Assessment]

  public init(id: UUID, key: CoursePlanKey, planWeeks: [PlanWeek], assessments: [Assessment]) {
    self.id = id
    self.key = key
    self.planWeeks = planWeeks
    self.assessments = assessments
  }
}

/// Wann ein Leistungsnachweis stattfindet, bezogen auf die Stunde.
public enum AssessmentTiming: Hashable, Sendable {
  /// Am Tag der Stunde.
  case onDay
  /// Irgendwann in dieser Woche (ohne festen Tag).
  case thisWeek
}

public struct AssessmentMarker: Hashable, Sendable {
  public let assessment: Assessment
  public let timing: AssessmentTiming

  public init(assessment: Assessment, timing: AssessmentTiming) {
    self.assessment = assessment
    self.timing = timing
  }
}

public struct LessonPlanHint: Hashable, Sendable {
  public let coursePlanID: UUID
  public let plannedTopic: String?
  /// `onDay` vor `thisWeek`.
  public let markers: [AssessmentMarker]

  public init(coursePlanID: UUID, plannedTopic: String?, markers: [AssessmentMarker]) {
    self.coursePlanID = coursePlanID
    self.plannedTopic = plannedTopic
    self.markers = markers
  }
}

/// Leistungsnachweis einer Woche samt Plan, für die Wochenansicht in Vorbereiten.
public struct PlannedAssessment: Hashable, Sendable {
  public let key: CoursePlanKey
  public let assessment: Assessment

  public init(key: CoursePlanKey, assessment: Assessment) {
    self.key = key
    self.assessment = assessment
  }
}

/// Leitet aus den Jahresplänen den Hinweis zu einer Unterrichtsstunde ab (FR-15.5, FR-15.6).
public enum LessonPlanHinter {
  /// nil: Ausfall, kein Schuljahr für das Datum, kein Jahrgang, kein Plan – oder weder Thema
  /// noch Leistungsnachweis.
  public static func hint(
    for lesson: Lesson, schoolYears: [SchoolYear], plans: [CoursePlanSnapshotEntry]
  ) -> LessonPlanHint? {
    guard !lesson.isCancelled else { return nil }
    let date = lesson.key.date
    guard let year = schoolYears.first(where: { $0.contains(date) }),
      let grade = GradeLevel.resolve(lesson.key.schoolClass, overrides: year.gradeOverrides)
    else { return nil }
    let key = CoursePlanKey(
      subject: lesson.key.subject, gradeLevel: grade, startYear: year.startYear)
    // Bei doppeltem Schlüssel (vor dem Zusammenführen) gilt der Plan mit der kleineren id.
    guard
      let plan = plans.filter({ $0.key == key })
        .min(by: { $0.id.uuidString < $1.id.uuidString })
    else { return nil }

    let monday = date.mondayOfWeek
    // Bei mehreren Planwochen mit diesem Montag gewinnt die zuletzt geänderte.
    let planWeek = plan.planWeeks.filter { $0.monday == monday }
      .max(by: { $0.updatedAt < $1.updatedAt })
    let topic = planWeek?.topic

    var onDay: [AssessmentMarker] = []
    var thisWeek: [AssessmentMarker] = []
    for assessment in plan.assessments where assessment.monday == monday {
      if assessment.day == date {
        onDay.append(AssessmentMarker(assessment: assessment, timing: .onDay))
      } else if assessment.day == nil {
        thisWeek.append(AssessmentMarker(assessment: assessment, timing: .thisWeek))
      }
    }
    let markers = onDay + thisWeek
    guard topic != nil || !markers.isEmpty else { return nil }
    return LessonPlanHint(coursePlanID: plan.id, plannedTopic: topic, markers: markers)
  }

  /// Alle Leistungsnachweise mit diesem Montag, nach Tag (ohne Tag zuletzt), dann Fach, Jahrgang.
  public static func assessments(
    inWeekOf monday: CalendarDay, plans: [CoursePlanSnapshotEntry]
  ) -> [PlannedAssessment] {
    plans
      .flatMap { plan in
        plan.assessments.filter { $0.monday == monday }
          .map { PlannedAssessment(key: plan.key, assessment: $0) }
      }
      .sorted { lhs, rhs in
        switch (lhs.assessment.day, rhs.assessment.day) {
        case let (l?, r?) where l != r: return l < r
        case (nil, _?): return false
        case (_?, nil): return true
        default: break
        }
        if lhs.key.subject.normalized != rhs.key.subject.normalized {
          return lhs.key.subject.normalized < rhs.key.subject.normalized
        }
        if lhs.key.gradeLevel != rhs.key.gradeLevel { return lhs.key.gradeLevel < rhs.key.gradeLevel }
        return lhs.assessment.id.uuidString < rhs.assessment.id.uuidString
      }
  }
}
