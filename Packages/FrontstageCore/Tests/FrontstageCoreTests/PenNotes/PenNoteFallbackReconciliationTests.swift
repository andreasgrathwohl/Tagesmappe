import Foundation
import Testing

@testable import FrontstageCore

struct PenNoteFallbackReconciliationTests {
  let early = Date(timeIntervalSince1970: 1_800_000_000)
  let late = Date(timeIntervalSince1970: 1_800_000_600)

  @Test("Ersatz-Seite, die in der Datei fehlt, wird in die Datei geschrieben")
  func missingInFileIsWritten() {
    let plan = PenNoteFallbackReconciliation.plan(fileUpdatedAt: [:], fallbackUpdatedAt: [0: early])
    #expect(plan.pagesToWrite == [0])
    #expect(plan.obsoleteFallbackPages.isEmpty)
  }

  @Test("Neuere Ersatz-Seite gewinnt gegen die Datei (Schreiben beim Schließen gescheitert)")
  func newerFallbackWins() {
    let plan = PenNoteFallbackReconciliation.plan(fileUpdatedAt: [1: early], fallbackUpdatedAt: [1: late])
    #expect(plan.pagesToWrite == [1])
    #expect(plan.obsoleteFallbackPages.isEmpty)
  }

  @Test("Datei gleich alt oder neuer: Ersatz-Seite ist überholt und wird gelöscht")
  func fileSameOrNewerMakesFallbackObsolete() {
    let plan = PenNoteFallbackReconciliation.plan(
      fileUpdatedAt: [0: early, 1: late], fallbackUpdatedAt: [0: early, 1: early])
    #expect(plan.pagesToWrite.isEmpty)
    #expect(plan.obsoleteFallbackPages == [0, 1])
  }

  @Test("Seiten nur in der Datei bleiben unberührt")
  func fileOnlyPagesAreIgnored() {
    let plan = PenNoteFallbackReconciliation.plan(fileUpdatedAt: [3: early], fallbackUpdatedAt: [:])
    #expect(plan == PenNoteFallbackReconciliation.Plan(pagesToWrite: [], obsoleteFallbackPages: []))
  }

  @Test("Gemischt: je Seite entscheidet der neuere Stand")
  func decidesPerPage() {
    let plan = PenNoteFallbackReconciliation.plan(
      fileUpdatedAt: [0: late, 1: early, 2: early], fallbackUpdatedAt: [0: early, 1: late, 4: early])
    #expect(plan.pagesToWrite == [1, 4])
    #expect(plan.obsoleteFallbackPages == [0])
  }

  @Test("Nach erfolgreichem Schreiben sind auch die geschriebenen Ersatz-Seiten löschbar")
  func removableAfterWriteIncludesWrittenPages() {
    let plan = PenNoteFallbackReconciliation.plan(
      fileUpdatedAt: [0: late, 1: early], fallbackUpdatedAt: [0: early, 1: late])
    #expect(plan.removableAfterSuccessfulWrite == [0, 1])
  }
}
