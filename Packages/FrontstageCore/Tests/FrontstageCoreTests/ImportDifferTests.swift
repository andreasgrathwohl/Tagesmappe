import Testing
@testable import FrontstageCore

@Suite("ImportDiffer")
struct ImportDifferTests {
  @Test("Import ergänzt neue Einträge und lässt von Hand angelegte unberührt (AK-3)")
  func importAddsEntriesKeepsManual() {
    let mine = entry(.monday, 1, "7a", "Deutsch")
    let imported = [
      entry(.tuesday, 2, "8b", "Englisch"),
      entry(.wednesday, 3, "9c", "Mathe"),
      entry(.thursday, 1, "6c", "Bio"),
    ]
    let diff = ImportDiffer.compare(existing: [mine], manuallyEdited: [mine], imported: imported)
    #expect(diff.added == imported)
    #expect(diff.removed.isEmpty)
    #expect(diff.changed.isEmpty)
    #expect(diff.manualConflicts.isEmpty)
  }

  @Test("Identischer Import ergibt einen leeren Diff (AK-3)")
  func identicalImportIsEmpty() {
    let list = [entry(.monday, 1, "7a", "Deutsch"), entry(.tuesday, 2, "8b", "Englisch")]
    let diff = ImportDiffer.compare(existing: list, manuallyEdited: [list[0]], imported: list)
    #expect(diff.isEmpty)
  }

  @Test("Abweichung am selben Platz bei Quell-Eintrag ist eine Änderung (AK-3)")
  func sourceEntryChangedAtSameSlot() {
    let old = entry(.tuesday, 2, "8b", "Englisch")
    let new = entry(.tuesday, 2, "8a", "Englisch")
    let diff = ImportDiffer.compare(existing: [old], manuallyEdited: [], imported: [new])
    #expect(diff.changed.map(\.old) == [old])
    #expect(diff.changed.map(\.new) == [new])
    #expect(diff.added.isEmpty)
    #expect(diff.removed.isEmpty)
    #expect(diff.manualConflicts.isEmpty)
  }

  @Test("Abweichung am selben Platz bei Hand-Eintrag ist ein Konflikt (AK-3)")
  func manualEntryConflictsAtSameSlot() {
    let mine = entry(.tuesday, 2, "8b", "Englisch")
    let source = entry(.tuesday, 2, "8a", "Englisch")
    let diff = ImportDiffer.compare(existing: [mine], manuallyEdited: [mine], imported: [source])
    #expect(diff.manualConflicts.map(\.mine) == [mine])
    #expect(diff.manualConflicts.map(\.source) == [source])
    #expect(diff.changed.isEmpty)
    #expect(diff.added.isEmpty)
    #expect(diff.removed.isEmpty)
  }

  @Test("Fehlender Quell-Eintrag wird als entfernt gemeldet (AK-3)")
  func missingSourceEntryIsRemoved() {
    let gone = entry(.friday, 5, "9c", "Mathe")
    let diff = ImportDiffer.compare(existing: [gone], manuallyEdited: [], imported: [])
    #expect(diff.removed == [gone])
    #expect(diff.added.isEmpty)
    #expect(diff.changed.isEmpty)
  }

  @Test("Andere Schreibweise derselben Klasse und desselben Fachs ist keine Änderung (AK-3)")
  func normalizedNamesAreNoChange() {
    let existing = entry(.tuesday, 2, "8b", "Englisch")
    let imported = entry(.tuesday, 2, "8 b", "englisch")
    let diff = ImportDiffer.compare(existing: [existing], manuallyEdited: [], imported: [imported])
    #expect(diff.isEmpty)
  }

  @Test("Doppelte importierte Einträge zählen einmal (AK-3)")
  func duplicateImportedEntriesCountOnce() {
    let e = entry(.tuesday, 2, "8b", "Englisch")
    let diff = ImportDiffer.compare(existing: [], manuallyEdited: [], imported: [e, e])
    #expect(diff.added.count == 1)
  }

  @Test("Von Hand angelegte und von Hand geänderte Einträge erscheinen nie in removed oder changed (AK-3)")
  func manualEntriesNeverRemovedOrChanged() {
    let manualCreated = entry(.monday, 1, "7a", "Deutsch")
    let manualChanged = entry(.tuesday, 2, "8b", "Englisch")
    let untouched = entry(.wednesday, 3, "9c", "Mathe")
    let source = entry(.tuesday, 2, "8a", "Englisch")
    let diff = ImportDiffer.compare(
      existing: [manualCreated, manualChanged, untouched],
      manuallyEdited: [manualCreated, manualChanged],
      imported: [source, untouched])
    #expect(diff.removed.isEmpty)
    #expect(diff.changed.isEmpty)
    #expect(diff.added.isEmpty)
    #expect(diff.manualConflicts.map(\.mine) == [manualChanged])
    #expect(diff.manualConflicts.map(\.source) == [source])
  }

  @Test("Listen sind nach Wochentag, Stunde und Woche sortiert (AK-3)")
  func resultsAreSorted() {
    let imported = [
      entry(.tuesday, 2, "8b", "Englisch", variant: .b),
      entry(.tuesday, 2, "8b", "Englisch", variant: .a),
      entry(.tuesday, 2, "8b", "Englisch"),
      entry(.monday, 4, "7a", "Bio"),
    ]
    let diff = ImportDiffer.compare(existing: [], manuallyEdited: [], imported: imported)
    #expect(diff.added == [imported[3], imported[2], imported[1], imported[0]])
  }
}
