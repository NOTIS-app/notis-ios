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

  /// AVG: a parent account has no email or password, only an anonymous UUID on this phone, and
  /// nobody's name is stored: the apps say "Ouder" and "Kind". A lost phone means linking again.
  /// Off: parents sign up with email + password. Needs migration 20261108000000_anonymous_parents.sql.
  /// Mirrors `FeatureFlags.ANONYMOUS_PARENTS` on Android.
  static let anonymousParents = true

  /// No pairing: every stone with a valid personal seal (`sealedStones`) locks with the profile
  /// picked on Home and unlocks again. "Mijn NOTIS" only lists the profiles. Stones paired
  /// before keep working. A school stone never locks with an own profile. Off: only paired
  /// stones work. Needs `homeProfilePicker`. Mirrors `FeatureFlags.ANY_NOTIS_STONE` on Android.
  static let anyNotisStone = true

  /// Avondslot: like an alarm clock, a lock time per day (one per day, chosen days, a profile)
  /// under Settings → Meldingen. At that time the phone locks; only a stone unlocks. Runs on the
  /// phone: the device activity monitor starts the lock, also with the app closed.
  /// Mirrors `FeatureFlags.BEDTIME_LOCK` on Android.
  static let bedtimeLock = true

  /// The evening lock's time on a 24-hour ring instead of wheels: one handle for the lock time,
  /// a second one for the end time when that is on. The handles can't pass each other.
  /// Mirrors `FeatureFlags.BEDTIME_DIAL` on Android.
  static let bedtimeDial = true

  /// While locked, a bar at the top of Home says with what: the profile, or the school and room.
  /// Replaces "met <naam>" under OP SLOT. Mirrors `FeatureFlags.LOCKED_WITH_BAR` on Android.
  static let lockedWithBar = true

  /// "Laatste les: uitchecken": a teacher opens the checkout of their room for 10 minutes; a
  /// student who taps the room's stone in that time is unlocked and checked out for the rest of
  /// the day (school stones don't lock again until tomorrow). Mirrors `FeatureFlags.ROOM_CHECKOUT`.
  static let roomCheckout = true

  /// Home with less text: a padlock (open or shut, animated between the two) instead of the
  /// words VRIJ / OP SLOT, and no explanation lines under it. The scan hint after tapping the
  /// stone stays. Mirrors `FeatureFlags.HOME_LOCK_GLYPH` on Android.
  static let homeLockGlyph = true

  /// With `homeLockGlyph`: show the padlock. Off, Home shows neither the padlock nor the words:
  /// the stone itself says free or locked. Mirrors `FeatureFlags.HOME_PADLOCK` on Android.
  static let homePadlock = false

  /// Less text: no explanation under the profiles list, and no grey line under "Ouder koppelen",
  /// "Ik ben ouder" and "Ik ben docent" in Settings. Mirrors `FeatureFlags.LESS_TEXT` on Android.
  static let lessText = true

  /// Home shows this week with the nav bar: closed, a low strip with the handle and the streak
  /// grows out of it; opened (tap, drag up, or right after unlocking) the strip rises with the week
  /// total, the streak and a bar per day. A tap outside closes it. Mirrors
  /// `FeatureFlags.HOME_STATS` on Android.
  static let homeStats = true

  /// The evening lock moves from Settings to the profiles tab, which is called "Mijn NOTIS" again:
  /// an orange "Avondslot" button at the top opens the lock times, the profiles follow below.
  /// Needs `bedtimeLock`. Mirrors `FeatureFlags.BEDTIME_IN_MY_NOTIS` on Android.
  static let bedtimeInMyNotis = true

  /// A round "i" at the top right of Settings, explaining its rows like Mijn NOTIS's "i".
  /// Mirrors `FeatureFlags.SETTINGS_HELP` on Android.
  static let settingsHelp = true

  /// Onboarding explains parents and children, and teachers, on a page each before the last one.
  /// Needs the school backend. Mirrors `FeatureFlags.ONBOARDING_ROLES` on Android.
  static let onboardingRoles = true

  /// Home gets a round "i" next to a narrower profile bar, explaining Home (the profile, the stone,
  /// pressing and holding it, the week, the emergency unlock). Its long-press sheet then drops its
  /// explanation line. Mirrors `FeatureFlags.HOME_HELP` on Android.
  static let homeHelp = true
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
