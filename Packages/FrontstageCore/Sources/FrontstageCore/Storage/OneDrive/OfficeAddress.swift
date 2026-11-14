import Foundation

/// Form der Office-URI: laut Dokumentation oder wie „In Desktop-App öffnen“ im Web.
public enum OfficeURIForm: String, Codable, Sendable {
  case documented, webStyle
}

/// Adressen für das Öffnen einer OneDrive-Datei in der Office-App (FR-5.1).
public enum OfficeAddress {
  /// Privat: `https://d.docs.live.net/<DRIVEID groß>/<Pfad>`; business/documentLibrary: `webUrl` mit `%2C` → `,`; sonst `nil`.
  public static func documentURL(for item: OneDriveItem) -> String? {
    switch item.parentReference.driveType {
    case "personal":
      guard let relative = OneDriveFolderMatching.rootRelativePath(of: item) else { return nil }
      let encoded = relative.split(separator: "/", omittingEmptySubsequences: true)
        .map { encodeSegment(String($0)) }
        .joined(separator: "/")
      return "https://d.docs.live.net/\(item.parentReference.driveId.uppercased())/\(encoded)"
    case "business", "documentLibrary":
      return item.webUrl.replacingOccurrences(of: "%2C", with: ",", options: .caseInsensitive)
    default:
      return nil
    }
  }

  /// Prozentkodiert ein Pfadsegment (NFC); unkodiert bleiben nur `A–Z a–z 0–9 - . _ ~`.
  public static func encodeSegment(_ segment: String) -> String {
    let hex = Array("0123456789ABCDEF")
    var result = ""
    for byte in segment.precomposedStringWithCanonicalMapping.utf8 {
      switch byte {
      case UInt8(ascii: "A")...UInt8(ascii: "Z"), UInt8(ascii: "a")...UInt8(ascii: "z"),
        UInt8(ascii: "0")...UInt8(ascii: "9"), UInt8(ascii: "-"), UInt8(ascii: "."),
        UInt8(ascii: "_"), UInt8(ascii: "~"):
        result.append(Character(UnicodeScalar(byte)))
      default:
        result.append("%")
        result.append(hex[Int(byte >> 4)])
        result.append(hex[Int(byte & 0x0F)])
      }
    }
    return result
  }

  /// Baut die Office-URI (`ms-word:ofe|u|…`); die Web-Form trennt mit `%7C`, damit `URL(string:)` sie nicht verändert.
  public static func officeURI(
    app: OfficeApp, documentURL: String, form: OfficeURIForm,
    origin: UUID, correlation: UUID, timestampMillis: Int64
  ) -> String {
    switch form {
    case .documented:
      return "\(app.scheme):ofe|u|\(documentURL)"
    case .webStyle:
      let fields = [
        "ofe", "or", origin.uuidString.lowercased() + "_0", "ct", String(timestampMillis),
        "cid", correlation.uuidString.lowercased(), "u", documentURL,
      ]
      return "\(app.scheme):" + fields.joined(separator: "%7C")
    }
  }
}
