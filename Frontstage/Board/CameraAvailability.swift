import AVFoundation

/// Ob und warum die Kamera der Tafel (FR-12.5) nutzbar ist.
enum CameraAvailability: Equatable, Sendable {
  case available
  /// Die Freigabe wurde noch nicht erfragt.
  case notDetermined
  /// Verweigert oder durch Einschränkungen (Bildschirmzeit, Geräteverwaltung) gesperrt.
  case denied
  /// Geteilte Ansicht (Split View/Slide Over): das System erlaubt der App dort keine Kamera.
  case unavailableInMultitasking
  case noCamera

  /// Reihenfolge der Gründe: erst fehlendes Gerät, dann Multitasking, dann die Freigabe.
  static func from(status: AVAuthorizationStatus, hasDevice: Bool, multitaskingBlocked: Bool) -> CameraAvailability {
    guard hasDevice else { return .noCamera }
    if multitaskingBlocked { return .unavailableInMultitasking }
    switch status {
    case .authorized: return .available
    case .notDetermined: return .notDetermined
    // Swift-Hinweis: `@unknown default` fängt künftige Fälle ab und warnt den Compiler, wenn welche dazukommen.
    case .denied, .restricted: return .denied
    @unknown default: return .denied
    }
  }
}
