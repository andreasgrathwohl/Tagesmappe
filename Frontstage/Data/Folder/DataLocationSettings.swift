import Foundation
import FrontstageCore

/// Datenordner (Glossar): der Ordner der App in OneDrive, auf diesem Gerät gemerkt.
struct DataFolder: Codable, Hashable, Sendable {
  var driveID: String
  var folderItemID: String
  var libraryID: UUID
  var accountUsername: String
}

/// Datenort und Datenordner je Gerät (UserDefaults `dataLocation`, `dataFolder`); ohne Wahl iCloud
/// (Entscheidung 10). Gespeichert wird nie ein Token, nur Kennungen.
///
/// Swift-Hinweis: `nonmutating set` erlaubt das Schreiben auch über eine `let`-Konstante, weil die
/// Werte nicht in der Struktur, sondern in `UserDefaults` (einem Referenztyp) liegen.
struct DataLocationSettings {
  private static let locationKey = "dataLocation"
  private static let folderKey = "dataFolder"

  private let defaults: UserDefaults

  init(defaults: UserDefaults = .standard) {
    self.defaults = defaults
  }

  var location: DataLocation {
    get {
      defaults.string(forKey: Self.locationKey).flatMap(DataLocation.init(rawValue:)) ?? .iCloud
    }
    nonmutating set { defaults.set(newValue.rawValue, forKey: Self.locationKey) }
  }

  var dataFolder: DataFolder? {
    get {
      guard let data = defaults.data(forKey: Self.folderKey) else { return nil }
      return try? JSONDecoder().decode(DataFolder.self, from: data)
    }
    nonmutating set {
      if let newValue, let data = try? JSONEncoder().encode(newValue) {
        defaults.set(data, forKey: Self.folderKey)
      } else {
        defaults.removeObject(forKey: Self.folderKey)
      }
    }
  }

  /// Ob auf diesem Gerät schon ein Datenort gewählt wurde (sonst gilt der Vorgabewert iCloud).
  var hasChosen: Bool { defaults.string(forKey: Self.locationKey) != nil }
}
