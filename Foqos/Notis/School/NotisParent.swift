import Foundation
import Supabase

/// A child as their parent sees it: the link, and the phone's last reported status.
struct ChildStatus: Identifiable, Equatable {
  let userId: String
  let name: String
  /// Set when the child unlinked this parent; no status is visible then.
  let unlinkedAt: Date?
  let state: String?
  let stateChangedAt: Date?
  let lastSeen: Date?
  var id: String { userId }
}

/// An app as a child's Android phone reports it to its parents: they can only pick from these.
/// An iPhone reports none: Apple doesn't let apps see which apps are installed.
struct ReportedApp: Codable, Equatable, Identifiable {
  let packageName: String
  let label: String
  var id: String { packageName }

  enum CodingKeys: String, CodingKey {
    case packageName = "package"
    case label
  }
}

/// Parent side ("Ik ben ouder"): link to a child's phone with its code and follow its lock
/// status. Mirrors `ParentRepository.kt` on Android, on the same account session as a teacher.
@MainActor
final class NotisParent {
  static let shared = NotisParent()

  private var client: SupabaseClient { SchoolBackend.accountClient }

  enum LinkError: Error {
    case codeInvalid, notParent, failed
  }

  private struct GuardianRow: Decodable {
    let child_user_id: String
    let child_name: String
    let unlinked_at: Date?
  }

  private struct DeviceStatusRow: Decodable {
    let user_id: String
    let state: String
    let state_changed_at: Date
    let last_seen: Date
  }

  /// The parent's children, by name; throws when offline.
  func children() async throws -> [ChildStatus] {
    guard let uid = client.auth.currentUser?.id else { return [] }
    let links: [GuardianRow] = try await client.from("guardians")
      .select("child_user_id, child_name, unlinked_at")
      .eq("guardian_user_id", value: uid.uuidString)
      .execute().value
    let active = links.filter { $0.unlinked_at == nil }.map(\.child_user_id)
    var statuses: [String: DeviceStatusRow] = [:]
    if !active.isEmpty {
      let rows: [DeviceStatusRow] = try await client.from("device_status")
        .select("user_id, state, state_changed_at, last_seen")
        .in("user_id", values: active)
        .execute().value
      for row in rows { statuses[row.user_id.lowercased()] = row }
    }
    return links.map { link in
      let status = statuses[link.child_user_id.lowercased()]
      return ChildStatus(
        userId: link.child_user_id,
        name: link.child_name,
        unlinkedAt: link.unlinked_at,
        state: status?.state,
        stateChangedAt: status?.state_changed_at,
        lastSeen: status?.last_seen
      )
    }
    .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
  }

  private struct RedeemParams: Encodable {
    let p_code: String
    let p_child_name: String
  }

  /// Redeems the code shown on the child's phone.
  func linkChild(code: String, name: String) async throws {
    do {
      try await client.rpc(
        "redeem_link_code",
        params: RedeemParams(
          p_code: code.trimmingCharacters(in: .whitespaces).uppercased(),
          p_child_name: name.trimmingCharacters(in: .whitespaces)
        )
      ).execute()
    } catch {
      let text = "\(error)"
      if text.contains("Unknown or expired link code") { throw LinkError.codeInvalid }
      if text.contains("Teacher accounts cannot link") { throw LinkError.notParent }
      throw LinkError.failed
    }
  }

  private struct DeviceAppsRow: Decodable {
    let apps: [ReportedApp]
  }

  /// The apps the child's phone reported, to choose from; empty until it reported once.
  func childApps(_ child: ChildStatus) async throws -> [ReportedApp] {
    let rows: [DeviceAppsRow] = try await client.from("device_apps")
      .select("apps")
      .eq("user_id", value: child.userId)
      .execute().value
    return (rows.first?.apps ?? [])
      .sorted { $0.label.localizedCaseInsensitiveCompare($1.label) == .orderedAscending }
  }

  private struct ChildRuleRow: Codable {
    let child_user_id: String
    let allowed_apps: [String]
    var updated_at: String? = nil
  }

  /// The apps this child may use on their own stones; nil when no list is set.
  func childRule(_ child: ChildStatus) async throws -> [String]? {
    let rows: [ChildRuleRow] = try await client.from("child_rules")
      .select("child_user_id, allowed_apps")
      .eq("child_user_id", value: child.userId)
      .execute().value
    return rows.first?.allowed_apps
  }

  /// Sets the child's list, or removes it ([packages] nil): the child then chooses again.
  func setChildRule(_ child: ChildStatus, packages: [String]?) async throws {
    if let packages {
      try await client.from("child_rules")
        .upsert(
          ChildRuleRow(
            child_user_id: child.userId,
            allowed_apps: packages.sorted(),
            updated_at: ISO8601DateFormatter().string(from: Date())
          )
        )
        .execute()
    } else {
      try await client.from("child_rules").delete().eq("child_user_id", value: child.userId).execute()
    }
  }

  /// Removes the link for good (also used to clear a link the child already ended).
  func removeChild(_ child: ChildStatus) async throws {
    guard let uid = client.auth.currentUser?.id else { return }
    try await client.from("guardians").delete()
      .eq("child_user_id", value: child.userId)
      .eq("guardian_user_id", value: uid.uuidString)
      .execute()
  }
}
