import Foundation
import Testing

@testable import FrontstageCore

@Suite("Pairing")
struct PairingPayloadTests {
  private func id(_ n: UInt8) -> UUID {
    UUID(uuid: (n, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0))
  }

  private func oneDrivePayload() -> PairingPayload {
    PairingPayload(
      dataLocation: .oneDrive, libraryID: id(1), driveID: "b!drive",
      folderItemID: "01APPROOT", accountHint: "l…@example.com")
  }

  private func marker(_ n: UInt8, formatVersion: Int? = nil) -> LibraryMarker {
    var m = LibraryMarker(libraryID: id(n), createdAt: Date(timeIntervalSince1970: 0))
    if let formatVersion { m.formatVersion = formatVersion }
    return m
  }

  @Test("FR-14.1: Code für OneDrive hin und zurück")
  func oneDriveRoundTrip() {
    let p = oneDrivePayload()
    #expect(p.text.hasPrefix("frontstage-pair:?v=1&loc=oneDrive"))
    #expect(PairingPayload(text: p.text) == p)
  }

  @Test("Code für iCloud braucht keine Kennungen")
  func iCloudRoundTrip() {
    let p = PairingPayload(dataLocation: .iCloud)
    #expect(p.text == "frontstage-pair:?v=1&loc=iCloud")
    #expect(PairingPayload(text: p.text) == p)
  }

  @Test("Fremder Text, unvollständiger OneDrive-Code oder unbekannter Datenort → nil")
  func rejectsInvalidText() {
    #expect(PairingPayload(text: "https://example.com") == nil)
    #expect(PairingPayload(text: "frontstage-pair:?v=1&loc=oneDrive&lib=\(id(1).uuidString)") == nil)
    #expect(PairingPayload(text: "frontstage-pair:?v=1&loc=nextcloud") == nil)
  }

  @Test("Sonderzeichen in Kennungen überstehen die Kodierung")
  func encodesSpecialCharacters() {
    let p = PairingPayload(
      dataLocation: .oneDrive, libraryID: id(2), driveID: "b!a+b/c=", folderItemID: "x&y z",
      accountHint: "a…@example.com")
    #expect(PairingPayload(text: p.text) == p)
  }

  @Test("Kontoname wird gekürzt")
  func masksAccount() {
    #expect(PairingPayload.maskedAccount("lehrkraft@example.com") == "l…@example.com")
    #expect(PairingPayload.maskedAccount("lehrkraft") == "l…")
  }

  @Test("AK-44: gleiche Kennungen → ok")
  func verifyAcceptsSameLibrary() {
    let v = PairingVerifier.verify(
      oneDrivePayload(), foundDriveID: "b!drive", foundFolderItemID: "01APPROOT", library: marker(1))
    #expect(v == .ok)
  }

  @Test("Review Focus 4: anderes Laufwerk → differentAccount")
  func verifyRejectsOtherDrive() {
    let v = PairingVerifier.verify(
      oneDrivePayload(), foundDriveID: "b!other", foundFolderItemID: "01APPROOT", library: marker(1))
    #expect(v == .differentAccount)
  }

  @Test("Review Focus 4: andere Bibliothek → differentLibrary")
  func verifyRejectsOtherLibrary() {
    let v = PairingVerifier.verify(
      oneDrivePayload(), foundDriveID: "b!drive", foundFolderItemID: "01APPROOT", library: marker(9))
    #expect(v == .differentLibrary)
  }

  @Test("Noch kein library.json → libraryMissing")
  func verifyLibraryMissing() {
    let v = PairingVerifier.verify(
      oneDrivePayload(), foundDriveID: "b!drive", foundFolderItemID: "01APPROOT", library: nil)
    #expect(v == .libraryMissing)
  }

  @Test("Neuere Version → needsNewerApp")
  func verifyNeedsNewerApp() {
    var p = oneDrivePayload()
    p.version = PairingPayload.currentVersion + 1
    #expect(
      PairingVerifier.verify(p, foundDriveID: "b!drive", foundFolderItemID: "01APPROOT", library: marker(1))
        == .needsNewerApp)
    let newer = marker(1, formatVersion: RecordEnvelope.currentFormatVersion + 1)
    #expect(
      PairingVerifier.verify(
        oneDrivePayload(), foundDriveID: "b!drive", foundFolderItemID: "01APPROOT", library: newer)
        == .needsNewerApp)
  }
}
