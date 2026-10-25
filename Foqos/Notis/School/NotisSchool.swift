import Foundation
import Supabase

/// The school this phone joined by tapping one of its stones (rooms, stappenplan-lokalen.md),
/// cached so its stones work offline. Same JSON as `school_config()` on the server and
/// `JoinedSchool` on Android.
struct JoinedSchool: Codable, Equatable {
  let schoolId: String
  let name: String
  let autoUnlockAt: String
  let allowedApps: [SchoolApp]
  let allowedAppsVersion: Int
  let stones: [SchoolStone]

  enum CodingKeys: String, CodingKey {
    case schoolId = "school_id"
    case name = "school_name"
    case autoUnlockAt = "auto_unlock_at"
    case allowedApps = "allowed_apps"
    case allowedAppsVersion = "allowed_apps_version"
    case stones
  }
}

/// An app on the school's list. iOS only gets the name: Apple doesn't let apps see which
/// apps a student picks, so the student picks them in Apple's picker with this list beside it.
struct SchoolApp: Codable, Equatable {
  let name: String
  let android: String?
}

struct SchoolStone: Codable, Equatable {
  let stoneHash: String
  let roomId: String
  let roomName: String

  enum CodingKeys: String, CodingKey {
    case stoneHash = "stone_hash"
    case roomId = "room_id"
    case roomName = "room_name"
  }
}

struct SchoolRoom: Equatable {
  let roomId: String
  let roomName: String
}

/// First tap on a stone of a school this phone hasn't joined: the home screen asks a name.
struct SchoolInvite: Identifiable, Equatable {
  let uid: String
  let schoolId: String
  let schoolName: String
  var id: String { uid }
}

/// What the phone reports; values match `device_status.state` on the server.
enum StudentState: String {
  case locked
  case unlocked
  case emergency
}

/// Student side of rooms: joining a school, the room the phone is checked in to, and
/// reporting the lock status. Mirrors `StudentRepository.kt` (rooms part) on Android.
@MainActor
final class NotisSchool: ObservableObject {
  static let shared = NotisSchool()

  @Published private(set) var school: JoinedSchool?
  /// The room this phone is checked in to while a school lock runs; nil otherwise.
  @Published var currentRoomId: String? {
    didSet { defaults.set(currentRoomId, forKey: Keys.currentRoom) }
  }
  /// Set when a stone of an unknown school was tapped; the home screen asks a name.
  @Published var pendingInvite: SchoolInvite?

  private let defaults = UserDefaults.standard
  private var client: SupabaseClient { SchoolBackend.client }

  private enum Keys {
    static let school = "notis.school"
    static let currentRoom = "notis.school.currentRoomId"
    static let displayName = "notis.school.displayName"
  }

  private init() {
    if let data = defaults.data(forKey: Keys.school) {
      school = try? JSONDecoder().decode(JoinedSchool.self, from: data)
    }
    currentRoomId = defaults.string(forKey: Keys.currentRoom)
  }

  var displayName: String { defaults.string(forKey: Keys.displayName) ?? "" }

  private func setSchool(_ newSchool: JoinedSchool?) {
    school = newSchool
    if let newSchool, let data = try? JSONEncoder().encode(newSchool) {
      defaults.set(data, forKey: Keys.school)
    } else {
      defaults.removeObject(forKey: Keys.school)
      currentRoomId = nil
    }
  }

  // MARK: - Stones

  /// The room of the joined school whose stone has this NFC [uid]; local, works offline.
  func roomFor(uid: String) -> SchoolRoom? {
    let hash = StoneHash.of(uid)
    guard let stone = school?.stones.first(where: { $0.stoneHash == hash }) else { return nil }
    return SchoolRoom(roomId: stone.roomId, roomName: stone.roomName)
  }

  func roomName(for roomId: String?) -> String? {
    guard let roomId else { return nil }
    return school?.stones.first { $0.roomId == roomId }?.roomName
  }

  private struct StoneParams: Encodable {
    let p_stone_hash: String
  }

  private struct SchoolForStoneRow: Decodable {
    let school_id: String
    let school_name: String
  }

  /// Asks the server which school this stone belongs to; nil for other stones or offline.
  func invite(uid: String) async -> SchoolInvite? {
    do {
      try await SchoolBackend.ensureStudentSignedIn()
      let rows: [SchoolForStoneRow] = try await client
        .rpc("school_for_stone", params: StoneParams(p_stone_hash: StoneHash.of(uid)))
        .execute().value
      guard let row = rows.first else { return nil }
      return SchoolInvite(uid: uid, schoolId: row.school_id, schoolName: row.school_name)
    } catch {
      print("NotisSchool invite failed: \(error)")
      return nil
    }
  }

  private struct JoinParams: Encodable {
    let p_stone_hash: String
    let p_display_name: String
  }

  /// Joins the school of the stone with this NFC [uid]; joining again updates the name.
  func joinByStone(uid: String, displayName: String) async throws {
    let name = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
    try await SchoolBackend.ensureStudentSignedIn()
    let joined: JoinedSchool = try await client
      .rpc("join_school_by_stone", params: JoinParams(p_stone_hash: StoneHash.of(uid), p_display_name: name))
      .execute().value
    defaults.set(name, forKey: Keys.displayName)
    if joined.schoolId != school?.schoolId { currentRoomId = nil }
    setSchool(joined)
  }

  /// Re-reads the joined school: its stones, app list and end time.
  func refreshSchool() async {
    guard school != nil else { return }
    do {
      try await SchoolBackend.ensureStudentSignedIn()
      let fresh: JoinedSchool? = try await client.rpc("my_school").execute().value
      // A student removed from the school on the server is no longer in it here.
      setSchool(fresh)
    } catch {
      print("NotisSchool refresh failed: \(error)")
    }
  }

  /// Leaves the school. Only clears the local copy when the server agreed.
  func leaveSchool() async -> Bool {
    do {
      try await SchoolBackend.ensureStudentSignedIn()
      try await client.rpc("leave_school").execute()
      setSchool(nil)
      return true
    } catch {
      print("NotisSchool leave failed: \(error)")
      return false
    }
  }

  // MARK: - Status

  private struct ReportParams: Encodable {
    let p_state: String
    let p_room_id: String?
  }

  /// Reports the lock state; a lock in a room also checks in to that room (the server ends
  /// the check-in on unlock). Failures are left for the next report: iOS can't retry in the
  /// background the way Android's WorkManager does.
  func report(_ state: StudentState) async {
    guard school != nil else { return }
    let roomId = state == .locked ? currentRoomId : nil
    do {
      try await SchoolBackend.ensureStudentSignedIn()
      try await client.rpc("report_status", params: ReportParams(p_state: state.rawValue, p_room_id: roomId))
        .execute()
    } catch {
      print("NotisSchool report failed: \(error)")
    }
  }

  /// The app came to the foreground: the only moment iOS reliably lets it talk to the server.
  /// Reports the current state (it doubles as "last seen"), ends a check-in whose lock ended
  /// in the background (the end time), and picks up changes to the school.
  func appBecameActive(isSchoolLocked: Bool, isEmergency: Bool) {
    guard school != nil else { return }
    if !isSchoolLocked && currentRoomId != nil { currentRoomId = nil }
    let state: StudentState = isSchoolLocked ? (isEmergency ? .emergency : .locked) : .unlocked
    Task {
      await refreshSchool()
      await report(state)
    }
  }

  // MARK: - End time

  /// When a school lock that started at [start] ends by itself: the first end time
  /// ("HH:mm", local) after the start. Same rule as `schoolLockEnd()` on Android.
  static func lockEnd(start: Date, endTime: String, calendar: Calendar = .current) -> Date? {
    let parts = endTime.split(separator: ":").compactMap { Int($0) }
    guard parts.count >= 2,
      var end = calendar.date(bySettingHour: parts[0], minute: parts[1], second: 0, of: start)
    else { return nil }
    if end <= start {
      guard let tomorrow = calendar.date(byAdding: .day, value: 1, to: end) else { return nil }
      end = tomorrow
    }
    return end
  }
}
