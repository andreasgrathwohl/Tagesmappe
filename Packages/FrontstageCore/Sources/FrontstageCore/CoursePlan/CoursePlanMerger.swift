import Foundation

/// Reduzierter Datenstand für das Zusammenführen nach dem Abgleich (nur Foundation, keine Modelle).
public struct CoursePlanMergeSnapshot: Sendable {
  public struct Year: Hashable, Sendable {
    public var id: UUID
    public var startYear: Int
    public var createdAt: Date
    public init(id: UUID, startYear: Int, createdAt: Date) {
      self.id = id
      self.startYear = startYear
      self.createdAt = createdAt
    }
  }

  public struct Plan: Hashable, Sendable {
    public var id: UUID
    public var key: CoursePlanKey
    public var createdAt: Date
    public init(id: UUID, key: CoursePlanKey, createdAt: Date) {
      self.id = id
      self.key = key
      self.createdAt = createdAt
    }
  }

  public struct Week: Hashable, Sendable {
    public var id: UUID
    public var planID: UUID?
    public var monday: CalendarDay?
    public var createdAt: Date
    public var updatedAt: Date
    public init(id: UUID, planID: UUID?, monday: CalendarDay?, createdAt: Date, updatedAt: Date) {
      self.id = id
      self.planID = planID
      self.monday = monday
      self.createdAt = createdAt
      self.updatedAt = updatedAt
    }
  }

  public struct Item: Hashable, Sendable {
    public var id: UUID
    public var planID: UUID?
    public var monday: CalendarDay?
    public var day: CalendarDay?
    public var kind: AssessmentKind
    public var title: String
    public var createdAt: Date
    public init(
      id: UUID, planID: UUID?, monday: CalendarDay?, day: CalendarDay?, kind: AssessmentKind,
      title: String, createdAt: Date
    ) {
      self.id = id
      self.planID = planID
      self.monday = monday
      self.day = day
      self.kind = kind
      self.title = title
      self.createdAt = createdAt
    }
  }

  public var years: [Year]
  public var plans: [Plan]
  public var weeks: [Week]
  public var assessments: [Item]

  public init(
    years: [Year] = [], plans: [Plan] = [], weeks: [Week] = [], assessments: [Item] = []
  ) {
    self.years = years
    self.plans = plans
    self.weeks = weeks
    self.assessments = assessments
  }
}

/// Was nach dem Abgleich für Schuljahre und Jahrespläne zu tun ist.
public struct CoursePlanMergePlan: Equatable, Sendable {
  /// Aufgegebene Datensätze (aller Arten), die zu löschen sind.
  public var deletions: Set<UUID> = []
  /// Planwoche/Leistungsnachweis → behaltener Jahresplan.
  public var parentChanges: [UUID: UUID] = [:]
  /// Behaltene Planwoche → Planwoche, deren Thema und Notizen gelten.
  public var weekContentSources: [UUID: UUID] = [:]

  public init() {}

  public var isEmpty: Bool {
    deletions.isEmpty && parentChanges.isEmpty && weekContentSources.isEmpty
  }
}

/// Reine Zusammenführ-Logik für Schuljahre, Jahrespläne, Planwochen und Leistungsnachweise:
/// je fachlichem Schlüssel bleibt der älteste Datensatz (wie `SyncMerger`).
public enum CoursePlanMerger {
  private struct WeekKey: Hashable {
    var planID: UUID
    var monday: CalendarDay
  }
  private struct AssessmentKey: Hashable {
    var planID: UUID
    var monday: CalendarDay?
    var day: CalendarDay?
    var kind: AssessmentKind
    var title: String
  }

  public static func plan(for snapshot: CoursePlanMergeSnapshot) -> CoursePlanMergePlan {
    var plan = CoursePlanMergePlan()

    // 1. Schuljahre gleichen Startjahrs.
    let yearMap = SyncMerger.survivors(
      snapshot.years, key: { $0.startYear }, id: { $0.id }, createdAt: { $0.createdAt })
    plan.deletions.formUnion(yearMap.keys)

    // 2. Jahrespläne gleichen Schlüssels; die Kinder wandern zum behaltenen Plan.
    let planMap = SyncMerger.survivors(
      snapshot.plans, key: { $0.key }, id: { $0.id }, createdAt: { $0.createdAt })
    plan.deletions.formUnion(planMap.keys)

    func effective(_ planID: UUID?) -> UUID? { planID.map { planMap[$0] ?? $0 } }

    // 3. Planwochen: gleicher wirksamer Plan und Montag; ohne Montag nie.
    let weekMap = SyncMerger.survivors(
      snapshot.weeks,
      key: { week -> WeekKey? in
        guard let planID = effective(week.planID), let monday = week.monday else { return nil }
        return WeekKey(planID: planID, monday: monday)
      }, id: { $0.id }, createdAt: { $0.createdAt })
    plan.deletions.formUnion(weekMap.keys)

    let weeksByID = Dictionary(uniqueKeysWithValues: snapshot.weeks.map { ($0.id, $0) })
    var droppedByKeeper: [UUID: [CoursePlanMergeSnapshot.Week]] = [:]
    for (dropped, keeper) in weekMap {
      if let week = weeksByID[dropped] { droppedByKeeper[keeper, default: []].append(week) }
    }
    for (keeperID, dropped) in droppedByKeeper {
      guard let keeper = weeksByID[keeperID] else { continue }
      // Jüngste Änderung gewinnt; bei Gleichstand kleinere id, damit das Ergebnis stabil bleibt.
      let newest = dropped.min {
        ($1.updatedAt, $0.id.uuidString) < ($0.updatedAt, $1.id.uuidString)
      }
      if let newest, newest.updatedAt > keeper.updatedAt {
        plan.weekContentSources[keeperID] = newest.id
      }
    }

    for week in snapshot.weeks where weekMap[week.id] == nil {
      if let planID = week.planID, let target = planMap[planID] {
        plan.parentChanges[week.id] = target
      }
    }

    // 4. Leistungsnachweise.
    let itemMap = SyncMerger.survivors(
      snapshot.assessments,
      key: { item -> AssessmentKey? in
        guard let planID = effective(item.planID) else { return nil }
        return AssessmentKey(
          planID: planID, monday: item.monday, day: item.day, kind: item.kind,
          title: item.title.trimmingCharacters(in: .whitespacesAndNewlines))
      }, id: { $0.id }, createdAt: { $0.createdAt })
    plan.deletions.formUnion(itemMap.keys)
    for item in snapshot.assessments where itemMap[item.id] == nil {
      if let planID = item.planID, let target = planMap[planID] {
        plan.parentChanges[item.id] = target
      }
    }

    return plan
  }
}
