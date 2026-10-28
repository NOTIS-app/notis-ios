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
  /// App Store bundle ID and icon, from the app catalogue on the admin page.
  var ios: String? = nil
  var icon: String? = nil
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

/// A parent who follows this phone; shown on the child's phone so it always knows who.
struct LinkedGuardian: Codable, Equatable, Identifiable {
  let guardianUserId: String
  let guardianEmail: String
  /// What the parent typed when linking ("Mama"); nil for links made before that existed.
  var guardianName: String? = nil
  var id: String { guardianUserId }

  /// How the child's phone names this parent.
  var displayName: String {
    if let name = guardianName, !name.isEmpty { return name }
    return guardianEmail.isEmpty ? String(localized: "Ouder") : guardianEmail
  }

  enum CodingKeys: String, CodingKey {
    case guardianUserId = "guardian_user_id"
    case guardianEmail = "guardian_email"
    case guardianName = "guardian_name"
  }
}

/// The code a parent enters to follow this phone; valid for 10 minutes.
struct ParentLinkCode: Decodable, Equatable {
  let code: String
  let expiresAt: Date

  enum CodingKeys: String, CodingKey {
    case code
    case expiresAt = "expires_at"
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
  /// Parents who follow this phone ("Ouder koppelen").
  @Published private(set) var guardians: [LinkedGuardian] = []

  /// A school or a parent follows this phone, so it reports its lock status.
  var isLinked: Bool { school != nil || !guardians.isEmpty }

  private let defaults = UserDefaults.standard
  private var client: SupabaseClient { SchoolBackend.client }

  private enum Keys {
    static let school = "notis.school"
    static let currentRoom = "notis.school.currentRoomId"
    static let displayName = "notis.school.displayName"
    static let chosenVersion = "notis.school.chosenListVersion"
    static let appCount = "notis.school.appCount"
    static let hasCategory = "notis.school.hasCategory"
    static let guardians = "notis.school.guardians"
  }

  private init() {
    if let data = defaults.data(forKey: Keys.school) {
      school = try? JSONDecoder().decode(JoinedSchool.self, from: data)
    }
    currentRoomId = defaults.string(forKey: Keys.currentRoom)
    if let data = defaults.data(forKey: Keys.guardians) {
      guardians = (try? JSONDecoder().decode([LinkedGuardian].self, from: data)) ?? []
    }
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

  /// Wipes this phone's anonymous account on the server (school, status, parents) and
  /// everything cached here; the next stone tap starts with a fresh account. False when the
  /// server couldn't be reached: then nothing changes. Mirrors `deleteMyData` on Android.
  func deleteMyData() async -> Bool {
    if client.auth.currentUser != nil {
      do {
        try await client.rpc("delete_my_account").execute()
      } catch {
        print("NotisSchool deleteMyData failed: \(error)")
        return false
      }
      try? await client.auth.signOut()
    }
    setSchool(nil)
    setGuardians([])
    pendingInvite = nil
    for key in [Keys.displayName, Keys.chosenVersion, Keys.appCount, Keys.hasCategory] {
      defaults.removeObject(forKey: key)
    }
    return true
  }

  // MARK: - Parents

  private func setGuardians(_ list: [LinkedGuardian]) {
    guardians = list
    defaults.set(try? JSONEncoder().encode(list), forKey: Keys.guardians)
  }

  /// Re-reads which parents follow this phone. Keeps the last list when offline.
  func refreshGuardians() async {
    do {
      let uid = try await SchoolBackend.ensureStudentSignedIn()
      func read(_ columns: String) async throws -> [LinkedGuardian] {
        try await client.from("guardians")
          .select(columns)
          .eq("child_user_id", value: uid.uuidString)
          .filter("unlinked_at", operator: "is", value: "null")
          .execute().value
      }
      // guardian_name needs migration 20261105000000_guardian_name.sql; without it, no names.
      let rows: [LinkedGuardian]
      do {
        rows = try await read("guardian_user_id, guardian_email, guardian_name")
      } catch {
        rows = try await read("guardian_user_id, guardian_email")
      }
      setGuardians(rows)
    } catch {
      print("NotisSchool refreshGuardians failed: \(error)")
    }
  }

  /// A fresh code for a parent to enter; nil when offline.
  func createLinkCode() async -> ParentLinkCode? {
    do {
      try await SchoolBackend.ensureStudentSignedIn()
      let rows: [ParentLinkCode] = try await client.rpc("create_link_code").execute().value
      return rows.first
    } catch {
      print("NotisSchool createLinkCode failed: \(error)")
      return nil
    }
  }

  private struct GuardianParams: Encodable {
    let p_guardian_user_id: String
  }

  /// Stops a parent from following this phone; the parent sees it as unlinked.
  func unlinkGuardian(_ guardian: LinkedGuardian) async -> Bool {
    do {
      try await SchoolBackend.ensureStudentSignedIn()
      try await client.rpc("unlink_guardian", params: GuardianParams(p_guardian_user_id: guardian.guardianUserId))
        .execute()
      setGuardians(guardians.filter { $0.guardianUserId != guardian.guardianUserId })
      return true
    } catch {
      print("NotisSchool unlinkGuardian failed: \(error)")
      return false
    }
  }

  // MARK: - App choice (8c)

  /// The teacher pressed "Keuze openen" for the room this phone is checked in to.
  @Published private(set) var isChoiceOpenedByTeacher = false

  /// The version of the school's list the student last chose apps for.
  private var chosenListVersion: Int {
    get { defaults.integer(forKey: Keys.chosenVersion) }
    set { defaults.set(newValue, forKey: Keys.chosenVersion) }
  }

  /// Choosing is open after joining or a change to the school's list (until the student
  /// chose), and for a few minutes after a teacher opens it. Otherwise the choice is fixed.
  var canChooseApps: Bool {
    guard let school else { return false }
    return chosenListVersion < school.allowedAppsVersion || isChoiceOpenedByTeacher
  }

  var hasChosenForCurrentList: Bool {
    guard let school else { return false }
    return chosenListVersion >= school.allowedAppsVersion
  }

  /// Asks the server whether a teacher opened the choice for this phone's room.
  func refreshChoiceOpen() async {
    guard school != nil else { return }
    do {
      try await SchoolBackend.ensureStudentSignedIn()
      let open: Bool = try await client.rpc("my_choice_open").execute().value
      isChoiceOpenedByTeacher = open
    } catch {
      print("NotisSchool choice check failed: \(error)")
    }
  }

  /// The student saved their apps: remembered for the app check that goes with every report.
  func didChooseApps(count: Int, hasCategory: Bool) {
    defaults.set(count, forKey: Keys.appCount)
    defaults.set(hasCategory, forKey: Keys.hasCategory)
    chosenListVersion = school?.allowedAppsVersion ?? chosenListVersion
    isChoiceOpenedByTeacher = false
    objectWillChange.send()
  }

  // MARK: - Recovery code (8d)

  enum UnlockCodeResult {
    case ok, wrong, tooMany, failed
  }

  private struct CodeParams: Encodable {
    let p_code: String
  }

  /// Tries a teacher's recovery code. On `.ok` the server already made a new code; the
  /// caller ends the school lock. Needs internet: the server keeps the code.
  func useUnlockCode(_ code: String) async -> UnlockCodeResult {
    do {
      try await SchoolBackend.ensureStudentSignedIn()
      let ok: Bool = try await client
        .rpc("use_unlock_code", params: CodeParams(p_code: code.trimmingCharacters(in: .whitespaces)))
        .execute().value
      return ok ? .ok : .wrong
    } catch {
      print("NotisSchool recovery code failed: \(error)")
      return "\(error)".contains("Too many attempts") ? .tooMany : .failed
    }
  }

  // MARK: - Status

  private struct ReportParams: Encodable {
    let p_state: String
    let p_room_id: String?
    let p_app_count: Int?
    let p_has_category: Bool?
    let p_list_version: Int?
    /// iOS can't report in the background: teachers see "laatst gezien" instead of "geen contact".
    let p_platform: String = "ios"
  }

  /// Reports the lock state; a lock in a room also checks in to that room (the server ends
  /// the check-in on unlock). Failures are left for the next report: iOS can't retry in the
  /// background the way Android's WorkManager does.
  func report(_ state: StudentState) async {
    guard isLinked else { return }
    let roomId = state == .locked ? currentRoomId : nil
    // The app check (8c): how many apps the student allowed, whether a whole category, and
    // for which version of the school's list. Only once the student has chosen.
    let hasCheck = roomId != nil && defaults.object(forKey: Keys.appCount) != nil
    let params = ReportParams(
      p_state: state.rawValue,
      p_room_id: roomId,
      p_app_count: hasCheck ? defaults.integer(forKey: Keys.appCount) : nil,
      p_has_category: hasCheck ? defaults.bool(forKey: Keys.hasCategory) : nil,
      p_list_version: hasCheck ? chosenListVersion : nil
    )
    do {
      try await SchoolBackend.ensureStudentSignedIn()
      try await client.rpc("report_status", params: params).execute()
    } catch {
      print("NotisSchool report failed: \(error)")
    }
  }

  /// The app came to the foreground: the only moment iOS reliably lets it talk to the server.
  /// Reports the current state (it doubles as "last seen"), ends a check-in whose lock ended
  /// in the background (the end time), and picks up changes to the school and the parents.
  /// [isLocked] counts every lock (a parent sees own stones too), [isSchoolLocked] only the
  /// school's.
  func appBecameActive(isLocked: Bool, isSchoolLocked: Bool, isEmergency: Bool) {
    guard isLinked else { return }
    if !isSchoolLocked && currentRoomId != nil { currentRoomId = nil }
    let state: StudentState = isLocked ? (isEmergency ? .emergency : .locked) : .unlocked
    Task {
      await refreshGuardians()
      if school != nil {
        await refreshSchool()
        await refreshChoiceOpen()
      }
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
