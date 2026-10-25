import FamilyControls
import Foundation
import SwiftData

/// A school lock (rooms) runs on one hidden profile: the NOTIS strategy without an NFC item,
/// so it never shows up in "Mijn NOTIS" and no own stone matches it. Its apps are the
/// student's pick from the school's list (iOS can't see app names, see `SchoolApp`).
extension BlockedProfiles {
  private static let schoolProfileIdKey = "notis.school.profileId"

  /// Session tag of a school lock: the room it is checked in to.
  static func notisSchoolTag(roomId: String) -> String { "room:\(roomId)" }

  var isNotisSchoolProfile: Bool {
    id.uuidString == UserDefaults.standard.string(forKey: Self.schoolProfileIdKey)
  }

  /// The school profile, created (with nothing allowed yet) the first time it is needed.
  static func notisSchoolProfile(in context: ModelContext) throws -> BlockedProfiles {
    let profiles = (try? fetchProfiles(in: context)) ?? []
    if let existing = profiles.first(where: \.isNotisSchoolProfile) { return existing }

    let profile = try createProfile(
      in: context,
      name: String(localized: "School"),
      selection: FamilyActivitySelection(),
      blockingStrategyId: NotisStoneBlockingStrategy.id,
      askForStartSettings: false,
      enableLiveActivity: NotisNotifications.isEnabled,
      enableAllowMode: true,
      physicalUnblockItems: nil,
      enableEmergencyUnblock: FeatureFlags.emergencyUnlock
    )
    UserDefaults.standard.set(profile.id.uuidString, forKey: schoolProfileIdKey)
    return profile
  }

  /// The school lock ends by itself at the school's end time: the existing strategy timer
  /// (DeviceActivity, so also with the app closed) ends the session then.
  static func scheduleNotisSchoolEnd(_ profile: BlockedProfiles, at end: Date) {
    let minutes = max(15, Int(end.timeIntervalSinceNow / 60))
    profile.strategyData = StrategyTimerData.toData(
      from: StrategyTimerData(durationInMinutes: minutes, hideStopButton: true))
    DeviceActivityCenterUtil.startStrategyTimerActivity(for: profile)
  }
}
