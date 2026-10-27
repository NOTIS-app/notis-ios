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

  /// Onboarding ends by pairing the first stone. Off: stones are paired in "Mijn NOTIS" (see
  /// `onboardingPairLater`).
  static let onboardingPairing = false

  /// Onboarding step "Welke apps mag je gebruiken?". Off: apps are chosen per stone in "Mijn NOTIS".
  static let onboardingApps = false

  /// Last onboarding page "Zo koppel je je NOTIS": three steps for "Mijn NOTIS", then
  /// "Aan de slag" (only without `onboardingPairing`).
  static let onboardingPairLater = true

  /// Lock from the app: press and hold the home stone to pick one of your stones instead of
  /// scanning it. Unlocking still takes a stone.
  static let lockFromApp = true

  /// School live: students join a class and a teacher's class stone locks the whole class.
  /// Off for the first TestFlight test.
  static let schoolLive = false

  /// Parents, as on Android: "Ouder koppelen" on a child's phone, "Ik ben ouder" to follow a
  /// child's lock status and choose the apps of a child's Android phone. An iPhone can't share
  /// its apps, so its parent only sees the status.
  static let parentControls = true

  /// Rooms (stappenplan-lokalen.md): every classroom has a stone. Students join a school by
  /// tapping one of its stones and check in per room; a teacher taps the room's stone and sees
  /// who is locked. Mirrors `FeatureFlags.ROOMS` on Android. Replaces `schoolLive`'s classes.
  static let rooms = true

  /// Only NOTIS stones: an own stone pairs only with a valid seal of a personal stone
  /// ([StoneSeal]). Stones paired before keep working. Off: any NFC chip pairs, as before. A
  /// school stone never pairs as an own stone, with or without this flag.
  /// Mirrors `FeatureFlags.SEALED_STONES` on Android.
  static let sealedStones = true

  /// Profiles apart from stones: a profile is a named list of allowed apps. "Mijn NOTIS" lists
  /// the profiles (create, rename, choose apps, delete) and the stones; each stone starts the
  /// profile chosen for it, and the home long-press picks a profile. Off: each stone has its own
  /// app list, as before. Mirrors `FeatureFlags.STONE_PROFILES` on Android.
  static let stoneProfiles = true

  /// Home has a bar at the top to pick the profile; every stone locks with that profile, and
  /// pressing and holding the home stone locks with it by hand. Stones are paired without a
  /// profile of their own. Off: each stone starts the profile chosen for it in "Mijn NOTIS".
  /// Needs `stoneProfiles`. Mirrors `FeatureFlags.HOME_PROFILE_PICKER` on Android.
  static let homeProfilePicker = true

  /// A separate "Account verwijderen" under signing out. Off: "Mijn gegevens wissen" deletes a
  /// signed-in parent's account as well, after typing the confirm word.
  /// Mirrors `FeatureFlags.SEPARATE_ACCOUNT_DELETE` on Android.
  static let separateAccountDelete = false
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
