import Foundation

/// Gekoppeltes Blättern der Lösung neben dem Blatt (FR-6.3, UI-17).
public enum SolutionPaging {
  /// Seite der Lösung (ab 0) zur Seite des Blatts: dieselbe, bei weniger Seiten die letzte; ohne Seiten 0.
  public static func coupledPage(sheetPage: Int, solutionPageCount: Int) -> Int {
    guard solutionPageCount > 0 else { return 0 }
    return min(max(sheetPage, 0), solutionPageCount - 1)
  }
}
