import SwiftUI

#if os(iOS)
  import VisionKit
#else
  import AVFoundation
  import AppKit
  import Vision
  import os
#endif

/// Kamera-Scanner für den Koppel-Code. `onCode` wird höchstens einmal gerufen.
///
/// iPad: `DataScannerViewController` (VisionKit). Mac: `AVCaptureSession` mit Vision-Barcode-Erkennung,
/// weil VisionKits Scanner am Mac fehlt. Die Kamera läuft nur, solange die Ansicht sichtbar ist.
struct PairingScannerView: View {
  let onCode: (String) -> Void

  init(onCode: @escaping (String) -> Void) {
    self.onCode = onCode
  }

  /// iPad: Gerät unterstützt den Scanner und Kamerazugriff ist nicht gesperrt. Mac: eine Kamera ist vorhanden.
  @MainActor static var isAvailable: Bool {
    #if os(iOS)
      DataScannerViewController.isSupported && DataScannerViewController.isAvailable
    #else
      AVCaptureDevice.default(for: .video) != nil
    #endif
  }

  var body: some View {
    #if os(iOS)
      DataScannerRepresentable(onCode: onCode)
    #else
      MacScannerRepresentable(onCode: onCode)
    #endif
  }
}

#if os(iOS)

  /// Swift-Hinweis: `UIViewControllerRepresentable` bettet einen UIKit-Controller in SwiftUI ein. Der
  /// `Coordinator` ist das Objekt, das UIKit-Delegaten-Rückrufe entgegennimmt (SwiftUI-Strukturen können
  /// kein Delegat sein, sie werden ständig neu angelegt).
  private struct DataScannerRepresentable: UIViewControllerRepresentable {
    let onCode: (String) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(onCode: onCode) }

    func makeUIViewController(context: Context) -> DataScannerViewController {
      let scanner = DataScannerViewController(
        recognizedDataTypes: [.barcode(symbologies: [.qr])], qualityLevel: .balanced,
        recognizesMultipleItems: false, isHighFrameRateTrackingEnabled: false,
        isPinchToZoomEnabled: true, isGuidanceEnabled: true, isHighlightingEnabled: true)
      scanner.delegate = context.coordinator
      return scanner
    }

    func updateUIViewController(_ scanner: DataScannerViewController, context: Context) {
      // Der Scanner darf erst starten, wenn seine Ansicht im Fenster hängt; `update` läuft danach.
      if !scanner.isScanning, !context.coordinator.delivered {
        try? scanner.startScanning()
      }
    }

    static func dismantleUIViewController(_ scanner: DataScannerViewController, coordinator: Coordinator) {
      scanner.stopScanning()
    }

    @MainActor final class Coordinator: NSObject, DataScannerViewControllerDelegate {
      private let onCode: (String) -> Void
      private(set) var delivered = false

      init(onCode: @escaping (String) -> Void) { self.onCode = onCode }

      func dataScanner(
        _ dataScanner: DataScannerViewController, didAdd addedItems: [RecognizedItem],
        allItems: [RecognizedItem]
      ) {
        guard !delivered else { return }
        for case .barcode(let barcode) in addedItems {
          if let text = barcode.payloadStringValue {
            delivered = true
            dataScanner.stopScanning()
            onCode(text)
            return
          }
        }
      }
    }
  }

#else

  /// Besitzt die Aufnahmesitzung. `startRunning()` blockiert und gehört nicht auf den Hauptakteur, deshalb
  /// läuft alles an der Sitzung auf einer eigenen seriellen Warteschlange.
  ///
  /// Swift-Hinweis: `@unchecked Sendable` sagt dem Compiler „ich garantiere die Thread-Sicherheit selbst“:
  /// hier, weil die Sitzung nur auf `queue` angefasst wird.
  private final class CameraSessionRunner: @unchecked Sendable {
    let session = AVCaptureSession()
    private let queue = DispatchQueue(label: "pairing.camera.session")
    private let sampleQueue = DispatchQueue(label: "pairing.camera.samples")
    private let delegate: BarcodeSampleDelegate

    init(onCode: @escaping @Sendable (String) -> Void) {
      delegate = BarcodeSampleDelegate(onCode: onCode)
    }

    func start() {
      queue.async { [self] in
        guard AVCaptureDevice.authorizationStatus(for: .video) != .denied,
          AVCaptureDevice.authorizationStatus(for: .video) != .restricted
        else { return }
        if session.inputs.isEmpty {
          guard let device = AVCaptureDevice.default(for: .video),
            let input = try? AVCaptureDeviceInput(device: device)
          else { return }
          session.beginConfiguration()
          if session.canAddInput(input) { session.addInput(input) }
          let output = AVCaptureVideoDataOutput()
          output.alwaysDiscardsLateVideoFrames = true
          output.setSampleBufferDelegate(delegate, queue: sampleQueue)
          if session.canAddOutput(output) { session.addOutput(output) }
          session.commitConfiguration()
        }
        if !session.isRunning { session.startRunning() }
      }
    }

    func stop() {
      queue.async { [self] in
        if session.isRunning { session.stopRunning() }
      }
    }
  }

  /// `CMSampleBuffer` ist je nach SDK nicht als `Sendable` markiert; der Puffer wird nur gelesen.
  private struct SampleBox: @unchecked Sendable {
    let buffer: CMSampleBuffer
  }

  /// Prüft höchstens alle 0,3 s ein Bild auf einen QR-Code und meldet den ersten Treffer genau einmal.
  private final class BarcodeSampleDelegate: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate,
    @unchecked Sendable
  {
    private struct State {
      var lastAttempt = Date.distantPast
      var busy = false
      var delivered = false
    }

    private let onCode: @Sendable (String) -> Void
    private let state = OSAllocatedUnfairLock(initialState: State())

    init(onCode: @escaping @Sendable (String) -> Void) { self.onCode = onCode }

    func captureOutput(
      _ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection
    ) {
      let now = Date()
      let proceed = state.withLock { state -> Bool in
        if state.delivered || state.busy || now.timeIntervalSince(state.lastAttempt) < 0.3 {
          return false
        }
        state.busy = true
        state.lastAttempt = now
        return true
      }
      guard proceed else { return }
      let box = SampleBox(buffer: sampleBuffer)
      Task.detached { [self] in
        var request = DetectBarcodesRequest()
        request.symbologies = [.qr]
        let observations = try? await request.perform(on: box.buffer)
        let text = observations?.lazy.compactMap(\.payloadString).first
        let deliver = state.withLock { state -> Bool in
          state.busy = false
          guard text != nil, !state.delivered else { return false }
          state.delivered = true
          return true
        }
        if deliver, let text { onCode(text) }
      }
    }
  }

  private struct MacScannerRepresentable: NSViewRepresentable {
    let onCode: (String) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(onCode: onCode) }

    func makeNSView(context: Context) -> CameraPreviewView {
      let view = CameraPreviewView(session: context.coordinator.runner.session)
      context.coordinator.runner.start()
      return view
    }

    func updateNSView(_ nsView: CameraPreviewView, context: Context) {}

    static func dismantleNSView(_ nsView: CameraPreviewView, coordinator: Coordinator) {
      coordinator.runner.stop()
    }

    @MainActor final class Coordinator {
      let runner: CameraSessionRunner

      init(onCode: @escaping @MainActor (String) -> Void) {
        // Der Rückruf kommt von der Warteschlange der Bilder und geht auf den Hauptakteur.
        runner = CameraSessionRunner(onCode: { text in
          Task { @MainActor in onCode(text) }
        })
      }
    }
  }

  /// Zeigt das Kamerabild; die Vorschauebene ist die Ebene der Ansicht selbst.
  private final class CameraPreviewView: NSView {
    init(session: AVCaptureSession) {
      super.init(frame: .zero)
      let preview = AVCaptureVideoPreviewLayer(session: session)
      preview.videoGravity = .resizeAspectFill
      layer = preview
      wantsLayer = true
    }

    @available(*, unavailable) required init?(coder: NSCoder) { fatalError("init(coder:) wird nicht benutzt") }
  }

#endif
