import FamilyControls
import Foundation
import SwiftData

/// A NOTIS stone is an NFC unblock item of a profile: the stone's tag UID. The UID is the same
/// uppercase hex string the Android app stores, so a stone works on both phones. Without
/// `FeatureFlags.stoneProfiles` every stone is a profile of its own with exactly one such item;
/// with it, a profile holds the stones that start it (`BlockedProfiles+NotisProfiles.swift`).
extension BlockedProfiles {
  var notisStoneTag: String? {
    physicalUnblockItems?.first { $0.type == .nfc }?.codeValue
  }

  var isNotisStone: Bool {
    blockingStrategyId == NotisStoneBlockingStrategy.id && notisStoneTag != nil
  }

  /// "3 apps toegestaan", as on the stone cards of Android's "Mijn NOTIS".
  var notisAppsSummary: String {
    let count = FamilyActivityUtil.countSelectedActivities(selectedActivity, allowMode: enableAllowMode)
    if enableAllowMode {
      switch count {
      case 0: return String(localized: "Alles geblokkeerd")
      case 1: return String(localized: "1 app toegestaan")
      default: return String(localized: "\(count) apps toegestaan")
      }
    }
    switch count {
    case 0: return String(localized: "Nog geen apps · tik om te kiezen")
    case 1: return String(localized: "1 app")
    default: return String(localized: "\(count) apps")
    }
  }

  static func fetchNotisStones(in context: ModelContext) -> [BlockedProfiles] {
    let profiles = (try? fetchProfiles(in: context)) ?? []
    return profiles.filter(\.isNotisStone)
  }

  /// The profile the stone with [tag] starts.
  static func findNotisStone(withTag tag: String, in context: ModelContext) -> BlockedProfiles? {
    fetchNotisStones(in: context).first { profile in
      profile.physicalUnblockItems?.contains { $0.type == .nfc && $0.codeValue == tag } == true
    }
  }

  static func createNotisStone(
    in context: ModelContext,
    name: String,
    tag: String,
    selection: FamilyActivitySelection
  ) throws -> BlockedProfiles {
    try createProfile(
      in: context,
      name: name,
      selection: selection,
      blockingStrategyId: NotisStoneBlockingStrategy.id,
      askForStartSettings: false,
      enableLiveActivity: NotisNotifications.isEnabled,
      enableAllowMode: FeatureFlags.allowList,
      physicalUnblockItems: [PhysicalUnblockItem(name: name, type: .nfc, codeValue: tag)],
      enableEmergencyUnblock: FeatureFlags.emergencyUnlock
    )
  }

  static func renameNotisStone(_ profile: BlockedProfiles, to name: String, in context: ModelContext)
    throws
  {
    profile.name = name
    profile.physicalUnblockItems = profile.physicalUnblockItems?.map { item in
      var renamed = item
      renamed.name = name
      return renamed
    }
    profile.updatedAt = Date()
    updateSnapshot(for: profile)
    try context.save()
  }

  /// The apps chosen during onboarding, kept until the first stone is paired (Android keeps
  /// them in its default profile).
  private static let onboardingAppsKey = "notis.onboardingApps"

  static func saveOnboardingApps(_ selection: FamilyActivitySelection) {
    UserDefaults.standard.set(try? JSONEncoder().encode(selection), forKey: onboardingAppsKey)
  }

  /// Hands the onboarding apps to the first stone, once.
  static func takeOnboardingApps() -> FamilyActivitySelection? {
    defer { UserDefaults.standard.removeObject(forKey: onboardingAppsKey) }
    guard let data = UserDefaults.standard.data(forKey: onboardingAppsKey) else { return nil }
    return try? JSONDecoder().decode(FamilyActivitySelection.self, from: data)
  }

  static func updateNotisStoneApps(
    _ profile: BlockedProfiles,
    selection: FamilyActivitySelection,
    in context: ModelContext
  ) throws {
    profile.selectedActivity = selection
    profile.updatedAt = Date()
    updateSnapshot(for: profile)
    try context.save()
  }
}
