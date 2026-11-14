import Foundation
import Testing

@testable import FrontstageCore

@Suite("Gerätebezogene Regeln der Stundenplan-Quelle")
struct SourceDeviceRulesTests {
  private let mo1 = entry(.monday, 1, "8b", "Mathe")
  private let di2 = entry(.tuesday, 2, "9c", "Deutsch", variant: .a)
  private let bell = BellSchedule(periods: [1: t(7, 45)...t(8, 30), 2: t(8, 35)...t(9, 20)])

  // MARK: - Zugangsdaten verwerfen (Nachtrag 1)

  @Test("Falsche Zugangsdaten und mehrere Schulen verwerfen die Zugangsdaten, Netzfehler nicht")
  func discardingErrors() {
    #expect(TimetableSourceError.invalidCredentials.discardsCredentials)
    #expect(TimetableSourceError.multipleSchoolsUnsupported.discardsCredentials)
    #expect(!TimetableSourceError.offline.discardsCredentials)
    #expect(!TimetableSourceError.server(status: 503).discardsCredentials)
    #expect(!TimetableSourceError.unexpectedResponse("x").discardsCredentials)
    #expect(!TimetableSourceError.notConfigured.discardsCredentials)
  }

  // MARK: - Abfrage nur mit Zugangsdaten auf diesem Gerät (Nachtrag 4)

  @Test("Von Hand: keine Quelle, unabhängig von Zugangsdaten")
  func manualHasNoSource() {
    #expect(SourceRefreshGate.evaluate(kind: .manual, hasCredentials: true) == .noSource)
    #expect(SourceRefreshGate.evaluate(kind: .manual, hasCredentials: false) == .noSource)
  }

  @Test("Schulmanager ohne Zugangsdaten auf diesem Gerät: Anmeldung nötig, keine Abfrage")
  func schulmanagerNeedsCredentials() {
    #expect(
      SourceRefreshGate.evaluate(kind: .schulmanager, hasCredentials: false) == .signInRequired)
    #expect(SourceRefreshGate.evaluate(kind: .schulmanager, hasCredentials: true) == .ready)
  }

  // MARK: - Prüfsumme des Stundenplan-Teils (Nachtrag 2)

  @Test("Prüfsumme hängt nicht von der Reihenfolge der Einträge ab")
  func checksumIgnoresOrder() {
    #expect(
      TimetablePartChecksum.of(entries: [mo1, di2], bellSchedule: bell)
        == TimetablePartChecksum.of(entries: [di2, mo1], bellSchedule: bell))
  }

  @Test("Prüfsumme ist stabil (gleiche Eingabe, gleicher Text) und 16 Hexziffern lang")
  func checksumIsStable() {
    let first = TimetablePartChecksum.of(entries: [mo1], bellSchedule: bell)
    #expect(first == TimetablePartChecksum.of(entries: [mo1], bellSchedule: bell))
    #expect(first.count == 16)
  }

  @Test("Prüfsumme ändert sich mit Einträgen, Wochenvariante und Zeitraster")
  func checksumReactsToContent() {
    let base = TimetablePartChecksum.of(entries: [mo1], bellSchedule: bell)
    #expect(base != TimetablePartChecksum.of(entries: [mo1, di2], bellSchedule: bell))
    #expect(
      base
        != TimetablePartChecksum.of(
          entries: [entry(.monday, 1, "8b", "Mathe", variant: .b)], bellSchedule: bell))
    #expect(
      base
        != TimetablePartChecksum.of(
          entries: [mo1], bellSchedule: BellSchedule(periods: [1: t(7, 50)...t(8, 35)])))
    #expect(base != TimetablePartChecksum.of(entries: [mo1], bellSchedule: nil))
  }

  @Test("Schreibweise des Fachs zählt nicht (Vergleich wie im Stundenplan, normalisiert)")
  func checksumUsesNormalizedNames() {
    #expect(
      TimetablePartChecksum.of(entries: [entry(.monday, 1, "8 B", "mathe")], bellSchedule: nil)
        == TimetablePartChecksum.of(entries: [mo1], bellSchedule: nil))
  }

  @Test("Leeres Zeitraster gilt wie keines (es ersetzt nie das von Hand gepflegte)")
  func emptyBellEqualsNone() {
    #expect(
      TimetablePartChecksum.of(entries: [mo1], bellSchedule: BellSchedule())
        == TimetablePartChecksum.of(entries: [mo1], bellSchedule: nil))
  }

  @Test("Prüfsumme eines Stands: nur bei abgeleitetem Wochenplan, Abweichungen zählen nicht")
  func snapshotChecksum() {
    func snapshot(_ timetable: TimetableDerivationOutcome, changes: [SourceChange] = [])
      -> SourceSnapshot
    {
      SourceSnapshot(
        kind: .schulmanager, fetchedAt: Date(timeIntervalSince1970: 0),
        range: d(2026, 11, 16)...d(2026, 12, 13), timetable: timetable, bellSchedule: bell,
        changes: changes)
    }
    let derived = TimetableDerivationOutcome.derived(
      DerivedTimetable(entries: [mo1], weekVariantCount: 1, referenceWeekA: nil))
    #expect(TimetablePartChecksum.of(snapshot(.noLessonsInRange)) == nil)
    #expect(
      TimetablePartChecksum.of(snapshot(derived))
        == TimetablePartChecksum.of(entries: [mo1], bellSchedule: bell))
    let change = SourceChange.cancelled(
      date: d(2026, 11, 17), period: 1, schoolClass: SchoolClass("8b"), subject: Subject("Mathe"))
    #expect(
      TimetablePartChecksum.of(snapshot(derived, changes: [change]))
        == TimetablePartChecksum.of(snapshot(derived)))
  }

  // MARK: - Gemerkte Vorschau (Nachtrag 2)

  @Test("Gleiche Prüfsumme wie gemerkt: keine Vorschau, Merker bleibt")
  func rememberedChecksumSuppresses() {
    let offer = PendingPreviewRules.offer(hasDifferences: true, checksum: "abc", remembered: "abc")
    #expect(offer == PendingPreviewRules.Offer(showsPreview: false, rememberedChecksum: "abc"))
  }

  @Test("Neuer Unterschied: Vorschau wieder zeigen, Merker fällt weg")
  func newDifferenceShowsAgain() {
    let offer = PendingPreviewRules.offer(hasDifferences: true, checksum: "def", remembered: "abc")
    #expect(offer == PendingPreviewRules.Offer(showsPreview: true, rememberedChecksum: nil))
  }

  @Test("Anderer Stand ohne Unterschied: keine Vorschau, Merker fällt weg")
  func otherStandWithoutDifferenceForgets() {
    let offer = PendingPreviewRules.offer(hasDifferences: false, checksum: "def", remembered: "abc")
    #expect(offer == PendingPreviewRules.Offer(showsPreview: false, rememberedChecksum: nil))
  }

  @Test("Ohne abgeleiteten Wochenplan (keine Prüfsumme): Merker bleibt")
  func noChecksumKeepsMemory() {
    let offer = PendingPreviewRules.offer(hasDifferences: false, checksum: nil, remembered: "abc")
    #expect(offer == PendingPreviewRules.Offer(showsPreview: false, rememberedChecksum: "abc"))
  }

  @Test("Übernahme mit „Meine Fassung behalten“ merkt die Prüfsumme, volle Übernahme nicht")
  func rememberAfterApply() {
    let source = entry(.monday, 1, "8b", "Physik")
    #expect(
      PendingPreviewRules.rememberedAfterApply(
        checksum: "abc", conflictSources: [source], acceptedFromSource: []) == "abc")
    #expect(
      PendingPreviewRules.rememberedAfterApply(
        checksum: "abc", conflictSources: [source], acceptedFromSource: [source]) == nil)
    #expect(
      PendingPreviewRules.rememberedAfterApply(
        checksum: "abc", conflictSources: [], acceptedFromSource: []) == nil)
  }

  // MARK: - Überholte Vorschau (Nachtrag 3)

  @Test("Vorschau ist überholt, wenn der gespiegelte Stand neuer ist")
  func supersededPreview() {
    let t0 = Date(timeIntervalSince1970: 1_000)
    #expect(
      PendingPreviewRules.isSuperseded(previewFetchedAt: t0, storedFetchedAt: t0.addingTimeInterval(1)))
    #expect(!PendingPreviewRules.isSuperseded(previewFetchedAt: t0, storedFetchedAt: t0))
    #expect(
      !PendingPreviewRules.isSuperseded(previewFetchedAt: t0, storedFetchedAt: t0.addingTimeInterval(-1)))
    #expect(!PendingPreviewRules.isSuperseded(previewFetchedAt: t0, storedFetchedAt: nil))
  }
}
