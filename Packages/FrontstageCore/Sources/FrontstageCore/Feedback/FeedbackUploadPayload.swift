import Foundation

/// Quittung des Rückmeldedienstes (201 neu, 200 bereits angenommen).
public struct FeedbackUploadReceipt: Hashable, Codable, Sendable {
  public let id: UUID
  public let reference: String
}

/// JSON-Teil des Uploads (Entscheidung 16). Schlüssel wörtlich; fehlende Werte als `null`.
public struct FeedbackUploadPayload: Hashable, Codable, Sendable {
  /// Geräteangaben in der Form des Vertrags: Thema flach statt als verschachteltes `Theme`.
  public struct Device: Hashable, Codable, Sendable {
    public let appVersion: String
    public let build: String
    public let systemName: String
    public let systemVersion: String
    public let modelIdentifier: String
    public let dataLocation: String
    public let baseTone: String
    public let accent: String?
    public let appearanceMode: String
    public let isUnlocked: Bool
    public let languageCode: String

    init(_ info: DeviceInfo) {
      appVersion = info.appVersion
      build = info.build
      systemName = info.systemName
      systemVersion = info.systemVersion
      modelIdentifier = info.modelIdentifier
      dataLocation = info.dataLocation.rawValue
      baseTone = info.theme.baseTone.rawValue
      accent = info.theme.accent?.hex
      appearanceMode = info.theme.appearanceMode.rawValue
      isUnlocked = info.isUnlocked
      languageCode = info.languageCode
    }

    public func encode(to encoder: Encoder) throws {
      var c = encoder.container(keyedBy: CodingKeys.self)
      try c.encode(appVersion, forKey: .appVersion)
      try c.encode(build, forKey: .build)
      try c.encode(systemName, forKey: .systemName)
      try c.encode(systemVersion, forKey: .systemVersion)
      try c.encode(modelIdentifier, forKey: .modelIdentifier)
      try c.encode(dataLocation, forKey: .dataLocation)
      try c.encode(baseTone, forKey: .baseTone)
      try c.encode(accent, forKey: .accent)  // optional: `encode` schreibt bei nil ausdrücklich `null`
      try c.encode(appearanceMode, forKey: .appearanceMode)
      try c.encode(isUnlocked, forKey: .isUnlocked)
      try c.encode(languageCode, forKey: .languageCode)
    }
  }

  public let clientDraftId: UUID
  public let kind: FeedbackKind
  public let text: String
  public let topic: HelpTopic?
  public let appVersion: String
  public let deviceInfo: Device?

  /// `deviceInfo` wird nur übernommen, wenn der Entwurf es erlaubt.
  public init(draftID: UUID, draft: FeedbackDraft, deviceInfo: DeviceInfo?, appVersion: String) {
    clientDraftId = draftID
    kind = draft.kind
    text = draft.text
    topic = draft.topic
    self.appVersion = appVersion
    self.deviceInfo = draft.includesDeviceInfo ? deviceInfo.map(Device.init) : nil
  }

  public func encode(to encoder: Encoder) throws {
    var c = encoder.container(keyedBy: CodingKeys.self)
    try c.encode(clientDraftId, forKey: .clientDraftId)
    try c.encode(kind, forKey: .kind)
    try c.encode(text, forKey: .text)
    try c.encode(topic, forKey: .topic)
    try c.encode(appVersion, forKey: .appVersion)
    try c.encode(deviceInfo, forKey: .deviceInfo)
  }

  public func jsonData() throws -> Data {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
    return try encoder.encode(self)
  }
}
