import Foundation

/// Namen neben dem Dokument (ADR-0011). Alle Namen in NFC; `documentFileName` mit Endung, ohne Pfad.
/// Geschrieben werden nur der Notiz-Ordner, `.json`-Dateien darin und Notiz-PDFs – nie das Original (FR-3.4).
public enum PenNoteFileLayout {
  public static let folderSuffix = ".frontstage-notizen"
  private static let pdfInfix = " – Notizen "  // Halbgeviertstrich U+2013

  /// `Arbeitsblatt Vokabeln.pdf` → `Arbeitsblatt Vokabeln.frontstage-notizen`.
  public static func notesFolderName(documentFileName: String) -> String {
    stem(of: nfc(documentFileName)) + folderSuffix
  }

  /// Stunden-Datei ohne verbotene Dateinamenzeichen (Entscheidung 1):
  /// Schlüsseltext mit `|` → `_` und `%` → `-`, Endung `.json`.
  public static func lessonFileName(for key: LessonKey) -> String {
    fileSafe(key) + ".json"
  }

  /// Ausweichname, wenn die Stunden-Datei einem gleichnamigen Dokument anderer Endung gehört (Entscheidung 2):
  /// `<stamm>.<endung klein>.json`.
  public static func alternateLessonFileName(for key: LessonKey, documentFileName: String) -> String {
    let ext = (extensionOf(nfc(documentFileName)) ?? "").lowercased()
    return ext.isEmpty ? lessonFileName(for: key) : fileSafe(key) + "." + ext + ".json"
  }

  /// Schlüssel aus dem Dateinamen (beide Formen); `nil` für fremde Dateien.
  public static func lessonKey(fromLessonFileName name: String) -> LessonKey? {
    let name = nfc(name)
    guard name.hasSuffix(".json") else { return nil }
    let base = String(name.dropLast(".json".count))
    let parts = base.split(separator: "_", omittingEmptySubsequences: false)
    guard parts.count == 4 else { return nil }
    // Der Ausweichname hängt `.<endung>` an die laufende Nummer.
    let ordinalParts = parts[3].split(separator: ".", maxSplits: 1, omittingEmptySubsequences: false)
    if ordinalParts.count == 2, ordinalParts[1].isEmpty || ordinalParts[1].contains(".") { return nil }
    // Nur Klasse und Fach tragen `-` für `%`; das Datum behält seine Bindestriche.
    let text = [
      String(parts[0]),
      parts[1].replacingOccurrences(of: "-", with: "%"),
      parts[2].replacingOccurrences(of: "-", with: "%"),
      String(ordinalParts[0]),
    ].joined(separator: "|")
    return LessonKey(storageText: text)
  }

  /// `Arbeitsblatt Vokabeln – Notizen 8b 2026-11-17.pdf`; ab der zweiten Stunde des Tages mit ` (2)` (Entscheidung 6).
  public static func notesPDFName(documentFileName: String, key: LessonKey) -> String {
    var name =
      stem(of: nfc(documentFileName)) + pdfInfix + sanitized(key.schoolClass.normalized) + " "
      + key.date.storageText
    if key.ordinal > 1 { name += " (\(key.ordinal))" }
    return name + ".pdf"
  }

  /// Ist `name` ein Notiz-PDF dieses Dokuments? Liefert den Teil hinter „<Name> – Notizen “
  /// (z. B. `8b 2026-11-17.pdf`), sonst `nil`.
  public static func notesPDFSuffix(_ name: String, documentFileName: String) -> String? {
    let name = nfc(name)
    let prefix = stem(of: nfc(documentFileName)) + pdfInfix
    guard name.hasPrefix(prefix), name.hasSuffix(".pdf"), !name.contains("/") else { return nil }
    let rest = String(name.dropFirst(prefix.count))
    return rest.count > ".pdf".count ? rest : nil
  }

  /// `true` nur für den Notiz-Ordner, `.json`-Stunden-Dateien darin und Notiz-PDFs dieses Dokuments
  /// (Pfad relativ zum Ordner des Dokuments). Alles andere – auch das Original – ist nicht schreibbar.
  public static func isNotesPath(_ relativePath: String, documentFileName: String) -> Bool {
    let components = nfc(relativePath).split(separator: "/", omittingEmptySubsequences: false).map(String.init)
    guard !components.contains(where: { $0.isEmpty || $0 == ".." || $0 == "." }) else { return false }
    let folder = notesFolderName(documentFileName: documentFileName)
    switch components.count {
    case 1:
      return components[0] == folder
        || notesPDFSuffix(components[0], documentFileName: documentFileName) != nil
    case 2:
      return components[0] == folder && lessonKey(fromLessonFileName: components[1]) != nil
    default:
      return false
    }
  }

  /// `/ \ : * ? " < > |` → `-`.
  public static func sanitized(_ component: String) -> String {
    String(component.map { "/\\:*?\"<>|".contains($0) ? "-" : $0 })
  }

  // MARK: Hilfen

  private static func nfc(_ text: String) -> String { text.precomposedStringWithCanonicalMapping }

  private static func fileSafe(_ key: LessonKey) -> String {
    key.storageText.replacingOccurrences(of: "|", with: "_").replacingOccurrences(of: "%", with: "-")
  }

  /// Endung = Teil hinter dem letzten Punkt; kein Punkt oder Punkt an Stelle 0 → keine Endung.
  private static func extensionOf(_ fileName: String) -> String? {
    guard let dot = fileName.lastIndex(of: "."), dot != fileName.startIndex else { return nil }
    return String(fileName[fileName.index(after: dot)...])
  }

  private static func stem(of fileName: String) -> String {
    guard let dot = fileName.lastIndex(of: "."), dot != fileName.startIndex else { return fileName }
    return String(fileName[..<dot])
  }
}
