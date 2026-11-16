import Foundation
import FrontstageCore
import Testing

#if os(iOS)
  import UIKit
#endif

@testable import Frontstage

@MainActor @Suite struct DeviceInfoCollectorTests {
  private let theme = Theme(baseTone: .warm, accent: nil, appearanceMode: .system)

  @Test("Version und Build aus dem Bundle, Modellkennung nicht leer")
  func collectsFromBundle() {
    let info = DeviceInfoCollector.collect(dataLocation: .iCloud, theme: theme, isUnlocked: true)
    let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0"
    let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "0"
    #expect(info.appVersion == version)
    #expect(info.build == build)
    #expect(!info.modelIdentifier.isEmpty)
    #expect(!info.systemName.isEmpty)
    #expect(!info.systemVersion.isEmpty)
    #expect(!info.languageCode.isEmpty)
    #expect(info.isUnlocked)
    #expect(info.dataLocation == .iCloud)
  }

  @Test("Keine Gerätenamen in den Zeilen")
  func neverContainsDeviceName() {
    let info = DeviceInfoCollector.collect(dataLocation: .oneDrive, theme: theme, isUnlocked: false)
    #if os(iOS)
      let deviceName = UIDevice.current.name
    #else
      let deviceName = Host.current().localizedName ?? ""
    #endif
    // Ein allgemeiner Name wie „iPad“ steckt ohnehin in „iPadOS“ oder der Modellkennung; er verrät nichts.
    let technical = info.systemName + info.modelIdentifier
    guard !deviceName.isEmpty, !technical.localizedCaseInsensitiveContains(deviceName) else { return }
    for line in info.reportLines {
      #expect(!line.contains(deviceName))
    }
  }
}
