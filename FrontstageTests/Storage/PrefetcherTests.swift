import Foundation
import FrontstageCore
import Testing

@testable import Frontstage

/// Attrappe: feste Zuordnungen, Aufrufe werden nicht geprüft.
@MainActor private final class FakeReferenceStore: MaterialReferenceStore {
  var links: [(key: LessonKey, reference: MaterialReference)] = []

  func linkedReferences(for keys: [LessonKey]) throws -> [(key: LessonKey, reference: MaterialReference)] {
    let wanted = Set(keys)
    return links.filter { wanted.contains($0.key) }
  }
  func folderGrantNames() throws -> Set<String> { Set(links.map { $0.reference.folderGrantName }) }
  func replaceReferences(atLocation locationKey: String, with reference: MaterialReference) throws -> Int { 0 }
}

/// Attrappe: merkt sich die angeforderten URLs.
private actor RecordingDownloader: FileDownloading {
  private(set) var urls: [URL] = []
  func requestDownload(of url: URL) async { urls.append(url) }
}

@MainActor @Suite struct PrefetcherTests {
  private let friday = CalendarDay(year: 2026, month: 11, day: 13)
  private let monday = CalendarDay(year: 2026, month: 11, day: 16)
  private let wednesday = CalendarDay(year: 2026, month: 11, day: 18)

  private let timetable = Timetable(
    weekVariantCount: 1, referenceWeekA: CalendarDay(year: 2026, month: 11, day: 16),
    entries: [
      TimetableEntry(weekday: .friday, period: 1, schoolClass: SchoolClass("8b"), subject: Subject("Englisch")),
      TimetableEntry(weekday: .monday, period: 2, schoolClass: SchoolClass("7a"), subject: Subject("Mathe")),
      TimetableEntry(weekday: .wednesday, period: 3, schoolClass: SchoolClass("9c"), subject: Subject("Deutsch")),
    ])

  private func key(_ day: CalendarDay, _ schoolClass: String, _ subject: String) -> LessonKey {
    LessonKey(date: day, schoolClass: SchoolClass(schoolClass), subject: Subject(subject), ordinal: 1)
  }

  private func reference(_ name: String, kind: MaterialFileKind) -> MaterialReference {
    MaterialReference(folderGrantName: "Unterricht", relativePath: name, displayName: name, fileKind: kind)
  }

  private func fileURL(_ reference: MaterialReference) -> URL {
    URL(fileURLWithPath: "/tmp/grant/\(reference.relativePath)")
  }

  private func prefetchAll(_ prefetcher: Prefetcher) async -> [MaterialReference] {
    await prefetcher.prefetch(today: friday, timetable: timetable, nonTeachingPeriods: [], changes: [])
  }

  @Test("Bereithalten fordert die Dateien von heute und vom nächsten Unterrichtstag an (NFR-1, AK-17)")
  func prefetchRequestsTodayAndNext() async {
    let fridayFile = reference("Arbeitsblatt Vokabeln.pdf", kind: .pdf)
    let mondayFile = reference("Vokabeln Unit 4.pptx", kind: .presentation)
    let wednesdayFile = reference("Übung.docx", kind: .document)
    let store = FakeReferenceStore()
    store.links = [
      (key(friday, "8b", "Englisch"), fridayFile),
      (key(monday, "7a", "Mathe"), mondayFile),
      (key(wednesday, "9c", "Deutsch"), wednesdayFile),
    ]
    let downloader = RecordingDownloader()
    let grantURL = URL(fileURLWithPath: "/tmp/grant", isDirectory: true)
    // Alle Dateien liegen noch nicht auf dem Gerät.
    let prefetcher = Prefetcher(
      lookup: { reference in
        (ResolvedMaterial(fileURL: self.fileURL(reference), grantURL: grantURL), .downloading(progress: nil))
      },
      store: store, downloader: downloader)

    let requested = await prefetchAll(prefetcher)

    #expect(requested == [fridayFile, mondayFile])
    #expect(await downloader.urls == [fileURL(fridayFile), fileURL(mondayFile)])
  }

  @Test("Bereits aktuelle Dateien werden nicht erneut angefordert")
  func currentFilesAreSkipped() async throws {
    // Echte lokale (nicht ubiquitäre) Datei: Zustand „auf dem Gerät, aktuell“.
    let root = FileManager.default.temporaryDirectory.appending(
      path: "prefetch-\(UUID().uuidString)", directoryHint: .isDirectory)
    let folder = root.appending(path: "Unterricht", directoryHint: .isDirectory)
    try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    try Data("x".utf8).write(to: folder.appending(path: "Arbeitsblatt Vokabeln.pdf", directoryHint: .notDirectory))
    let grants = FolderGrantStore(fileURL: root.appending(path: "FolderGrants.json", directoryHint: .notDirectory))
    _ = try grants.add(folderURL: folder, name: "Unterricht")

    let store = FakeReferenceStore()
    store.links = [(key(friday, "8b", "Englisch"), reference("Arbeitsblatt Vokabeln.pdf", kind: .pdf))]
    let downloader = RecordingDownloader()
    let prefetcher = Prefetcher(resolver: MaterialResolver(grants: grants), store: store, downloader: downloader)

    let requested = await prefetchAll(prefetcher)

    #expect(requested.isEmpty)
    #expect(await downloader.urls.isEmpty)
  }

  @Test("Nicht auflösbare Verweise werden übersprungen, ohne abzubrechen")
  func unresolvedReferencesAreSkipped() async {
    let missing = reference("Fehlt.pdf", kind: .pdf)
    let present = reference("Vokabeln Unit 4.pptx", kind: .presentation)
    let store = FakeReferenceStore()
    store.links = [(key(friday, "8b", "Englisch"), missing), (key(monday, "7a", "Mathe"), present)]
    let downloader = RecordingDownloader()
    let grantURL = URL(fileURLWithPath: "/tmp/grant", isDirectory: true)
    let prefetcher = Prefetcher(
      lookup: { reference in
        reference == missing
          ? nil
          : (ResolvedMaterial(fileURL: self.fileURL(reference), grantURL: grantURL), .onDevice(isCurrent: false))
      },
      store: store, downloader: downloader)

    let requested = await prefetchAll(prefetcher)

    #expect(requested == [present])
    #expect(await downloader.urls == [fileURL(present)])
  }
}
