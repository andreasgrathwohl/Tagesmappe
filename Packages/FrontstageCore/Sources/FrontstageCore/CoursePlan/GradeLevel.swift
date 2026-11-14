/// Jahrgang (Glossar), 1...13.
public struct GradeLevel: Hashable, Comparable, Codable, Sendable {
  public let value: Int

  public init?(_ value: Int) {
    guard (1...13).contains(value) else { return nil }
    self.value = value
  }

  public static func < (lhs: GradeLevel, rhs: GradeLevel) -> Bool { lhs.value < rhs.value }

  /// Erste Ziffernfolge in `normalized` („8b“ → 8, „q11“ → 11); ohne Ziffern oder außerhalb
  /// 1...13 → nil.
  public static func derived(from schoolClass: SchoolClass) -> GradeLevel? {
    let digits = schoolClass.normalized
      .drop { !($0.isASCII && $0.isNumber) }
      .prefix { $0.isASCII && $0.isNumber }
    guard !digits.isEmpty, let number = Int(digits) else { return nil }
    return GradeLevel(number)
  }

  /// Abgeleitet, sonst `overrides[schoolClass.normalized]`, sonst nil.
  public static func resolve(_ schoolClass: SchoolClass, overrides: [String: Int]) -> GradeLevel? {
    if let derived = derived(from: schoolClass) { return derived }
    return overrides[schoolClass.normalized].flatMap { GradeLevel($0) }
  }
}
