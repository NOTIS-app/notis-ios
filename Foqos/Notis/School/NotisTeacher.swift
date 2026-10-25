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
  let platform: String?

  var id: String { userId }
  /// iPhones can't report in the background, so silence doesn't mean "geen contact".
  var isIphone: Bool { platform == "ios" }

  enum CodingKeys: String, CodingKey {
    case userId = "user_id"
    case displayName = "display_name"
    case state
    case stateChangedAt = "state_changed_at"
    case lastSeen = "last_seen"
    case tooMany = "too_many"
    case platform
  }
}

/// Teacher side of rooms (8e): signing in, tapping a room's stone (or picking the room) to see
/// who is locked there, "Keuze openen" and the recovery code. Mirrors `RoomRepository.kt`
/// and `AccountRepository.kt` on Android: the email + password account on this phone is a
/// teacher, a parent ("Ik ben ouder", `NotisParent`) or a NOTIS admin, who signs in through a
/// hidden entry (seven taps on "Over NOTIS") and only prepares and links stones (`NotisAdmin`).
/// The kinds are separate: an account only signs in where its kind belongs.
@MainActor
final class NotisTeacher: ObservableObject {
  static let shared = NotisTeacher()

  enum AccountRole: String, Identifiable {
    var id: String { rawValue }

    case teacher, parent, admin
  }

  @Published private(set) var email: String?
  @Published private(set) var role: AccountRole?
  /// The room whose live list is open (stone tapped or picked), or nil.
  @Published var openRoom: TeacherRoom?

  var isTeacher: Bool { role == .teacher }
  var isParent: Bool { role == .parent }
  var isAdmin: Bool { role == .admin }

  private var client: SupabaseClient { SchoolBackend.accountClient }

  private init() {
    email = client.auth.currentUser?.email
    let defaults = UserDefaults.standard
    // Before parents, only a teacher flag was kept.
    let stored = defaults.string(forKey: Self.roleKey)
      ?? (defaults.bool(forKey: Self.legacyTeacherKey) ? AccountRole.teacher.rawValue : nil)
    role = email == nil ? nil : stored.flatMap(AccountRole.init(rawValue:))
  }

  private static let roleKey = "notis.account.role"
  private static let legacyTeacherKey = "notis.teacher.isTeacher"

  enum SignInError: Error {
    case invalidLogin, notTeacher, notParent, notAdmin, emailTaken, weakPassword, emailNotConfirmed, failed
  }

  /// Signs in, but only with an account of the [expected] kind; otherwise signs out again.
  func signIn(email: String, password: String, as expected: AccountRole = .teacher) async throws {
    do {
      try await client.auth.signIn(email: email.trimmingCharacters(in: .whitespaces), password: password)
    } catch {
      throw "\(error)".localizedCaseInsensitiveContains("invalid") ? SignInError.invalidLogin : SignInError.failed
    }
    let actual = await currentRole()
    guard actual == expected else {
      try? await client.auth.signOut()
      switch expected {
      case .teacher: throw SignInError.notTeacher
      case .parent: throw SignInError.notParent
      case .admin: throw SignInError.notAdmin
      }
    }
    setSignedIn(as: actual)
  }

  /// Creates a parent account; email confirmation is off for the pilot, so it signs in right
  /// away. The "parent" mark keeps this account out of the teachers table for good.
  func signUpParent(email: String, password: String) async throws {
    do {
      let response = try await client.auth.signUp(
        email: email.trimmingCharacters(in: .whitespaces),
        password: password,
        data: ["role": .string("parent")]
      )
      // With "Confirm email" on in Supabase the account exists but has no session yet.
      guard response.session != nil else { throw SignInError.emailNotConfirmed }
    } catch let error as SignInError {
      throw error
    } catch {
      let text = "\(error)"
      if text.contains("already") || text.contains("user_already_exists") { throw SignInError.emailTaken }
      if text.contains("weak_password") || text.contains("Password should be") { throw SignInError.weakPassword }
      throw SignInError.failed
    }
    setSignedIn(as: .parent)
  }

  /// Teacher when listed in `teachers`, admin when in `platform_admins`, parent otherwise.
  private func currentRole() async -> AccountRole {
    let teacher: Bool = (try? await client.rpc("is_teacher").execute().value) ?? false
    if teacher { return .teacher }
    let admin: Bool = (try? await client.rpc("is_platform_admin").execute().value) ?? false
    return admin ? .admin : .parent
  }

  private func setSignedIn(as newRole: AccountRole) {
    email = client.auth.currentUser?.email
    role = newRole
    UserDefaults.standard.set(newRole.rawValue, forKey: Self.roleKey)
  }

  func signOut() async {
    try? await client.auth.signOut()
    email = nil
    role = nil
    openRoom = nil
    UserDefaults.standard.removeObject(forKey: Self.roleKey)
    UserDefaults.standard.set(false, forKey: Self.legacyTeacherKey)
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
