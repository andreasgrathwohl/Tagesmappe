/// Reine Berechnungen auf dem Stundenplan; liest nie die Uhr.
public enum TimetableCalculator {
  /// Wochenvariante der Woche, die `day` enthält; `nil` bei nur einer Variante.
  public static func weekVariant(for day: CalendarDay, timetable: Timetable) -> WeekVariant? {
    guard timetable.weekVariantCount == 2 else { return nil }
    let days = day.mondayOfWeek.dayNumber - timetable.referenceWeekA.mondayOfWeek.dayNumber
    // Abrunden statt Abschneiden, damit Wochen vor der Bezugswoche richtig wechseln.
    let weeks = floorDiv(days, 7)
    return weeks % 2 == 0 ? .a : .b
  }

  /// Alle Unterrichtsstunden eines Tages: reguläre Einträge plus Vertretungen, mit Zeit, laufender
  /// Nummer und Ausfallmarkierung. An unterrichtsfreien Tagen leer, auch bei Vertretungen.
  public static func lessons(
    on day: CalendarDay, timetable: Timetable, nonTeachingPeriods: [NonTeachingPeriod],
    changes: [ScheduleChange]
  ) -> [Lesson] {
    if nonTeachingPeriods.contains(where: { $0.contains(day) }) { return [] }

    let variant = weekVariant(for: day, timetable: timetable)
    // `sorted` ist nicht stabil garantiert; deshalb zusätzlich nach Klasse und Fach ordnen.
    let regular = timetable.entries
      .filter { entry in
        entry.weekday == day.weekday
          && (variant == nil || entry.weekVariant == nil || entry.weekVariant == variant)
      }
      .sorted { ($0.period, $0.schoolClass.normalized, $0.subject.normalized)
        < ($1.period, $1.schoolClass.normalized, $1.subject.normalized) }

    // Vertretungen des Tages, dedupliziert nach Datum, Stunde, Klasse und Fach (Herkunft egal).
    struct SubstituteID: Hashable {
      let period: Int
      let schoolClass: SchoolClass
      let subject: Subject
    }
    var seen = Set<SubstituteID>()
    var substitutes: [(period: Int, schoolClass: SchoolClass, subject: Subject)] = []
    for change in changes {
      guard case let .substituteLesson(date, period, schoolClass, subject, _) = change,
        date == day
      else { continue }
      if seen.insert(SubstituteID(period: period, schoolClass: schoolClass, subject: subject))
        .inserted
      {
        substitutes.append((period, schoolClass, subject))
      }
    }
    substitutes.sort {
      ($0.period, $0.schoolClass.normalized, $0.subject.normalized)
        < ($1.period, $1.schoolClass.normalized, $1.subject.normalized)
    }

    // Ausfälle je Schlüssel; liegen beide Herkünfte vor, gilt `.manual`.
    var cancellations: [LessonKey: Origin] = [:]
    for change in changes {
      guard case let .cancellation(key, origin) = change, key.date == day else { continue }
      if origin == .manual || cancellations[key] == nil { cancellations[key] = origin }
    }

    struct Slot {
      let period: Int
      let schoolClass: SchoolClass
      let subject: Subject
      let isSubstitute: Bool
    }
    // Vertretungen hinten anstellen, damit eine nachträglich eingetragene Vertretung die
    // Schlüssel vorhandener Zuordnungen nicht verschiebt (ADR-0005).
    let slots =
      regular.map { Slot(period: $0.period, schoolClass: $0.schoolClass, subject: $0.subject, isSubstitute: false) }
      + substitutes.map {
        Slot(period: $0.period, schoolClass: $0.schoolClass, subject: $0.subject, isSubstitute: true)
      }

    struct Group: Hashable {
      let schoolClass: SchoolClass
      let subject: Subject
    }
    var counters: [Group: Int] = [:]
    var result: [Lesson] = []
    for slot in slots {
      let group = Group(schoolClass: slot.schoolClass, subject: slot.subject)
      let ordinal = (counters[group] ?? 0) + 1
      counters[group] = ordinal
      let key = LessonKey(
        date: day, schoolClass: slot.schoolClass, subject: slot.subject, ordinal: ordinal)
      let origin = cancellations[key]
      result.append(
        Lesson(
          key: key, period: slot.period, time: timetable.bellSchedule.periods[slot.period],
          isSubstituteLesson: slot.isSubstitute, isCancelled: origin != nil,
          cancellationOrigin: origin))
    }

    return result.sorted {
      if $0.period != $1.period { return $0.period < $1.period }
      if $0.isSubstituteLesson != $1.isSubstituteLesson { return !$0.isSubstituteLesson }
      return $0.key.schoolClass.normalized < $1.key.schoolClass.normalized
    }
  }
}
