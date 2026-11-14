import Foundation
import FrontstageCore
import Observation

/// Schmale Sicht auf den Controller für Tests.
@MainActor protocol PairingControlling: AnyObject {
  var location: DataLocation { get }
  var dataFolder: DataFolder? { get }
  func switchToOneDrive(anchor: AuthPresentationAnchor, expected: PairingPayload?) async throws
    -> PairingVerdict
  func switchToICloud() async throws
}

extension DataLocationController: PairingControlling {}

/// Ablauf des Koppelns (FR-14.1): eigenen Code zeigen, fremden scannen, bestätigen, übernehmen.
///
/// Swift-Hinweis: `@Observable` ersetzt `ObservableObject`/`@Published`; SwiftUI beobachtet jede gelesene
/// Eigenschaft automatisch. `private(set)` hält den Zustand von außen schreibgeschützt.
@MainActor @Observable final class PairingFlowModel {
  enum Step: Equatable {
    case showCode, scanning, confirm(PairingPayload), working, done
    case rejected(PairingVerdict), invalidCode, failed
  }

  private(set) var step: Step = .showCode
  /// Ob beim Scannen die Kamera bereitsteht; `nil` = wird noch geprüft (z. B. läuft die Rückfrage des Systems).
  private(set) var cameraReady: Bool?

  @ObservationIgnored private let controller: any PairingControlling
  @ObservationIgnored private let accountUsername: () -> String?
  @ObservationIgnored private let prepareCamera: @MainActor () async -> Bool

  /// `prepareCamera`: fragt beim ersten Mal nach dem Kamerazugriff und meldet, ob gescannt werden kann
  /// (in der App `PairingScannerView.prepareCamera`).
  init(
    controller: any PairingControlling, accountUsername: @escaping () -> String?,
    prepareCamera: @escaping @MainActor () async -> Bool = { true }
  ) {
    self.controller = controller
    self.accountUsername = accountUsername
    self.prepareCamera = prepareCamera
  }

  /// Code dieses Geräts (nil bei OneDrive ohne Datenordner – dann erst Datenort wählen).
  var ownPayload: PairingPayload? {
    switch controller.location {
    case .iCloud:
      return PairingPayload(dataLocation: .iCloud)
    case .oneDrive:
      guard let folder = controller.dataFolder else { return nil }
      let name = folder.accountUsername.isEmpty ? (accountUsername() ?? "") : folder.accountUsername
      return PairingPayload(
        dataLocation: .oneDrive, libraryID: folder.libraryID, driveID: folder.driveID,
        folderItemID: folder.folderItemID,
        accountHint: name.isEmpty ? nil : PairingPayload.maskedAccount(name))
    }
  }

  func startScanning() {
    guard step != .working else { return }
    cameraReady = nil
    step = .scanning
  }

  /// Beim Erscheinen des Scan-Schritts: Kamerazugriff erfragen (falls noch nie gefragt) und das Ergebnis
  /// merken. Ohne diese Rückfrage meldet VisionKit den Scanner auf einem frisch installierten iPad als nicht
  /// verfügbar, und die Systemabfrage erschiene nie.
  func checkCamera() async {
    guard step == .scanning else { return }
    let ready = await prepareCamera()
    guard step == .scanning else { return }
    cameraReady = ready
  }

  /// Nur während des Scannens; spätere Treffer derselben Kamera werden ignoriert.
  func scanned(_ text: String) {
    guard step == .scanning else { return }
    if let payload = PairingPayload(text: text) {
      step = .confirm(payload)
    } else {
      step = .invalidCode
    }
  }

  func confirm(anchor: AuthPresentationAnchor) async {
    guard case .confirm(let payload) = step else { return }
    step = .working
    do {
      switch payload.dataLocation {
      case .iCloud:
        try await controller.switchToICloud()
        step = .done
      case .oneDrive:
        let verdict = try await controller.switchToOneDrive(anchor: anchor, expected: payload)
        step = verdict == .ok ? .done : .rejected(verdict)
      }
    } catch {
      step = .failed
    }
  }

  func cancel() {
    guard step != .working else { return }
    step = .showCode
  }
}
