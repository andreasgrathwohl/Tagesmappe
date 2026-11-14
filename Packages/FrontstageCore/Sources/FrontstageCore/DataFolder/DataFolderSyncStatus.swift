import Foundation

/// Stand des Abgleichs, wie ihn die Einstellungen anzeigen.
public struct DataFolderSyncStatus: Equatable, Sendable {
  public enum Phase: Equatable, Sendable { case idle, syncing, offline, signInRequired, failed }

  public var phase: Phase
  public var lastSuccess: Date?
  /// Lokale Änderungen, die noch nicht geschrieben sind.
  public var pendingCount: Int
  /// Kennungen, die auf einen fehlenden Anhang oder eine unlesbare Datei warten.
  public var waitingCount: Int
  /// Dateien in einem neueren Format als dieses Gerät lesen kann.
  public var newerFormatCount: Int

  public init(
    phase: Phase = .idle, lastSuccess: Date? = nil, pendingCount: Int = 0, waitingCount: Int = 0,
    newerFormatCount: Int = 0
  ) {
    self.phase = phase
    self.lastSuccess = lastSuccess
    self.pendingCount = pendingCount
    self.waitingCount = waitingCount
    self.newerFormatCount = newerFormatCount
  }

  /// Genau eine Aussage für „Stand des Abgleichs“ – in der Vorrangfolge der Fälle.
  public var summary: DataFolderSyncSummary {
    if phase == .signInRequired { return .signInRequired }
    if newerFormatCount > 0 { return .needsNewerApp }
    if phase == .offline { return .offline(pending: pendingCount) }
    if phase == .failed { return .failed(lastSuccess: lastSuccess) }
    if phase == .syncing { return .syncing }
    if waitingCount > 0 { return .waiting(count: waitingCount) }
    if pendingCount > 0 { return .pending(count: pendingCount) }
    if let lastSuccess { return .upToDate(since: lastSuccess) }
    return .neverSynced
  }
}

/// Die eine Aussage zum Stand des Abgleichs.
public enum DataFolderSyncSummary: Equatable, Sendable {
  case signInRequired
  case needsNewerApp
  case offline(pending: Int)
  case failed(lastSuccess: Date?)
  case syncing
  case waiting(count: Int)
  case pending(count: Int)
  case upToDate(since: Date)
  case neverSynced
}
