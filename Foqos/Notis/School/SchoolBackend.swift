import Foundation
import Supabase

/// The NOTIS Supabase project (rooms, stappenplan-lokalen.md). Mirrors `SchoolBackend.kt` in
/// the Android app: one anonymous session for the student side and a separate email +
/// password session for a teacher, each kept under its own storage key.
///
/// The key is Supabase's publishable key: it is meant to ship inside apps, and Row Level
/// Security on the server decides what anyone can read or write with it.
enum SchoolBackend {
  static let url = URL(string: "https://dmwvjixdoiiuiihcyugi.supabase.co")!
  static let publishableKey = "sb_publishable_6PaCs-JjeOi3GfkrZGBthw_tgyygUxQ"

  static var isAvailable: Bool { FeatureFlags.rooms }

  /// Anonymous student session: joins a school and reports the lock status.
  static let client = make(storageKey: "notis-student-session")

  /// Teacher session (email + password): watches a room, shows the recovery code.
  static let accountClient = make(storageKey: "notis-teacher-session")

  private static func make(storageKey: String) -> SupabaseClient {
    SupabaseClient(
      supabaseURL: url,
      supabaseKey: publishableKey,
      options: SupabaseClientOptions(auth: .init(storageKey: storageKey))
    )
  }

  /// The student's user id, signing in anonymously the first time. The session is kept, so
  /// the same phone stays the same student in its school.
  @discardableResult
  static func ensureStudentSignedIn() async throws -> UUID {
    if let user = client.auth.currentUser { return user.id }
    let session = try await client.auth.signInAnonymously()
    return session.user.id
  }
}
