/// Leitet aus datierten Schulmanager-Stunden den Wochenplan einer Lehrkraft ab, einschließlich A/B-Wochen.
///
/// Die Quelle liefert nur datierte Stunden, keinen Wochenrhythmus. Der Rhythmus wird aus zwei
/// aufeinanderfolgenden Unterrichtswochen erschlossen: Was in beiden Wochen steht, gilt jede Woche; was nur in
/// einer steht, gehört zu deren Variante. Ferien und Feiertage dürfen dabei keinen Planunterschied vortäuschen.
public enum SchulmanagerTimetableDeriver {
  /// Eine feste Stunde ohne Wochenvariante.
  private struct Slot: Hashable {
    var weekday: Weekday
    var period: Int
    var schoolClass: SchoolClass
    var subject: Subject
  }

  public static func derive(
    lessons: [SchulmanagerLesson], teacherID: String, existing: Timetable?
  ) -> TimetableDerivationOutcome {
    // 1. Geplante eigene Stunden je Woche und Wochentag.
    var weeks: [CalendarDay: [Weekday: Set<Slot>]] = [:]
    for lesson in lessons {
      let infos: [SchulmanagerLessonInfo]
      switch lesson.type {
      case .regularLesson: infos = lesson.actual.map { [$0] } ?? []
      case .cancelledLesson, .changedLesson: infos = lesson.originals
      case .event: infos = []
      }
      let weekday = lesson.date.weekday
      for info in infos where info.teacherIDs.contains(teacherID) {
        for className in info.classNames {
          let slot = Slot(
            weekday: weekday, period: lesson.period, schoolClass: SchoolClass(className),
            subject: Subject(info.subjectName))
          weeks[lesson.date.mondayOfWeek, default: [:]][weekday, default: []].insert(slot)
        }
      }
    }

    // 2. Nutzbar ist eine Woche mit mindestens einer geplanten Stunde (Slots sind nie leer eingetragen).
    let usable = weeks.keys.sorted()
    guard let first = usable.first else { return .noLessonsInRange }

    // 3. Erstes Paar unmittelbar aufeinanderfolgender nutzbarer Wochen.
    let pair = usable.first(where: { weeks[$0.adding(days: 7)] != nil })

    let existingHasVariants = existing?.weekVariantCount == 2

    // 4. Nur eine Woche.
    guard let week1 = pair else {
      if existingHasVariants { return .weekVariantsUndetermined }
      let slots = weeks[first, default: [:]].values.flatMap { $0 }
      let entries = sorted(slots.map { ($0, nil) })
      return .derived(
        DerivedTimetable(
          entries: entries, weekVariantCount: 1, referenceWeekA: existing?.referenceWeekA))
    }

    // 5. Paar: je Wochentag vergleichen.
    let week2 = week1.adding(days: 7)
    let days1 = weeks[week1, default: [:]]
    let days2 = weeks[week2, default: [:]]
    // 6. Benennung der Varianten.
    let variant1: WeekVariant
    let variant2: WeekVariant
    let reference: CalendarDay?
    if let existing, existingHasVariants {
      // Eine Woche mit Planunterschied wird nie ohne Variante benannt; hier nur Zuordnung.
      variant1 = TimetableCalculator.weekVariant(for: week1, timetable: existing) ?? .a
      variant2 = TimetableCalculator.weekVariant(for: week2, timetable: existing) ?? .b
      reference = existing.referenceWeekA
    } else {
      variant1 = .a
      variant2 = .b
      reference = week1
    }

    var result: [(Slot, WeekVariant?)] = []
    for weekday in Weekday.allCases {
      let s1 = days1[weekday]
      let s2 = days2[weekday]
      switch (s1, s2) {
      case (nil, nil): break
      case (let only?, nil), (nil, let only?):
        // Der Tag zählt nur in einer Woche (Feiertag): kein Planunterschied.
        result += only.map { ($0, nil) }
      case (let a?, let b?):
        result += a.intersection(b).map { ($0, nil) }
        result += a.subtracting(b).map { ($0, variant1) }
        result += b.subtracting(a).map { ($0, variant2) }
      }
    }

    let hasVariants = result.contains { $0.1 != nil }
    if hasVariants {
      return .derived(
        DerivedTimetable(entries: sorted(result), weekVariantCount: 2, referenceWeekA: reference))
    }
    return .derived(
      DerivedTimetable(
        entries: sorted(result), weekVariantCount: 1, referenceWeekA: existing?.referenceWeekA))
  }

  /// Deterministische Reihenfolge: Wochentag, Stunde, Variante (ohne vor A vor B), Klasse, Fach.
  private static func sorted(_ items: [(Slot, WeekVariant?)]) -> [TimetableEntry] {
    func rank(_ v: WeekVariant?) -> Int {
      switch v {
      case nil: 0
      case .a?: 1
      case .b?: 2
      }
    }
    return items.sorted { l, r in
      let lk = (l.0.weekday.rawValue, l.0.period, rank(l.1))
      let rk = (r.0.weekday.rawValue, r.0.period, rank(r.1))
      if lk != rk { return lk < rk }
      if l.0.schoolClass.normalized != r.0.schoolClass.normalized {
        return l.0.schoolClass.normalized < r.0.schoolClass.normalized
      }
      return l.0.subject.normalized < r.0.subject.normalized
    }.map {
      TimetableEntry(
        weekVariant: $0.1, weekday: $0.0.weekday, period: $0.0.period,
        schoolClass: $0.0.schoolClass, subject: $0.0.subject)
    }
  }
}
