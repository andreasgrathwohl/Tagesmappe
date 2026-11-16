import Foundation

/// Prüft Hostnamen auf Platzhalter; gemeinsam für Mailadresse und Dienstadresse.
enum FeedbackHostRules {
  private static let reservedNames: Set<String> = ["example.com", "example.org", "example.net", "localhost"]
  private static let reservedSuffixes = [".example.com", ".example.org", ".example.net", ".example", ".invalid", ".local", ".test"]

  /// `true`, wenn der Host einen Punkt hat und keine Platzhalter-Domain ist.
  static func isUsable(_ host: String) -> Bool {
    let h = host.lowercased()
    guard h.contains("."), !reservedNames.contains(h) else { return false }
    return !reservedSuffixes.contains { h.hasSuffix($0) }
  }
}

/// Empfangsadresse der Rückmeldung (Build-Einstellung); unbrauchbare Werte ergeben `nil`.
public enum FeedbackRecipient {
  public static func resolve(_ raw: String?) -> String? {
    guard let raw else { return nil }
    let value = raw.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !value.isEmpty,
          !value.contains(where: { $0.isWhitespace }),
          !value.contains("$(") else { return nil }
    let parts = value.split(separator: "@", omittingEmptySubsequences: false)
    guard parts.count == 2, !parts[0].isEmpty, !parts[1].isEmpty else { return nil }
    guard FeedbackHostRules.isUsable(String(parts[1])) else { return nil }
    return value
  }
}
