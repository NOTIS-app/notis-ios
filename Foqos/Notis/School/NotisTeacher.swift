import Foundation
import Supabase

/// A room as the teacher's side sees it.
struct TeacherRoom: Identifiable, Equatable, Decodable {
  let id: String
  let name: String
}

/// One student checked in to the room today, as `room_students()` returns it.
struct RoomStudent: Identifiable, Equatable, Decodable {
  let userId: String
  let displayName: String
  let state: String
  let stateChangedAt: Date
  let lastSeen: Date
  let tooMany: Bool

  var id: String { userId }

  enum CodingKeys: String, CodingKey {
    case userId = "user_id"
    case displayName = "display_name"
    case state
    case stateChangedAt = "state_changed_at"
    case lastSeen = "last_seen"
    case tooMany = "too_many"
  }
}

/// Teacher side of rooms (8e): signing in, tapping a room's stone (or picking the room) to see
/// who is locked there, "Keuze openen" and the recovery code. Mirrors `RoomRepository.kt`
/// and the teacher parts of `AccountRepository.kt` on Android. Stone linking (NOTIS admins)
/// stays Android-only.
@MainActor
final class NotisTeacher: ObservableObject {
  static let shared = NotisTeacher()

  @Published private(set) var email: String?
  @Published private(set) var isTeacher = false
  /// The room whose live list is open (stone tapped or picked), or nil.
  @Published var openRoom: TeacherRoom?

  private var client: SupabaseClient { SchoolBackend.accountClient }

  private init() {
    email = client.auth.currentUser?.email
    isTeacher = UserDefaults.standard.bool(forKey: Self.isTeacherKey) && email != nil
  }

  private static let isTeacherKey = "notis.teacher.isTeacher"

  enum SignInError: Error {
    case invalidLogin, notTeacher, failed
  }

  /// Signs in; only teacher accounts are accepted here (parents sign in on Android only).
  func signIn(email: String, password: String) async throws {
    do {
      try await client.auth.signIn(email: email.trimmingCharacters(in: .whitespaces), password: password)
    } catch {
      throw "\(error)".localizedCaseInsensitiveContains("invalid") ? SignInError.invalidLogin : SignInError.failed
    }
    let teacher: Bool = (try? await client.rpc("is_teacher").execute().value) ?? false
    guard teacher else {
      try? await client.auth.signOut()
      throw SignInError.notTeacher
    }
    self.email = client.auth.currentUser?.email
    isTeacher = true
    UserDefaults.standard.set(true, forKey: Self.isTeacherKey)
  }

  func signOut() async {
    try? await client.auth.signOut()
    email = nil
    isTeacher = false
    openRoom = nil
    UserDefaults.standard.set(false, forKey: Self.isTeacherKey)
  }

  // MARK: - Rooms

  private struct RoomRow: Decodable {
    let id: String
    let name: String
  }

  /// Rooms of the teacher's school (the only ones the server lets a teacher read), in
  /// natural order: B1.2 before B1.10.
  func rooms() async -> [TeacherRoom] {
    guard isTeacher else { return [] }
    do {
      let rows: [RoomRow] = try await client.from("rooms").select("id, name").execute().value
      return rows.map { TeacherRoom(id: $0.id, name: $0.name) }
        .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    } catch {
      print("NotisTeacher rooms failed: \(error)")
      return []
    }
  }

  private struct StoneRoomRow: Decodable {
    struct Room: Decodable { let name: String }
    let room_id: String
    let rooms: Room?
  }

  /// A signed-in teacher tapped a stone: when it is a room of their school, couple them to it
  /// for today (the teacher web page follows) and return it.
  func roomForStone(uid: String) async -> TeacherRoom? {
    guard isTeacher else { return nil }
    do {
      let rows: [StoneRoomRow] = try await client.from("room_stones")
        .select("room_id, rooms(name)")
        .eq("stone_hash", value: StoneHash.of(uid))
        .execute().value
      guard let row = rows.first else { return nil }
      let room = TeacherRoom(id: row.room_id, name: row.rooms?.name ?? "")
      await checkIn(room)
      return room
    } catch {
      print("NotisTeacher roomForStone failed: \(error)")
      return nil
    }
  }

  private struct RoomParams: Encodable {
    let p_room_id: String
  }

  /// Couples the teacher to [room] for today, so the teacher web page shows that room.
  func checkIn(_ room: TeacherRoom) async {
    do {
      try await client.rpc("teacher_check_in", params: RoomParams(p_room_id: room.id)).execute()
    } catch {
      print("NotisTeacher check-in failed: \(error)")
    }
  }

  /// Students checked in to [room] today; nil when it failed (offline).
  func students(in room: TeacherRoom) async -> [RoomStudent]? {
    do {
      return try await client.rpc("room_students", params: RoomParams(p_room_id: room.id)).execute().value
    } catch {
      print("NotisTeacher students failed: \(error)")
      return nil
    }
  }

  private struct ChoiceParams: Encodable {
    let p_room_id: String
    let p_minutes: Int
  }

  /// The students checked in to [room] may choose their apps again for 5 minutes; returns
  /// until when, or nil when it failed.
  func openChoice(in room: TeacherRoom) async -> Date? {
    do {
      return try await client.rpc("open_choice", params: ChoiceParams(p_room_id: room.id, p_minutes: 5))
        .execute().value
    } catch {
      print("NotisTeacher openChoice failed: \(error)")
      return nil
    }
  }

  // MARK: - Recovery code

  /// Signs in again with [password] (the server only gives the code right after that), then
  /// returns the school's recovery code.
  func recoveryCode(password: String) async throws -> String {
    guard let email else { throw SignInError.failed }
    do {
      try await client.auth.signIn(email: email, password: password)
    } catch {
      throw SignInError.invalidLogin
    }
    return try await client.rpc("teacher_unlock_code").execute().value
  }
}
