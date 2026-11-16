import Foundation
import Testing
@testable import FrontstageCore

@Suite("Feedback Upload Payload") struct FeedbackUploadPayloadTests {
  private func json(_ p: FeedbackUploadPayload) throws -> String {
    String(decoding: try p.jsonData(), as: UTF8.self)
  }

  @Test("Vertrag mit Teilplan 12, Schlüssel wörtlich")
  func encodesContract() throws {
    var d = FeedbackDraft(kind: .issue, topic: .board)
    d.text = "Tafel speichert nicht"
    d.includesDeviceInfo = true
    let p = FeedbackUploadPayload(draftID: d.id, draft: d, deviceInfo: FeedbackFixtures.info, appVersion: "0.1.0 (1)")
    let expected = "{\"appVersion\":\"0.1.0 (1)\",\"clientDraftId\":\"\(d.id.uuidString)\",\"deviceInfo\":{\"accent\":null,\"appVersion\":\"0.1.0\",\"appearanceMode\":\"system\",\"baseTone\":\"warm\",\"build\":\"1\",\"dataLocation\":\"iCloud\",\"isUnlocked\":false,\"languageCode\":\"de\",\"modelIdentifier\":\"iPad14,5\",\"systemName\":\"iPadOS\",\"systemVersion\":\"26.1\"},\"kind\":\"issue\",\"text\":\"Tafel speichert nicht\",\"topic\":\"board\"}"
    #expect(try json(p) == expected)
  }

  @Test("Geräteangaben aus → deviceInfo null, topic fehlt → null")
  func encodesNulls() throws {
    var d = FeedbackDraft(kind: .idea, topic: nil)
    d.text = "x"
    let p = FeedbackUploadPayload(draftID: d.id, draft: d, deviceInfo: FeedbackFixtures.info, appVersion: "0.1.0 (1)")
    let expected = "{\"appVersion\":\"0.1.0 (1)\",\"clientDraftId\":\"\(d.id.uuidString)\",\"deviceInfo\":null,\"kind\":\"idea\",\"text\":\"x\",\"topic\":null}"
    #expect(try json(p) == expected)
  }

  @Test("Eigener Akzent als #RRGGBB")
  func encodesAccent() throws {
    var d = FeedbackDraft(kind: .idea, topic: nil)
    d.includesDeviceInfo = true
    var info = FeedbackFixtures.info
    info.theme = Theme(baseTone: .petrol, accent: ThemeAccent(hex: "#FFF3A0"), appearanceMode: .dark)
    let text = try json(FeedbackUploadPayload(draftID: d.id, draft: d, deviceInfo: info, appVersion: "v"))
    #expect(text.contains("\"accent\":\"#FFF3A0\""))
    #expect(text.contains("\"baseTone\":\"petrol\""))
    #expect(text.contains("\"appearanceMode\":\"dark\""))
  }

  @Test("Quittung lesen")
  func decodesReceipt() throws {
    let id = UUID()
    let data = Data("{\"id\":\"\(id.uuidString)\",\"reference\":\"AB12CD34\"}".utf8)
    let r = try JSONDecoder().decode(FeedbackUploadReceipt.self, from: data)
    #expect(r.id == id && r.reference == "AB12CD34")
  }
}
