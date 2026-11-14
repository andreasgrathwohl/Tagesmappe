import FrontstageCore
import Foundation
import Testing

@testable import Frontstage

/// Tagesansicht-Logik: Zeilen, Lücken, Ausfall, Vertretung, Ferien, Öffnen.
@MainActor @Suite struct DayViewModelTests {
  private let data: DataStore
  private let storage = FakeStorage()

  init() throws {
    data = try makeStore()
  }

  private func makeModel(day: CalendarDay = Fixtures.tue17) -> DayViewModel {
    DayViewModel(environment: Fixtures.environment(store: data, storage: storage, today: day))
  }

  private func dayRows(_ vm: DayViewModel) -> [DayRow] {
    guard case .rows(let rows) = vm.content else { return [] }
    return rows
  }

  private func lessonRows(_ vm: DayViewModel) -> [LessonRow] {
    dayRows(vm).compactMap { row in
      if case .lesson(let lesson) = row { return lesson }
      return nil
    }
  }

  private func lessonRow(_ vm: DayViewModel, _ period: Int) throws -> LessonRow {
    try #require(lessonRows(vm).first { $0.lesson.period == period })
  }

  @discardableResult
  private func assign(_ name: String, to key: LessonKey, kind: MaterialFileKind = .pdf) throws
    -> MaterialLinkItem
  {
    try data.assignItem(Fixtures.reference(name, kind), to: key, at: nil)
  }

  @Test("AK-1: jeder Dienstag zeigt 2. Stunde 8b Englisch")
  func everyTuesdayShowsEntry() throws {
    try Fixtures.seed(data, [Fixtures.entry(.tuesday, 2, "8b", "Englisch")])
    let vm = makeModel()
    for day in [Fixtures.tue17, Fixtures.tue24] {
      vm.day = day
      vm.reload()
      let rows = lessonRows(vm)
      #expect(rows.count == 1)
      #expect(rows.first?.lesson.period == 2)
      #expect(rows.first?.lesson.key.schoolClass.normalized == "8b")
      #expect(rows.first?.lesson.key.subject.display == "Englisch")
    }
    vm.day = Fixtures.wed18
    vm.reload()
    #expect(vm.content == .noLessons)
  }

  @Test("AK-42: Tagesansicht zeigt die Zeit an der 2. Stunde")
  func showsBellScheduleTime() throws {
    try Fixtures.seed(data, [Fixtures.entry(.tuesday, 2, "8b", "Englisch")])
    let row = try lessonRow(makeModel(), 2)
    #expect(row.lesson.time == TimeOfDay(hour: 8, minute: 35)...TimeOfDay(hour: 9, minute: 20))
  }

  @Test("AK-10: fünf Unterrichtsstunden in zeitlicher Reihenfolge, drei mit Material")
  func fiveLessonsInOrder() throws {
    try Fixtures.seed(
      data,
      [
        Fixtures.entry(.tuesday, 1, "7a", "Deutsch"), Fixtures.entry(.tuesday, 2, "8b", "Englisch"),
        Fixtures.entry(.tuesday, 3, "9c", "Englisch"), Fixtures.entry(.tuesday, 4, "6c", "Mathe"),
        Fixtures.entry(.tuesday, 5, "8a", "Englisch"),
      ])
    try assign("Arbeitsblatt Vokabeln", to: Fixtures.key(.tue17, "7a", "Deutsch"))
    for name in ["Unit 4 – Präsentation", "Arbeitsblatt Vokabeln", "Lösung Vokabeln"] {
      try assign(name, to: Fixtures.key(.tue17, "8b", "Englisch"))
    }
    try assign("Lösung Vokabeln", to: Fixtures.key(.tue17, "8a", "Englisch"))
    let vm = makeModel()
    #expect(lessonRows(vm).map(\.lesson.period) == [1, 2, 3, 4, 5])
    #expect(lessonRows(vm).map { $0.materials.count } == [1, 3, 0, 0, 1])
  }

  @Test("Lücke, ohne Material, nicht verfügbar, Ausfall erscheinen als verschiedene Zustände")
  func fourStatementsInRows() throws {
    try Fixtures.seed(
      data,
      [
        Fixtures.entry(.tuesday, 2, "8b", "Englisch"), Fixtures.entry(.tuesday, 4, "9c", "Englisch"),
        Fixtures.entry(.tuesday, 6, "8a", "Englisch"),
      ])
    try data.replaceScheduleChanges(
      [
        .cancellation(Fixtures.key(.tue17, "9c", "Englisch"), .source),
        .substituteLesson(
          date: .tue17, period: 5, schoolClass: SchoolClass("6c"), subject: Subject("Mathe"), .manual),
      ], sourceFetchedAt: nil)
    let missing = try assign("Fehlt.pdf", to: Fixtures.key(.tue17, "8a", "Englisch"))
    storage.availability[missing.reference.locationKey] = .unavailable(.fileMissing)
    let vm = makeModel()
    let slot3 = TimeOfDay(hour: 9, minute: 40)...TimeOfDay(hour: 10, minute: 25)
    #expect(dayRows(vm).count == 5)
    #expect(dayRows(vm)[2] == .noLesson(period: 3, time: slot3))
    #expect(dayRows(vm)[2].id == "free-3")
    #expect(try lessonRow(vm, 4).status == .cancelled(.source))
    #expect(try lessonRow(vm, 5).status == .substitute)
    #expect(try lessonRow(vm, 5).materials.isEmpty)
    #expect(try lessonRow(vm, 6).materials.first?.availability == .unavailable(.fileMissing))
  }

  @Test("Thema und Hausaufgabe erscheinen in der Zeile, ohne Kauf (FR-11.1, FR-13)")
  func rowShowsLessonInfo() throws {
    try Fixtures.seed(data, [Fixtures.entry(.tuesday, 2, "8b", "Englisch")])
    try data.setLessonInfo(
      LessonInfo(topic: "Unit 4 – Wortschatz", homework: "Seite 12"),
      for: Fixtures.key(.tue17, "8b", "Englisch"))
    let row = try lessonRow(makeModel(), 2)
    #expect(row.info.topic == "Unit 4 – Wortschatz")
    #expect(row.info.homework == "Seite 12")
  }

  @Test("AK-14: Herbstferien – keine Stunden, Material bleibt")
  func holidayKeepsMaterial() throws {
    try Fixtures.seed(data, [Fixtures.entry(.tuesday, 2, "8b", "Englisch")])
    try data.addNonTeachingPeriod(
      NonTeachingPeriod(
        from: CalendarDay(year: 2026, month: 11, day: 2), to: CalendarDay(year: 2026, month: 11, day: 6),
        title: "Herbstferien"))
    try assign("Arbeitsblatt Vokabeln", to: Fixtures.key(.nov3, "8b", "Englisch"))
    let vm = makeModel(day: .nov3)
    #expect(vm.content == .nonTeachingDay(title: "Herbstferien"))
    #expect(vm.materialsWithoutLesson.map(\.reference.displayName) == ["Arbeitsblatt Vokabeln"])
  }

  @Test("AK-15: Ausfall erkennbar, Material weiter sichtbar")
  func cancelledRowKeepsMaterial() throws {
    try Fixtures.seed(data, [Fixtures.entry(.tuesday, 2, "8b", "Englisch")])
    let key = Fixtures.key(.tue17, "8b", "Englisch")
    try assign("Arbeitsblatt Vokabeln", to: key)
    try data.markCancelled(key)
    let row = try lessonRow(makeModel(), 2)
    #expect(row.status == .cancelled(.manual))
    #expect(row.materials.map(\.item.reference.displayName) == ["Arbeitsblatt Vokabeln"])
  }

  @Test("AK-16: Vertretungsstunde nur am Mittwoch 18.11.")
  func substituteOnlyOnItsDate() throws {
    try Fixtures.seed(data, [Fixtures.entry(.tuesday, 2, "8b", "Englisch")])
    _ = try data.addSubstituteLesson(
      date: .wed18, period: 4, schoolClass: SchoolClass("6c"), subject: Subject("Mathe"))
    let vm = makeModel(day: .wed18)
    let row = try lessonRow(vm, 4)
    #expect(row.lesson.key.schoolClass.normalized == "6c")
    #expect(row.status == .substitute)
    vm.day = Fixtures.wed25
    vm.reload()
    #expect(vm.content == .noLessons)
  }

  @Test("Ohne Zeitraster bleibt die Stundenreihenfolge")
  func dayRowsWithoutBellScheduleKeepPeriodOrder() throws {
    try Fixtures.seed(
      data,
      [
        Fixtures.entry(.tuesday, 1, "7a", "Deutsch"), Fixtures.entry(.tuesday, 2, "8b", "Englisch"),
        Fixtures.entry(.tuesday, 4, "6c", "Mathe"),
      ], bell: BellSchedule(periods: [:]))
    let vm = makeModel()
    #expect(lessonRows(vm).map(\.lesson.period) == [1, 2, 4])
    #expect(lessonRows(vm).allSatisfy { $0.lesson.time == nil })
    #expect(dayRows(vm)[2] == .noLesson(period: 3, time: nil))
  }

  @Test("Tageswechsel: gestern, morgen, heute")
  func dayNavigation() {
    let vm = makeModel()
    vm.showNextDay()
    #expect(vm.day == Fixtures.wed18)
    vm.showPreviousDay()
    vm.showPreviousDay()
    #expect(vm.day == Fixtures.tue17.adding(days: -1))
    vm.showToday()
    #expect(vm.day == Fixtures.tue17)
  }

  @Test("PDF geht ohne Anzeige an die Übergabe")
  func openActionWithoutViewer() throws {
    let env = Fixtures.environment(store: data, storage: storage)
    let vm = DayViewModel(environment: env)
    let item = try assign("Blatt.pdf", to: Fixtures.key(.tue17, "8b", "Englisch"))
    let row = MaterialRow(item: item, availability: .onDevice(isCurrent: true))
    #expect(vm.openAction(for: row) == .open(item.reference))
    env.viewerAvailable = true
    #expect(vm.openAction(for: row) == .viewer(item))
    let text = try assign("Text.docx", to: Fixtures.key(.tue17, "8b", "Englisch"), kind: .document)
    #expect(vm.openAction(for: MaterialRow(item: text, availability: nil)) == .open(text.reference))
    let missing = MaterialRow(item: item, availability: .unavailable(.fileMissing))
    #expect(vm.openAction(for: missing) == .unavailable(item.reference))
  }

  @Test("Ladezustand, solange open auf das Herunterladen wartet (03: bis 120 s)")
  func openShowsLoadingWhileWaiting() async throws {
    let vm = makeModel()
    let item = try assign("Blatt.pdf", to: Fixtures.key(.tue17, "8b", "Englisch"))
    let row = MaterialRow(item: item, availability: nil)
    storage.openDelay = .milliseconds(200)
    storage.openOutcome = .handedOff
    let task = Task { await vm.open(row, anchor: HandOffAnchor()) }
    try await Task.sleep(for: .milliseconds(50))
    #expect(vm.openingLinkIDs.contains(row.id))
    guard case .handedOff = await task.value else {
      Issue.record("erwartet .handedOff")
      return
    }
    #expect(vm.openingLinkIDs.isEmpty)
  }

  @Test("Zweiter Tipp während des Wartens: .waitingForDownload, Ladezustand bleibt bis zum Ende des ersten")
  func secondTapWhileWaiting() async throws {
    let vm = makeModel()
    let item = try assign("Blatt.pdf", to: Fixtures.key(.tue17, "8b", "Englisch"))
    let row = MaterialRow(item: item, availability: nil)
    storage.openDelay = .milliseconds(300)
    let first = Task { await vm.open(row, anchor: HandOffAnchor()) }
    try await Task.sleep(for: .milliseconds(50))
    guard case .waitingForDownload = await vm.open(row, anchor: HandOffAnchor()) else {
      Issue.record("erwartet .waitingForDownload")
      return
    }
    #expect(vm.openingLinkIDs.contains(row.id))
    _ = await first.value
    #expect(vm.openingLinkIDs.isEmpty)
  }

  @Test("Ohne Stundenplan: leerer Tag ohne Absturz")
  func emptyDayWithoutTimetable() {
    let vm = makeModel()
    #expect(vm.content == .noLessons)
    #expect(vm.materialsWithoutLesson.isEmpty)
  }
}

@Suite struct DayStatementTests {
  @Test("Vier Aussagen unterscheiden sich in Symbol und Text")
  func fourStatementsDistinct() {
    #expect(Set(DayStatement.allCases.map(\.symbolName)).count == 4)
    #expect(Set(DayStatement.allCases.map(\.labelKey)).count == 4)
  }
}
