import Foundation
import FrontstageCore
import Testing

@testable import Frontstage

/// Stundenplan von Hand: Anlegen, A-/B-Woche, Bezugswoche (FR-1, FR-1.1).
@MainActor @Suite struct TimetableEditorViewModelTests {
  private let store: DataStore
  private let storage = FakeStorage()

  init() throws {
    store = try makeStore()
  }

  private func makeModel() -> TimetableEditorViewModel {
    TimetableEditorViewModel(environment: Fixtures.environment(store: store, storage: storage))
  }

  @Test("AK-1: Eintrag Di 2. Std 8b Englisch anlegen")
  func addEntryFromEmpty() throws {
    let vm = makeModel()
    let entry = Fixtures.entry(.tuesday, 2, "8b", "Englisch")
    try vm.save(entry, replacing: nil)
    #expect(try store.timetable()?.entries == [entry])
    // Herkunft .manual (AK-3)
    #expect(try store.manuallyEditedEntries().contains(entry))
    #expect(vm.entries(weekday: .tuesday, period: 2) == [entry])
  }

  @Test("AK-2 Logik: A-Woche 7a, B-Woche 9c")
  func abWeeksResolve() throws {
    let vm = makeModel()
    #expect(vm.setWeekVariantCount(2, confirmed: false) == nil)
    vm.setReferenceWeek(containing: .init(year: 2026, month: 11, day: 18))
    #expect(vm.weekVariantCount == 2)
    #expect(vm.referenceWeekA == .init(year: 2026, month: 11, day: 16))
    try vm.save(Fixtures.entry(.monday, 1, "7a", "Deutsch", .a), replacing: nil)
    try vm.save(Fixtures.entry(.monday, 1, "9c", "Mathe", .b), replacing: nil)
    // Mo 16.11. (A-Woche) zeigt 7a, Mo 23.11. (B-Woche) zeigt 9c.
    #expect(try store.lessons(on: .init(year: 2026, month: 11, day: 16)).map(\.key.schoolClass) == [SchoolClass("7a")])
    #expect(try store.lessons(on: .init(year: 2026, month: 11, day: 23)).map(\.key.schoolClass) == [SchoolClass("9c")])
  }

  @Test("Ansicht zeigt bei zwei Varianten nur die gewählte plus Einträge ohne Variante")
  func shownVariantFilters() throws {
    try Fixtures.seed(
      store,
      [
        Fixtures.entry(.monday, 1, "7a", "Deutsch", .a), Fixtures.entry(.monday, 1, "9c", "Mathe", .b),
        Fixtures.entry(.monday, 1, "8b", "Kunst"),
      ], variants: 2)
    let vm = makeModel()
    #expect(vm.entries(weekday: .monday, period: 1).map(\.schoolClass.normalized) == ["7a", "8b"])
    vm.shownVariant = .b
    #expect(vm.entries(weekday: .monday, period: 1).map(\.schoolClass.normalized) == ["8b", "9c"])
  }

  @Test("Leere Klasse wird abgelehnt")
  func emptyClassRejected() {
    let vm = makeModel()
    #expect(throws: TimetableEditError.emptyClass) {
      try vm.save(Fixtures.entry(.monday, 1, "  ", "Englisch"), replacing: nil)
    }
  }

  @Test("Leeres Fach und ungültige Stunde werden abgelehnt")
  func emptySubjectAndPeriodRejected() {
    let vm = makeModel()
    #expect(throws: TimetableEditError.emptySubject) {
      try vm.save(Fixtures.entry(.monday, 1, "8b", " "), replacing: nil)
    }
    #expect(throws: TimetableEditError.invalidPeriod) {
      try vm.save(Fixtures.entry(.monday, 0, "8b", "Englisch"), replacing: nil)
    }
  }

  @Test("Doppelter Eintrag wird abgelehnt")
  func duplicateRejected() throws {
    let vm = makeModel()
    try vm.save(Fixtures.entry(.monday, 1, "8b", "Englisch"), replacing: nil)
    #expect(throws: TimetableEditError.duplicate) {
      try vm.save(Fixtures.entry(.monday, 1, "8 B", "englisch"), replacing: nil)
    }
    // Ändern auf einen bestehenden anderen Eintrag ist ebenfalls ein Duplikat.
    try vm.save(Fixtures.entry(.monday, 2, "8b", "Englisch"), replacing: nil)
    #expect(throws: TimetableEditError.duplicate) {
      try vm.save(
        Fixtures.entry(.monday, 1, "8b", "Englisch"), replacing: Fixtures.entry(.monday, 2, "8b", "Englisch"))
    }
  }

  @Test("Ändern ersetzt den Eintrag, Löschen entfernt ihn")
  func replaceAndDelete() throws {
    let vm = makeModel()
    let old = Fixtures.entry(.monday, 1, "8b", "Englisch")
    let new = Fixtures.entry(.monday, 3, "8b", "Englisch")
    try vm.save(old, replacing: nil)
    try vm.save(new, replacing: old)
    #expect(try store.timetable()?.entries == [new])
    vm.delete(new)
    #expect(try store.timetable()?.entries == [])
    #expect(vm.allEntries.isEmpty)
  }

  @Test("Bei einer Variante wird die A-/B-Zuordnung verworfen")
  func variantDroppedWithOneVariant() throws {
    let vm = makeModel()
    try vm.save(Fixtures.entry(.monday, 1, "8b", "Englisch", .b), replacing: nil)
    #expect(try store.timetable()?.entries == [Fixtures.entry(.monday, 1, "8b", "Englisch")])
  }

  @Test("Zurück auf eine Variante verlangt Bestätigung")
  func reducingToOneVariantRequiresConfirmation() throws {
    try Fixtures.seed(
      store,
      [Fixtures.entry(.monday, 1, "7a", "Deutsch", .a), Fixtures.entry(.monday, 1, "9c", "Mathe", .b)],
      variants: 2)
    let vm = makeModel()
    #expect(vm.setWeekVariantCount(1, confirmed: false) == 1)
    #expect(vm.weekVariantCount == 2)
    #expect(try store.timetable()?.entries.count == 2)

    #expect(vm.setWeekVariantCount(1, confirmed: true) == nil)
    #expect(vm.weekVariantCount == 1)
    #expect(try store.timetable()?.entries == [Fixtures.entry(.monday, 1, "7a", "Deutsch")])
  }

  @Test("Zurück auf eine Variante ohne B-Einträge braucht keine Bestätigung")
  func reducingWithoutBEntries() throws {
    try Fixtures.seed(store, [Fixtures.entry(.monday, 1, "7a", "Deutsch", .a)], variants: 2)
    let vm = makeModel()
    #expect(vm.setWeekVariantCount(1, confirmed: false) == nil)
    #expect(vm.weekVariantCount == 1)
    #expect(try store.timetable()?.entries == [Fixtures.entry(.monday, 1, "7a", "Deutsch")])
  }

  @Test("Stundenauswahl: Zeitraster, sonst 1 bis 10; Raster zeigt auch Stunden außerhalb")
  func periodChoices() throws {
    let empty = makeModel()
    #expect(empty.periodChoices == Array(1...10))
    try Fixtures.seed(store, [Fixtures.entry(.monday, 8, "8b", "Englisch")])
    let vm = makeModel()
    #expect(vm.periodChoices == [1, 2, 3, 4, 5, 6])
    #expect(vm.gridPeriods == [1, 2, 3, 4, 5, 6, 8])
  }

  @Test("Bestehender Eintrag für beide Wochen behält beim Bearbeiten „beide“ (A-Ansicht, zwei Varianten)")
  func editingBothWeeksEntryKeepsNilVariant() throws {
    let vm = makeModel()
    #expect(vm.setWeekVariantCount(2, confirmed: false) == nil)
    vm.shownVariant = .a
    let both = Fixtures.entry(.monday, 1, "7a", "Deutsch")
    #expect(vm.initialVariant(editing: both) == nil)
    #expect(vm.initialVariant(editing: Fixtures.entry(.monday, 1, "7a", "Deutsch", .b)) == .b)
    // Neuer Eintrag: gezeigte Variante als Vorgabe.
    #expect(vm.initialVariant(editing: nil) == .a)
  }
}

