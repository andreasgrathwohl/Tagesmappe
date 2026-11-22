import SwiftUI

#if os(iOS)
  import UIKit

  /// Meldet, ob das System das Tablet-Bild gerade aufnimmt oder spiegelt (FR-6.3, Schutz der Lösung).
  ///
  /// UIKit-Hinweis: Seit iOS 17 trägt die Trait-Collection einer Ansicht `sceneCaptureState`; er ist `.active`,
  /// solange die Szene gespiegelt oder aufgezeichnet wird. Mit `registerForTraitChanges` meldet die Ansicht jeden
  /// Wechsel. Die eigene Szene für den Zweitbildschirm zählt nicht dazu – dort sieht die Klasse nur, was wir zeigen.
  struct ScreenCaptureReader: UIViewRepresentable {
    /// `nil`, bis die Ansicht im Fenster hängt und den Zustand kennt.
    @Binding var isCaptured: Bool?

    func makeUIView(context: Context) -> CaptureView {
      let view = CaptureView()
      view.onChange = { captured in
        if isCaptured != captured { isCaptured = captured }
      }
      return view
    }

    func updateUIView(_ view: CaptureView, context: Context) {
      view.onChange = { captured in
        if isCaptured != captured { isCaptured = captured }
      }
    }

    final class CaptureView: UIView {
      var onChange: @MainActor (Bool) -> Void = { _ in }

      override init(frame: CGRect) {
        super.init(frame: frame)
        isUserInteractionEnabled = false
        registerForTraitChanges([UITraitSceneCaptureState.self]) { (view: CaptureView, _: UITraitCollection) in
          view.report()
        }
      }

      required init?(coder: NSCoder) { fatalError("init(coder:) wird nicht benutzt") }

      override func didMoveToWindow() {
        super.didMoveToWindow()
        report()
      }

      private func report() {
        let captured = traitCollection.sceneCaptureState == .active
        // Außerhalb des Layout-Durchgangs melden: SwiftUI-Zustand nicht während eines Updates ändern.
        Task { @MainActor [weak self] in self?.onChange(captured) }
      }
    }
  }
#endif
