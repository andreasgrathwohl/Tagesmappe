import Foundation

/// Baustein eines Hilfetexts. Inline-Markdown bleibt unverändert im String.
public enum HelpBlock: Hashable, Sendable {
  case heading(String), paragraph(String), bullets([String]), steps([String]), note(String)
}

public enum HelpBodyError: Error, Hashable, Sendable {
  case empty
  /// `#`, `###` usw. am Zeilenanfang (1-basierte Zeilennummer).
  case unsupportedHeading(line: Int)
}

/// Zerlegt den Artikeltext in Blöcke. Unterstützt: `## Titel`, `- Punkt`, `1. Schritt`, `> Hinweis`.
public enum HelpBodyParser {
  public static func parse(_ text: String) throws -> [HelpBlock] {
    if text.allSatisfy(\.isWhitespace) { throw HelpBodyError.empty }

    // "\r\n" ist in Swift ein einzelnes Character; `isNewline` erfasst es und "\n".
    let lines = text.split(omittingEmptySubsequences: false, whereSeparator: \.isNewline).map(String.init)

    var blocks: [HelpBlock] = []
    var kind: Kind?
    var items: [String] = []

    func flush() {
      defer { kind = nil; items = [] }
      guard let kind else { return }
      switch kind {
      case .paragraph: blocks.append(.paragraph(items.joined(separator: " ")))
      case .bullets: blocks.append(.bullets(items))
      case .steps: blocks.append(.steps(items))
      case .note: blocks.append(.note(items.joined(separator: " ")))
      }
    }

    func add(_ newKind: Kind, _ item: String) {
      if kind != newKind { flush(); kind = newKind }
      items.append(item)
    }

    for (index, raw) in lines.enumerated() {
      let line = raw.trimmingCharacters(in: .whitespaces)
      if line.isEmpty { flush(); continue }
      if line.hasPrefix("##") && !line.hasPrefix("###") && line.dropFirst(2).first == " " {
        flush()
        blocks.append(.heading(String(line.dropFirst(3)).trimmingCharacters(in: .whitespaces)))
      } else if line.hasPrefix("#") {
        throw HelpBodyError.unsupportedHeading(line: index + 1)
      } else if line.hasPrefix("- ") {
        add(.bullets, String(line.dropFirst(2)).trimmingCharacters(in: .whitespaces))
      } else if let rest = stepText(line) {
        add(.steps, rest)
      } else if line.hasPrefix(">") {
        add(.note, String(line.dropFirst(1)).trimmingCharacters(in: .whitespaces))
      } else {
        add(.paragraph, line)
      }
    }
    flush()
    return blocks
  }

  private enum Kind { case paragraph, bullets, steps, note }

  /// Text hinter `<Ziffern>. `, sonst `nil`.
  private static func stepText(_ line: String) -> String? {
    let digits = line.prefix(while: { $0.isASCII && $0.isNumber })
    guard !digits.isEmpty else { return nil }
    let rest = line.dropFirst(digits.count)
    guard rest.hasPrefix(". ") else { return nil }
    return String(rest.dropFirst(2)).trimmingCharacters(in: .whitespaces)
  }
}
