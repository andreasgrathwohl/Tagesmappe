import Testing
@testable import FrontstageCore

@Suite("MaterialAvailability")
struct MaterialAvailabilityTests {
  struct Row: Sendable, CustomTestStringConvertible {
    let facts: FileFacts
    let online: Bool
    let expected: MaterialAvailability
    let label: String
    var testDescription: String { label }
  }

  static let rows: [Row] = [
    Row(facts: FileFacts(grantResolved: false, exists: false, isUbiquitous: false), online: true,
        expected: .unavailable(.grantMissing), label: "grant missing"),
    Row(facts: FileFacts(grantResolved: true, exists: false, isUbiquitous: false), online: true,
        expected: .unavailable(.fileMissing), label: "file missing"),
    Row(facts: FileFacts(grantResolved: true, exists: true, isUbiquitous: false), online: false,
        expected: .onDevice(isCurrent: true), label: "local file"),
    Row(facts: FileFacts(grantResolved: true, exists: true, isUbiquitous: true, downloadStatus: .current),
        online: false, expected: .onDevice(isCurrent: true), label: "cloud current"),
    Row(facts: FileFacts(grantResolved: true, exists: true, isUbiquitous: true, downloadStatus: .downloaded),
        online: false, expected: .onDevice(isCurrent: false), label: "cloud older version"),
    Row(facts: FileFacts(grantResolved: true, exists: true, isUbiquitous: true, downloadStatus: .downloaded,
                         isDownloading: true), online: true,
        expected: .downloading(progress: nil), label: "older version, updating"),
    Row(facts: FileFacts(grantResolved: true, exists: true, isUbiquitous: true, downloadStatus: .notDownloaded,
                         isDownloading: true, downloadFraction: 0.4), online: true,
        expected: .downloading(progress: 0.4), label: "downloading with fraction"),
    Row(facts: FileFacts(grantResolved: true, exists: true, isUbiquitous: true, downloadStatus: .notDownloaded),
        online: true, expected: .downloading(progress: nil), label: "online, triggers download"),
    Row(facts: FileFacts(grantResolved: true, exists: true, isUbiquitous: true, downloadStatus: .notDownloaded),
        online: false, expected: .unavailable(.notDownloadedOffline), label: "offline, not downloaded"),
    Row(facts: FileFacts(grantResolved: true, exists: true, isUbiquitous: true, downloadStatus: .notDownloaded,
                         hasDownloadError: true), online: true,
        expected: .unavailable(.downloadFailed), label: "download failed"),
  ]

  @Test("Zustand aus Dateifakten (NFR-1, Area ablage)", arguments: rows)
  func classifiesFacts(row: Row) {
    #expect(AvailabilityClassifier.classify(row.facts, isOnline: row.online) == row.expected)
  }
}
