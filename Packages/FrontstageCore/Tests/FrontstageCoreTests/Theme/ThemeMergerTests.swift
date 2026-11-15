import Foundation
import Testing
@testable import FrontstageCore

@Suite("Theme Merge")
struct ThemeMergerTests {
  private func id(_ n: Int) -> UUID {
    let digits = String(n)
    let padded = String(repeating: "0", count: 12 - digits.count) + digits
    return UUID(uuidString: "00000000-0000-0000-0000-\(padded)")!
  }

  private func date(_ seconds: Double) -> Date { Date(timeIntervalSince1970: 1_795_000_000 + seconds) }

  @Test("Ein Datensatz: nichts zu tun")
  func singleRecordNeedsNothing() {
    let plan = ThemeMerger.plan(for: [ThemeMergeEntry(id: id(1), createdAt: date(0), updatedAt: date(0))])
    #expect(plan.isEmpty)
    #expect(plan.deletions.isEmpty)
    #expect(ThemeMerger.plan(for: []).isEmpty)
  }

  @Test("Zwei Geräte: ältester bleibt, Inhalt des zuletzt geänderten")
  func keepsOldestRecordWithNewestContent() {
    let older = ThemeMergeEntry(id: id(2), createdAt: date(0), updatedAt: date(10))
    let newer = ThemeMergeEntry(id: id(1), createdAt: date(5), updatedAt: date(50))
    let plan = ThemeMerger.plan(for: [newer, older])
    #expect(plan.keeperID == id(2))
    #expect(plan.contentSourceID == id(1))
    #expect(plan.deletions == [id(1)])
    #expect(!plan.isEmpty)
  }

  @Test("Gleiche Anlagezeit: kleinere Kennung bleibt")
  func tieOnCreatedAtUsesSmallerID() {
    let first = ThemeMergeEntry(id: id(3), createdAt: date(0), updatedAt: date(0))
    let second = ThemeMergeEntry(id: id(1), createdAt: date(0), updatedAt: date(0))
    let plan = ThemeMerger.plan(for: [first, second])
    #expect(plan.keeperID == id(1))
    #expect(plan.contentSourceID == id(1))
    #expect(plan.deletions == [id(3)])
  }
}
