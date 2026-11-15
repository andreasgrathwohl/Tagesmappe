import Foundation
import Testing
@testable import FrontstageCore

@Suite("DataFolder Format")
struct RecordFormatTests {
  private func id(_ n: Int) -> UUID {
    let digits = String(n)
    let padded = String(repeating: "0", count: 12 - digits.count) + digits
    return UUID(uuidString: "00000000-0000-0000-0000-\(padded)")!
  }

  private let created = Date(timeIntervalSince1970: 1_795_000_000)

  private var sampleLink: MaterialLinkPayload {
    MaterialLinkPayload(
      createdAt: created, lessonKeyText: "", dayText: "2026-11-17", position: 0, folderGrantName: "Material",
      relativePath: "8b/Vokabeln.pdf", displayName: "Vokabeln", fileKindRaw: "pdf", oneDriveItemID: nil,
      oneDriveDriveID: nil)
  }

  private func tombstone(_ id: UUID, at seconds: Double) -> RecordEnvelope {
    RecordEnvelope(
      id: id, model: .materialLink, updatedAt: Date(timeIntervalSince1970: seconds), deviceID: "device-A",
      deleted: true, payload: nil)
  }

  private func linkEnvelope() -> RecordEnvelope {
    RecordEnvelope(
      id: id(1), model: .materialLink, updatedAt: Date(timeIntervalSince1970: 1_795_000_000.125),
      deviceID: "device-A", deleted: false, payload: .materialLink(sampleLink))
  }

  @Test("FR-14: Hülle hin und zurück, Zeitstempel mit Millisekunden")
  func envelopeRoundTrip() throws {
    // .125 statt .123: binär exakt darstellbar, sonst kann der Rundlauf über Millisekunden-Text um ein ulp abweichen
    let env = linkEnvelope()
    #expect(try DataFolderCoding.decode(try DataFolderCoding.encode(env)) == env)
  }

  @Test("Festes Dateiformat: Schlüssel sortiert, Datum als ISO-Text in UTC, Löschmarke ohne Inhalt")
  func encodesPinnedLayout() throws {
    let text = String(decoding: try DataFolderCoding.encode(tombstone(id(1), at: 1_795_000_000.5)), as: UTF8.self)
    #expect(text.contains(#""updatedAt" : "2026-11-18T11:06:40.500Z""#))
    #expect(text.range(of: "\"deleted\"")!.lowerBound < text.range(of: "\"deviceID\"")!.lowerBound)
    #expect(!text.contains("payload"))
  }

  @Test("Nicht gelöschter Datensatz ohne Inhalt wirft payloadMissing")
  func missingPayloadThrows() throws {
    let json = """
      {"deleted":false,"deviceID":"d","formatVersion":1,"id":"\(id(1).uuidString)","model":"MaterialLink",\
      "updatedAt":"2026-11-18T11:06:40.500Z"}
      """
    #expect(throws: DataFolderCodingError.payloadMissing) { try DataFolderCoding.decode(Data(json.utf8)) }
    let env = RecordEnvelope(
      id: id(1), model: .materialLink, updatedAt: created, deviceID: "d", deleted: false, payload: nil)
    #expect(throws: DataFolderCodingError.payloadMissing) { try DataFolderCoding.encode(env) }
  }

  @Test("Inhalt passend zum Modell; Abweichung wirft modelMismatch")
  func modelMismatchThrows() {
    let env = RecordEnvelope(
      id: id(1), model: .penNote, updatedAt: created, deviceID: "d", deleted: false,
      payload: .materialLink(sampleLink))
    #expect(throws: DataFolderCodingError.modelMismatch) { try DataFolderCoding.encode(env) }
  }

  @Test("Neuere Formatversion wird abgelehnt")
  func rejectsNewerFormatVersion() {
    let json = """
      {"deleted":true,"deviceID":"d","formatVersion":2,"id":"\(id(1).uuidString)","model":"MaterialLink",\
      "updatedAt":"2026-11-18T11:06:40.500Z"}
      """
    #expect(throws: DataFolderCodingError.unsupportedFormatVersion(2)) {
      try DataFolderCoding.decode(Data(json.utf8))
    }
  }

  @Test("Unbekannte Felder im Inhalt werden ignoriert (additive Schemaänderung)")
  func ignoresUnknownPayloadFields() throws {
    let data = try DataFolderCoding.encode(linkEnvelope())
    var text = String(decoding: data, as: UTF8.self)
    text = text.replacingOccurrences(of: "\"payload\" : {", with: "\"payload\" : {\n    \"futureField\" : 42,")
    #expect(text.contains("futureField"))
    #expect(try DataFolderCoding.decode(Data(text.utf8)) == linkEnvelope())
  }

  @Test("Prüfsumme: gleicher Inhalt gleich, ein Zeichen anders → anders")
  func payloadHashIsStable() throws {
    var other = sampleLink
    other.displayName = "Vokabeln!"
    let a = try DataFolderCoding.payloadHash(.materialLink(sampleLink))
    #expect(a == (try DataFolderCoding.payloadHash(.materialLink(sampleLink))))
    #expect(a != (try DataFolderCoding.payloadHash(.materialLink(other))))
    #expect(a.count == 16)
  }

  @Test("FNV-1a 64 bekannter Werte")
  func fnvKnownValues() {
    #expect(ContentHash.fnv1a64(Data()) == "cbf29ce484222325")
    #expect(ContentHash.fnv1a64(Data("a".utf8)) == "af63dc4c8601ec8c")
  }

  @Test("Zuletzt geschrieben gilt; Gleichstand nach Geräte-Kennung")
  func newerComparesTimeThenDevice() {
    let env = tombstone(id(1), at: 100)
    #expect(env.isNewer(than: (updatedAt: Date(timeIntervalSince1970: 99), deviceID: "z")))
    #expect(!env.isNewer(than: (updatedAt: Date(timeIntervalSince1970: 101), deviceID: "a")))
    #expect(env.isNewer(than: (updatedAt: Date(timeIntervalSince1970: 100), deviceID: "device-0")))
    #expect(!env.isNewer(than: (updatedAt: Date(timeIntervalSince1970: 100), deviceID: "device-A")))
    #expect(!env.isNewer(than: (updatedAt: Date(timeIntervalSince1970: 100), deviceID: "device-B")))
  }

  @Test("Anhänge und Elternkennung je Modell")
  func attachmentsAndParent() {
    let ref = AttachmentRef(hash: "abc", byteCount: 3)
    let page = RecordPayload.boardPage(
      BoardPagePayload(
        createdAt: created, lessonKeyText: "k", position: 0, backgroundRaw: "blank", backgroundImage: ref,
        drawing: ref, updatedAt: created))
    #expect(Set(page.attachments.keys) == ["drawing", "backgroundImage"])
    let note = RecordPayload.penNote(
      PenNotePayload(
        createdAt: created, materialLinkID: id(7), pageIndex: 0, drawing: nil, pageWidth: 0, pageHeight: 0,
        updatedAt: created))
    #expect(note.parentID == id(7))
    #expect(note.attachments.isEmpty)
    let info = RecordPayload.lessonInfo(
      LessonInfoPayload(
        createdAt: created, lessonKeyText: "k", topic: nil, toPrepare: nil, homework: nil, updatedAt: created,
        topicUpdatedAt: nil, toPrepareUpdatedAt: nil, homeworkUpdatedAt: nil))
    #expect(info.attachments.isEmpty)
    #expect(info.parentID == nil)
  }

  @Test("Anwende-Reihenfolge: Eltern vor Kindern")
  func applyOrderParentsFirst() {
    let order = SyncModel.applyOrder
    #expect(order.firstIndex(of: .timetable)! < order.firstIndex(of: .timetableEntry)!)
    #expect(order.firstIndex(of: .materialLink)! < order.firstIndex(of: .penNote)!)
    #expect(order.count == SyncModel.allCases.count)
  }

  @Test("FR-15: Jahresplan-Modelle hin und zurück")
  func coursePlanPayloadsRoundTrip() throws {
    let payloads: [(SyncModel, RecordPayload)] = [
      (
        .schoolYear,
        .schoolYear(
          SchoolYearPayload(
            createdAt: created, firstDayText: "2026-08-10", secondTermStartText: "2027-02-01",
            lastDayText: "2027-06-25", gradeOverrides: ["ef": 11]))
      ),
      (
        .coursePlan,
        .coursePlan(
          CoursePlanPayload(
            createdAt: created, subjectText: "Mathematik", gradeLevel: 8, startYear: 2026, notes: "Notiz"))
      ),
      (
        .planWeek,
        .planWeek(
          PlanWeekPayload(
            createdAt: created, coursePlanID: id(2), mondayText: "2026-11-16", position: 3, topic: "Brüche",
            notes: nil, updatedAt: created))
      ),
      (
        .assessment,
        .assessment(
          AssessmentPayload(
            createdAt: created, coursePlanID: id(2), mondayText: "2026-11-16", dayText: "2026-11-18",
            kindRaw: "test", title: "Arbeit 1", updatedAt: created))
      ),
    ]
    for (index, entry) in payloads.enumerated() {
      let env = RecordEnvelope(
        id: id(10 + index), model: entry.0, updatedAt: Date(timeIntervalSince1970: 1_795_000_000.125),
        deviceID: "device-A", deleted: false, payload: entry.1)
      #expect(try DataFolderCoding.decode(try DataFolderCoding.encode(env)) == env)
    }
  }

  @Test("FR-16: Erscheinungsbild hin und zurück")
  func themePayloadRoundTrips() throws {
    let payload = ThemePayload(
      createdAt: created, baseToneRaw: "cool", accentHex: "#FFF3A0", appearanceModeRaw: "dark", updatedAt: created)
    let env = RecordEnvelope(
      id: id(30), model: .theme, updatedAt: Date(timeIntervalSince1970: 1_795_000_000.125),
      deviceID: "device-A", deleted: false, payload: .theme(payload))
    #expect(try DataFolderCoding.decode(try DataFolderCoding.encode(env)) == env)
    #expect(RecordPayload.theme(payload).attachments.isEmpty)
    #expect(RecordPayload.theme(payload).parentID == nil)
  }

  @Test("Theme hängt hinten an, die zwölf bisherigen behalten ihre Reihenfolge")
  func themeAppendedLast() {
    #expect(SyncModel.applyOrder.last == .theme)
    #expect(SyncModel.applyOrder.count == 13)
    #expect(SyncModel(rawValue: "Theme") == .theme)
    #expect(SyncModel.applyOrder[11] == .assessment)
  }

  @Test("Eltern vor Kindern: Jahresplan vor Planwoche und Leistungsnachweis")
  func coursePlanApplyOrder() {
    let order = SyncModel.applyOrder
    #expect(order.firstIndex(of: .coursePlan)! < order.firstIndex(of: .planWeek)!)
    #expect(order.firstIndex(of: .coursePlan)! < order.firstIndex(of: .assessment)!)
    #expect(
      Array(order.prefix(8)) == [
        .timetable, .timetableEntry, .nonTeachingPeriod, .scheduleChange, .materialLink, .penNote, .lessonInfo,
        .boardPage,
      ])
  }

  @Test("parentID der Planwoche und des Leistungsnachweises")
  func coursePlanParentIDs() {
    let week = RecordPayload.planWeek(
      PlanWeekPayload(
        createdAt: created, coursePlanID: id(5), mondayText: nil, position: 0, topic: nil, notes: nil,
        updatedAt: created))
    let assessment = RecordPayload.assessment(
      AssessmentPayload(
        createdAt: created, coursePlanID: id(6), mondayText: nil, dayText: nil, kindRaw: "test", title: "",
        updatedAt: created))
    let year = RecordPayload.schoolYear(
      SchoolYearPayload(
        createdAt: created, firstDayText: "", secondTermStartText: "", lastDayText: "", gradeOverrides: [:]))
    #expect(week.parentID == id(5))
    #expect(assessment.parentID == id(6))
    #expect(year.parentID == nil)
    #expect(week.attachments.isEmpty && assessment.attachments.isEmpty && year.attachments.isEmpty)
  }

  @Test("Datenort-Rohwerte laut Glossar")
  func dataLocationRawValues() {
    #expect(DataLocation.allCases.map(\.rawValue) == ["iCloud", "oneDrive"])
  }

  @Test("FR-14.1: library.json mit Millisekunden wird gelesen, der Rundlauf bleibt exakt")
  func markerWithMillisecondsRoundTrips() throws {
    let json = Data(
      """
      {"createdAt":"2026-11-14T10:00:00.123Z","formatVersion":1,"libraryID":"00000000-0000-0000-0000-000000000001"}
      """.utf8)
    let marker = try DataFolderCoding.decodeMarker(json)
    #expect(marker.libraryID == id(1))
    #expect(abs(marker.createdAt.timeIntervalSince1970.truncatingRemainder(dividingBy: 1) - 0.123) < 0.001)

    let again = try DataFolderCoding.decodeMarker(try DataFolderCoding.encodeMarker(marker))
    #expect(again == marker)
    #expect(String(decoding: try DataFolderCoding.encodeMarker(marker), as: UTF8.self).contains(".123Z"))
  }

  @Test("FR-14.1: library.json ohne Millisekunden (ältere Schreiber) bleibt lesbar")
  func markerWithoutMillisecondsIsAccepted() throws {
    let json = Data(
      """
      {"createdAt":"2026-11-14T10:00:00Z","formatVersion":1,"libraryID":"00000000-0000-0000-0000-000000000001"}
      """.utf8)
    #expect(try DataFolderCoding.decodeMarker(json).libraryID == id(1))
  }
}
