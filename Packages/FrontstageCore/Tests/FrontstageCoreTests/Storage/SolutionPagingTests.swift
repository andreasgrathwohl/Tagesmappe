import Testing
@testable import FrontstageCore

@Suite("SolutionPaging")
struct SolutionPagingTests {
  @Test("Gekoppelt: gleiche Seite, sonst die letzte der Lösung")
  func coupledPageClamps() {
    #expect(SolutionPaging.coupledPage(sheetPage: 1, solutionPageCount: 2) == 1)
    #expect(SolutionPaging.coupledPage(sheetPage: 2, solutionPageCount: 2) == 1)
    #expect(SolutionPaging.coupledPage(sheetPage: 3, solutionPageCount: 0) == 0)
    #expect(SolutionPaging.coupledPage(sheetPage: -1, solutionPageCount: 3) == 0)
  }
}
