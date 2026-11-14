import Foundation
import FrontstageCore

/// Stößt das Herunterladen einer Datei an; austauschbar für Tests.
protocol FileDownloading: Sendable {
  func requestDownload(of url: URL) async
}

/// Ubiquitäre Dateien: `startDownloadingUbiquitousItem`; sonst koordiniertes Lesen ohne Änderung
/// (`.withoutChanges`), das bei dateibasierten Anbietern das Laden auslösen kann – am Gerät zu belegen
/// (Geräte-Checkliste AK-17, AK-19). Der Zugriff auf die Freigabe muss beim Aufruf offen sein.
struct SystemFileDownloader: FileDownloading {
  func requestDownload(of url: URL) async {
    let isUbiquitous = (try? url.resourceValues(forKeys: [.isUbiquitousItemKey]))?.isUbiquitousItem ?? false
    if isUbiquitous {
      // Fehler sind hier folgenlos: Der Zustand wird später erneut aus den Ressourcenwerten gelesen.
      try? FileManager.default.startDownloadingUbiquitousItem(at: url)
      return
    }
    // Koordiniertes Lesen blockiert; deshalb außerhalb des Hauptthreads.
    await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
      DispatchQueue.global(qos: .utility).async {
        var coordinationError: NSError?
        NSFileCoordinator(filePresenter: nil).coordinate(
          readingItemAt: url, options: .withoutChanges, error: &coordinationError
        ) { _ in }
        continuation.resume()
      }
    }
  }
}

/// Hält die Dateien von heute und vom nächsten Unterrichtstag bereit (NFR-1).
@MainActor final class Prefetcher {
  /// Löst einen Verweis auf und liefert Datei, Freigabe und Zustand; `nil` = löst nicht auf.
  typealias Lookup = @MainActor (MaterialReference) -> (material: ResolvedMaterial, availability: MaterialAvailability)?

  private let lookup: Lookup
  private let store: any MaterialReferenceStore
  private let downloader: any FileDownloading

  init(resolver: MaterialResolver, store: any MaterialReferenceStore, downloader: any FileDownloading) {
    // Bereithalten läuft bei Netz; der Zustand wird deshalb als „online“ bewertet.
    self.lookup = { reference in
      guard let material = resolver.resolve(reference) else { return nil }
      return (material, resolver.availability(of: reference, isOnline: true))
    }
    self.store = store
    self.downloader = downloader
  }

  /// Für Tests: eigene Auflösung statt Dateisystem.
  init(lookup: @escaping Lookup, store: any MaterialReferenceStore, downloader: any FileDownloading) {
    self.lookup = lookup
    self.store = store
    self.downloader = downloader
  }

  /// Liefert die angestoßenen Verweise (für Zustandsaktualisierung und Tests).
  @discardableResult
  func prefetch(
    today: CalendarDay, timetable: Timetable, nonTeachingPeriods: [NonTeachingPeriod],
    changes: [ScheduleChange]
  ) async -> [MaterialReference] {
    let keys = PrefetchPlanner.lessonKeys(
      today: today, timetable: timetable, nonTeachingPeriods: nonTeachingPeriods, changes: changes)
    // Ein Lesefehler im Speicher bricht das Bereithalten nur ab; es läuft beim nächsten Anlass erneut.
    guard let links = try? store.linkedReferences(for: keys) else { return [] }
    let references = PrefetchPlanner.references(for: keys, links: links)
    return await requestDownloads(for: references)
  }

  /// Beim Zuordnen: sofort anfordern.
  func prefetch(_ references: [MaterialReference]) async {
    await requestDownloads(for: references)
  }

  @discardableResult
  private func requestDownloads(for references: [MaterialReference]) async -> [MaterialReference] {
    var requested: [MaterialReference] = []
    for reference in references {
      // Nicht auflösbare Verweise überspringen, ohne die übrigen aufzuhalten.
      guard let found = lookup(reference) else { continue }
      switch found.availability {
      case .downloading, .onDevice(isCurrent: false):
        // Zugriff auf die Freigabe während des Aufrufs halten; `stop()` beendet ihn genau einmal.
        let token = AccessToken(scopeURL: found.material.grantURL)
        await downloader.requestDownload(of: found.material.fileURL)
        token.stop()
        requested.append(reference)
      case .onDevice(isCurrent: true), .unavailable:
        continue
      }
    }
    return requested
  }
}
