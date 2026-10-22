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
      guard let stone = BlockedProfiles.findNotisStone(withTag: tag.id, in: context) else {
        self.nfcScanner.resultErrorMessage = String(localized: "Deze steen is niet gekoppeld")
        return
      }
      self.nfcScanner.resultMessage = String(localized: "Apps op slot · met \(stone.name)")

      self.appBlocker.activateRestrictions(for: BlockedProfiles.getSnapshot(for: stone))

      let activeSession = BlockedProfileSession.createSession(
        in: context,
        withTag: tag.id,
        withProfile: stone,
        forceStart: false
      )
      try? context.save()
      NotisEmergencyUnlock.resetForNewSession()
      self.onSessionCreation?(.started(activeSession))
    }

    nfcScanner.scan(alertMessage: String(localized: "Houd de bovenkant van je iPhone tegen je NOTIS"))

    return nil
  }

  func stopBlocking(
    context: ModelContext,
    session: BlockedProfileSession
  ) -> (any View)? {
    prepareScanner()
    nfcScanner.onTagScanned = { tag in
      guard let stone = BlockedProfiles.findNotisStone(withTag: tag.id, in: context) else {
        self.nfcScanner.resultErrorMessage = String(localized: "Deze steen is niet gekoppeld")
        return
      }
      self.nfcScanner.resultMessage = String(localized: "Apps weer vrij · met \(stone.name)")

      // Scanning during an emergency unlock ends the whole session, pause timer included.
      DeviceActivityCenterUtil.removePauseTimerActivity(for: session.blockedProfile)
      NotisEmergencyUnlock.clear()

      session.endSession()
      try? context.save()
      self.appBlocker.deactivateRestrictions()

      self.onSessionCreation?(.ended(session.blockedProfile))
    }

    nfcScanner.scan(alertMessage: String(localized: "Houd de bovenkant van je iPhone tegen je NOTIS"))

    return nil
  }

  /// Errors from the NFC sheet itself (no NFC, timeout) reach the home screen's alert.
  private func prepareScanner() {
    nfcScanner.resultMessage = nil
    nfcScanner.onError = { message in
      self.onErrorMessage?(message)
    }
  }
}
