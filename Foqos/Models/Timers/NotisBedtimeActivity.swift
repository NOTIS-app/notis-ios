import DeviceActivity
import FamilyControls
import Foundation
import OSLog

private let log = Logger(subsystem: "com.foqos.monitor", category: NotisBedtimeActivity.id)

/// NOTIS evening lock (Avondslot, `FeatureFlags.bedtimeLock`), run by the device activity monitor
/// so it works with the app closed. One activity per weekday of an alarm, named
/// "NotisBedtimeActivity:<weekday>:<minuteOfDay>:<armedAt>:<endMinuteOfDay or -1>:<profileId>"
/// (older ones have no end field). Its start locks with the profile; an own lock that is running
/// becomes the evening lock, a school lock stays. Its end unlocks only when the alarm has an end
/// time and the evening lock is still the one running; otherwise only a stone unlocks.
class NotisBedtimeActivity: TimerActivity {
  static var id: String = "NotisBedtimeActivity"

  private let appBlocker = AppBlockerUtil()

  static func activityName(
    weekday: Int, minuteOfDay: Int, armedAt: Date, endMinuteOfDay: Int?, profileId: UUID
  ) -> DeviceActivityName {
    DeviceActivityName(
      rawValue:
        "\(id):\(weekday):\(minuteOfDay):\(Int(armedAt.timeIntervalSince1970)):\(endMinuteOfDay ?? -1):\(profileId.uuidString)"
    )
  }

  /// The parts of a name: lock time, set-up time and end time (nil: none).
  static func parts(of activity: DeviceActivityName)
    -> (weekday: Int, minuteOfDay: Int, armedAt: TimeInterval, endMinuteOfDay: Int?, profileId: String)?
  {
    let parts = activity.rawValue.split(separator: ":").map(String.init)
    guard parts.count == 5 || parts.count == 6, let weekday = Int(parts[1]),
      let minuteOfDay = Int(parts[2]), let armedAt = TimeInterval(parts[3])
    else { return nil }
    let end = parts.count == 6 ? Int(parts[4]).flatMap { $0 >= 0 ? $0 : nil } : nil
    return (weekday, minuteOfDay, armedAt, end, parts[parts.count - 1])
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
    guard let parts = Self.parts(of: activityName) else { return }

    // Set up while this interval was already running (iOS starts it right away): skipped. The
    // interval may have begun yesterday evening, when it runs to the next morning.
    let now = Date()
    var lockTime = Calendar.current.startOfDay(for: now)
      .addingTimeInterval(TimeInterval(parts.minuteOfDay * 60))
    if lockTime > now { lockTime = lockTime.addingTimeInterval(-24 * 60 * 60) }
    if Date(timeIntervalSince1970: parts.armedAt) > lockTime {
      log.info("Evening lock set up after its time, skipped")
      return
    }

    // Without Screen Time the lock would block nothing.
    guard AuthorizationCenter.shared.authorizationStatus == .approved else {
      log.info("Evening lock: Screen Time not allowed, skipped")
      return
    }

    if let running = SharedData.getActiveSharedSession() {
      // A school lock (its tag is "room:<id>") stays; an own lock becomes the evening lock.
      if running.tag.hasPrefix("room:") {
        log.info("Evening lock: school lock running, nothing to do")
        return
      }
      SharedData.endActiveSharedSession()
    }

    let session = SharedData.createSessionForSchedular(for: profile.id)
    BlockingSessionLifecycleRegistry.sessionDidStart(
      BlockingSessionLifecycleContext(profile: profile, session: session)
    )
    appBlocker.activateRestrictions(for: profile)
    log.info("Evening lock started for \(profile.id.uuidString)")
  }

  func stop(for profile: SharedData.ProfileSnapshot, activityName: DeviceActivityName) {
    // Without an end time the evening lock stays until a stone unlocks.
    guard Self.parts(of: activityName)?.endMinuteOfDay != nil,
      let session = SharedData.getActiveSharedSession(),
      // Still the evening lock (a stone in between ends it, another lock has its own tag).
      session.blockedProfileId == profile.id, session.tag == profile.id.uuidString
    else { return }

    BlockingSessionLifecycleRegistry.sessionDidEnd(
      BlockingSessionLifecycleContext(profile: profile, session: session)
    )
    appBlocker.deactivateRestrictions()
    SharedData.endActiveSharedSession()
    log.info("Evening lock ended at its end time")
  }
}
