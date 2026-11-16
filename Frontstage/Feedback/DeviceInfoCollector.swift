import Foundation
import FrontstageCore

#if os(iOS)
  import UIKit
#endif

/// Sammelt die Geräteangaben (FR-17.3): nur technische Werte. Der Gerätename wird nie gelesen, denn er
/// enthält oft den Namen der Lehrkraft.
@MainActor
enum DeviceInfoCollector {
  static func collect(dataLocation: DataLocation, theme: Theme, isUnlocked: Bool) -> DeviceInfo {
    let bundle = Bundle.main
    let version = bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0"
    let build = bundle.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "0"

    let systemName: String
    let systemVersion: String
    #if os(iOS)
      systemName = UIDevice.current.systemName
      systemVersion = UIDevice.current.systemVersion
    #else
      let os = ProcessInfo.processInfo.operatingSystemVersion
      systemName = "macOS"
      systemVersion = "\(os.majorVersion).\(os.minorVersion).\(os.patchVersion)"
    #endif

    // Sprache der App („de“ ohne Region), nicht die Region des Geräts.
    let preferred = bundle.preferredLocalizations.first ?? "de"
    let languageCode = Locale(identifier: preferred).language.languageCode?.identifier ?? "de"

    return DeviceInfo(
      appVersion: version, build: build, systemName: systemName, systemVersion: systemVersion,
      modelIdentifier: modelIdentifier(), dataLocation: dataLocation, theme: theme, isUnlocked: isUnlocked,
      languageCode: languageCode)
  }

  /// `hw.machine` (iOS, z. B. „iPad14,3“) bzw. `hw.model` (macOS, z. B. „Mac14,2“). Im Simulator liefert
  /// `hw.machine` nur die Architektur; dort steht das simulierte Modell in der Umgebung.
  static func modelIdentifier() -> String {
    if let simulated = ProcessInfo.processInfo.environment["SIMULATOR_MODEL_IDENTIFIER"], !simulated.isEmpty {
      return simulated
    }
    #if os(iOS)
      let name = "hw.machine"
    #else
      let name = "hw.model"
    #endif
    var size = 0
    guard sysctlbyname(name, nil, &size, nil, 0) == 0, size > 0 else { return "unknown" }
    var buffer = [UInt8](repeating: 0, count: size)
    guard sysctlbyname(name, &buffer, &size, nil, 0) == 0 else { return "unknown" }
    let text = String(decoding: buffer.prefix { $0 != 0 }, as: UTF8.self)
    return text.isEmpty ? "unknown" : text
  }
}
