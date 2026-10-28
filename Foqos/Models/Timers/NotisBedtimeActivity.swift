import DeviceActivity
import FamilyControls
import Foundation
import OSLog

private let log = Logger(subsystem: "com.foqos.monitor", category: NotisBedtimeActivity.id)

/// NOTIS evening lock (Avondslot, `FeatureFlags.bedtimeLock`), run by the device activity monitor
/// so it works with the app closed. One activity per weekday of an alarm, named
/// "NotisBedtimeActivity:<weekday>:<minuteOfDay>:<armedAt>:<profileId>". Its start locks with the
/// profile, unless something already is locked; its end does nothing: only a stone unlocks.
class NotisBedtimeActivity: TimerActivity {
  static var id: String = "NotisBedtimeActivity"

  private let appBlocker = AppBlockerUtil()

  static func activityName(weekday: Int, minuteOfDay: Int, armedAt: Date, profileId: UUID)
    -> DeviceActivityName
  {
    DeviceActivityName(
      rawValue:
        "\(id):\(weekday):\(minuteOfDay):\(Int(armedAt.timeIntervalSince1970)):\(profileId.uuidString)"
    )
  }

  static func isBedtime(_ activity: DeviceActivityName) -> Bool {
    activity.rawValue.hasPrefix("\(id):")
  }

  func profileId(from activityName: DeviceActivityName) -> String {
    String(activityName.rawValue.split(separator: ":").last ?? "")
  }

  func start(for profile: SharedData.ProfileSnapshot) {}

  func stop(for profile: SharedData.ProfileSnapshot) {}

  func start(for profile: SharedData.ProfileSnapshot, activityName: DeviceActivityName) {
    let parts = activityName.rawValue.split(separator: ":")
    guard parts.count == 5, let minuteOfDay = Int(parts[2]), let armedAt = TimeInterval(parts[3])
    else { return }

    // Set up while today's interval was already running (iOS starts it right away): not today.
    let todaysLock = Calendar.current.startOfDay(for: Date())
      .addingTimeInterval(TimeInterval(minuteOfDay * 60))
    if Date(timeIntervalSince1970: armedAt) > todaysLock {
      log.info("Evening lock set up after today's time, skipped")
      return
    }

    // Without Screen Time the lock would block nothing.
    guard AuthorizationCenter.shared.authorizationStatus == .approved else {
      log.info("Evening lock: Screen Time not allowed, skipped")
      return
    }

    guard SharedData.getActiveSharedSession() == nil else {
      log.info("Evening lock: already locked, nothing to do")
      return
    }

    let session = SharedData.createSessionForSchedular(for: profile.id)
    BlockingSessionLifecycleRegistry.sessionDidStart(
      BlockingSessionLifecycleContext(profile: profile, session: session)
    )
    appBlocker.activateRestrictions(for: profile)
    log.info("Evening lock started for \(profile.id.uuidString)")
  }

  func stop(for profile: SharedData.ProfileSnapshot, activityName: DeviceActivityName) {
    // The evening lock stays until a stone unlocks.
  }
}
