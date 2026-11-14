import Foundation
import FrontstageCore
import ImageIO
import PDFKit
import PencilKit
import UniformTypeIdentifiers

@testable import Frontstage

#if os(iOS)
  import UIKit
#else
  import AppKit
#endif

/// Erfundene Zeichnungen für die Tests des Betrachters.
enum TestDrawings {
  /// Ein Strich von `start` nach `end`.
  static func line(from start: CGPoint, to end: CGPoint) -> PKDrawing {
    PKDrawing(strokes: [stroke(from: start, to: end)])
  }

  /// Eine Notiz mit einem Strich.
  static var word: PKDrawing {
    line(from: CGPoint(x: 50, y: 50), to: CGPoint(x: 150, y: 80))
  }

  /// Eine Notiz mit zwei Strichen.
  static var twoWords: PKDrawing {
    PKDrawing(strokes: [
      stroke(from: CGPoint(x: 50, y: 50), to: CGPoint(x: 150, y: 80)),
      stroke(from: CGPoint(x: 60, y: 200), to: CGPoint(x: 220, y: 230)),
    ])
  }

  private static func stroke(from start: CGPoint, to end: CGPoint) -> PKStroke {
    #if os(iOS)
      let color = UIColor.black
    #else
      let color = NSColor.black
    #endif
    let points = [start, end].enumerated().map { index, location in
      PKStrokePoint(
        location: location, timeOffset: TimeInterval(index) * 0.1, size: CGSize(width: 4, height: 4),
        opacity: 1, force: 1, azimuth: 0, altitude: .pi / 2)
    }
    return PKStroke(
      ink: PKInk(.pen, color: color),
      path: PKStrokePath(controlPoints: points, creationDate: Date(timeIntervalSince1970: 0)))
  }
}

/// Erfundene Stundenschlüssel (nur Klassen `8a`/`8b`, Fach „Englisch“, 17.–19.11.2026).
enum TestKeys {
  static let tue8aEnglish = key("8a", day: 17)
  static let wed8bEnglish = key("8b", day: 18)
  static let thu8aEnglish = key("8a", day: 19)
  static let tue8bEnglish = key("8b", day: 17)
  static let thu8bEnglish = key("8b", day: 19)

  private static func key(_ schoolClass: String, day: Int) -> LessonKey {
    LessonKey(
      date: CalendarDay(year: 2026, month: 11, day: day), schoolClass: SchoolClass(schoolClass),
      subject: Subject("Englisch"), ordinal: 1)
  }
}

extension PageSize {
  /// A4 in PDF-Punkten.
  static let a4 = PageSize(width: 595, height: 842)
}

/// Erfundene Dokumente (PDF über CoreGraphics/PDFKit, PNG über ImageIO – nicht über UIKit-Renderer).
enum TestDocuments {
  /// PDF mit leeren Seiten.
  static func pdfData(pages: Int, size: PageSize) -> Data {
    let data = NSMutableData()
    guard let consumer = CGDataConsumer(data: data as CFMutableData) else { return Data() }
    var box = CGRect(x: 0, y: 0, width: size.width, height: size.height)
    guard let context = CGContext(consumer: consumer, mediaBox: &box, nil) else { return Data() }
    for _ in 0..<max(pages, 1) {
      context.beginPDFPage(nil)
      context.endPDFPage()
    }
    context.closePDF()
    return data as Data
  }

  /// Eine Seite mit Größe und Drehung. Das Dokument wird festgehalten: `PDFPage` verweist nur schwach darauf.
  static func page(width: Double, height: Double, rotation: Int) -> PDFPage {
    let document = PDFDocument(data: pdfData(pages: 1, size: PageSize(width: width, height: height)))!
    retained.keep(document)
    let page = document.page(at: 0)!
    page.rotation = rotation
    return page
  }

  /// Einfarbiges PNG.
  static func pngData(width: Int, height: Int) -> Data {
    let space = CGColorSpaceCreateDeviceRGB()
    guard
      let context = CGContext(
        data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0, space: space,
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue),
      let image = context.makeImage()
    else { return Data() }
    let output = NSMutableData()
    guard let destination = CGImageDestinationCreateWithData(output, UTType.png.identifier as CFString, 1, nil)
    else { return Data() }
    CGImageDestinationAddImage(destination, image, nil)
    CGImageDestinationFinalize(destination)
    return output as Data
  }

  private static let retained = Retained()

  private final class Retained: @unchecked Sendable {
    private let lock = NSLock()
    private var documents: [PDFDocument] = []
    func keep(_ document: PDFDocument) {
      lock.lock()
      documents.append(document)
      lock.unlock()
    }
  }
}

/// Temporäre Ordner als Stand-in für den Ordner eines Dokuments.
enum TestFolders {
  /// Neuer Ordner mit diesen Dateien (Pfade relativ, Unterordner werden angelegt).
  static func make(with files: [String: Data] = [:]) throws -> URL {
    let dir = FileManager.default.temporaryDirectory.appending(
      path: "frontstage-viewer-\(UUID().uuidString)", directoryHint: .isDirectory)
    try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    for (name, data) in files {
      let url = dir.appending(path: name, directoryHint: .notDirectory)
      try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
      try data.write(to: url)
    }
    return dir
  }

  private static func documentData(named name: String) -> Data {
    name.lowercased().hasSuffix(".png")
      ? TestDocuments.pngData(width: 20, height: 20) : TestDocuments.pdfData(pages: 3, size: .a4)
  }

  /// Dokument mit Notiz-Datei der Stunde `TestKeys.tue8bEnglish` für diese Seiten (optional mit Notiz-PDF).
  static func documentWithNote(
    pages: [Int], documentName: String = "Arbeitsblatt Vokabeln.pdf", withPDF: Bool = false
  ) throws -> (URL, LessonKey) {
    let key = TestKeys.tue8bEnglish
    let dir = try make(with: [documentName: documentData(named: documentName)])
    let doc = dir.appending(path: documentName, directoryHint: .notDirectory)
    let store = PenNoteFileStore()
    _ = try store.write(
      TestFiles.note(key, pages: pages, document: documentName), changedPages: Set(pages), documentURL: doc, key: key)
    if withPDF { try store.writePDF(Data("%PDF-1.7".utf8), documentURL: doc, key: key) }
    return (doc, key)
  }

  /// Dokument mit einer rohen Datei unter dem Standardnamen der Stunde (z. B. kaputtes JSON).
  static func documentWithRawNote(_ raw: Data) throws -> (URL, LessonKey) {
    let key = TestKeys.tue8bEnglish
    let name = "Arbeitsblatt Vokabeln.pdf"
    let folder = PenNoteFileLayout.notesFolderName(documentFileName: name)
    let dir = try make(with: [
      name: documentData(named: name), "\(folder)/\(PenNoteFileLayout.lessonFileName(for: key))": raw,
    ])
    return (dir.appending(path: name, directoryHint: .notDirectory), key)
  }

  /// Rohinhalt der Stunden-Datei unter dem Standardnamen.
  static func rawNote(beside document: URL, key: LessonKey) throws -> Data {
    let folder = PenNoteFileLayout.notesFolderName(documentFileName: document.lastPathComponent)
    return try Data(
      contentsOf: document.deletingLastPathComponent().appending(path: folder, directoryHint: .isDirectory)
        .appending(path: PenNoteFileLayout.lessonFileName(for: key), directoryHint: .notDirectory))
  }

  /// Dokument in einem Ordner mit Rechten `0o555` (nicht beschreibbar).
  static func readOnlyDocument() throws -> (URL, LessonKey) {
    let name = "Arbeitsblatt Vokabeln.pdf"
    let dir = try make(with: [name: documentData(named: name)])
    try FileManager.default.setAttributes([.posixPermissions: 0o555], ofItemAtPath: dir.path(percentEncoded: false))
    return (dir.appending(path: name, directoryHint: .notDirectory), TestKeys.tue8bEnglish)
  }
}

/// Erfundene Notiz-Dateien und Verweise.
enum TestFiles {
  /// Notiz-Datei mit einem Strich je Seite.
  static func note(_ key: LessonKey, pages: [Int], document: String = "Arbeitsblatt Vokabeln.pdf") -> PenNoteFile {
    let stamp = Date(timeIntervalSince1970: 1_800_000_000)
    return PenNoteFile(
      lessonKey: key, document: document, device: "test", updatedAt: stamp,
      pages: pages.map {
        PenNotePage(
          index: $0, width: PageSize.a4.width, height: PageSize.a4.height,
          drawing: TestDrawings.word.dataRepresentation(), updatedAt: stamp)
      })
  }

  /// Verweis in der Freigabe „Unterricht“; Anzeigename = letzter Pfadteil, Art aus der Endung.
  static func reference(_ relativePath: String) -> MaterialReference {
    let name = relativePath.split(separator: "/").last.map(String.init) ?? relativePath
    return MaterialReference(
      folderGrantName: "Unterricht", relativePath: relativePath, displayName: name,
      fileKind: MaterialFileKind(fileExtension: (name as NSString).pathExtension))
  }
}

/// Daten für Tests, die einen `DataStore` brauchen.
@MainActor enum TestStore {
  /// Store mit einer Zuordnung zur Stunde `key`.
  static func contextWithLink(
    key: LessonKey = TestKeys.tue8aEnglish, kind: MaterialFileKind = .pdf
  ) throws -> (DataStore, MaterialLinkRecord) {
    let store = try makeStore()
    let name = kind == .image ? "Tafelbild.png" : "Arbeitsblatt Vokabeln.pdf"
    let link = try store.assign(TestFiles.reference(name), to: key)
    return (store, link)
  }

  /// Dieselbe Datei in einer anderen Stunde.
  static func addLink(to store: DataStore, sameFileAs link: MaterialLinkRecord, key: LessonKey) throws
    -> MaterialLinkRecord
  {
    try store.assign(link.reference, to: key)
  }

  /// Legt einen Ausweich-Datensatz an (auch doppelte Datensätze einer Seite lassen sich so nachstellen).
  static func addFallbackNote(
    to store: DataStore, link: MaterialLinkRecord, page: Int = 0, drawing: PKDrawing = TestDrawings.word,
    updatedAt: Date = Date.now, size: PageSize = .a4
  ) throws {
    let note = PenNoteRecord(materialLink: link, pageIndex: page)
    note.drawingData = drawing.dataRepresentation()
    note.pageWidth = size.width
    note.pageHeight = size.height
    note.updatedAt = updatedAt
    store.modelContext.insert(note)
    try store.saveAndBump()
  }
}

/// Notiz-Dateien im Speicher (je Ort ein temporärer Ordner, bedient vom echten `PenNoteFileStore`).
actor InMemoryPenNoteFiles: PenNoteFileAccessing {
  private let blocked: PenNoteBlockReason?
  private let notWritable: Bool
  private var unreachable: Bool
  private var folders: [String: URL] = [:]
  private let base = FileManager.default.temporaryDirectory.appending(
    path: "frontstage-memory-\(UUID().uuidString)", directoryHint: .isDirectory)

  private(set) var writeCount = 0
  private(set) var pdfWriteCount = 0

  init(blocked: PenNoteBlockReason? = nil, notWritable: Bool = false, unreachable: Bool = false) {
    self.blocked = blocked
    self.notWritable = notWritable
    self.unreachable = unreachable
  }

  func setUnreachable(_ value: Bool) { unreachable = value }

  /// Legt eine Datei (und optional ihr Notiz-PDF) für den Ort ab.
  func put(_ file: PenNoteFile, for reference: MaterialReference, withPDF: Bool = false) throws {
    let document = documentURL(for: reference)
    let key = LessonKey(storageText: file.lessonKey)!
    let store = PenNoteFileStore()
    _ = try store.write(file, changedPages: Set(file.pages.map(\.index)), documentURL: document, key: key)
    if withPDF { try store.writePDF(Data("%PDF-1.7".utf8), documentURL: document, key: key) }
  }

  func lessonKeys(for reference: MaterialReference) -> [LessonKey] {
    PenNoteFileStore().existingNotesPaths(documentURL: documentURL(for: reference)).compactMap {
      $0.split(separator: "/").last.flatMap { PenNoteFileLayout.lessonKey(fromLessonFileName: String($0)) }
    }
  }

  func pdfNames(for reference: MaterialReference) -> [String] {
    PenNoteFileStore().existingNotesPaths(documentURL: documentURL(for: reference)).filter { !$0.contains("/") }
  }

  func documentName(for reference: MaterialReference, key: LessonKey) -> String? {
    if case .notes(let file, _) = PenNoteFileStore().read(documentURL: documentURL(for: reference), key: key) {
      return file.document
    }
    return nil
  }

  private func documentURL(for reference: MaterialReference) -> URL {
    let id = reference.locationKey
    let folder: URL
    if let known = folders[id] {
      folder = known
    } else {
      folder = base.appending(path: UUID().uuidString, directoryHint: .isDirectory)
      try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
      folders[id] = folder
    }
    let name = reference.relativePath.split(separator: "/").last.map(String.init) ?? reference.relativePath
    return folder.appending(path: name, directoryHint: .notDirectory)
  }

  // MARK: PenNoteFileAccessing

  func read(_ reference: MaterialReference, key: LessonKey) -> PenNoteFileRead {
    if unreachable { return .none }
    if let blocked { return .blocked(blocked) }
    return PenNoteFileStore().read(documentURL: documentURL(for: reference), key: key)
  }

  func write(_ file: PenNoteFile, changedPages: Set<Int>, reference: MaterialReference, key: LessonKey) throws
    -> PenNoteFile
  {
    if unreachable { throw PenNoteWriteError.failed }
    if let blocked { throw PenNoteWriteError.blocked(blocked) }
    if notWritable { throw PenNoteWriteError.notWritable }
    let written = try PenNoteFileStore().write(
      file, changedPages: changedPages, documentURL: documentURL(for: reference), key: key)
    writeCount += 1
    return written
  }

  func writePDF(_ data: Data, reference: MaterialReference, key: LessonKey) throws {
    if unreachable { throw PenNoteWriteError.failed }
    if notWritable { throw PenNoteWriteError.notWritable }
    try PenNoteFileStore().writePDF(data, documentURL: documentURL(for: reference), key: key)
    pdfWriteCount += 1
  }

  func removePDF(reference: MaterialReference, key: LessonKey) throws {
    if unreachable { throw PenNoteWriteError.failed }
    try PenNoteFileStore().removePDF(documentURL: documentURL(for: reference), key: key)
  }

  func existingNotesPaths(for reference: MaterialReference) -> [String]? {
    unreachable ? nil : PenNoteFileStore().existingNotesPaths(documentURL: documentURL(for: reference))
  }

  func apply(
    _ plan: PenNoteRelocationPlan, from source: MaterialReference, to target: MaterialReference,
    combine: @escaping @Sendable (Data, Data) -> Data
  ) throws {
    if unreachable { throw PenNoteWriteError.failed }
    try PenNoteFileStore().apply(
      plan, sourceDocumentURL: documentURL(for: source), targetDocumentURL: documentURL(for: target),
      combine: combine)
  }
}

/// Fehler für Ersatz-Leser.
enum StubError: Error, Equatable { case unresolvable }

/// Liest feste Daten oder wirft; ersetzt `ScopedFileReader`.
struct StubReader: MaterialFileReading {
  let data: Data
  let error: (any Error)?

  func readData(for reference: MaterialReference) async throws -> Data {
    if let error { throw error }
    return data
  }
}

/// Baut ein `ViewerModel` samt Store, Notiz-Dateien im Speicher und frischem Zweitbildschirm-Zustand.
@MainActor enum TestViewer {
  /// - Parameters:
  ///   - notePages: Seiten mit einer Notiz in A4-Größe.
  ///   - notes: Seiten mit einer Notiz in der angegebenen Größe (für „Größe geändert“, „Seite fehlt“).
  ///   - existingPDF: Neben dem Dokument liegt schon ein Notiz-PDF dieser Stunde.
  ///   - notWritable: Der Ordner des Dokuments ist nicht beschreibbar.
  static func make(
    kind: MaterialFileKind, data: Data = Data(), readError: (any Error)? = nil, notePages: [Int] = [],
    notes: [Int: PageSize] = [:], existingPDF: Bool = false, notWritable: Bool = false,
    saveDelay: Duration = .milliseconds(500)
  ) async throws -> (ViewerModel, InMemoryPenNoteFiles, SecondScreenState) {
    let (store, link) = try TestStore.contextWithLink(kind: kind)
    let files = InMemoryPenNoteFiles(notWritable: notWritable)
    guard let key = LessonKey(storageText: link.lessonKeyText) else { throw StubError.unresolvable }
    var sizes = notes
    for page in notePages where sizes[page] == nil { sizes[page] = .a4 }
    if !sizes.isEmpty || existingPDF {
      let stamp = Date(timeIntervalSince1970: 1_800_000_000)
      let file = PenNoteFile(
        lessonKey: key, document: link.displayName, device: "test", updatedAt: stamp,
        pages: sizes.keys.sorted().map { index in
          PenNotePage(
            index: index, width: sizes[index]!.width, height: sizes[index]!.height,
            drawing: TestDrawings.word.dataRepresentation(), updatedAt: stamp)
        })
      try await files.put(file, for: link.reference, withPDF: existingPDF)
    }
    let screen = SecondScreenState()
    let penNotes = PenNoteStore(link: link, files: files, fallback: store, saveDelay: saveDelay)
    let model = ViewerModel(
      link: link, notes: penNotes, fileReader: StubReader(data: data, error: readError), files: files,
      secondScreen: screen)
    return (model, files, screen)
  }
}
