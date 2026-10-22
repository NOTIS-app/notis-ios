import Foundation
import SwiftData

/// Emergency unlock, the same as Android: a few minutes of access, a limited number per session.
/// It reuses Foqos' pause timer, so the DeviceMonitor extension lifts the restrictions and puts
/// them back on time even when NOTIS is closed.
enum NotisEmergencyUnlock {
  static let maxPerSession = 2
  static let durationInMinutes = 5

  static let remainingKey = "notisEmergencyUnlocksRemaining"
  static let endsAtKey = "notisEmergencyEndsAt"

  private static var defaults: UserDefaults { .standard }

  static var remaining: Int {
    defaults.object(forKey: remainingKey) as? Int ?? maxPerSession
  }

  static func resetForNewSession() {
    defaults.set(maxPerSession, forKey: remainingKey)
    defaults.set(0.0, forKey: endsAtKey)
  }

  static func clear() {
    defaults.set(0.0, forKey: endsAtKey)
  }

  static func start(session: BlockedProfileSession, context: ModelContext) throws {
    guard remaining > 0 else { return }

    let profile = session.blockedProfile
    // The pause timer reads its duration from the profile's strategy data.
    profile.strategyData = StrategyPauseTimerData.toData(
      from: StrategyPauseTimerData(pauseDurationInMinutes: durationInMinutes))
    BlockedProfiles.updateSnapshot(for: profile)
    try context.save()

    try DeviceActivityCenterUtil.schedulePauseTimerActivity(for: profile)

    defaults.set(remaining - 1, forKey: remainingKey)
    let endsAt = Date().addingTimeInterval(TimeInterval(durationInMinutes * 60))
    defaults.set(endsAt.timeIntervalSince1970, forKey: endsAtKey)
  }

  /// "Blokkeren hervatten": end the pause early. Stopping the monitor skips its end callback,
  /// so the restrictions go back on here.
  static func resume(session: BlockedProfileSession, context: ModelContext) {
    DeviceActivityCenterUtil.removePauseTimerActivity(for: session.blockedProfile)
    AppBlockerUtil().activateRestrictions(for: BlockedProfiles.getSnapshot(for: session.blockedProfile))
    if session.isPauseActive {
      session.endPause()
    }
    try? context.save()
    clear()
  }
}
