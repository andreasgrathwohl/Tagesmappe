import FrontstageCore
import SwiftUI

/// Hinweis, den die Statusleiste der Stundenplan-Quelle zeigt.
enum SourceStatusNotice: Equatable {
  case none
  /// Der Stand ist nicht von heute (oder fehlt noch).
  case stale
  case failed(TimetableSourceError)
  /// Mehrere Abfragen in Folge schlugen fehl: Stundenplan von Hand pflegen vorschlagen.
  case suggestManualMaintenance
  /// Eine Vorschau wartet auf Übernahme.
  case previewPending
  /// Quelle gewählt, aber keine Zugangsdaten im Schlüsselbund.
  case notSignedIn
}

/// Reines Wertmodell der Statusleiste: berechnet alles aus Stand, Zustand und Uhrzeit (DESIGN.md: keine danebengepflegten Zahlen).
struct SourceStatusBarModel: Equatable {
  /// Ab dieser Zahl aufeinanderfolgender Fehler wird Pflege von Hand vorgeschlagen.
  static let manualMaintenanceThreshold = 3

  let kind: TimetableSourceKind
  let fetchedAt: Date?
  let notice: SourceStatusNotice
  /// Ob `fetchedAt` am selben Kalendertag wie „jetzt“ liegt (steuert die Darstellung der Uhrzeit).
  let isFetchedToday: Bool

  /// Vorrang: notSignedIn > suggestManualMaintenance > failed > previewPending > stale > none.
  /// `stale` rechnet aus `fetchedAt` (gespiegelter Stand), nicht aus `status.lastSuccessAt`.
  init(
    kind: TimetableSourceKind, fetchedAt: Date?, status: SourceStatus, hasPendingPreview: Bool,
    hasCredentials: Bool, now: Date, calendar: Calendar
  ) {
    self.kind = kind
    self.fetchedAt = fetchedAt
    let today = fetchedAt.map { calendar.isDate($0, inSameDayAs: now) } ?? false
    isFetchedToday = today

    if kind == .schulmanager && !hasCredentials {
      notice = .notSignedIn
    } else if status.consecutiveFailures >= Self.manualMaintenanceThreshold {
      notice = .suggestManualMaintenance
    } else if let error = status.lastError {
      notice = .failed(error)
    } else if hasPendingPreview {
      notice = .previewPending
    } else if !today {
      notice = .stale
    } else {
      notice = .none
    }
  }

  /// Bei „von Hand“ gibt es keine Quelle und damit keinen Stand.
  var isVisible: Bool { kind != .manual }
}

/// Statusleiste der Stundenplan-Quelle für den Kopf der Tagesansicht; Teilplan 04 hängt sie dort ein.
/// Zustand immer als Symbol plus Text, nie nur über Farbe. Gestaltung (Wortlaut, Anordnung) ist offen.
///
/// Swift-Hinweis: `@Environment(Type.self)` liest ein `@Observable`-Objekt aus der Umgebung; SwiftUI
/// zeichnet die Ansicht neu, sobald sich eine dabei gelesene Eigenschaft ändert.
struct SourceStatusBar: View {
  @Environment(TimetableSourceCoordinator.self) private var coordinator

  /// Dieselben Zugangsdaten wie in `TimetableSourceSettingsView` und `SourceCoordinatorHolder.live`.
  private let credentials: any CredentialStore = KeychainCredentialStore()

  /// Ob Zugangsdaten im Schlüsselbund liegen; `nil`, solange noch nicht gelesen. Gelesen wird beim
  /// Erscheinen und nach Anmelden/Abmelden, nicht bei jedem Neuzeichnen (jeder Zugriff fragt den Schlüsselbund).
  @State private var hasCredentials: Bool?

  init() {}

  var body: some View {
    let model = makeModel()
    if model.isVisible {
      VStack(alignment: .leading, spacing: 4) {
        HStack {
          Label {
            Text(sourceNameKey(model.kind))
          } icon: {
            Image(systemName: "calendar.badge.clock")
          }
          Spacer()
          fetchedAtText(model)
            .foregroundStyle(.secondary)
          Button("sourceStatus.refresh") {
            Task { await coordinator.refresh(.userRequest) }
          }
          .disabled(coordinator.isFetching || model.notice == .notSignedIn)
        }
        noticeLabel(model.notice)
      }
      .font(.footnote)
      // `.task(id:)` läuft beim Erscheinen und erneut, sobald sich der Wert ändert.
      .task(id: coordinator.credentialsRevision) {
        hasCredentials = (try? credentials.load()) != nil
      }
    }
  }

  // MARK: - Bausteine

  @ViewBuilder private func fetchedAtText(_ model: SourceStatusBarModel) -> some View {
    if let fetchedAt = model.fetchedAt {
      if model.isFetchedToday {
        Text("sourceStatus.fetchedToday \(fetchedAt.formatted(date: .omitted, time: .shortened))")
      } else {
        Text(
          "sourceStatus.fetchedOther \(fetchedAt.formatted(.dateTime.weekday(.wide).hour().minute()))")
      }
    } else {
      Text("sourceStatus.neverFetched")
    }
  }

  @ViewBuilder private func noticeLabel(_ notice: SourceStatusNotice) -> some View {
    switch notice {
    case .none:
      EmptyView()
    case .stale:
      Label("sourceStatus.notice.stale", systemImage: "clock.badge.exclamationmark")
    case .failed(let error):
      Label {
        if case .server(let status) = error {
          Text("timetableSource.error.server \(status)")
        } else {
          Text(LocalizedStringKey(error.settingsMessageKey))
        }
      } icon: {
        Image(systemName: "exclamationmark.triangle")
      }
    case .suggestManualMaintenance:
      Label("sourceStatus.notice.manualMaintenance", systemImage: "hand.point.up.left")
    case .previewPending:
      Label("sourceStatus.notice.previewPending", systemImage: "tray.and.arrow.down")
    case .notSignedIn:
      Label("sourceStatus.notice.notSignedIn", systemImage: "person.crop.circle.badge.xmark")
    }
  }

  private func sourceNameKey(_ kind: TimetableSourceKind) -> LocalizedStringKey {
    switch kind {
    case .manual: "timetableSource.source.manual"
    case .schulmanager: "timetableSource.source.schulmanager"
    }
  }

  private func makeModel() -> SourceStatusBarModel {
    // Mitlesen, damit ein Abgleich vom anderen Gerät (Stand, Quelle) neu zeichnet; die Abfragen darunter
    // sind für SwiftUI nicht beobachtbar.
    _ = coordinator.repository.revision
    return SourceStatusBarModel(
      kind: (try? coordinator.repository.timetableSourceKind()) ?? .manual,
      fetchedAt: try? coordinator.repository.sourceFetchedAt(),
      status: coordinator.status,
      hasPendingPreview: coordinator.pendingPreview != nil,
      // Noch nicht gelesen: kein „nicht angemeldet“ aufblitzen lassen.
      hasCredentials: hasCredentials ?? true,
      now: Date(), calendar: .current)
  }
}
