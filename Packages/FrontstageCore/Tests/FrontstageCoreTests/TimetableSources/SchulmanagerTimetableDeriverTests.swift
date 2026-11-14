import Testing

@testable import FrontstageCore

@Suite("SchulmanagerTimetableDeriver")
struct SchulmanagerTimetableDeriverTests {
  private let me = "T-100"

  private func lesson(
    _ day: CalendarDay, _ period: Int, _ cls: String, _ subject: String, teacher: String = "T-100",
    type: SchulmanagerLessonType = .regularLesson
  ) -> SchulmanagerLesson {
    let info = SchulmanagerLessonInfo(subjectName: subject, classNames: [cls], teacherIDs: [teacher])
    return SchulmanagerLesson(
      date: day, period: period, type: type, actual: type == .regularLesson ? info : nil,
      originals: type == .regularLesson ? [] : [info], isCancelled: false, isSubstitution: false)
  }

  private func derived(_ outcome: TimetableDerivationOutcome) -> DerivedTimetable? {
    if case .derived(let value) = outcome { return value }
    return nil
  }

  @Test("A/B-Wochen aus zwei Wochen erkennen (Werte aus AK-2)")
  func derivesWeekVariants() throws {
    let lessons = [
      lesson(d(2026, 11, 16), 1, "7a", "Deutsch"), lesson(d(2026, 11, 17), 2, "8b", "Englisch"),
      lesson(d(2026, 11, 23), 1, "9c", "Englisch"), lesson(d(2026, 11, 24), 2, "8b", "Englisch"),
    ]
    let result = try #require(
      derived(SchulmanagerTimetableDeriver.derive(lessons: lessons, teacherID: me, existing: nil)))
    #expect(
      result.entries == [
        entry(.monday, 1, "7a", "Deutsch", variant: .a),
        entry(.monday, 1, "9c", "Englisch", variant: .b),
        entry(.tuesday, 2, "8b", "Englisch"),
      ])
    #expect(result.weekVariantCount == 2)
    #expect(result.referenceWeekA == d(2026, 11, 16))
  }

  @Test("Drei Einträge aus der Quelle (AK-3)")
  func derivesThreeEntriesFromIdenticalWeeks() throws {
    var lessons: [SchulmanagerLesson] = []
    for week in [d(2026, 11, 16), d(2026, 11, 23)] {
      lessons += [
        lesson(week.adding(days: 1), 2, "8b", "Englisch"), lesson(week.adding(days: 2), 4, "7a", "Deutsch"),
        lesson(week.adding(days: 4), 2, "8a", "Englisch"),
      ]
    }
    let result = try #require(
      derived(SchulmanagerTimetableDeriver.derive(lessons: lessons, teacherID: me, existing: nil)))
    #expect(result.entries.count == 3)
    #expect(result.entries.allSatisfy { $0.weekVariant == nil })
    #expect(result.weekVariantCount == 1)
  }

  @Test("Eine leere Ferienwoche wird übersprungen")
  func holidayWeekIsSkipped() throws {
    var lessons: [SchulmanagerLesson] = []
    // Die Woche ab 2026-11-16 ist leer.
    for week in [d(2026, 11, 23), d(2026, 11, 30)] {
      lessons += [lesson(week, 1, "7a", "Deutsch"), lesson(week.adding(days: 1), 2, "8b", "Englisch")]
    }
    let result = try #require(
      derived(SchulmanagerTimetableDeriver.derive(lessons: lessons, teacherID: me, existing: nil)))
    #expect(result.entries.count == 2)
    #expect(result.weekVariantCount == 1)
  }

  @Test("Ein einzelner fehlender Wochentag ist keine Variante")
  func singleMissingWeekdayIsNotAVariant() throws {
    let w1 = d(2026, 11, 16)
    let w2 = d(2026, 11, 23)
    // Mittwoch 2026-11-18 ohne Stunden (Feiertag); der Mittwoch der zweiten Woche hat eine.
    let lessons = [
      lesson(w1, 1, "7a", "Deutsch"), lesson(w1.adding(days: 1), 2, "8b", "Englisch"),
      lesson(w2, 1, "7a", "Deutsch"), lesson(w2.adding(days: 1), 2, "8b", "Englisch"),
      lesson(w2.adding(days: 2), 3, "9c", "Physik"),
    ]
    let result = try #require(
      derived(SchulmanagerTimetableDeriver.derive(lessons: lessons, teacherID: me, existing: nil)))
    #expect(result.entries.contains(entry(.wednesday, 3, "9c", "Physik")))
    #expect(result.weekVariantCount == 1)
  }

  @Test("Nur Ereignisse im Zeitraum lassen den Plan unberührt")
  func noLessonsInRangeLeavesTimetableAlone() {
    let event = SchulmanagerLesson(
      date: d(2026, 11, 16), period: 1, type: .event, actual: nil, originals: [], isCancelled: false,
      isSubstitution: false)
    #expect(
      SchulmanagerTimetableDeriver.derive(lessons: [event], teacherID: me, existing: nil)
        == .noLessonsInRange)
  }

  @Test("Eine Woche bei vorhandenem A/B ist unbestimmt")
  func singleWeekWithExistingABIsUndetermined() {
    let existing = Timetable(weekVariantCount: 2, referenceWeekA: d(2026, 11, 16))
    let outcome = SchulmanagerTimetableDeriver.derive(
      lessons: [lesson(d(2026, 11, 16), 1, "7a", "Deutsch")], teacherID: me, existing: existing)
    #expect(outcome == .weekVariantsUndetermined)
  }

  @Test("Benennung der Varianten folgt dem vorhandenen Plan")
  func usesExistingVariantNaming() throws {
    let existing = Timetable(weekVariantCount: 2, referenceWeekA: d(2026, 11, 23))
    let lessons = [lesson(d(2026, 11, 16), 1, "7a", "Deutsch"), lesson(d(2026, 11, 23), 1, "9c", "Englisch")]
    let result = try #require(
      derived(SchulmanagerTimetableDeriver.derive(lessons: lessons, teacherID: me, existing: existing)))
    #expect(
      result.entries == [
        entry(.monday, 1, "9c", "Englisch", variant: .a),
        entry(.monday, 1, "7a", "Deutsch", variant: .b),
      ])
    #expect(result.referenceWeekA == d(2026, 11, 23))
  }

  @Test("Stunden fremder Lehrkräfte werden ignoriert")
  func foreignLessonsAreIgnored() throws {
    let lessons = [
      lesson(d(2026, 11, 16), 1, "7a", "Deutsch"), lesson(d(2026, 11, 16), 2, "8b", "Kunst", teacher: "T-200"),
    ]
    let result = try #require(
      derived(SchulmanagerTimetableDeriver.derive(lessons: lessons, teacherID: me, existing: nil)))
    #expect(result.entries == [entry(.monday, 1, "7a", "Deutsch")])
  }

  @Test("Ausgefallene Stunden gehören weiter zum geplanten Plan")
  func cancelledLessonsStayInPlan() throws {
    let lessons = [lesson(d(2026, 11, 16), 1, "7a", "Deutsch", type: .cancelledLesson)]
    let result = try #require(
      derived(SchulmanagerTimetableDeriver.derive(lessons: lessons, teacherID: me, existing: nil)))
    #expect(result.entries == [entry(.monday, 1, "7a", "Deutsch")])
  }
}
