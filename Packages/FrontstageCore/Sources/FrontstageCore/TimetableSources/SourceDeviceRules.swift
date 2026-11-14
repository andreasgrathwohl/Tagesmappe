import Foundation

// Regeln, die von Zugangsdaten und Zustand dieses Geräts abhängen (Teilplan 05, Nachtrag).
// Zugangsdaten liegen nur im Schlüsselbund des Geräts (NFR-4); Stundenplan und Stand werden gespiegelt.

extension TimetableSourceError {
  /// Fehler, nach denen gespeicherte Zugangsdaten gelöscht werden: Sie würden bei jeder weiteren Abfrage
  /// wieder scheitern (falsch) oder nie unterstützt (mehrere Schulen, Annahme A5). Löschen beendet zugleich
  /// die automatischen Abfragen (siehe `SourceRefreshGate`). Netz-, Server- und Formfehler sind vorübergehend:
  /// Die Zugangsdaten bleiben.
  public var discardsCredentials: Bool {
    switch self {
    case .invalidCredentials, .multipleSchoolsUnsupported: return true
    case .notConfigured, .offline, .server, .unexpectedResponse: return false
    }
  }
}

/// Ob dieses Gerät die Quelle überhaupt abfragen darf – vor Abfrage-Regeln und Fehlzähler.
public enum SourceRefreshGate: Equatable, Sendable {
  /// „Von Hand“: Es gibt nichts abzufragen.
  case noSource
  /// Die Quelle braucht eine Anmeldung, auf diesem Gerät liegen aber keine Zugangsdaten (typisch der Mac,
  /// wenn nur am iPad angemeldet wurde). Kein Versuch, kein Fehler; der Stand kommt per Spiegelung.
  case signInRequired
  case ready

  public static func evaluate(kind: TimetableSourceKind, hasCredentials: Bool) -> SourceRefreshGate {
    switch kind {
    case .manual: return .noSource
    case .schulmanager: return hasCredentials ? .ready : .signInRequired
    }
  }
}

/// Stabile Prüfsumme des Stundenplan-Teils eines Stands (Einträge und Zeitraster, ohne Abweichungen).
/// Unabhängig von Reihenfolge, Plattform und Prozess – Swifts `Hasher` ist je Prozess anders geimpft und
/// taugt deshalb nicht zum Speichern.
public enum TimetablePartChecksum {
  /// Eine Zeile je Eintrag mit den normalisierten Namen (wie der Vergleich im Stundenplan), sortiert;
  /// danach das Zeitraster nach Stundennummer. Ein leeres Zeitraster zählt wie keines.
  public static func of(entries: [TimetableEntry], bellSchedule: BellSchedule?) -> String {
    let entryLines = entries.map { entry in
      [
        entry.weekVariant?.rawValue ?? "-", String(entry.weekday.rawValue), String(entry.period),
        entry.schoolClass.normalized, entry.subject.normalized,
      ].joined(separator: "\u{1F}")  // Einheitentrenner: kommt in Namen nicht vor
    }.sorted()
    let bellLines = (bellSchedule?.periods ?? [:]).sorted { $0.key < $1.key }.map { period, range in
      "\(period)=\(range.lowerBound.minutesSinceMidnight)-\(range.upperBound.minutesSinceMidnight)"
    }
    let text = (entryLines + ["#bell"] + bellLines).joined(separator: "\n")
    return ContentHash.fnv1a64(Data(text.utf8))
  }

  /// `nil`, wenn der Stand keinen Wochenplan abgeleitet hat (dann gibt es auch keine Vorschau).
  public static func of(_ snapshot: SourceSnapshot) -> String? {
    guard case .derived(let derived) = snapshot.timetable else { return nil }
    return of(entries: derived.entries, bellSchedule: snapshot.bellSchedule)
  }
}

/// Wann eine Vorschau angeboten, gemerkt oder verworfen wird.
public enum PendingPreviewRules {
  /// Ergebnis nach einer Abfrage: ob eine Vorschau entsteht und welche Prüfsumme gemerkt bleibt.
  public struct Offer: Equatable, Sendable {
    public var showsPreview: Bool
    public var rememberedChecksum: String?

    public init(showsPreview: Bool, rememberedChecksum: String?) {
      self.showsPreview = showsPreview
      self.rememberedChecksum = rememberedChecksum
    }
  }

  /// Eine verworfene (oder mit „Meine Fassung behalten“ übernommene) Vorschau kommt nicht wieder, solange
  /// die Quelle denselben Stundenplan-Teil liefert. Liefert sie etwas anderes, gilt der Merker nicht mehr –
  /// auch wenn dieser andere Stand nichts zu zeigen hat, damit eine spätere Rückkehr zum alten Stand wieder
  /// als Unterschied erscheint. Ohne Prüfsumme (kein abgeleiteter Wochenplan) bleibt der Merker.
  public static func offer(hasDifferences: Bool, checksum: String?, remembered: String?) -> Offer {
    guard let checksum else {
      return Offer(showsPreview: hasDifferences, rememberedChecksum: remembered)
    }
    if checksum == remembered {
      return Offer(showsPreview: false, rememberedChecksum: remembered)
    }
    return Offer(showsPreview: hasDifferences, rememberedChecksum: nil)
  }

  /// Nach dem Übernehmen: Hat die Lehrkraft bei mindestens einem Konflikt ihre Fassung behalten, würde
  /// dieselbe Quelle den Konflikt bei jeder Abfrage wieder zeigen – also merken. Sonst nichts merken.
  public static func rememberedAfterApply(
    checksum: String?, conflictSources: [TimetableEntry], acceptedFromSource: Set<TimetableEntry>
  ) -> String? {
    let keptMine = conflictSources.contains { !acceptedFromSource.contains($0) }
    return keptMine ? checksum : nil
  }

  /// Die Vorschau liegt nur auf diesem Gerät. Ist der gespiegelte Stand neuer (das andere Gerät hat später
  /// abgefragt), ist sie überholt und wird verworfen statt übernommen.
  public static func isSuperseded(previewFetchedAt: Date, storedFetchedAt: Date?) -> Bool {
    guard let storedFetchedAt else { return false }
    return storedFetchedAt > previewFetchedAt
  }
}
