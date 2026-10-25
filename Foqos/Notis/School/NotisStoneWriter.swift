import CoreNFC
import Foundation

/// What happened to a stone in "Stenen voorbereiden". Mirrors `StonePrepareViewModel.Feedback`
/// on Android.
enum StonePrepareOutcome: Equatable {
  /// The stone now carries a seal of [kind]. [previous] is the kind it had before (a stone that
  /// was rewritten), [unlinkedRoom] the room a school stone left when made personal.
  case prepared(kind: StoneKind, locked: Bool, previous: StoneKind?, unlinkedRoom: String?)
  /// The stone already carries a valid seal of this kind.
  case alreadySealed(StoneKind)
  /// Locked read-only earlier, so it can't get a (new) seal. The kind is its current seal.
  case readOnly(StoneKind?)
  /// Moved too soon: hold the stone against the iPhone again.
  case lost
  /// No NDEF, or too small for the seal.
  case unsupported
  /// The server signed with a key that doesn't match the app's public key.
  case wrongKey
  case failed(String)
  /// The NFC sheet was closed without a stone.
  case cancelled

  var isSuccess: Bool {
    switch self {
    case .prepared, .alreadySealed: return true
    default: return false
    }
  }
}

/// Production (NOTIS admins): one NFC session per stone. It reads the chip, asks the server for
/// the seal ([sign]) while the stone stays on the iPhone, and writes it, optionally locking
/// the chip for good. A stone with the other seal is rewritten: personal to school and back.
///
/// iOS shows its own NFC sheet for every scan, so stones go one at a time, where Android takes
/// them in a continuous series.
final class NotisStoneWriter: NSObject, NFCTagReaderSessionDelegate {
  typealias Sign = (_ uid: String, _ kind: StoneKind) async throws -> StoneSealResult

  private var session: NFCTagReaderSession?
  private var continuation: CheckedContinuation<StonePrepareOutcome, Never>?
  private var kind = StoneKind.personal
  private var lock = false
  private var sign: Sign?

  @MainActor
  func prepare(kind: StoneKind, lock: Bool, sign: @escaping Sign) async -> StonePrepareOutcome {
    guard NFCTagReaderSession.readingAvailable else {
      return .failed(String(localized: "NFC is niet beschikbaar op dit toestel."))
    }
    return await withCheckedContinuation { continuation in
      self.continuation = continuation
      self.kind = kind
      self.lock = lock
      self.sign = sign
      session = NFCTagReaderSession(pollingOption: [.iso14443, .iso15693], delegate: self, queue: nil)
      session?.alertMessage = kind == .school
        ? String(localized: "Houd een schoolsteen tegen de bovenkant van je iPhone")
        : String(localized: "Houd een persoonlijke steen tegen de bovenkant van je iPhone")
      session?.begin()
    }
  }

  func tagReaderSessionDidBecomeActive(_ session: NFCTagReaderSession) {}

  func tagReaderSession(_ session: NFCTagReaderSession, didInvalidateWithError error: Error) {
    // Our own invalidate after a result comes here too; then the continuation is gone already.
    finish(.cancelled, close: false)
  }

  func tagReaderSession(_ session: NFCTagReaderSession, didDetect tags: [NFCTag]) {
    guard let tag = tags.first else { return }
    Task { await handle(tag, in: session) }
  }

  private func handle(_ tag: NFCTag, in session: NFCTagReaderSession) async {
    let ndef: NFCNDEFTag
    let identifier: Data
    switch tag {
    case .miFare(let chip):
      ndef = chip
      identifier = chip.identifier
    case .iso15693(let chip):
      ndef = chip
      identifier = chip.identifier
    default:
      return finish(.unsupported)
    }

    do {
      try await session.connect(to: tag)
    } catch {
      return finish(.lost)
    }

    let uid = identifier.hexEncodedString()
    let ndefStatus: (NFCNDEFStatus, Int)
    do {
      ndefStatus = try await ndef.queryNDEFStatus()
    } catch {
      return finish(.lost)
    }
    let (status, capacity) = ndefStatus
    // An empty chip has no message to read; that is fine.
    let current = StoneSeal.kind(uid: uid, message: try? await ndef.readNDEF())
    if current == kind { return finish(.alreadySealed(kind)) }
    // Checked before signing, so the server never records a stone that keeps its old data.
    switch status {
    case .readOnly: return finish(.readOnly(current))
    case .notSupported: return finish(.unsupported)
    default: break
    }

    session.alertMessage = String(localized: "Bezig… houd de steen stil")
    let seal: StoneSealResult
    do {
      guard let sign else { return finish(.cancelled) }
      seal = try await sign(uid, kind)
    } catch {
      return finish(.failed(error.localizedDescription))
    }
    guard StoneSeal.verify(uid: uid, payload: seal.payload) == kind else { return finish(.wrongKey) }

    let message = StoneSeal.ndefMessage(payload: seal.payload)
    guard message.length <= capacity else { return finish(.unsupported) }
    do {
      try await ndef.writeNDEF(message)
      if lock { try await ndef.writeLock() }
    } catch {
      return finish(.lost)
    }
    finish(.prepared(kind: kind, locked: lock, previous: current, unlinkedRoom: seal.unlinkedRoom))
  }

  /// Hands [outcome] to the waiting screen and, with [close], closes the NFC sheet with a
  /// short message (iOS shows a check or a cross by itself).
  private func finish(_ outcome: StonePrepareOutcome, close: Bool = true) {
    guard let continuation else { return }
    self.continuation = nil
    let session = self.session
    self.session = nil
    sign = nil
    if close {
      if outcome.isSuccess {
        session?.alertMessage = String(localized: "Klaar!")
        session?.invalidate()
      } else {
        session?.invalidate(errorMessage: String(localized: "Niet gelukt"))
      }
    }
    continuation.resume(returning: outcome)
  }
}
