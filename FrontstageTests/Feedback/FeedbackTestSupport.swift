import CoreGraphics
import Foundation
import FrontstageCore

@testable import Frontstage

/// Hilfen für die Rückmeldungs-Tests: ein Kontext mit eigenem Temp-Ordner, eigenen Einstellungen und einem
/// 400×300-Testbild als „Fensteraufnahme“.
@MainActor
enum FeedbackTestSupport {
  static let recipient = "hilfe@frontstage-rueckmeldung.de"
  static let endpoint = FeedbackServiceEndpoint.resolve("https://rueckmeldung.frontstage-app.de")!

  static func makeDirectory() -> URL {
    FileManager.default.temporaryDirectory.appending(
      path: "FeedbackTests-\(UUID().uuidString)", directoryHint: .isDirectory)
  }

  static func makeImage(width: Int = 400, height: Int = 300) -> CGImage {
    let space = CGColorSpace(name: CGColorSpace.sRGB)!
    let context = CGContext(
      data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0, space: space,
      bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
    context.setFillColor(CGColor(red: 0.2, green: 0.5, blue: 0.8, alpha: 1))
    context.fill(CGRect(x: 0, y: 0, width: width, height: height))
    return context.makeImage()!
  }

  /// Echte, gültige JPEG-Daten für `addPhotos`.
  static func makePhotoData() -> Data {
    FeedbackImageEncoder.preparedJPEG(from: makeImage(width: 200, height: 100))!
  }

  static func makeDefaults() -> UserDefaults {
    UserDefaults(suiteName: "FeedbackTests-\(UUID().uuidString)")!
  }

  static func makeContext(
    directory: URL = makeDirectory(), service: FeedbackServiceEndpoint? = nil, appKey: String? = nil,
    uploader: FeedbackUploader = FeedbackUploader(), defaults: UserDefaults = makeDefaults(),
    recipient: String? = FeedbackTestSupport.recipient, canSendMail: Bool = true,
    capture: @escaping @MainActor () -> CGImage? = { FeedbackTestSupport.makeImage() }
  ) -> FeedbackContext {
    FeedbackContext(
      store: FeedbackDraftStore(directory: directory), service: service, appKey: appKey, uploader: uploader,
      consentDefaults: defaults, recipient: recipient, canSendMail: { canSendMail },
      deviceInfo: {
        DeviceInfo(
          appVersion: "0.1.0", build: "1", systemName: "iPadOS", systemVersion: "26.0",
          modelIdentifier: "iPad14,3", dataLocation: .iCloud, theme: .standard, isUnlocked: false,
          languageCode: "de")
      },
      capture: capture)
  }
}
