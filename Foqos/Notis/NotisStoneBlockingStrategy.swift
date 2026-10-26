import SwiftData
import SwiftUI

/// NOTIS: scanning a paired stone locks with that stone's app list; scanning any paired stone
/// unlocks again (same rule as the Android app). The tag UID identifies the stone, not a URL,
/// so stones paired on Android work here too.
class NotisStoneBlockingStrategy: BlockingStrategy {
  static var id: String = "NotisStoneBlockingStrategy"

  var name: String = "NOTIS"
  var description: String = "Lock by holding your phone to a NOTIS stone. Any of your stones unlocks."
  var color: Color = NotisTheme.mandarin
  var pickerCategory: BlockingStrategyPickerCategory = .mostPopular

  var usesNFC: Bool = true
  var requiresSameCodeToStop: Bool = false
  var allowsTimedBreaks: Bool = false

  var onSessionCreation: ((SessionStatus) -> Void)?
  var onErrorMessage: ((String) -> Void)?

  private let nfcScanner: NFCScannerUtil = NFCScannerUtil()
  private let appBlocker: AppBlockerUtil = AppBlockerUtil()

  func getIdentifier() -> String {
    return NotisStoneBlockingStrategy.id
  }

  func startBlocking(
    context: ModelContext,
    profile: BlockedProfiles,
    forceStart: Bool?
  ) -> (any View)? {
    prepareScanner()
    nfcScanner.onTagScanned = { tag in
      // The stone decides which app list applies, not the profile the caller passed in.
      if let stone = BlockedProfiles.findNotisStone(withTag: tag.id, in: context) {
        let name = stone.notisStoneName(tag: tag.id) ?? stone.name
        self.nfcScanner.resultMessage = String(localized: "Apps op slot · met \(name)")
        self.lock(context: context, stone: stone, tag: tag.id)
        return
      }
      if FeatureFlags.rooms {
        self.scanUnknownStoneWhileFree(uid: tag.id, context: context)
        return
      }
      self.nfcScanner.resultErrorMessage = String(localized: "Deze steen is niet gekoppeld")
    }

    nfcScanner.scan(alertMessage: String(localized: "Houd de bovenkant van je iPhone tegen je NOTIS"))

    return nil
  }

  /// "Op slot zonder tikken": locks with a stone (with `FeatureFlags.stoneProfiles`: a profile)
  /// chosen in the app. Unlocking still scans.
  func startWithoutScan(context: ModelContext, stone: BlockedProfiles) {
    lock(context: context, stone: stone, tag: stone.notisStoneTag ?? "")
  }

  private func lock(context: ModelContext, stone: BlockedProfiles, tag: String) {
    appBlocker.activateRestrictions(for: BlockedProfiles.getSnapshot(for: stone))

    let activeSession = BlockedProfileSession.createSession(
      in: context,
      withTag: tag,
      withProfile: stone,
      forceStart: false
    )
    try? context.save()
    NotisEmergencyUnlock.resetForNewSession()
    onSessionCreation?(.started(activeSession))
    // A parent sees every lock; a school lock reports itself, with its room (lockSchool).
    if !stone.isNotisSchoolProfile {
      MainActor.assumeIsolated {
        let school = NotisSchool.shared
        Task { await school.report(.locked) }
      }
    }
  }

  func stopBlocking(
    context: ModelContext,
    session: BlockedProfileSession
  ) -> (any View)? {
    prepareScanner()
    nfcScanner.onTagScanned = { tag in
      if FeatureFlags.rooms, self.scanSchoolStoneWhileLocked(uid: tag.id, session: session, context: context) {
        return
      }
      // Only the room's stone ends a school lock; own stones don't (that would be a way out).
      if session.blockedProfile.isNotisSchoolProfile {
        self.nfcScanner.resultErrorMessage = String(
          localized: "Op slot door school: tik de steen van je lokaal om te ontgrendelen")
        return
      }
      guard let stone = BlockedProfiles.findNotisStone(withTag: tag.id, in: context) else {
        self.nfcScanner.resultErrorMessage = String(localized: "Deze steen is niet gekoppeld")
        return
      }
      let name = stone.notisStoneName(tag: tag.id) ?? stone.name
      self.nfcScanner.resultMessage = String(localized: "Apps weer vrij · met \(name)")
      self.unlock(context: context, session: session)
    }

    nfcScanner.scan(alertMessage: String(localized: "Houd de bovenkant van je iPhone tegen je NOTIS"))

    return nil
  }

  /// Cancelling during the grace period (`NotisGracePeriod`) ends the session without a scan.
  func cancelWithoutScan(context: ModelContext, session: BlockedProfileSession) {
    unlock(context: context, session: session)
  }

  // MARK: - Rooms (stappenplan-lokalen.md)

  /// Not locked, and the stone isn't one of the phone's own: a room of the joined school locks
  /// and checks in; any other stone is asked about on the server (a school to join, or a stone
  /// of our school linked after the last refresh).
  private func scanUnknownStoneWhileFree(uid: String, context: ModelContext) {
    MainActor.assumeIsolated {
      let school = NotisSchool.shared
      if let room = school.roomFor(uid: uid) {
        nfcScanner.resultMessage = String(localized: "Apps op slot · in \(room.roomName)")
        lockSchool(context: context, room: room)
        return
      }
      nfcScanner.resultMessage = String(localized: "Steen gelezen")
      Task { @MainActor in
        guard let invite = await school.invite(uid: uid) else {
          self.onErrorMessage?(String(localized: "Deze steen is niet gekoppeld"))
          return
        }
        if invite.schoolId == school.school?.schoolId {
          await school.refreshSchool()
          if let room = school.roomFor(uid: uid) {
            self.lockSchool(context: context, room: room)
            return
          }
        }
        school.pendingInvite = invite
      }
    }
  }

  /// Locked: a room stone of the joined school. Returns false for other stones.
  /// - Same room as the check-in: unlock.
  /// - Another room while locked by the school: move the check-in, stay locked.
  /// - Locked by an own stone: the school lock replaces it.
  private func scanSchoolStoneWhileLocked(
    uid: String, session: BlockedProfileSession, context: ModelContext
  ) -> Bool {
    MainActor.assumeIsolated {
      let school = NotisSchool.shared
      guard let room = school.roomFor(uid: uid) else { return false }

      if !session.blockedProfile.isNotisSchoolProfile {
        nfcScanner.resultMessage = String(localized: "Apps op slot · in \(room.roomName)")
        unlock(context: context, session: session)
        lockSchool(context: context, room: room)
      } else if school.currentRoomId == room.roomId {
        nfcScanner.resultMessage = String(localized: "Apps weer vrij · in \(room.roomName)")
        unlock(context: context, session: session)
      } else {
        nfcScanner.resultMessage = String(localized: "Ingecheckt in \(room.roomName)")
        school.currentRoomId = room.roomId
        Task { await school.report(.locked) }
      }
      return true
    }
  }

  /// Locks with the school profile (the student's pick from the school's list) and checks in
  /// to [room]. Also used right after joining, without a second scan.
  @MainActor
  func lockSchool(context: ModelContext, room: SchoolRoom) {
    guard let profile = try? BlockedProfiles.notisSchoolProfile(in: context) else {
      onErrorMessage?(String(localized: "Op slot gaan lukte niet"))
      return
    }
    let school = NotisSchool.shared
    school.currentRoomId = room.roomId
    lock(context: context, stone: profile, tag: BlockedProfiles.notisSchoolTag(roomId: room.roomId))
    if let end = school.school.flatMap({ NotisSchool.lockEnd(start: Date(), endTime: $0.autoUnlockAt) }) {
      BlockedProfiles.scheduleNotisSchoolEnd(profile, at: end)
      try? context.save()
    }
    Task { await school.report(.locked) }
  }

  private func unlock(context: ModelContext, session: BlockedProfileSession) {
    if session.blockedProfile.isNotisSchoolProfile {
      DeviceActivityCenterUtil.removeAllStrategyTimerActivities()
      MainActor.assumeIsolated {
        let school = NotisSchool.shared
        school.currentRoomId = nil
        Task { await school.report(.unlocked) }
      }
    } else {
      MainActor.assumeIsolated {
        let school = NotisSchool.shared
        Task { await school.report(.unlocked) }
      }
    }
    // Ending during an emergency unlock ends the whole session, pause timer included.
    DeviceActivityCenterUtil.removePauseTimerActivity(for: session.blockedProfile)
    NotisEmergencyUnlock.clear()

    session.endSession()
    try? context.save()
    appBlocker.deactivateRestrictions()

    onSessionCreation?(.ended(session.blockedProfile))
  }

  /// Errors from the NFC sheet itself (no NFC, timeout) reach the home screen's alert.
  private func prepareScanner() {
    nfcScanner.resultMessage = nil
    nfcScanner.onError = { message in
      self.onErrorMessage?(message)
    }
  }
}
