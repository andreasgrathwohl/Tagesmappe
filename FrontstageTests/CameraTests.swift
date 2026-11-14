import AVFoundation
import Foundation
import FrontstageCore
import Testing

@testable import Frontstage

@Suite("Kamera der Tafel (FR-12.5)")
struct CameraTests {
  @Test("Review Focus 5: Kamerazustand aus Freigabe, Gerät und Multitasking")
  func cameraAvailabilityMapping() {
    #expect(CameraAvailability.from(status: .authorized, hasDevice: true, multitaskingBlocked: false) == .available)
    #expect(CameraAvailability.from(status: .denied, hasDevice: true, multitaskingBlocked: false) == .denied)
    #expect(CameraAvailability.from(status: .restricted, hasDevice: true, multitaskingBlocked: false) == .denied)
    #expect(
      CameraAvailability.from(status: .notDetermined, hasDevice: true, multitaskingBlocked: false) == .notDetermined)
    #expect(CameraAvailability.from(status: .authorized, hasDevice: false, multitaskingBlocked: false) == .noCamera)
    #expect(
      CameraAvailability.from(status: .authorized, hasDevice: true, multitaskingBlocked: true)
        == .unavailableInMultitasking)
  }

  #if os(iOS)
    @MainActor
    @Test("AK-37 (ohne Gerät): Standbild wird neue Seite mit Bild-Hintergrund")
    func stillBecomesNewPage() throws {
      let (session, _) = try makeSession()
      try session.open(tue8b)
      let jpeg = try CameraFeed.stillJPEG(from: TestImages.solid(gray: 0.5, width: 1920, height: 1080))
      try session.addPage(background: .image, imageData: jpeg)
      #expect(session.pages.count == 2)
      #expect(session.pages[1].background == .image)
      #expect(session.pageIndex == 1)
      #expect(TestImages.decode(jpeg)?.width == 2400)
    }
  #endif
}
