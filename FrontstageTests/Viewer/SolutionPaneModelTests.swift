import Foundation
import FrontstageCore
import Testing

@testable import Frontstage

/// Lösung neben dem Blatt (FR-6.3, UI-17): Laden, gekoppeltes Blättern, Spiegelungsschutz.
@MainActor @Suite struct SolutionPaneModelTests {
  private let solution = MaterialReference(
    folderGrantName: "Unterricht", relativePath: "AB Bruchrechnen – Lösung.pdf",
    displayName: "AB Bruchrechnen – Lösung", fileKind: .pdf)

  private func loadedModel(pages: Int = 2) async throws -> SolutionPaneModel {
    let model = SolutionPaneModel(
      reference: solution, fileReader: StubReader(data: TestDocuments.pdfData(pages: pages, size: .a4), error: nil))
    await model.load()
    return model
  }

  @Test("Lösung lädt; gekoppelt folgt sie dem Blatt bis zu ihrer letzten Seite")
  func loadsSolutionAndCouplesPages() async throws {
    let model = try await loadedModel()
    #expect(model.phase == .ready)
    #expect(model.pageCount == 2)
    model.sheetPageChanged(to: 1)
    #expect(model.pageIndex == 1)
    model.sheetPageChanged(to: 2)
    #expect(model.pageIndex == 1)
  }

  @Test("Eigenes Blättern löst die Kopplung")
  func ownPagingDecouples() async throws {
    let model = try await loadedModel()
    model.sheetPageChanged(to: 1)
    model.goToPage(0)
    #expect(!model.isCoupled)
    model.sheetPageChanged(to: 1)
    #expect(model.pageIndex == 0)
    model.goToPage(5)
    #expect(model.pageIndex == 1)
  }

  @Test("Kopplung wieder an springt auf die Seite des Blatts")
  func recouplingJumpsToSheetPage() async throws {
    let model = try await loadedModel()
    model.goToPage(0)
    model.toggleCoupling(sheetPage: 1)
    #expect(model.isCoupled)
    #expect(model.pageIndex == 1)
  }

  @Test("Review Focus 2: unlesbare Lösung → nicht verfügbar")
  func unreadableSolutionIsUnavailable() async {
    let model = SolutionPaneModel(reference: solution, fileReader: StubReader(data: Data(), error: StubError.unresolvable))
    await model.load()
    #expect(model.phase == .unavailable)
  }

  @Test("Review Focus 1: gespiegelt ausgeblendet, außer auf Wunsch; ausgeblendet bleibt ausgeblendet")
  func mirroringHidesUnlessOverridden() {
    let visibility = SolutionVisibility()
    #expect(visibility.isVisible(isMirrored: false))
    #expect(!visibility.isVisible(isMirrored: true))
    visibility.overrideMirroring = true
    #expect(visibility.isVisible(isMirrored: true))
    visibility.isShownByUser = false
    #expect(!visibility.isVisible(isMirrored: false))
    visibility.viewerClosed()
    #expect(!visibility.overrideMirroring)
  }

  @Test("AK-69: Der Zweitbildschirm zeigt das Blatt, nie die Lösung")
  func secondScreenNeverGetsSolution() async throws {
    let sheetData = TestDocuments.pdfData(pages: 3, size: .a4)
    let (viewer, _, screen) = try await TestViewer.make(kind: .pdf, data: sheetData)
    await viewer.load()
    let pane = try await loadedModel()
    pane.sheetPageChanged(to: 1)
    #expect(screen.material?.documentData == sheetData)
    #expect(screen.material?.documentData != pane.documentData)
  }
}
