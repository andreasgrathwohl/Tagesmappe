#if os(iOS)
  import AVFoundation
  import CoreImage
  import Observation
  import SwiftUI
  import UIKit

  /// Das Livebild der Kamera für die Tafel (FR-12.5): Heft, Buchseite oder Versuch erscheinen als Hintergrund,
  /// ein „Standbild“ wird zur neuen Tafelseite. Das Livebild wird nie gespeichert.
  ///
  /// Nur iPad/iPhone; am Mac gibt es die Tafel-Kamera nicht (Entscheidung in Aufgabe 13).
  ///
  /// Der Halter ist `shared`, weil zwei Szenen dasselbe Bild brauchen: die Tafel am Tablet (Knöpfe) und der
  /// Zweitbildschirm (`BoardView` zeigt `latestFrame`).
  ///
  /// Swift-Hinweis: Die Kamera läuft auf einer eigenen seriellen Warteschlange (`CaptureHost`); fertige Bilder
  /// kommen über einen `Task` zurück auf den Hauptakteur. So blockiert `startRunning()` nie die Oberfläche.
  @MainActor @Observable final class CameraFeed {
    static let shared = CameraFeed()

    /// Das jüngste Bild (höchstens 15 pro Sekunde); `nil`, solange nichts läuft.
    private(set) var latestFrame: CGImage?
    private(set) var availability: CameraAvailability = .notDetermined
    private(set) var position: AVCaptureDevice.Position = .back

    @ObservationIgnored private let host: CaptureHost
    @ObservationIgnored private var multitaskingBlocked = false

    init() {
      let host = CaptureHost()
      self.host = host
      host.setHandlers(
        onFrame: { [weak self] box in
          Task { @MainActor in self?.receive(box.image) }
        },
        onInterruption: { [weak self] blocked in
          Task { @MainActor in self?.setMultitaskingBlocked(blocked) }
        })
      refreshAvailability()
    }

    /// Fragt bei Bedarf die Freigabe an und startet das Livebild. Ohne Freigabe bleibt `availability` der Grund.
    ///
    /// Ein früherer Sperrgrund (geteilte Ansicht) wird hier verworfen: `start()` läuft nur auf ausdrücklichen
    /// Tipp, und bleibt die Sperre bestehen, meldet die Sitzung sie sofort neu.
    func start() async {
      multitaskingBlocked = false
      if AVCaptureDevice.authorizationStatus(for: .video) == .notDetermined {
        _ = await AVCaptureDevice.requestAccess(for: .video)
      }
      refreshAvailability()
      guard availability == .available else { return }
      await host.start(position: position)
    }

    /// Beendet das Livebild und verwirft das letzte Bild. Der Sperrgrund bleibt bewusst stehen, damit der
    /// Hinweis „in geteilter Ansicht nicht verfügbar“ sichtbar bleibt; `start()` und das Ende der
    /// Unterbrechung räumen ihn ab.
    func stop() {
      host.stop()
      latestFrame = nil
      refreshAvailability()
    }

    /// Wechselt zwischen Rück- und Frontkamera.
    func switchCamera() async {
      position = position == .back ? .front : .back
      latestFrame = nil
      guard availability == .available else { return }
      await host.start(position: position)
    }

    /// Das jüngste Bild als JPEG für eine neue Tafelseite.
    func stillJPEG() throws -> Data {
      guard let latestFrame else { throw CameraFeedError.noFrame }
      return try Self.stillJPEG(from: latestFrame)
    }

    /// Passt das Bild einpassend in 2400 × 1350 (Fläche der Tafel) und kodiert es als JPEG mit Qualität 0,8.
    nonisolated static func stillJPEG(from frame: CGImage) throws -> Data {
      try TemplateRenderer.renderImage(frame)
    }

    // MARK: Zustand

    private func receive(_ image: CGImage) {
      latestFrame = image
    }

    private func setMultitaskingBlocked(_ blocked: Bool) {
      multitaskingBlocked = blocked
      refreshAvailability()
    }

    private func refreshAvailability() {
      let hasDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: position) != nil
      availability = CameraAvailability.from(
        status: AVCaptureDevice.authorizationStatus(for: .video), hasDevice: hasDevice,
        multitaskingBlocked: multitaskingBlocked)
    }
  }

  /// Das Livebild der Kamera als Fläche, 16:9 einpassend, schwarze Streifen am Rand (Platzhalter, Gestaltung offen).
  /// Für die Tafel am Tablet und am Zweitbildschirm.
  ///
  /// Swift-Hinweis: Liest die Sicht `CameraFeed.shared.latestFrame`, ein `@Observable`, zeichnet SwiftUI sie bei
  /// jedem neuen Bild neu – ohne `@State` oder `@Bindable`.
  struct CameraLiveView: View {
    var body: some View {
      ZStack {
        Color.black
        if let frame = CameraFeed.shared.latestFrame {
          Image(decorative: frame, scale: 1)
            .resizable()
            .scaledToFit()
        }
      }
    }
  }

  enum CameraFeedError: Error, Equatable {
    /// Es liegt noch kein Bild vor.
    case noFrame
  }

  /// Ein Bild auf dem Weg von der Kamera-Warteschlange zum Hauptakteur.
  ///
  /// `@unchecked Sendable`: Das `CGImage` ist unveränderlich und wird nach dem Erzeugen nur noch gelesen.
  struct FrameBox: @unchecked Sendable {
    let image: CGImage
  }

  /// Besitzt die `AVCaptureSession` und alles, was an ihrer Warteschlange hängt.
  ///
  /// `nonisolated`, weil der Delegate auf der Kamera-Warteschlange aufgerufen wird, nicht auf dem Hauptakteur.
  /// `@unchecked Sendable`: Jeder veränderliche Zustand wird nur auf `queue` angefasst (die Handler sind nach
  /// `setHandlers` unveränderlich, der Winkel liegt hinter einer Sperre); der Compiler kann das nicht prüfen.
  private nonisolated final class CaptureHost: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate,
    @unchecked Sendable
  {
    private let queue = DispatchQueue(label: "frontstage.camera")
    private let session = AVCaptureSession()
    private let output = AVCaptureVideoDataOutput()
    private let ciContext = CIContext()
    private let angleLock = NSLock()

    // Nur auf `queue`:
    private var rotation: AVCaptureDevice.RotationCoordinator?
    private var angleObservation: NSKeyValueObservation?
    private var observers: [NSObjectProtocol] = []
    private var lastEmit: CFTimeInterval = 0
    private var isConfigured = false
    private var onFrame: (@Sendable (FrameBox) -> Void)?
    private var onInterruption: (@Sendable (Bool) -> Void)?

    // Hinter `angleLock`: der Drehwinkel für waagerechte Aufnahmen.
    private var angle: CGFloat = 90

    /// Höchstens 15 Bilder pro Sekunde (FR-12.5).
    private static let minFrameInterval: CFTimeInterval = 1.0 / 15.0

    func setHandlers(
      onFrame: @escaping @Sendable (FrameBox) -> Void, onInterruption: @escaping @Sendable (Bool) -> Void
    ) {
      queue.sync {
        self.onFrame = onFrame
        self.onInterruption = onInterruption
      }
    }

    /// Richtet die Sitzung ein (Kamera, Ausgabe, Unterbrechungen) und startet sie – alles auf `queue`.
    func start(position: AVCaptureDevice.Position) async {
      await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
        queue.async {
          self.configureAndRun(position: position)
          continuation.resume()
        }
      }
    }

    func stop() {
      queue.async {
        if self.session.isRunning { self.session.stopRunning() }
      }
    }

    private func configureAndRun(position: AVCaptureDevice.Position) {
      session.beginConfiguration()
      for input in session.inputs { session.removeInput(input) }
      if session.canSetSessionPreset(.hd1920x1080) { session.sessionPreset = .hd1920x1080 }
      guard
        let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: position),
        let input = try? AVCaptureDeviceInput(device: device), session.canAddInput(input)
      else {
        session.commitConfiguration()
        return
      }
      session.addInput(input)
      if !isConfigured {
        output.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA]
        output.alwaysDiscardsLateVideoFrames = true
        output.setSampleBufferDelegate(self, queue: queue)
        if session.canAddOutput(output) { session.addOutput(output) }
        observeInterruptions()
        isConfigured = true
      }
      // Ohne Berechtigung des Systems ist das in geteilter Ansicht nicht möglich; dann meldet die
      // Unterbrechung unten `unavailableInMultitasking`.
      if session.isMultitaskingCameraAccessSupported { session.isMultitaskingCameraAccessEnabled = true }
      session.commitConfiguration()

      // Ausrichtung: Der Koordinator liefert den Winkel, der das Bild zur Schwerkraft ausrichtet; er wird auf dem
      // Hauptthread beobachtet und hier hinter einer Sperre abgelegt.
      let coordinator = AVCaptureDevice.RotationCoordinator(device: device, previewLayer: nil)
      rotation = coordinator
      store(angle: coordinator.videoRotationAngleForHorizonLevelCapture)
      angleObservation = coordinator.observe(\.videoRotationAngleForHorizonLevelCapture, options: [.new]) {
        [weak self] _, change in
        if let value = change.newValue { self?.store(angle: value) }
      }

      if !session.isRunning { session.startRunning() }
    }

    private func observeInterruptions() {
      let center = NotificationCenter.default
      let interrupted = center.addObserver(
        forName: AVCaptureSession.wasInterruptedNotification, object: session, queue: nil
      ) { [weak self] note in
        let raw = note.userInfo?[AVCaptureSessionInterruptionReasonKey] as? Int
        let reason = raw.flatMap { AVCaptureSession.InterruptionReason(rawValue: $0) }
        // Nur die geteilte Ansicht sperrt; eine Unterbrechung im Hintergrund darf keine Sperre hinterlassen.
        if reason == .videoDeviceNotAvailableWithMultipleForegroundApps {
          self?.report(blocked: true)
        }
      }
      let ended = center.addObserver(
        forName: AVCaptureSession.interruptionEndedNotification, object: session, queue: nil
      ) { [weak self] _ in
        self?.report(blocked: false)
      }
      observers = [interrupted, ended]
    }

    private func report(blocked: Bool) {
      queue.async { self.onInterruption?(blocked) }
    }

    private func store(angle value: CGFloat) {
      angleLock.lock()
      angle = value
      angleLock.unlock()
    }

    private func currentAngle() -> CGFloat {
      angleLock.lock()
      defer { angleLock.unlock() }
      return angle
    }

    // MARK: AVCaptureVideoDataOutputSampleBufferDelegate

    func captureOutput(
      _ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection
    ) {
      let now = CACurrentMediaTime()
      guard now - lastEmit >= Self.minFrameInterval else { return }
      let target = currentAngle()
      if connection.isVideoRotationAngleSupported(target), connection.videoRotationAngle != target {
        connection.videoRotationAngle = target
      }
      guard let buffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
      let image = CIImage(cvPixelBuffer: buffer)
      guard let cgImage = ciContext.createCGImage(image, from: image.extent) else { return }
      lastEmit = now
      onFrame?(FrameBox(image: cgImage))
    }
  }
#endif
