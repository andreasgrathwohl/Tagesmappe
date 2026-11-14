import Foundation

/// Kennung dieses Geräts für den Abgleich (UserDefaults `deviceID`); wird beim ersten Aufruf erzeugt.
enum DeviceIdentity {
  private static let key = "deviceID"

  static func current(defaults: UserDefaults = .standard) -> String {
    if let existing = defaults.string(forKey: key), !existing.isEmpty { return existing }
    let created = UUID().uuidString
    defaults.set(created, forKey: key)
    return created
  }
}
