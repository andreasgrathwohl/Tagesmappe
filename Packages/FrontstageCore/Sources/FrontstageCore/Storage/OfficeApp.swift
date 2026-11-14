import Foundation

/// Microsoft-Office-App, an die eine Datei per URI-Schema übergeben wird (FR-5.1).
public enum OfficeApp: String, Codable, Sendable {
  case word, excel, powerpoint

  /// Bestimmt die App aus der Dateiendung (ohne Punkt, Groß-/Kleinschreibung egal); `nil` für Nicht-Microsoft-Formate.
  public init?(fileExtension: String) {
    switch fileExtension.lowercased() {
    case "doc", "docx", "docm": self = .word
    case "xls", "xlsx", "xlsm": self = .excel
    case "ppt", "pptx", "pptm", "pps", "ppsx", "ppsm": self = .powerpoint
    default: return nil
    }
  }

  /// URI-Schema der App laut „Office URI Schemes“.
  public var scheme: String {
    switch self {
    case .word: "ms-word"
    case .excel: "ms-excel"
    case .powerpoint: "ms-powerpoint"
    }
  }

  /// Höchstlänge der Adresse in der Office-URI (Office URI Schemes 1.7): 256 Zeichen, bei Excel 216.
  public var addressLengthLimit: Int {
    self == .excel ? 216 : 256
  }
}
