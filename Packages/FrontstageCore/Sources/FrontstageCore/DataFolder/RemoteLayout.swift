import Foundation

/// Was eine Datei im Datenordner ist. Pfade relativ zum App-Ordner, Trenner "/".
public enum RemoteEntry: Hashable, Sendable {
  /// `library.json`
  case library
  /// `<Modell>/<Kennung>.json`
  case record(model: SyncModel, id: UUID)
  /// `<Modell>/<Kennung><Zusatz>.json`, z. B. von einer Synchronisierung angelegt
  case conflictCopy(model: SyncModel, id: UUID)
  /// `<Modell>/<Kennung>.<Feld>.<Hash>.bin`
  case attachment(model: SyncModel, id: UUID, field: String, hash: String)
  /// Anderes `<Kennung>`-Präfix mit Endung `.bin`; wird entfernt.
  case attachmentCopy(model: SyncModel, id: UUID)
}

public enum RemoteLayout {
  public static let libraryPath = "library.json"

  /// Länge einer UUID als Text ("8-4-4-4-12").
  private static let uuidLength = 36

  public static func recordPath(model: SyncModel, id: UUID) -> String {
    "\(model.rawValue)/\(id.uuidString).json"
  }

  public static func attachmentPath(model: SyncModel, id: UUID, field: String, hash: String) -> String {
    "\(model.rawValue)/\(id.uuidString).\(field).\(hash).bin"
  }

  /// `nil` = fremde Datei (z. B. von der Lehrkraft abgelegt) – wird nie angefasst.
  public static func classify(path: String) -> RemoteEntry? {
    if path == libraryPath { return .library }

    let parts = path.split(separator: "/", omittingEmptySubsequences: false)
    guard parts.count == 2, let model = SyncModel(rawValue: String(parts[0])) else { return nil }
    let name = String(parts[1])

    // Die ersten 36 Zeichen müssen eine UUID sein (Groß-/Kleinschreibung egal).
    guard name.count > uuidLength else { return nil }
    let idText = String(name.prefix(uuidLength))
    guard let id = UUID(uuidString: idText) else { return nil }
    let rest = String(name.dropFirst(uuidLength))

    if rest.hasSuffix(".json") {
      let extra = rest.dropLast(".json".count)
      return extra.isEmpty ? .record(model: model, id: id) : .conflictCopy(model: model, id: id)
    }
    if rest.hasSuffix(".bin") {
      // Erwartet: ".<Feld>.<Hash>" – genau zwei nicht leere Teile.
      let middle = rest.dropLast(".bin".count)
      if middle.hasPrefix(".") {
        let pieces = middle.dropFirst().split(separator: ".", omittingEmptySubsequences: false)
        if pieces.count == 2, !pieces[0].isEmpty, !pieces[1].isEmpty {
          return .attachment(model: model, id: id, field: String(pieces[0]), hash: String(pieces[1]))
        }
      }
      return .attachmentCopy(model: model, id: id)
    }
    return nil
  }

  /// Nur Pfade, die `classify` erkennt; kein "..", kein führendes "/", keine weiteren Ebenen.
  public static func isValidPath(_ path: String) -> Bool {
    guard !path.hasPrefix("/"), !path.contains(".."), !path.contains("\\") else { return false }
    return classify(path: path) != nil
  }
}
