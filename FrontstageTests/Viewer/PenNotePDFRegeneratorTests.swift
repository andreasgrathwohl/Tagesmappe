import Foundation
import FrontstageCore
import Testing

@testable import Frontstage

@MainActor @Suite struct PenNotePDFRegeneratorTests {
  @Test("Nach dem Zusammenführen: Notiz-PDF neben dem Dokument neu erzeugt (Entscheidung 8)")
  func writesPDFFromNotesFile() async throws {
    let files = InMemoryPenNoteFiles()
    let reference = TestFiles.reference("Arbeitsblatt Vokabeln.pdf")
    try await files.put(TestFiles.note(TestKeys.thu8aEnglish, pages: [0]), for: reference)
    let reader = StubReader(data: TestDocuments.pdfData(pages: 1, size: .a4), error: nil)
    await PenNotePDFRegenerator.regenerate(
      reference: reference, key: TestKeys.thu8aEnglish, reader: reader, files: files)
    #expect(await files.pdfNames(for: reference).count == 1)
  }

  @Test("Dokument nicht lesbar: nichts geschrieben, kein Absturz")
  func unreadableDocumentWritesNothing() async throws {
    let files = InMemoryPenNoteFiles()
    let reference = TestFiles.reference("Arbeitsblatt Vokabeln.pdf")
    try await files.put(TestFiles.note(TestKeys.thu8aEnglish, pages: [0]), for: reference)
    let reader = StubReader(data: Data(), error: StubError.unresolvable)
    await PenNotePDFRegenerator.regenerate(
      reference: reference, key: TestKeys.thu8aEnglish, reader: reader, files: files)
    #expect(await files.pdfNames(for: reference).isEmpty)
  }
}
