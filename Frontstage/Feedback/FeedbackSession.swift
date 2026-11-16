import CoreGraphics
import Foundation
import FrontstageCore
import SwiftUI

#if os(iOS)
  import MessageUI
#else
  import AppKit
#endif

/// Was eine Rückmeldung von außen braucht. `RootView` setzt es (Task 10); die Vorgabe taugt für Vorschauen.
///
/// Swift-Hinweis: `Sendable` ist hier erfüllt, weil jedes Feld `Sendable` ist – Abschlüsse mit
/// `@MainActor` sind es von Natur aus. Das braucht `@Entry`, dessen Vorgabewert ein statischer Wert ist.
struct FeedbackContext: Sendable {
  var store: FeedbackDraftStore
  /// `nil`, wenn `FeedbackConfiguration.service()` oder `appKey()` fehlt.
  var service: FeedbackServiceEndpoint?
  var appKey: String?
  var uploader: FeedbackUploader
  /// Swift-Hinweis: `UserDefaults` ist im SDK nicht `Sendable`, laut Apple aber threadsicher;
  /// `nonisolated(unsafe)` nimmt nur dieses Feld aus der `Sendable`-Prüfung.
  nonisolated(unsafe) var consentDefaults: UserDefaults
  var recipient: String?
  var canSendMail: @MainActor () -> Bool
  var deviceInfo: @MainActor () -> DeviceInfo
  var capture: @MainActor () -> CGImage?

  /// Echte Werte der App. Datenort, Erscheinungsbild und Kaufstand kennt nur die Wurzelansicht; hier gelten
  /// neutrale Werte, `RootView` ersetzt `deviceInfo`.
  @MainActor static var standard: FeedbackContext {
    FeedbackContext(
      store: .shared,
      service: FeedbackConfiguration.service(),
      appKey: FeedbackConfiguration.appKey(),
      uploader: FeedbackUploader(),
      consentDefaults: .standard,
      recipient: FeedbackConfiguration.recipient(),
      canSendMail: {
        #if os(iOS)
          return MFMailComposeViewController.canSendMail()
        #else
          return NSSharingService(named: .composeEmail)?.canPerform(withItems: ["x"]) == true
        #endif
      },
      deviceInfo: {
        DeviceInfoCollector.collect(dataLocation: .iCloud, theme: .standard, isUnlocked: false)
      },
      capture: { WindowCapture.captureMainWindow() })
  }
}

extension EnvironmentValues {
  // Der Vorgabewert von `@Entry` ist nicht isoliert, `.standard` aber `@MainActor` (Swift 6 strikt);
  // SwiftUI liest die Umgebung auf dem Hauptthread.
  @Entry var feedbackContext: FeedbackContext = MainActor.assumeIsolated { .standard }
}

/// Eine offene Rückmeldung; `Identifiable`, damit `.sheet(item:)` sie als Blatt zeigen kann.
struct FeedbackSession: Identifiable {
  let id: UUID
  let model: FeedbackModel
}

@MainActor
enum FeedbackStarter {
  /// Reihenfolge fest: zuerst `context.capture()`, dann Entwurf laden oder anlegen, dann Modell. Die Aufnahme
  /// muss entstehen, bevor das Blatt sichtbar ist, sonst zeigt sie das Blatt selbst.
  static func start(kind: FeedbackKind, topic: HelpTopic?, context: FeedbackContext) -> FeedbackSession {
    let image = context.capture()
    let draft = context.store.load() ?? FeedbackDraft(kind: kind, topic: topic)
    let model = FeedbackModel(draft: draft, context: context)
    if let image { model.addCapturedWindow(image) }
    return FeedbackSession(id: model.draft.id, model: model)
  }
}

extension View {
  /// Zeigt die Rückmeldung als Blatt.
  func feedbackSheet(_ session: Binding<FeedbackSession?>) -> some View {
    sheet(item: session) { session in
      FeedbackView(model: session.model)
        .fontDesign(.rounded)
    }
  }
}
