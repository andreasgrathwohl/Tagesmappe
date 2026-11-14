import Testing

@testable import FrontstageCore

@Suite("ImportApply")
struct ImportApplyTests {
  private let imported3 = [
    entry(.tuesday, 2, "8b", "Englisch"), entry(.wednesday, 4, "7a", "Deutsch"),
    entry(.friday, 2, "8a", "Englisch"),
  ]

  @Test("Import übernimmt 3 Einträge, der von Hand angelegte bleibt (AK-3)")
  func importKeepsManualEntry() {
    let manual = entry(.monday, 5, "8a", "Englisch")
    let diff = ImportDiffer.compare(existing: [manual], manuallyEdited: [manual], imported: imported3)
    let result = ImportApplier.apply(
      diff, existing: [manual], manuallyEdited: [manual], acceptedFromSource: [])
    #expect(result.entries.count == 4)
    #expect(result.entries.contains(manual))
    #expect(result.manuallyEdited == [manual])
  }

  @Test("Konflikt: eigene Fassung bleibt ohne Wahl (AK-3)")
  func conflictKeepsMineByDefault() {
    let mine = entry(.monday, 5, "8a", "Englisch")
    let source = entry(.monday, 5, "8b", "Englisch")
    let diff = ImportDiffer.compare(existing: [mine], manuallyEdited: [mine], imported: [source])
    let result = ImportApplier.apply(
      diff, existing: [mine], manuallyEdited: [mine], acceptedFromSource: [])
    #expect(result.entries == [mine])
    #expect(!result.entries.contains(source))
  }

  @Test("Konflikt: Quell-Fassung gewählt, Hand-Markierung entfällt")
  func conflictTakesSourceWhenChosen() {
    let mine = entry(.monday, 5, "8a", "Englisch")
    let source = entry(.monday, 5, "8b", "Englisch")
    let diff = ImportDiffer.compare(existing: [mine], manuallyEdited: [mine], imported: [source])
    let result = ImportApplier.apply(
      diff, existing: [mine], manuallyEdited: [mine], acceptedFromSource: [source])
    #expect(result.entries == [source])
    #expect(result.manuallyEdited.isEmpty)
  }

  @Test("Geänderte und entfernte Quell-Einträge werden ersetzt")
  func appliesChangedAndRemoved() {
    let old = entry(.tuesday, 2, "8b", "Englisch")
    let gone = entry(.thursday, 1, "7a", "Deutsch")
    let new = entry(.tuesday, 2, "8c", "Englisch")
    let diff = ImportDiffer.compare(existing: [old, gone], manuallyEdited: [], imported: [new])
    let result = ImportApplier.apply(
      diff, existing: [old, gone], manuallyEdited: [], acceptedFromSource: [])
    #expect(result.entries == [new])
  }

  /// Plan: Di 2026-11-17, 4. Stunde 9c Englisch.
  private var plan: Timetable {
    timetable([entry(.tuesday, 4, "9c", "Englisch"), entry(.tuesday, 2, "8b", "Mathematik")])
  }

  @Test("Ausfall wird dem Schlüssel der berechneten Stunde zugeordnet")
  func resolvesCancellationToLessonKey() {
    let change = SourceChange.cancelled(
      date: d(2026, 11, 17), period: 4, schoolClass: SchoolClass("9c"), subject: Subject("Englisch"))
    let result = SourceChangeResolver.resolve([change], timetable: plan, nonTeachingPeriods: [])
    let key = LessonKey(
      date: d(2026, 11, 17), schoolClass: SchoolClass("9c"), subject: Subject("Englisch"), ordinal: 1)
    #expect(result.resolved == [.cancellation(key, .source)])
    #expect(result.unmatched.isEmpty)
  }

  @Test("Ausfall an unterrichtsfreiem Tag bleibt unzugeordnet")
  func cancellationOnNonTeachingDayIsUnmatched() {
    let change = SourceChange.cancelled(
      date: d(2026, 11, 17), period: 4, schoolClass: SchoolClass("9c"), subject: Subject("Englisch"))
    let holiday = NonTeachingPeriod(from: d(2026, 11, 16), to: d(2026, 11, 20), title: "Ferien")
    let result = SourceChangeResolver.resolve([change], timetable: plan, nonTeachingPeriods: [holiday])
    #expect(result.resolved.isEmpty)
    #expect(result.unmatched == [change])
  }

  @Test("Ausfall ohne passende Stunde bleibt unzugeordnet")
  func cancellationWithoutMatchingLessonIsUnmatched() {
    let change = SourceChange.cancelled(
      date: d(2026, 11, 17), period: 5, schoolClass: SchoolClass("9c"), subject: Subject("Englisch"))
    let result = SourceChangeResolver.resolve([change], timetable: plan, nonTeachingPeriods: [])
    #expect(result.unmatched == [change])
  }

  @Test("Vertretungsstunde erscheint in der 3. Stunde (AK-21)")
  func substituteAppearsInLessons() {
    let change = SourceChange.substitute(
      date: d(2026, 11, 17), period: 3, schoolClass: SchoolClass("6c"), subject: Subject("Englisch"))
    let result = SourceChangeResolver.resolve([change], timetable: plan, nonTeachingPeriods: [])
    let lessons = TimetableCalculator.lessons(
      on: d(2026, 11, 17), timetable: plan, nonTeachingPeriods: [], changes: result.resolved)
    let substitute = lessons.first { $0.period == 3 && $0.key.schoolClass == SchoolClass("6c") }
    #expect(substitute?.isSubstituteLesson == true)
  }

  @Test("Merger ersetzt nur Quell-Abweichungen im Zeitraum")
  func mergerReplacesOnlySourceChangesInRange() {
    func key(_ day: CalendarDay) -> LessonKey {
      LessonKey(date: day, schoolClass: SchoolClass("9c"), subject: Subject("Englisch"), ordinal: 1)
    }
    let manualCancel = ScheduleChange.cancellation(key(d(2026, 11, 17)), .manual)
    let sourceSub = ScheduleChange.substituteLesson(
      date: d(2026, 11, 17), period: 3, schoolClass: SchoolClass("6c"), subject: Subject("Englisch"),
      .source)
    let oldSourceCancel = ScheduleChange.cancellation(key(d(2026, 11, 10)), .source)
    let newCancel = ScheduleChange.cancellation(key(d(2026, 11, 18)), .source)
    let result = ScheduleChangeMerger.replacingSourceChanges(
      in: [manualCancel, sourceSub, oldSourceCancel], with: [newCancel],
      range: d(2026, 11, 16)...d(2026, 12, 13))
    #expect(result.count == 3)
    #expect(result.contains(manualCancel))
    #expect(!result.contains(sourceSub))
    #expect(result.contains(oldSourceCancel))
    #expect(result.contains(newCancel))
  }
}
