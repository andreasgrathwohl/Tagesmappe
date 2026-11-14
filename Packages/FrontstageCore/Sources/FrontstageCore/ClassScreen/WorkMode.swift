/// Arbeitsform der laufenden Unterrichtsstunde, die die Lehrkraft für den Klassenbildschirm wählt (FR-11.3).
public enum WorkMode: String, CaseIterable, Codable, Sendable {
  /// Einzelarbeit.
  case individual
  /// Partnerarbeit.
  case pairs
  /// Gruppenarbeit.
  case groups
}
