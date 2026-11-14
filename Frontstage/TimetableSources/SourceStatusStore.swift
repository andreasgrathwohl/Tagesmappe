import Foundation
import FrontstageCore

/// Merkt sich den Stand der Quelle (Zeitpunkte, Fehlzähler) nur auf diesem Gerät in `UserDefaults`.
/// `SourceStatus` enthält nie Zugangsdaten oder Token – nur Zeiten, Zähler und den Fehlertyp.
struct SourceStatusStore {
  private static let key = "timetableSource.status"
  private let defaults: UserDefaults

  init(defaults: UserDefaults = .standard) {
    self.defaults = defaults
  }

  /// Fehlt der Eintrag oder ist er unlesbar → leerer Stand.
  func load() -> SourceStatus {
    guard let data = defaults.data(forKey: Self.key),
      let status = try? JSONDecoder().decode(SourceStatus.self, from: data)
    else { return SourceStatus() }
    return status
  }

  func save(_ status: SourceStatus) {
    guard let data = try? JSONEncoder().encode(status) else { return }
    defaults.set(data, forKey: Self.key)
  }
}
