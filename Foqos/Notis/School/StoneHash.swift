import CryptoKit
import Foundation

/// The server never sees a stone's NFC UID, only this hash of it. Same recipe as
/// `StoneHash.kt` on Android, so a stone linked on one platform is known on the other.
enum StoneHash {
  static func of(_ uid: String) -> String {
    let digest = SHA256.hash(data: Data("notis-stone:\(uid.uppercased())".utf8))
    return digest.map { String(format: "%02x", $0) }.joined()
  }
}
