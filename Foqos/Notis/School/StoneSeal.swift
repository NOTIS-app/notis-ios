import CoreNFC
import CryptoKit
import Foundation

/// What a NOTIS stone was made for.
enum StoneKind: UInt8 {
  /// Sold to a person: pairs on a phone as an own stone.
  case personal = 0x50  // "P"
  /// Hangs in a classroom: never pairs as an own stone.
  case school = 0x53  // "S"
}

/// Only NOTIS stones (stappenplan-lokalen.md): in production every stone gets a seal, an NDEF
/// record `notisapp.nl:stone` with its kind and NOTIS's signature over the stone's hash and
/// kind. The app only holds the public key, so it checks a seal offline but can't make one. A
/// copied seal is worthless on another chip, because the hash comes from the chip's own UID.
///
/// Payload: version (1) | kind ("P" or "S") | signature (64 bytes, r || s).
/// Same format and key as `StoneSeal.kt` on Android. NOTIS admins prepare stones on both
/// (`NotisStoneWriter`).
enum StoneSeal {
  private static let recordType = "notisapp.nl:stone"
  private static let version: UInt8 = 1

  /// Public half of C:\NOTIS\geheim\stone-signing-key.pem (P-256, SubjectPublicKeyInfo).
  private static let publicKey = try? P256.Signing.PublicKey(
    derRepresentation: Data(
      base64Encoded:
        "MFkwEwYHKoZIzj0CAQYIKoZIzj0DAQcDQgAEO9Ujw0KPR1Mg4qrY+ztVSuem8ipEGQMAzgWobMwrwtv8ubYQRy174uYFdKlMBsUl1jRWkSJfPaPMhZs7QW8s9A=="
    )!
  )

  /// The kind the seal in [message] proves for the chip with [uid], or nil.
  static func kind(uid: String, message: NFCNDEFMessage?) -> StoneKind? {
    guard
      let record = message?.records.first(where: {
        $0.typeNameFormat == .nfcExternal
          && String(data: $0.type, encoding: .utf8)?.lowercased() == recordType
      })
    else { return nil }
    return verify(uid: uid, payload: record.payload)
  }

  static func payload(kind: StoneKind, signature: Data) -> Data {
    Data([version, kind.rawValue]) + signature
  }

  /// What production writes on a stone: the seal first, so Android routes the stone to NOTIS,
  /// then Android's app record, so it is NOTIS that opens there. Same bytes as on Android.
  static func ndefMessage(payload: Data) -> NFCNDEFMessage {
    NFCNDEFMessage(records: [
      NFCNDEFPayload(format: .nfcExternal, type: Data(recordType.utf8), identifier: Data(), payload: payload),
      NFCNDEFPayload(
        format: .nfcExternal, type: Data("android.com:pkg".utf8), identifier: Data(),
        payload: Data("nl.notisapp.android".utf8)
      ),
    ])
  }

  static func verify(uid: String, payload: Data) -> StoneKind? {
    let bytes = [UInt8](payload)
    guard bytes.count == 66, bytes[0] == version, let kind = StoneKind(rawValue: bytes[1]),
      let key = publicKey,
      let signature = try? P256.Signing.ECDSASignature(rawRepresentation: Data(bytes[2...]))
    else { return nil }
    let letter = kind == .school ? "S" : "P"
    let message = Data("notis-stone-v1:\(letter):\(StoneHash.of(uid))".utf8)
    return key.isValidSignature(signature, for: message) ? kind : nil
  }

  /// Why this tag can't be paired as an own stone, or nil when it can. A school stone never
  /// becomes an own stone: that is how a student would turn the stone of a room into theirs.
  static func pairingRefusal(_ result: NFCResult) -> String? {
    if result.seal == .school
      || (FeatureFlags.rooms && NotisSchool.shared.roomFor(uid: result.id) != nil)
    {
      return String(localized: "Dit is een schoolsteen: die kun je niet als eigen steen koppelen")
    }
    if FeatureFlags.sealedStones && result.seal == nil {
      return String(localized: "Dit is geen NOTIS-steen")
    }
    return nil
  }
}
