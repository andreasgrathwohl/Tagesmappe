import Foundation

/// Ordnerfreigabe – nur auf diesem Gerät, nie gespiegelt (ADR-0003, ADR-0010).
struct FolderGrant: Identifiable, Codable, Hashable, Sendable {
  var id: UUID
  /// Gespiegelter Name, über den Materialverweise die Freigabe auf jedem Gerät wiederfinden.
  var name: String
  /// Security-scoped Bookmark (macOS) bzw. Minimal-Bookmark (iOS) auf den Ordner.
  var bookmark: Data
  /// Nur zur Anzeige; nie zum Auflösen verwenden.
  var displayPath: String
  /// Pfad relativ zur OneDrive-Wurzel, gesetzt vom OneDrive-Dienst oder von Hand.
  var oneDrivePath: String?
}

enum FolderGrantError: Error, Equatable {
  /// Eine andere Freigabe trägt schon diesen Namen.
  case nameInUse
  /// Das System verweigert den Zugriff auf den gewählten Ordner.
  case accessDenied
  /// Aus dem Ordner ließ sich kein Bookmark erzeugen.
  case bookmarkFailed
}
