import CoreGraphics
import Foundation
import FrontstageCore
import Testing

@testable import Frontstage

#if os(iOS)
  import UIKit
#else
  import AppKit
#endif

/// Attrappe des Controllers: merkt sich die Aufrufe, wechselt aber nichts.
@MainActor private final class FakePairingController: PairingControlling {
  var location: DataLocation = .iCloud
  var dataFolder: DataFolder?
  var verdict: PairingVerdict = .ok
  var error: (any Error)?
  private(set) var oneDriveCalls: [PairingPayload?] = []
  private(set) var iCloudCalls = 0

  func switchToOneDrive(anchor: AuthPresentationAnchor, expected: PairingPayload?) async throws
    -> PairingVerdict
  {
    oneDriveCalls.append(expected)
    if let error { throw error }
    if verdict == .ok { location = .oneDrive }
    return verdict
  }

  func switchToICloud() async throws {
    iCloudCalls += 1
    if let error { throw error }
    location = .iCloud
  }
}

@MainActor private func makeAnchor() -> AuthPresentationAnchor {
  #if os(iOS)
    UIViewController()
  #else
    NSViewController()
  #endif
}

private let libraryID = UUID()

private func oneDrivePayload() -> PairingPayload {
  PairingPayload(
    dataLocation: .oneDrive, libraryID: libraryID, driveID: "drive-1", folderItemID: "item-1",
    accountHint: "m…@example.com")
}

@MainActor @Suite struct PairingFlowModelTests {
  @Test("AK-44: OneDrive-Code scannen, bestätigen → Wechsel mit erwarteter Bibliothek")
  func scanAndConfirmOneDrive() async {
    let controller = FakePairingController()
    let model = PairingFlowModel(controller: controller, accountUsername: { nil })
    let payload = oneDrivePayload()

    model.startScanning()
    #expect(model.step == .scanning)
    model.scanned(payload.text)
    #expect(model.step == .confirm(payload))

    await model.confirm(anchor: makeAnchor())
    #expect(controller.oneDriveCalls == [payload])
    #expect(controller.location == .oneDrive)
    #expect(model.step == .done)
  }

  @Test("AK-44: iCloud-Code stellt auf iCloud um")
  func scanICloudSwitchesToICloud() async {
    let controller = FakePairingController()
    controller.location = .oneDrive
    let model = PairingFlowModel(controller: controller, accountUsername: { nil })

    model.startScanning()
    model.scanned(PairingPayload(dataLocation: .iCloud).text)
    await model.confirm(anchor: makeAnchor())

    #expect(controller.iCloudCalls == 1)
    #expect(controller.oneDriveCalls.isEmpty)
    #expect(controller.location == .iCloud)
    #expect(model.step == .done)
  }

  @Test("Review Focus 4: Code eines anderen Kontos → rejected, Datenort unverändert")
  func pairingWithOtherAccountChangesNothing() async {
    let controller = FakePairingController()
    controller.verdict = .differentAccount
    let model = PairingFlowModel(controller: controller, accountUsername: { nil })

    model.startScanning()
    model.scanned(oneDrivePayload().text)
    await model.confirm(anchor: makeAnchor())

    #expect(model.step == .rejected(.differentAccount))
    #expect(controller.location == .iCloud)
  }

  @Test("Fremder Text → invalidCode, kein Wechsel")
  func invalidCodeDoesNothing() {
    let controller = FakePairingController()
    let model = PairingFlowModel(controller: controller, accountUsername: { nil })

    model.startScanning()
    model.scanned("https://example.com")

    #expect(model.step == .invalidCode)
    #expect(controller.oneDriveCalls.isEmpty)
    #expect(controller.iCloudCalls == 0)
  }

  @Test("Eigener Code enthält Datenordner und gekürztes Konto")
  func ownPayloadFromDataFolder() {
    let controller = FakePairingController()
    let model = PairingFlowModel(controller: controller, accountUsername: { nil })
    #expect(model.ownPayload == PairingPayload(dataLocation: .iCloud))

    controller.location = .oneDrive
    #expect(model.ownPayload == nil)  // OneDrive ohne Datenordner: erst Datenort wählen

    controller.dataFolder = DataFolder(
      driveID: "drive-1", folderItemID: "item-1", libraryID: libraryID,
      accountUsername: "max@example.com")
    #expect(
      model.ownPayload
        == PairingPayload(
          dataLocation: .oneDrive, libraryID: libraryID, driveID: "drive-1",
          folderItemID: "item-1", accountHint: "m…@example.com"))
  }

  @Test("QR-Bild entsteht für einen Code")
  func rendererProducesImage() throws {
    let image = try #require(QRCodeRenderer.image(for: oneDrivePayload().text, scale: 8))
    #expect(image.width > 0)
    #expect(image.width % 8 == 0)
  }
}
