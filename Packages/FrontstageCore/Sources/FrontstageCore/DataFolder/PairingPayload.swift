import Foundation

/// Inhalt des QR-Codes (Glossar „Koppeln“, `pairing`). Überträgt keinen Zugriff, nur Kennungen.
public struct PairingPayload: Hashable, Sendable {
  public static let currentVersion = 1
  private static let prefix = "frontstage-pair:"

  public var version: Int
  public var dataLocation: DataLocation
  /// Nur OneDrive.
  public var libraryID: UUID?
  /// Nur OneDrive.
  public var driveID: String?
  /// App-Ordner, nur OneDrive.
  public var folderItemID: String?
  /// Gekürzter Kontoname, z. B. "l…@example.com".
  public var accountHint: String?

  public init(
    dataLocation: DataLocation, libraryID: UUID? = nil, driveID: String? = nil,
    folderItemID: String? = nil, accountHint: String? = nil
  ) {
    self.version = Self.currentVersion
    self.dataLocation = dataLocation
    self.libraryID = libraryID
    self.driveID = driveID
    self.folderItemID = folderItemID
    self.accountHint = accountHint
  }

  /// Zeichen, die unkodiert bleiben dürfen. Bewusst enger als der Standard für Query-Werte,
  /// damit `&`, `=`, `+` und `/` in Kennungen sicher kodiert werden.
  private static let unreserved = CharacterSet(
    charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~")

  private static func encode(_ value: String) -> String {
    value.addingPercentEncoding(withAllowedCharacters: unreserved) ?? value
  }

  /// "frontstage-pair:?v=1&loc=oneDrive&lib=<UUID>&drive=<…>&item=<…>&acct=<…>"
  public var text: String {
    var parts = ["v=\(version)", "loc=\(dataLocation.rawValue)"]
    if let libraryID { parts.append("lib=\(libraryID.uuidString)") }
    if let driveID { parts.append("drive=\(Self.encode(driveID))") }
    if let folderItemID { parts.append("item=\(Self.encode(folderItemID))") }
    if let accountHint { parts.append("acct=\(Self.encode(accountHint))") }
    return Self.prefix + "?" + parts.joined(separator: "&")
  }

  /// nil bei fremdem Text, fehlenden Pflichtfeldern (oneDrive ohne lib/drive/item) oder unbekanntem loc.
  public init?(text: String) {
    guard text.hasPrefix(Self.prefix),
      let components = URLComponents(string: text),
      components.scheme == "frontstage-pair",
      let items = components.queryItems
    else { return nil }

    func value(_ name: String) -> String? {
      items.first { $0.name == name }?.value
    }

    guard let v = value("v").flatMap({ Int($0) }),
      let loc = value("loc").flatMap({ DataLocation(rawValue: $0) })
    else { return nil }

    let lib = value("lib").flatMap { UUID(uuidString: $0) }
    let drive = value("drive")
    let item = value("item")
    if loc == .oneDrive {
      guard lib != nil, drive != nil, item != nil else { return nil }
    }

    self.version = v
    self.dataLocation = loc
    self.libraryID = lib
    self.driveID = drive
    self.folderItemID = item
    self.accountHint = value("acct")
  }

  /// Erstes Zeichen des Namens, „…“, alles ab „@“; ohne „@“: erstes Zeichen und „…“.
  public static func maskedAccount(_ username: String) -> String {
    guard let first = username.first else { return "" }
    if let at = username.firstIndex(of: "@") {
      return "\(first)…\(username[at...])"
    }
    return "\(first)…"
  }
}

public enum PairingVerdict: Equatable, Sendable {
  case ok, differentAccount, libraryMissing, differentLibrary, needsNewerApp
}

public enum PairingVerifier {
  /// Prüft, was das zweite Gerät nach der Anmeldung im eigenen App-Ordner vorfindet.
  public static func verify(
    _ payload: PairingPayload, foundDriveID: String, foundFolderItemID: String,
    library: LibraryMarker?
  ) -> PairingVerdict {
    if payload.version > PairingPayload.currentVersion { return .needsNewerApp }
    if payload.driveID != foundDriveID || payload.folderItemID != foundFolderItemID {
      return .differentAccount
    }
    guard let library else { return .libraryMissing }
    if library.formatVersion > RecordEnvelope.currentFormatVersion { return .needsNewerApp }
    if library.libraryID != payload.libraryID { return .differentLibrary }
    return .ok
  }
}
