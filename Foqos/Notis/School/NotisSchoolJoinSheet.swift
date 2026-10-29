import SwiftUI

/// First tap on a stone of a school this phone hasn't joined: "Je zit op … Wat is je naam?".
/// Also asked again after the server wiped the name. After joining, the same tap locks the phone
/// in that stone's room. AVG: a short name, first name + first letter is enough. Mirrors
/// `SchoolJoinDialog` on Android.
struct NotisSchoolJoinSheet: View {
  let schoolName: String
  let initialName: String
  /// Joins under the name; throws when that failed (offline, server).
  let onJoin: @MainActor (String) async throws -> Void
  let onCancel: () -> Void

  @State private var name = ""
  @State private var isBusy = false
  @State private var errorText: String?

  private var canJoin: Bool {
    !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isBusy
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 16) {
      Text("Je zit op \(schoolName)")
        .font(.satoshi(22, .bold))
        .foregroundStyle(NotisBrand.ink)
      Text(
        "Wat is je naam? Je voornaam en de eerste letter van je achternaam is genoeg. Alleen de docent van het lokaal waar je les hebt ziet deze naam, samen met of je telefoon gelocked is."
      )
      .font(.satoshi(15))
      .foregroundStyle(NotisBrand.inkSoft)

      TextField("Je naam, bijv. Sanne V.", text: $name)
        .font(.satoshi(17))
        .textInputAutocapitalization(.words)
        .padding(14)
        .background(NotisBrand.card, in: RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(NotisBrand.ink.opacity(0.12)))
        .onChange(of: name) { _, value in
          // The server keeps at most 20 characters.
          if value.count > 20 { name = String(value.prefix(20)) }
        }

      if let errorText {
        Text(errorText)
          .font(.satoshi(13))
          .foregroundStyle(.red)
      }

      Button {
        Task { await join() }
      } label: {
        Group {
          if isBusy {
            ProgressView().tint(.white)
          } else {
            Text("Aansluiten en locken").font(.satoshi(16, .bold))
          }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 52)
        .background(canJoin ? NotisBrand.mandarinDark : NotisBrand.mandarinDark.opacity(0.4), in: RoundedRectangle(cornerRadius: 16))
        .foregroundStyle(.white)
      }
      .disabled(!canJoin)

      Button("Annuleren", action: onCancel)
        .font(.satoshi(15, .medium))
        .foregroundStyle(NotisBrand.inkSoft)
        .frame(maxWidth: .infinity)
        .disabled(isBusy)
    }
    .padding(24)
    .onAppear { name = initialName }
  }

  private func join() async {
    isBusy = true
    errorText = nil
    do {
      try await onJoin(name)
    } catch {
      errorText = String(localized: "Aansluiten lukte niet. Controleer je internet en probeer het opnieuw.")
    }
    isBusy = false
  }
}
