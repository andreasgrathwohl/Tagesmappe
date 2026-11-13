import Foundation

/// Dateiart des Materials; entscheidet Anzeige (im eigenen Betrachter) oder Übergabe (an eine andere App).
public enum MaterialFileKind: String, Codable, Sendable, CaseIterable {
  case pdf, image, presentation, document, spreadsheet, other

  /// Bestimmt die Dateiart aus der Endung (ohne Punkt, Groß-/Kleinschreibung egal); Unbekanntes ist `.other`.
  public init(fileExtension: String) {
    switch fileExtension.lowercased() {
    case "pdf": self = .pdf
    case "png", "jpg", "jpeg", "heic", "gif", "tif", "tiff": self = .image
    case "ppt", "pptx", "pps", "ppsx", "key", "odp": self = .presentation
    case "doc", "docx", "pages", "odt", "rtf": self = .document
    case "xls", "xlsx", "numbers", "ods", "csv": self = .spreadsheet
    default: self = .other
    }
  }

  /// Wird im eigenen Betrachter geöffnet statt an eine andere App übergeben.
  public var opensInViewer: Bool {
    self == .pdf || self == .image
  }
}
