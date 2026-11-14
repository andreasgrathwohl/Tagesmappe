@testable import FrontstageCore

/// Schuljahr 2026/27 für Tests: 14.9.2026, zweites Halbjahr ab 1.2.2027, Ende 28.7.2027.
func year2026() -> SchoolYear {
  SchoolYear(firstDay: d(2026, 9, 14), secondTermStart: d(2027, 2, 1), lastDay: d(2027, 7, 28))
}

/// Schuljahr 2025/26 für Tests (grenzt ohne Überschneidung an 2026/27).
func year2025() -> SchoolYear {
  SchoolYear(firstDay: d(2025, 9, 15), secondTermStart: d(2026, 2, 2), lastDay: d(2026, 7, 29))
}
