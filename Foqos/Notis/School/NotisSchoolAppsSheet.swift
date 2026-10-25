import FamilyControls
import SwiftData
import SwiftUI

/// The apps a student may use during a school lock (8c). iOS doesn't let NOTIS see app names,
/// so the student picks them in Apple's picker with the school's list beside it. Choosing is
/// only possible while the choice is open (`NotisSchool.canChooseApps`); the teacher sees
/// how many apps and whether a whole category was picked.
struct NotisSchoolAppsSheet: View {
  @Environment(\.modelContext) private var context
  @Environment(\.dismiss) private var dismiss

  @ObservedObject var school: NotisSchool
  /// A school lock is running: saving applies the new choice right away.
  let isSchoolLocked: Bool

  @State private var selection = FamilyActivitySelection()
  @State private var showPicker = false
  @State private var errorText: String?

  private var schoolApps: [SchoolApp] { school.school?.allowedApps ?? [] }

  var body: some View {
    VStack(alignment: .leading, spacing: 16) {
      Text("Apps voor school")
        .font(.satoshi(22, .bold))
        .foregroundStyle(NotisBrand.ink)

      Text(
        schoolApps.isEmpty
          ? "Je school heeft nog geen apps toegestaan. Tijdens het schoolslot gaat alles op slot."
          : "Deze apps mag je tijdens het schoolslot gebruiken. Kies ze in het keuzescherm van Apple; al het andere gaat op slot."
      )
      .font(.satoshi(15))
      .foregroundStyle(NotisBrand.inkSoft)

      if !schoolApps.isEmpty {
        VStack(alignment: .leading, spacing: 8) {
          ForEach(schoolApps, id: \.name) { app in
            Label(app.name, systemImage: "checkmark.circle")
              .font(.satoshi(16, .medium))
              .foregroundStyle(NotisBrand.ink)
          }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(NotisBrand.card, in: RoundedRectangle(cornerRadius: 18))
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(NotisBrand.ink.opacity(0.12)))
      }

      if school.canChooseApps {
        Text("Kies alleen deze apps. Je docent ziet hoeveel apps je kiest.")
          .font(.satoshi(13))
          .foregroundStyle(NotisBrand.inkSoft)
        Button {
          showPicker = true
        } label: {
          Text("Apps kiezen")
            .font(.satoshi(16, .bold))
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .background(NotisBrand.mandarinDark, in: RoundedRectangle(cornerRadius: 16))
            .foregroundStyle(.white)
        }
      } else {
        Text("De keuze staat dicht. Vraag je docent om de keuze te openen.")
          .font(.satoshi(15, .medium))
          .foregroundStyle(NotisBrand.ink)
      }

      if let errorText {
        Text(errorText).font(.satoshi(13)).foregroundStyle(.red)
      }

      Button("Sluiten") { dismiss() }
        .font(.satoshi(15, .medium))
        .foregroundStyle(NotisBrand.inkSoft)
        .frame(maxWidth: .infinity)
    }
    .padding(24)
    .task {
      if let profile = try? BlockedProfiles.notisSchoolProfile(in: context) {
        selection = profile.selectedActivity
      }
      await school.refreshChoiceOpen()
    }
    .sheet(isPresented: $showPicker) {
      NotisAppPicker(selection: $selection, allowMode: true) {
        showPicker = false
        save()
      }
    }
  }

  private func save() {
    do {
      let profile = try BlockedProfiles.notisSchoolProfile(in: context)
      try BlockedProfiles.updateNotisStoneApps(profile, selection: selection, in: context)
      if isSchoolLocked {
        AppBlockerUtil().activateRestrictions(for: BlockedProfiles.getSnapshot(for: profile))
      }
      school.didChooseApps(
        count: selection.applicationTokens.count + selection.webDomainTokens.count,
        hasCategory: !selection.categoryTokens.isEmpty
      )
      if isSchoolLocked {
        Task { await school.report(.locked) }
      }
      errorText = nil
    } catch {
      errorText = String(localized: "Opslaan lukte niet: \(error.localizedDescription)")
    }
  }
}
