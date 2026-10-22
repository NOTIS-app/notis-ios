import FamilyControls
import Foundation
import SwiftData

/// A NOTIS stone is a profile with exactly one NFC unblock item: the stone's tag UID. The UID
/// is the same uppercase hex string the Android app stores, so a stone works on both phones.
extension BlockedProfiles {
  var notisStoneTag: String? {
    physicalUnblockItems?.first { $0.type == .nfc }?.codeValue
  }

  var isNotisStone: Bool {
    blockingStrategyId == NotisStoneBlockingStrategy.id && notisStoneTag != nil
  }

  static func fetchNotisStones(in context: ModelContext) -> [BlockedProfiles] {
    let profiles = (try? fetchProfiles(in: context)) ?? []
    return profiles.filter(\.isNotisStone)
  }

  static func findNotisStone(withTag tag: String, in context: ModelContext) -> BlockedProfiles? {
    fetchNotisStones(in: context).first { $0.notisStoneTag == tag }
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
