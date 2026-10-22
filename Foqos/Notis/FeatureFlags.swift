import Foundation

/// NOTIS keeps the app deliberately simple: only a NOTIS stone locks and unlocks. Foqos
/// features we don't show are hidden here, not deleted, so a flag set back to `true`
/// restores them. Mirrors `FeatureFlags.kt` in the Android app.
enum FeatureFlags {
  /// NOTIS home (stone button, "Mijn NOTIS", settings). Off: the original Foqos dashboard
  /// with profiles, strategies, insights and schedules.
  static let notisHome = true

  /// Each stone lists the apps that stay usable; everything else is blocked during a session.
  /// Off: each stone lists the apps to block.
  static let allowList = true

  /// Long-press the stone button to unlock without a stone (limited count).
  static let emergencyUnlock = true

  /// School live: students join a class and a teacher's class stone locks the whole class.
  /// Off for the first TestFlight test.
  static let schoolLive = false

  /// Parent controls: a parent sets the app list for a child's phone. Off for the first
  /// TestFlight test.
  static let parentControls = false
}

enum NotisDevice {
  static var isSimulator: Bool {
    #if targetEnvironment(simulator)
      return true
    #else
      return false
    #endif
  }
}
