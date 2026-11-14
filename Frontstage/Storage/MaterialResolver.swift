import Foundation
import FrontstageCore

struct ResolvedMaterial: Sendable {
  let fileURL: URL
  let grantURL: URL
}

/// Löst Materialverweise (Freigabe-Name + Pfad) auf diesem Gerät zu Dateien auf.
/// Nur lesend: Ressourcenwerte und `contentsOfDirectory`.
@MainActor final class MaterialResolver {
  private let grants: FolderGrantStore

  init(grants: FolderGrantStore) {
    self.grants = grants
  }

  private enum Lookup {
    case grantMissing
    case fileMissing
    case found(ResolvedMaterial)
  }

  /// Läuft Pfadbestandteil für Pfadbestandteil: erst der genaue Name, sonst Nachschlagen im
  /// Ordnerinhalt per `StoragePath.matchName` (NFC, Groß-/Kleinschreibung).
  ///
  /// Mit `resolvingFile: false` werden nur die Ordnerkomponenten aufgelöst; der Dateiname bleibt unverändert
  /// (die Datei muss dann nicht existieren, z. B. für Notizen neben dem Dokument).
  private func lookup(_ reference: MaterialReference, resolvingFile: Bool = true) -> Lookup {
    guard let grant = grants.grant(named: reference.folderGrantName),
      let grantURL = grants.resolvedURL(for: grant)
    else { return .grantMissing }

    // Zugriffsfenster nur für die Suche; `open` hält später ein eigenes.
    let accessing = grantURL.startAccessingSecurityScopedResource()
    defer { if accessing { grantURL.stopAccessingSecurityScopedResource() } }

    let components = StoragePath.components(ofRelativePath: reference.relativePath)
    guard !components.isEmpty else { return .fileMissing }
    let fileManager = FileManager.default
    var current = grantURL
    for (index, component) in components.enumerated() {
      if !resolvingFile, index == components.count - 1 {
        current = current.appending(path: component, directoryHint: .notDirectory)
        break
      }
      let direct = current.appending(path: component, directoryHint: .inferFromPath)
      if fileManager.fileExists(atPath: direct.path(percentEncoded: false)) {
        current = direct
        continue
      }
      guard let names = try? fileManager.contentsOfDirectory(atPath: current.path(percentEncoded: false)),
        let match = StoragePath.matchName(component, among: names)
      else { return .fileMissing }
      current = current.appending(path: match, directoryHint: .inferFromPath)
    }
    return .found(ResolvedMaterial(fileURL: current, grantURL: grantURL))
  }

  /// Freigabe-URL + Pfad; `nil` = löst nicht auf (Freigabe oder Datei fehlt).
  func resolve(_ reference: MaterialReference) -> ResolvedMaterial? {
    if case .found(let resolved) = lookup(reference) { return resolved }
    return nil
  }

  /// Wie `resolve`, löst aber nur die Ordner auf und hängt den Dateinamen unverändert an (Teilplan 06: Notizen
  /// liegen neben dem Dokument). `nil` = Freigabe oder ein Ordner fehlt.
  func resolveFolder(of reference: MaterialReference) -> ResolvedMaterial? {
    if case .found(let resolved) = lookup(reference, resolvingFile: false) { return resolved }
    return nil
  }

  func availability(of reference: MaterialReference, isOnline: Bool) -> MaterialAvailability {
    let facts: FileFacts
    switch lookup(reference) {
    case .grantMissing:
      facts = FileFacts(grantResolved: false, exists: false, isUbiquitous: false)
    case .fileMissing:
      facts = FileFacts(grantResolved: true, exists: false, isUbiquitous: false)
    case .found(let resolved):
      let accessing = resolved.grantURL.startAccessingSecurityScopedResource()
      defer { if accessing { resolved.grantURL.stopAccessingSecurityScopedResource() } }
      facts = FileFactsReader.facts(at: resolved.fileURL)
    }
    return AvailabilityClassifier.classify(facts, isOnline: isOnline)
  }

  /// Öffnet den Zugriff und hält ihn, bis `close()` oder `deinit`. `nil` = löst nicht auf.
  func open(_ reference: MaterialReference) -> ScopedFile? {
    guard let resolved = resolve(reference) else { return nil }
    return ScopedFile(url: resolved.fileURL, reference: reference, grantURL: resolved.grantURL)
  }

  /// Datei aus der Ordnerauswahl → Verweis; `nil` = außerhalb freigegebener Ordner.
  func reference(forPickedFile url: URL) -> MaterialReference? {
    let path = url.standardizedFileURL.resolvingSymlinksInPath().path(percentEncoded: false)
    let components = StoragePath.normalizedComponents(path)
    guard let location = StoragePath.relativeLocation(ofFile: components, in: grants.grantLocations())
    else { return nil }
    let fileName = url.lastPathComponent.precomposedStringWithCanonicalMapping
    return MaterialReference(
      folderGrantName: location.folderGrantName, relativePath: location.relativePath,
      displayName: (fileName as NSString).deletingPathExtension,
      fileKind: MaterialFileKind(fileExtension: url.pathExtension))
  }
}
