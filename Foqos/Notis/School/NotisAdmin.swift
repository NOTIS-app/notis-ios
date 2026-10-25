import Foundation
import Supabase

/// A school, as offered to a NOTIS admin who links stones.
struct AdminSchool: Identifiable, Equatable, Decodable {
  let id: String
  let name: String
}

/// A classroom and how many stones are linked to it.
struct LinkRoom: Identifiable, Equatable {
  let id: String
  let name: String
  let stoneCount: Int
}

enum StoneLinkResult: Equatable {
  case linked
  /// The stone already belongs to this room; linking again with replace moves it.
  case taken(String)
  /// The stone belongs to a room of a school this account can't manage.
  case otherSchool
  /// The server knows no school seal for this stone.
  case notSchoolStone
}

/// A seal from the server: the payload to write onto the chip ([StoneSeal]), and the room a
/// school stone was unlinked from when it became a personal stone.
struct StoneSealResult {
  let payload: Data
  let unlinkedRoom: String?
}

/// NOTIS admins (signed in through the hidden login): prepare stones and link school stones
/// room after room. Mirrors the admin parts of `RoomRepository.kt` on Android. Only a hash of
/// a stone's UID leaves the phone.
@MainActor
final class NotisAdmin {
  static let shared = NotisAdmin()

  private var client: SupabaseClient { SchoolBackend.accountClient }

  struct Failure: LocalizedError {
    let errorDescription: String?
  }

  /// All schools, in natural order.
  func schools() async throws -> [AdminSchool] {
    let rows: [AdminSchool] = try await guarded { try await client.rpc("admin_list_schools").execute().value }
    return rows.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
  }

  private struct RoomRow: Decodable {
    struct Count: Decodable { let count: Int }
    let id: String
    let name: String
    let room_stones: [Count]?
  }

  /// Rooms of [schoolId] in natural order (B1.2 before B1.10), with their stone count.
  func rooms(schoolId: String) async throws -> [LinkRoom] {
    let rows: [RoomRow] = try await guarded {
      try await client.from("rooms").select("id, name, room_stones(count)")
        .eq("school_id", value: schoolId)
        .execute().value
    }
    return rows.map { LinkRoom(id: $0.id, name: $0.name, stoneCount: $0.room_stones?.first?.count ?? 0) }
      .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
  }

  private struct LinkParams: Encodable {
    let p_room_id: String
    let p_stone_hash: String
    let p_replace: Bool
  }

  /// Links the stone with this NFC [uid] to [roomId]. A stone that is already in another room
  /// is only moved with [replace], so a series of taps never overwrites by accident.
  func linkStone(roomId: String, uid: String, replace: Bool) async throws -> StoneLinkResult {
    do {
      try await client.rpc(
        "link_room_stone",
        params: LinkParams(p_room_id: roomId, p_stone_hash: StoneHash.of(uid), p_replace: replace)
      ).execute()
      return .linked
    } catch let error as PostgrestError {
      let message = error.message
      if let range = message.range(of: "already linked to ") {
        return .taken(String(message[range.upperBound...]).trimmingCharacters(in: .whitespaces))
      }
      if message.contains("belongs to another school") { return .otherSchool }
      if message.contains("not a NOTIS school stone") { return .notSchoolStone }
      throw Failure(errorDescription: message)
    } catch {
      throw readable(error)
    }
  }

  private struct SignParams: Encodable {
    let stone_hash: String
    let kind: String
  }

  private struct SignResponse: Decodable {
    let signature: String
    let unlinked_room: String?
  }

  /// Production: NOTIS signs the stone's hash and [kind] on the server (edge function
  /// sign-stone) and records the stone.
  func sealStone(uid: String, kind: StoneKind) async throws -> StoneSealResult {
    let response: SignResponse = try await guarded {
      try await client.functions.invoke(
        "sign-stone",
        options: FunctionInvokeOptions(
          body: SignParams(stone_hash: StoneHash.of(uid), kind: kind == .school ? "school" : "personal")
        )
      )
    }
    guard let signature = Data(base64Encoded: response.signature) else {
      throw Failure(errorDescription: String(localized: "De server gaf geen geldige handtekening."))
    }
    return StoneSealResult(payload: StoneSeal.payload(kind: kind, signature: signature), unlinkedRoom: response.unlinked_room)
  }

  private func guarded<T>(_ work: () async throws -> T) async throws -> T {
    do {
      return try await work()
    } catch {
      throw readable(error)
    }
  }

  /// A message an admin can act on: offline, the server's own error text, or the error itself.
  private func readable(_ error: Error) -> Error {
    if error is URLError {
      return Failure(errorDescription: String(localized: "Geen verbinding met de server. Controleer je internet."))
    }
    if case FunctionsError.httpError(_, let data) = error,
      let body = try? JSONDecoder().decode([String: String].self, from: data), let message = body["error"]
    {
      return Failure(errorDescription: message)
    }
    if let error = error as? PostgrestError {
      return Failure(errorDescription: error.message)
    }
    return error
  }
}

/// The room to link next after [afterId] got its stone: the first room without a stone that
/// follows it in the list, wrapping around to the start. Nil when every room has a stone.
func nextRoomWithoutStone(_ rooms: [LinkRoom], after afterId: String?) -> LinkRoom? {
  guard !rooms.isEmpty else { return nil }
  let start = rooms.firstIndex { $0.id == afterId } ?? -1
  return (1...rooms.count)
    .map { rooms[(start + $0 + rooms.count) % rooms.count] }
    .first { $0.stoneCount == 0 && $0.id != afterId }
}
