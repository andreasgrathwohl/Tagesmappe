import Foundation

/// Adresse des Rückmeldedienstes: nur https, keine Platzhalter-Domains, ohne Pfad, Abfrage oder Fragment.
public struct FeedbackServiceEndpoint: Hashable, Sendable {
  public let baseURL: URL

  private init(baseURL: URL) { self.baseURL = baseURL }

  /// „https://x.de/“ ergibt die Basis „https://x.de“; alles Unbrauchbare ergibt `nil`.
  public static func resolve(_ raw: String?) -> FeedbackServiceEndpoint? {
    guard let raw else { return nil }
    let value = raw.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !value.isEmpty, !value.contains("$("),
          !value.contains(where: { $0.isWhitespace }),
          let parts = URLComponents(string: value),
          parts.scheme?.lowercased() == "https",
          let host = parts.host, FeedbackHostRules.isUsable(host),
          parts.user == nil, parts.password == nil,
          parts.query == nil, parts.fragment == nil,
          parts.path.isEmpty || parts.path == "/" else { return nil }
    var base = URLComponents()
    base.scheme = "https"
    base.host = host
    base.port = parts.port
    guard let url = base.url else { return nil }
    return FeedbackServiceEndpoint(baseURL: url)
  }

  public var feedbackURL: URL { baseURL.appendingPathComponent("api/v1/feedback") }
  public var privacyURL: URL { baseURL.appendingPathComponent("datenschutz") }
}
