import FrontstageCore
import Foundation
import SwiftUI

#if os(iOS)
  import UIKit
#else
  import AppKit
#endif

/// Wo das „Öffnen in …“-Menü am Tablet erscheint. Teilplan 04 liefert es aus der angetippten Zeile.
struct HandOffAnchor {
  #if os(iOS)
    weak var view: UIView?
    var rect: CGRect

    init(view: UIView?, rect: CGRect) {
      self.view = view
      self.rect = rect
    }
  #endif

  /// Ohne Ort (am Mac gibt es kein Menü; am iPad zeigt das System dann nichts).
  init() {
    #if os(iOS)
      self.view = nil
      self.rect = .zero
    #endif
  }
}

@MainActor protocol DocumentHandingOff {
  /// Datei an die zuständige App übergeben (Öffnen am Ort, keine Kopie). true = übergeben/Menü gezeigt.
  func handOff(_ file: ScopedFile, anchor: HandOffAnchor) async -> Bool
  /// Office-Adresse übergeben; nil = keine Antwort innerhalb von `limit`.
  func openOfficeURI(_ uri: String, limit: Duration) async -> Bool?
  func isInstalled(_ app: OfficeApp) -> Bool
}

/// Setzt eine Fortsetzung genau einmal fort: Wer zuerst kommt (Antwort oder Frist), gewinnt.
/// Genutzt für die Office-Übergabe (hier) und die Vorbereitungsfrist in `StorageService.fetchItem`.
///
/// Swift-Hinweis: `withTaskGroup` würde auf alle Kind-Aufgaben warten, auch auf ein nicht abbrechbares
/// `UIApplication.open` oder MSAL `acquireTokenSilent`. Eine Fortsetzung kehrt dagegen sofort zurück; der
/// Merker verhindert ein zweites `resume`, das in Swift ein Absturz wäre. Die verlierende Aufgabe wird nur
/// abgebrochen und läuft, falls nicht abbrechbar, im Hintergrund zu Ende; ihr Ergebnis wird verworfen.
@MainActor final class FirstOutcome<Value: Sendable> {
  private var continuation: CheckedContinuation<Value, Never>?
  private var tasks: [Task<Void, Never>] = []

  init(_ continuation: CheckedContinuation<Value, Never>) { self.continuation = continuation }

  func adopt(_ task: Task<Void, Never>) {
    if continuation == nil { task.cancel() } else { tasks.append(task) }
  }

  func finish(_ value: Value) {
    guard let continuation else { return }
    self.continuation = nil
    continuation.resume(returning: value)
    tasks.forEach { $0.cancel() }
    tasks = []
  }
}

@MainActor final class SystemDocumentHandOff: DocumentHandingOff {
  private let openURL: @MainActor (URL) async -> Bool

  #if os(iOS)
    /// Hält Menü-Controller und Dateizugriff, bis das System das Ende meldet.
    private var session: IOSHandOffSession?
  #endif

  /// Für Tests: eigene Öffnen-Funktion statt der Systemfunktion.
  init(openURL: @escaping @MainActor (URL) async -> Bool) {
    self.openURL = openURL
  }

  convenience init() {
    self.init(openURL: SystemDocumentHandOff.systemOpen)
  }

  private static func systemOpen(_ url: URL) async -> Bool {
    #if os(iOS)
      // Swift-Hinweis: `open(_:options:)` gibt es als `async`-Variante, die das Ergebnis direkt liefert.
      return await UIApplication.shared.open(url, options: [:])
    #else
      do {
        _ = try await NSWorkspace.shared.open(url, configuration: NSWorkspace.OpenConfiguration())
        return true
      } catch {
        return false
      }
    #endif
  }

  func openOfficeURI(_ uri: String, limit: Duration) async -> Bool? {
    guard let url = URL(string: uri) else { return false }
    let open = openURL
    return await withCheckedContinuation { (continuation: CheckedContinuation<Bool?, Never>) in
      let outcome = FirstOutcome(continuation)
      outcome.adopt(Task { @MainActor in outcome.finish(await open(url)) })
      outcome.adopt(
        Task { @MainActor in
          // Abbruch (Antwort kam zuerst) darf keine Frist melden.
          guard (try? await Task.sleep(for: limit)) != nil else { return }
          outcome.finish(nil)
        })
    }
  }

  #if os(iOS)
    func handOff(_ file: ScopedFile, anchor: HandOffAnchor) async -> Bool {
      guard let view = anchor.view else { return false }
      session?.end()
      let newSession = IOSHandOffSession(file: file) { [weak self] ended in
        if self?.session === ended { self?.session = nil }
      }
      session = newSession
      if newSession.present(from: anchor.rect, in: view) { return true }
      newSession.end()
      return false
    }

    func isInstalled(_ app: OfficeApp) -> Bool {
      guard let url = URL(string: "\(app.scheme):") else { return false }
      return UIApplication.shared.canOpenURL(url)
    }
  #else
    func handOff(_ file: ScopedFile, anchor: HandOffAnchor) async -> Bool {
      // Der Zugriff bleibt offen, bis das System die Datei übernommen hat.
      defer { file.close() }
      return await openURL(file.url)
    }

    func isInstalled(_ app: OfficeApp) -> Bool {
      guard let url = URL(string: "\(app.scheme):") else { return false }
      return NSWorkspace.shared.urlForApplication(toOpen: url) != nil
    }
  #endif
}

#if os(iOS)
  /// Ein Übergabevorgang am iPad: Controller und Dateizugriff leben, bis das Menü endet.
  @MainActor private final class IOSHandOffSession: NSObject, UIDocumentInteractionControllerDelegate {
    private let file: ScopedFile
    private let controller: UIDocumentInteractionController
    private let onEnd: (IOSHandOffSession) -> Void
    private var ended = false

    init(file: ScopedFile, onEnd: @escaping (IOSHandOffSession) -> Void) {
      self.file = file
      self.controller = UIDocumentInteractionController(url: file.url)
      self.onEnd = onEnd
      super.init()
      controller.delegate = self
    }

    func present(from rect: CGRect, in view: UIView) -> Bool {
      controller.presentOpenInMenu(from: rect, in: view, animated: true)
    }

    /// Gibt Controller und Dateizugriff frei; mehrfaches Aufrufen schadet nicht.
    func end() {
      guard !ended else { return }
      ended = true
      controller.delegate = nil
      file.close()
      onEnd(self)
    }

    // Swift-Hinweis: `UIDocumentInteractionControllerDelegate` ist (anders als die meisten UIKit-Protokolle)
    // nicht `@MainActor`. Eine Methode des Hauptakteurs darf eine solche Anforderung unter Swift 6 nicht
    // erfüllen; deshalb `nonisolated`. UIKit ruft die Delegaten auf dem Hauptthread, was
    // `MainActor.assumeIsolated` zur Laufzeit prüft.
    nonisolated func documentInteractionController(
      _ controller: UIDocumentInteractionController, didEndSendingToApplication application: String?
    ) {
      MainActor.assumeIsolated { end() }
    }

    nonisolated func documentInteractionControllerDidDismissOpenInMenu(
      _ controller: UIDocumentInteractionController
    ) {
      MainActor.assumeIsolated { end() }
    }
  }
#endif

/// SwiftUI-Hilfe: liefert den UIView/UIViewController (iOS) bzw. NSView/NSViewController (macOS)
/// unter einer Zeile als Anker. Als `.background` an die Zeile hängen.
struct HandOffAnchorReader: View {
  let onResolve: (HandOffAnchor, AuthPresentationAnchor) -> Void

  init(onResolve: @escaping (HandOffAnchor, AuthPresentationAnchor) -> Void) {
    self.onResolve = onResolve
  }

  var body: some View {
    Representable(onResolve: onResolve).allowsHitTesting(false)
  }

  #if os(iOS)
    private struct Representable: UIViewRepresentable {
      let onResolve: (HandOffAnchor, AuthPresentationAnchor) -> Void

      func makeUIView(context: Context) -> ResolvingView {
        let view = ResolvingView()
        view.onResolve = onResolve
        return view
      }

      func updateUIView(_ view: ResolvingView, context: Context) { view.onResolve = onResolve }
    }

    private final class ResolvingView: UIView {
      /// Wird bewusst ohne `didSet` gesetzt: `updateUIView` läuft mitten in einem SwiftUI-Update.
      var onResolve: ((HandOffAnchor, AuthPresentationAnchor) -> Void)?
      /// Zuletzt gemeldeter Rahmen; verhindert Wiederholungen ohne Änderung.
      private var lastRect: CGRect?

      override func didMoveToWindow() {
        super.didMoveToWindow()
        lastRect = nil
        resolve()
      }

      override func layoutSubviews() {
        super.layoutSubviews()
        resolve()
      }

      /// Meldet nur bei geändertem Rahmen und asynchron, damit der Empfänger nie während eines
      /// SwiftUI-Updates Zustand schreibt.
      private func resolve() {
        guard window != nil, lastRect != bounds else { return }
        lastRect = bounds
        Task { @MainActor [weak self] in
          guard let self, self.window != nil, let onResolve = self.onResolve,
            let controller = self.owningController()
          else { return }
          onResolve(HandOffAnchor(view: self, rect: self.bounds), controller)
        }
      }

      /// Läuft die Responder-Kette hinauf bis zum ersten ViewController.
      private func owningController() -> UIViewController? {
        var responder: UIResponder? = next
        while let current = responder {
          if let controller = current as? UIViewController { return controller }
          responder = current.next
        }
        return nil
      }
    }
  #else
    private struct Representable: NSViewRepresentable {
      let onResolve: (HandOffAnchor, AuthPresentationAnchor) -> Void

      func makeNSView(context: Context) -> ResolvingView {
        let view = ResolvingView()
        view.onResolve = onResolve
        return view
      }

      func updateNSView(_ view: ResolvingView, context: Context) { view.onResolve = onResolve }
    }

    private final class ResolvingView: NSView {
      /// Wird bewusst ohne `didSet` gesetzt: `updateNSView` läuft mitten in einem SwiftUI-Update.
      var onResolve: ((HandOffAnchor, AuthPresentationAnchor) -> Void)?

      override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        resolve()
      }

      /// Meldet nur beim Einhängen ins Fenster und asynchron (kein Zustandsschreiben im Update).
      private func resolve() {
        guard window != nil else { return }
        Task { @MainActor [weak self] in
          guard let self, let onResolve = self.onResolve,
            let controller = self.window?.contentViewController
          else { return }
          onResolve(HandOffAnchor(), controller)
        }
      }
    }
  #endif
}
