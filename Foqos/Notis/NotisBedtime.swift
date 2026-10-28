import DeviceActivity
import Foundation
import SwiftData

/// One evening lock time, like an alarm (`FeatureFlags.bedtimeLock`), as Android's
/// `BedtimeAlarm`. At `minuteOfDay` on each of its `days` the phone locks with `profileId`;
/// only a stone unlocks. There can be any number of alarms, but a day has at most one that is on.
struct NotisBedtimeAlarm: Codable, Equatable, Identifiable {
  var id = UUID().uuidString
  /// Minutes after midnight, 0..1439.
  var minuteOfDay: Int
  /// Bitmask, bit 0 = Monday … bit 6 = Sunday, as on Android.
  var days: Int
  /// The profile to lock with; nil = the profile picked on Home.
  var profileId: String?
  var enabled = true

  var hour: Int { minuteOfDay / 60 }
  var minute: Int { minuteOfDay % 60 }
  var timeText: String { String(format: "%02d:%02d", hour, minute) }
}

/// The alarms, kept on the phone, and the device activities that lock at their times. Runs
/// locally: iOS starts the lock through the device activity monitor, also with the app closed.
enum NotisBedtime {
  static let allDays = 0b1111111
  static let weekdays = 0b0011111
  static let weekend = 0b1100000

  private static let key = "notis.bedtimeAlarms"

  /// Monday first, as the day chips show them.
  static let dayOrder = Array(0..<7)

  static func load() -> [NotisBedtimeAlarm] {
    guard let data = UserDefaults.standard.data(forKey: key),
      let alarms = try? JSONDecoder().decode([NotisBedtimeAlarm].self, from: data)
    else { return [] }
    return alarms
  }

  private static func store(_ alarms: [NotisBedtimeAlarm]) {
    UserDefaults.standard.set(try? JSONEncoder().encode(alarms), forKey: key)
  }

  /// Days already used by the other alarms: those can't be picked for `exceptId`.
  /// Days that another switched-on alarm than `exceptId` already locks on.
  static func takenDays(_ alarms: [NotisBedtimeAlarm], exceptId: String?) -> Int {
    alarms.filter { $0.id != exceptId && $0.enabled }.reduce(0) { $0 | $1.days }
  }

  /// `alarms` with `alarm` saved (new or edited). When it is on, the other switched-on alarms
  /// that share a day with it are switched off: one lock time per day. They are kept.
  static func saved(_ alarms: [NotisBedtimeAlarm], _ alarm: NotisBedtimeAlarm) -> [NotisBedtimeAlarm] {
    let others = alarms.filter { $0.id != alarm.id }.map { other in
      var other = other
      if alarm.enabled && other.enabled && other.days & alarm.days != 0 { other.enabled = false }
      return other
    }
    return (others + [alarm]).sorted { $0.minuteOfDay < $1.minuteOfDay }
  }

  /// Saves `alarm` (new or edited); other switched-on alarms on its days go off.
  static func save(_ alarm: NotisBedtimeAlarm, in context: ModelContext) -> [NotisBedtimeAlarm] {
    write(saved(load(), alarm), in: context)
  }

  /// Switches alarm `id` on or off; switching on turns clashing ones off.
  static func setEnabled(_ id: String, _ enabled: Bool, in context: ModelContext) -> [NotisBedtimeAlarm] {
    let alarms = load()
    guard var alarm = alarms.first(where: { $0.id == id }) else { return alarms }
    alarm.enabled = enabled
    return write(saved(alarms, alarm), in: context)
  }

  static func delete(_ id: String, in context: ModelContext) -> [NotisBedtimeAlarm] {
    write(load().filter { $0.id != id }, in: context)
  }

  private static func write(_ alarms: [NotisBedtimeAlarm], in context: ModelContext) -> [NotisBedtimeAlarm] {
    store(alarms)
    rearm(alarms, in: context)
    return alarms
  }

  /// Brings the evening lock's device activities in line with the alarms: one per weekday of each
  /// enabled alarm. Only changed ones are stopped or started: starting one again while its
  /// interval runs would lock again right away (after a stone unlocked it, say). A new one is
  /// marked with the time it was set up, so a lock time that already passed today waits.
  /// An alarm's profile that is gone falls back to the profile picked on Home.
  static func rearm(_ alarms: [NotisBedtimeAlarm] = load(), in context: ModelContext) {
    let center = DeviceActivityCenter()
    let running = center.activities.filter(NotisBedtimeActivity.isBedtime)
    var desired: [String: (DeviceActivitySchedule, Int, Int, UUID)] = [:]

    if FeatureFlags.bedtimeLock {
      let profiles = BlockedProfiles.fetchNotisProfiles(in: context)
      let picked = BlockedProfiles.selectedNotisProfile(in: context)
      for alarm in alarms where alarm.enabled {
        guard let profile = profiles.first(where: { $0.id.uuidString == alarm.profileId }) ?? picked
        else { continue }
        // The monitor reads the profile from its snapshot.
        BlockedProfiles.updateSnapshot(for: profile)
        for dayIndex in dayOrder where alarm.days & (1 << dayIndex) != 0 {
          // Calendar weekdays: 1 = Sunday … 7 = Saturday; ours start on Monday.
          let weekday = (dayIndex + 1) % 7 + 1
          let start = DateComponents(hour: alarm.hour, minute: alarm.minute, weekday: weekday)
          // iOS needs an interval of at least 15 minutes; its end does nothing.
          let endMinute = alarm.minuteOfDay + 16
          let end =
            endMinute < 24 * 60
            ? DateComponents(hour: endMinute / 60, minute: endMinute % 60, weekday: weekday)
            : DateComponents(
              hour: (endMinute - 24 * 60) / 60, minute: endMinute % 60, weekday: weekday % 7 + 1)
          let schedule = DeviceActivitySchedule(intervalStart: start, intervalEnd: end, repeats: true)
          desired[identity(weekday: weekday, minuteOfDay: alarm.minuteOfDay, profileId: profile.id.uuidString)] =
            (schedule, weekday, alarm.minuteOfDay, profile.id)
        }
      }
    }

    let runningByIdentity = Dictionary(
      running.map { (identity(of: $0), $0) }, uniquingKeysWith: { first, _ in first })
    center.stopMonitoring(running.filter { desired[identity(of: $0)] == nil })
    for (key, value) in desired where runningByIdentity[key] == nil {
      let (schedule, weekday, minuteOfDay, profileId) = value
      let name = NotisBedtimeActivity.activityName(
        weekday: weekday, minuteOfDay: minuteOfDay, armedAt: Date(), profileId: profileId)
      do {
        try center.startMonitoring(name, during: schedule)
      } catch {
        print("NotisBedtime: could not schedule \(name.rawValue): \(error)")
      }
    }
  }

  /// An activity without the time it was set up: what makes two of them the same lock.
  private static func identity(weekday: Int, minuteOfDay: Int, profileId: String) -> String {
    "\(weekday):\(minuteOfDay):\(profileId)"
  }

  private static func identity(of activity: DeviceActivityName) -> String {
    let parts = activity.rawValue.split(separator: ":")
    guard parts.count == 5 else { return activity.rawValue }
    return identity(weekday: Int(parts[1]) ?? 0, minuteOfDay: Int(parts[2]) ?? 0, profileId: String(parts[4]))
  }

  /// "Elke dag", "Doordeweeks", "Weekend" or "ma, wo, vr", as on Android.
  static func daysText(_ days: Int) -> String {
    switch days {
    case allDays: return String(localized: "Elke dag")
    case weekdays: return String(localized: "Doordeweeks")
    case weekend: return String(localized: "Weekend")
    case 0: return String(localized: "Nooit")
    default: return dayOrder.filter { days & (1 << $0) != 0 }.map(dayShort).joined(separator: ", ")
    }
  }

  static func dayShort(_ dayIndex: Int) -> String {
    // shortWeekdaySymbols start on Sunday.
    let symbols = Calendar.current.shortWeekdaySymbols
    return symbols[(dayIndex + 1) % 7].trimmingCharacters(in: CharacterSet(charactersIn: ".")).lowercased()
  }
}
