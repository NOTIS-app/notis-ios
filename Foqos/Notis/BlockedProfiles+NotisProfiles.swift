import FamilyControls
import Foundation
import SwiftData

/// Profiles apart from stones (`FeatureFlags.stoneProfiles`), as on Android: a profile is a
/// named list of allowed apps, and each stone starts the profile chosen for it.
///
/// A profile is a `BlockedProfiles` with the NOTIS strategy (the hidden school profile aside).
/// Its stones are its NFC unblock items, one per stone (tag UID and the stone's name), so a
/// stone always belongs to exactly one profile: the one it starts. Stones paired before this
/// were a profile with one item and the same name, so they keep their apps as they are.
extension BlockedProfiles {
  var isNotisProfile: Bool {
    blockingStrategyId == NotisStoneBlockingStrategy.id && !isNotisSchoolProfile
  }

  /// The stones that start this profile.
  var notisStones: [PhysicalUnblockItem] {
    physicalUnblockItems?.filter { $0.type == .nfc } ?? []
  }

  /// The name of the stone with [tag], when it starts this profile.
  func notisStoneName(tag: String) -> String? {
    notisStones.first { $0.codeValue == tag }?.name
  }

  /// "Mijn NOTIS" order: oldest first, as Android lists its profiles.
  static func fetchNotisProfiles(in context: ModelContext) -> [BlockedProfiles] {
    let profiles = (try? fetchProfiles(in: context)) ?? []
    return profiles.filter(\.isNotisProfile).sorted(by: notisProfileOrder)
  }

  static func notisProfileOrder(_ a: BlockedProfiles, _ b: BlockedProfiles) -> Bool {
    a.order != b.order ? a.order < b.order : a.createdAt < b.createdAt
  }

  /// A new profile with no apps chosen yet (with the allowlist: everything blocked).
  static func createNotisProfile(
    in context: ModelContext,
    name: String,
    selection: FamilyActivitySelection = FamilyActivitySelection(includeEntireCategory: FeatureFlags.allowList)
  ) throws -> BlockedProfiles {
    try createProfile(
      in: context,
      name: name,
      selection: selection,
      blockingStrategyId: NotisStoneBlockingStrategy.id,
      askForStartSettings: false,
      enableLiveActivity: NotisNotifications.isEnabled,
      enableAllowMode: FeatureFlags.allowList,
      physicalUnblockItems: [],
      enableEmergencyUnblock: FeatureFlags.emergencyUnlock
    )
  }

  /// Pairs stone [tag] so that it starts [profile]; without one, the profile at the top of the
  /// list, or a new "Standaard" profile when there is none (with the onboarding apps, if any).
  static func pairNotisStone(
    tag: String,
    name: String,
    profile: BlockedProfiles?,
    in context: ModelContext
  ) throws -> BlockedProfiles {
    let target: BlockedProfiles
    if let profile, !profile.isDeleted {
      target = profile
    } else if let top = fetchNotisProfiles(in: context).first {
      target = top
    } else {
      target = try createNotisProfile(
        in: context,
        name: String(localized: "Standaard"),
        selection: takeOnboardingApps()
          ?? FamilyActivitySelection(includeEntireCategory: FeatureFlags.allowList)
      )
    }
    target.physicalUnblockItems = (target.physicalUnblockItems ?? [])
      + [PhysicalUnblockItem(name: name, type: .nfc, codeValue: tag)]
    try saveNotisProfile(target, in: context)
    return target
  }

  /// The stone with [tag] starts [profile] from now on.
  static func moveNotisStone(tag: String, to profile: BlockedProfiles, in context: ModelContext) throws {
    guard let owner = findNotisStone(withTag: tag, in: context), owner.id != profile.id,
      let item = owner.notisStones.first(where: { $0.codeValue == tag })
    else { return }
    owner.physicalUnblockItems = owner.physicalUnblockItems?.filter { $0.codeValue != tag }
    profile.physicalUnblockItems = (profile.physicalUnblockItems ?? []) + [item]
    try saveNotisProfile(owner, in: context)
    try saveNotisProfile(profile, in: context)
  }

  static func renameNotisStone(tag: String, to name: String, in context: ModelContext) throws {
    guard let owner = findNotisStone(withTag: tag, in: context) else { return }
    owner.physicalUnblockItems = owner.physicalUnblockItems?.map { item in
      guard item.codeValue == tag else { return item }
      var renamed = item
      renamed.name = name
      return renamed
    }
    try saveNotisProfile(owner, in: context)
  }

  /// Removes a stone; its profile stays (it is the user's, not the stone's).
  static func removeNotisStone(tag: String, in context: ModelContext) throws {
    guard let owner = findNotisStone(withTag: tag, in: context) else { return }
    owner.physicalUnblockItems = owner.physicalUnblockItems?.filter { $0.codeValue != tag }
    try saveNotisProfile(owner, in: context)
  }

  static func renameNotisProfile(_ profile: BlockedProfiles, to name: String, in context: ModelContext) throws {
    profile.name = name
    try saveNotisProfile(profile, in: context)
  }

  /// The profile [profile]'s stones move to when it is deleted: the top of the list without it.
  static func notisProfileHeir(of profile: BlockedProfiles, in context: ModelContext) -> BlockedProfiles? {
    fetchNotisProfiles(in: context).first { $0.id != profile.id }
  }

  enum NotisProfileDeleteError: LocalizedError {
    case last

    var errorDescription: String? {
      String(localized: "Er moet minstens één profiel blijven: elke steen start er een.")
    }
  }

  /// Deletes a profile; its stones move to the profile at the top of the list. The last profile
  /// stays. The caller refuses during a lock, as Android does.
  static func deleteNotisProfile(_ profile: BlockedProfiles, in context: ModelContext) throws {
    guard let heir = notisProfileHeir(of: profile, in: context) else { throw NotisProfileDeleteError.last }
    heir.physicalUnblockItems = (heir.physicalUnblockItems ?? []) + profile.notisStones
    profile.physicalUnblockItems = []
    try saveNotisProfile(heir, in: context)
    try deleteProfile(profile, in: context)
    try context.save()
  }

  private static func saveNotisProfile(_ profile: BlockedProfiles, in context: ModelContext) throws {
    profile.updatedAt = Date()
    updateSnapshot(for: profile)
    try context.save()
  }
}
