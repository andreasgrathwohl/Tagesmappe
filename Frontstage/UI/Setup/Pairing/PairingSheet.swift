import FrontstageCore
import SwiftUI

/// Liefert der Microsoft-Anmeldung (MSAL) den Controller, aus dem sie ihr Fenster zeigt.
///
/// Swift-Hinweis: SwiftUI kennt keine View-Controller; MSAL verlangt aber einen. Ein unsichtbarer
/// Representable legt einen an und reicht ihn über einen Halter nach außen.
@MainActor final class AnchorHolder {
  var anchor: AuthPresentationAnchor?
}

#if os(iOS)
  import UIKit

  struct AnchorReader: UIViewControllerRepresentable {
    let holder: AnchorHolder
    func makeUIViewController(context: Context) -> UIViewController {
      let controller = UIViewController()
      holder.anchor = controller
      return controller
    }
    func updateUIViewController(_ controller: UIViewController, context: Context) {}
  }
#else
  import AppKit

  /// `NSViewController()` ohne Ansicht stürzt beim Zugriff auf `view` ab; deshalb eine leere Ansicht.
  private final class EmptyViewController: NSViewController {
    override func loadView() { view = NSView() }
  }

  struct AnchorReader: NSViewControllerRepresentable {
    let holder: AnchorHolder
    func makeNSViewController(context: Context) -> NSViewController {
      let controller = EmptyViewController()
      holder.anchor = controller
      return controller
    }
    func updateNSViewController(_ controller: NSViewController, context: Context) {}
  }
#endif

/// „Gerät koppeln“ (FR-14.1): eigener Code, darunter der Weg zum Scannen. Systemstandard, Gestaltung offen.
struct PairingSheet: View {
  @State private var model: PairingFlowModel
  @State private var holder = AnchorHolder()
  @Environment(\.dismiss) private var dismiss

  init(controller: DataLocationController, accountUsername: @escaping () -> String?) {
    _model = State(
      initialValue: PairingFlowModel(
        controller: controller, accountUsername: accountUsername,
        prepareCamera: { await PairingScannerView.prepareCamera() }))
  }

  var body: some View {
    NavigationStack {
      content
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .navigationTitle(Text("pairing.title"))
        #if os(iOS)
          .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar {
          ToolbarItem(placement: .cancellationAction) {
            Button("pairing.close") {
              model.cancel()
              dismiss()
            }
          }
        }
    }
    .background(AnchorReader(holder: holder).frame(width: 0, height: 0))
    #if os(macOS)
      .frame(minWidth: 380, minHeight: 460)
    #endif
  }

  @ViewBuilder private var content: some View {
    switch model.step {
    case .showCode:
      VStack(spacing: 24) {
        if let payload = model.ownPayload {
          PairingCodeView(payload: payload)
        }
        Button("pairing.scan.action") { model.startScanning() }
          .buttonStyle(.borderedProminent)
      }
    case .scanning:
      VStack(spacing: 16) {
        switch model.cameraReady {
        case nil:
          // Die Rückfrage des Systems nach der Kamera läuft (nur beim ersten Mal).
          ProgressView()
        case true?:
          // Die Kamera läuft nur, solange diese Ansicht steht (Wechsel des Schritts baut sie ab).
          PairingScannerView { model.scanned($0) }
            .clipShape(.rect(cornerRadius: 12))
        case false?:
          Text("pairing.noCamera").multilineTextAlignment(.center)
        }
        Button("pairing.scan.cancel") { model.cancel() }
      }
      // Swift-Hinweis: `.task` startet beim Erscheinen und wird beim Verschwinden abgebrochen.
      .task { await model.checkCamera() }
    case .confirm(let payload):
      VStack(spacing: 16) {
        confirmText(for: payload)
        HStack {
          Button("pairing.scan.cancel") { model.cancel() }
          Button("pairing.confirm.action") {
            guard let anchor = holder.anchor else { return }
            Task { await model.confirm(anchor: anchor) }
          }
          .buttonStyle(.borderedProminent)
        }
      }
    case .working:
      ProgressView()
    case .done:
      VStack(spacing: 16) {
        Text("pairing.done")
        Button("pairing.close") { dismiss() }
      }
    case .rejected(let verdict):
      result(rejectionText(for: verdict))
    case .invalidCode:
      result(Text("pairing.invalidCode"))
    case .failed:
      result(Text("pairing.failed"))
    }
  }

  @ViewBuilder private func confirmText(for payload: PairingPayload) -> some View {
    switch payload.dataLocation {
    case .iCloud:
      Text("pairing.confirm.iCloud")
    case .oneDrive:
      Text("pairing.confirm.oneDrive \(payload.accountHint ?? "")")
    }
  }

  private func rejectionText(for verdict: PairingVerdict) -> Text {
    switch verdict {
    case .differentAccount: Text("pairing.rejected.differentAccount")
    case .libraryMissing: Text("pairing.rejected.libraryMissing")
    case .differentLibrary: Text("pairing.rejected.differentLibrary")
    case .needsNewerApp: Text("pairing.rejected.needsNewerApp")
    case .ok: Text("pairing.done")
    }
  }

  private func result(_ text: Text) -> some View {
    VStack(spacing: 16) {
      text.multilineTextAlignment(.center)
      Button("pairing.retry") { model.cancel() }
    }
  }
}
