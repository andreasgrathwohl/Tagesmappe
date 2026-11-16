import CoreGraphics
import Foundation

#if os(iOS)
  import UIKit
#else
  import AppKit
#endif

/// Nimmt das Fenster der Hauptszene auf (Entscheidung 5). Externe Bildschirme und die Anzeige für den
/// Beamer (zweite Szene) werden nie aufgenommen.
@MainActor
enum WindowCapture {
  /// `nil`, wenn gerade kein Fenster der Hauptszene da ist.
  static func captureMainWindow() -> CGImage? {
    #if os(iOS)
      let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
      guard
        let scene = scenes.first(where: {
          $0.session.role == .windowApplication && $0.activationState == .foregroundActive
        }),
        let window = scene.keyWindow ?? scene.windows.first
      else { return nil }
      let renderer = UIGraphicsImageRenderer(bounds: window.bounds)
      let image = renderer.image { _ in
        _ = window.drawHierarchy(in: window.bounds, afterScreenUpdates: true)
      }
      return image.cgImage
    #else
      // Läuft die Rückmeldung als Blatt, ist `sheetParent` das Fenster darunter – das wird aufgenommen;
      // das Blatt selbst ist ein eigenes Fenster und fehlt in `cacheDisplay`.
      guard let window = NSApp.mainWindow ?? NSApp.keyWindow else { return nil }
      let target = window.sheetParent ?? window
      guard let view = target.contentView,
        let representation = view.bitmapImageRepForCachingDisplay(in: view.bounds)
      else { return nil }
      view.cacheDisplay(in: view.bounds, to: representation)
      return representation.cgImage
    #endif
  }
}
