import FamilyControls
import SwiftData
import SwiftUI
import UIKit

/// Settings, laid out like Android's `SettingsScreen` with NOTIS' flags: a notifications card,
/// then SYSTEEM with permissions, privacy and the version.
struct NotisSettingsView: View {
  @Environment(\.modelContext) private var context
  @Environment(\.openURL) private var openURL

  @EnvironmentObject private var requestAuthorizer: RequestAuthorizer
  @EnvironmentObject private var strategyManager: StrategyManager

  @AppStorage(NotisNotifications.key) private var notificationsEnabled = true
  @ObservedObject private var school = NotisSchool.shared
  @ObservedObject private var teacher = NotisTeacher.shared
  @State private var showLeaveSchool = false
  @State private var showDeleteData = false
  @State private var deleteDataFailed = false
  @State private var showDeleteAccount = false
  @State private var showLicenses = false
  @State private var deleteAccountFailed = false
  /// "Mijn gegevens wissen" with an account: what was typed, and whether it wasn't the word.
  @State private var deleteWord = ""
  @State private var deleteWordWrong = false
  /// The login sheet that is open: "Ik ben docent", "Ik ben ouder" or the hidden admin login.
  @State private var loginRole: NotisTeacher.AccountRole?
  @State private var showParentLink = false
  @State private var unlinkingGuardian: LinkedGuardian?
  @State private var children: [ChildStatus] = []
  @State private var showAddChild = false
  @State private var childApps: ChildStatus?
  @State private var removingChild: ChildStatus?
  @State private var showRecoveryCode = false
  @State private var showStonePrepare = false
  @State private var showStoneLink = false
  /// Hidden NOTIS admin login: seven quick taps on "Over NOTIS", as on Android.
  @State private var aboutTaps = 0
  @State private var lastAboutTap = Date.distantPast

  private var isSchoolLocked: Bool {
    strategyManager.activeSession?.blockedProfile.isNotisSchoolProfile == true
  }

  private var isAuthorized: Bool {
    requestAuthorizer.isAuthorized || NotisDevice.isSimulator
  }

  private var appVersion: String {
    let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?"
    let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "?"
    return "v\(version) (\(build))"
  }

  var body: some View {
    ZStack {
      NotisBrand.paper.ignoresSafeArea()

      ScrollView {
        VStack(alignment: .leading, spacing: 12) {
          Text("Instellingen")
            .font(.satoshi(28, .bold))
            .foregroundStyle(NotisBrand.ink)
            .padding(.top, 16)

          notificationsCard

          // Same layout as Android: SCHOOL & OUDERS (StudentClassCard), then the account.
          if FeatureFlags.rooms {
            Text("SCHOOL & OUDERS")
              .font(.satoshi(12, .bold))
              .tracking(1)
              .foregroundStyle(NotisBrand.inkSoft)
              .padding(.top, 4)
            SettingsCard {
              // The school this phone joined by tapping one of its stones (8d).
              if let joined = school.school {
                SettingsRow(
                  icon: "graduationcap",
                  title: joined.name,
                  subtitle: String(localized: "Als \(school.displayName) · tik de steen van je lokaal om te locken"),
                  showsChevron: false
                )
                // No leaving during a school lock: that would be a way out of it.
                if !isSchoolLocked {
                  SettingsRow(
                    icon: "rectangle.portrait.and.arrow.right",
                    title: String(localized: "Afmelden bij school"),
                    action: { showLeaveSchool = true }
                  )
                }
              }
              if FeatureFlags.parentControls {
                // Always visible on the child's phone: who can see whether NOTIS is locked.
                ForEach(school.guardians) { guardian in
                  SettingsRow(
                    icon: "figure.and.child.holdinghands",
                    title: guardian.displayName,
                    subtitle: String(localized: "Kan zien of NOTIS gelocked is"),
                    showsChevron: false,
                    onRemove: { unlinkingGuardian = guardian }
                  )
                }
                SettingsRow(
                  icon: "link",
                  title: String(localized: "Ouder koppelen"),
                  subtitle: school.guardians.isEmpty ? String(localized: "Laat een ouder zien of NOTIS gelocked is") : nil,
                  action: { showParentLink = true }
                )
              }
            }

            accountCards
          }

          Text("SYSTEEM")
            .font(.satoshi(12, .bold))
            .tracking(1)
            .foregroundStyle(NotisBrand.inkSoft)
            .padding(.top, 4)

          SettingsCard {
            SettingsRow(
              icon: "checkmark.shield",
              title: String(localized: "Toestemmingen"),
              subtitle: isAuthorized
                ? String(localized: "Alles aan") : String(localized: "Schermtijd ontbreekt"),
              subtitleColor: isAuthorized ? NotisBrand.mandarinDark : NotisPalette.light.error,
              action: openPermissions
            )
          }

          SettingsCard {
            SettingsRow(
              icon: "hand.raised",
              title: String(localized: "Privacybeleid"),
              trailingSystemImage: "arrow.up.right.square",
              action: { openURL(URL(string: "https://notisapp.nl/privacy.html")!) }
            )
            // The license texts ship with the app (MIT asks for that), with a link to the website.
            SettingsRow(
              icon: "doc.text",
              title: String(localized: "Open-sourcelicenties"),
              action: { showLicenses = true }
            )
          }

          // "Over NOTIS" stands on its own, without a card, as on Android. Seven quick taps open
          // the NOTIS admin login; nothing on screen gives it away.
          SettingsRow(
            icon: "info.circle",
            title: String(localized: "Over NOTIS"),
            subtitle: appVersion,
            showsChevron: false
          )
          .onTapGesture(perform: tapAbout)

          // Last on the screen, in red (the App Store requires it). Not during a school lock:
          // that would be a way out of it.
          // With a parent signed in, the account goes too. Not for teachers and NOTIS admins:
          // a NOTIS admin removes them.
          if FeatureFlags.rooms && !isSchoolLocked && teacher.role != .admin && teacher.role != .teacher {
            SettingsRow(
              icon: "trash",
              iconColor: NotisPalette.light.error,
              title: String(localized: "Mijn gegevens wissen"),
              titleColor: NotisPalette.light.error,
              subtitle: deletesAccount
                ? String(localized: "Verwijdert ook je account \(teacher.email ?? "")")
                : String(localized: "Haalt je school, naam, status en ouders weg bij NOTIS"),
              action: {
                deleteWord = ""
                showDeleteData = true
              }
            )
          }
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 104)
      }
    }
    .onAppear {
      requestAuthorizer.refreshAuthorizationStatus()
    }
    .sheet(item: $loginRole) { role in
      NotisTeacherLoginSheet(teacher: teacher, role: role) { loginRole = nil }
        .presentationDetents([.medium, .large])
        .presentationBackground(NotisBrand.paper)
    }
    .sheet(isPresented: $showParentLink) {
      NotisParentLinkSheet(school: school, isLocked: strategyManager.isBlocking) { showParentLink = false }
        .presentationDetents([.medium])
        .presentationBackground(NotisBrand.paper)
    }
    .sheet(isPresented: $showAddChild) {
      NotisAddChildSheet { linked in
        showAddChild = false
        if linked { Task { await reloadChildren() } }
      }
      .presentationDetents([.medium, .large])
      .presentationBackground(NotisBrand.paper)
    }
    .sheet(item: $childApps) { child in
      NotisChildAppsSheet(child: child) { childApps = nil }
    }
    .alert(
      String(localized: "Deze ouder ontkoppelen?"),
      isPresented: Binding(get: { unlinkingGuardian != nil }, set: { if !$0 { unlinkingGuardian = nil } })
    ) {
      Button("Ontkoppelen", role: .destructive) {
        if let guardian = unlinkingGuardian {
          Task {
            if await school.unlinkGuardian(guardian) {
              await school.report(strategyManager.isBlocking ? .locked : .unlocked)
            }
          }
        }
      }
      Button("Annuleren", role: .cancel) {}
    } message: {
      Text("Je ouder ziet dan niet meer of NOTIS gelocked is, en ziet dat je hebt ontkoppeld.")
    }
    .alert(
      String(localized: "\(removingChild?.name ?? "") verwijderen?"),
      isPresented: Binding(get: { removingChild != nil }, set: { if !$0 { removingChild = nil } })
    ) {
      Button("Verwijderen", role: .destructive) {
        if let child = removingChild {
          Task {
            try? await NotisParent.shared.removeChild(child)
            await reloadChildren()
          }
        }
      }
      Button("Annuleren", role: .cancel) {}
    } message: {
      Text("Je ziet dan niet meer of NOTIS op deze telefoon gelocked is. Opnieuw koppelen kan met een nieuwe code.")
    }
    // A parent follows their children's status while settings is open.
    .task(id: teacher.role) {
      guard teacher.isParent else {
        children = []
        return
      }
      while !Task.isCancelled {
        await reloadChildren()
        try? await Task.sleep(for: .seconds(10))
      }
    }
    .fullScreenCover(isPresented: $showStonePrepare) {
      NotisStonePrepareView { showStonePrepare = false }
    }
    .fullScreenCover(isPresented: $showStoneLink) {
      NotisStoneLinkView { showStoneLink = false }
    }
    .sheet(isPresented: $showLicenses) {
      NotisLicensesSheet { showLicenses = false }
    }
    .sheet(isPresented: $showRecoveryCode) {
      NotisRecoveryCodeRevealSheet(teacher: teacher) { showRecoveryCode = false }
        .presentationDetents([.medium])
        .presentationBackground(NotisBrand.paper)
    }
    .alert(
      String(localized: "\(school.school?.name ?? "") verlaten?"),
      isPresented: $showLeaveSchool
    ) {
      Button("Verlaten", role: .destructive) {
        Task { _ = await school.leaveSchool() }
      }
      Button("Annuleren", role: .cancel) {}
    } message: {
      Text(
        "Je docenten zien dan niet meer of je telefoon gelocked is, en de stenen van deze school zetten je telefoon niet meer op slot."
      )
    }
    .alert(String(localized: "Mijn gegevens wissen"), isPresented: $showDeleteData) {
      if deletesAccount {
        TextField("Typ WISSEN om te bevestigen", text: $deleteWord)
          .textInputAutocapitalization(.characters)
      }
      Button("Wissen", role: .destructive, action: deleteMyData)
      Button("Annuleren", role: .cancel) {}
    } message: {
      if deletesAccount {
        Text(
          "NOTIS wist alles wat het over deze telefoon bewaart (je school, naam, status en gekoppelde ouders) en verwijdert je account \(teacher.email ?? "") met alles wat eraan gekoppeld is (voor een ouder: de koppelingen met je kinderen en de app-lijsten die je instelde). Je profielen en instellingen op deze telefoon blijven. Dit kan niet ongedaan worden."
        )
      } else {
        Text(
          "NOTIS wist alles wat het over deze telefoon bewaart: je school, de naam die je koos, of NOTIS op slot staat en gekoppelde ouders. Je profielen en instellingen op deze telefoon blijven. Dit kan niet ongedaan worden."
        )
      }
    }
    .alert(String(localized: "Er is niets gewist"), isPresented: $deleteWordWrong) {
      Button("OK", role: .cancel) {}
    } message: {
      Text("Typ WISSEN om te bevestigen dat ook je account weg mag.")
    }
    .alert(String(localized: "Account verwijderen"), isPresented: $showDeleteAccount) {
      Button("Verwijderen", role: .destructive) {
        Task {
          do {
            try await teacher.deleteAccount()
          } catch {
            deleteAccountFailed = true
          }
        }
      }
      Button("Annuleren", role: .cancel) {}
    } message: {
      Text(
        "Je login en alles wat eraan gekoppeld is worden voorgoed verwijderd (voor een ouder: de koppelingen met je kinderen en de app-lijsten die je instelde). Dit kan niet ongedaan worden."
      )
    }
    .alert(
      String(localized: "NOTIS is niet bereikbaar"),
      isPresented: Binding(
        get: { deleteDataFailed || deleteAccountFailed },
        set: { if !$0 { deleteDataFailed = false; deleteAccountFailed = false } }
      )
    ) {
      Button("OK", role: .cancel) {}
    } message: {
      Text("Er is niets gewist. Controleer je internet en probeer het opnieuw.")
    }
    .onChange(of: notificationsEnabled) { _, isOn in
      NotisNotifications.apply(isOn, context: context, strategyManager: strategyManager)
    }
  }

  /// Android's notifications `ActionCard`, alone on its row because the theme picker is off.
  private var notificationsCard: some View {
    VStack(alignment: .leading, spacing: 0) {
      HStack(alignment: .top) {
        SettingsIcon(systemName: "bell")
        Spacer()
        Toggle("", isOn: $notificationsEnabled)
          .labelsHidden()
          .tint(NotisBrand.mandarinDark)
          .scaleEffect(0.85, anchor: .topTrailing)
      }
      Spacer(minLength: 12)
      Text("Meldingen")
        .font(.satoshi(16, .bold))
        .foregroundStyle(NotisBrand.ink)
      Text(notificationsEnabled ? "Aan" : "Uit")
        .font(.satoshi(13))
        .foregroundStyle(notificationsEnabled ? NotisBrand.mandarinDark : NotisBrand.inkSoft)
    }
    .padding(14)
    .frame(maxWidth: .infinity, minHeight: 130, alignment: .topLeading)
    .notisCard()
  }

  private func tapAbout() {
    guard FeatureFlags.rooms, teacher.email == nil else { return }
    let now = Date()
    aboutTaps = now.timeIntervalSince(lastAboutTap) < 1.5 ? aboutTaps + 1 : 1
    lastAboutTap = now
    if aboutTaps >= 7 {
      aboutTaps = 0
      loginRole = .admin
    }
  }

  private func reloadChildren() async {
    // Offline: keep the last list.
    if let fresh = try? await NotisParent.shared.children() { children = fresh }
  }

  /// "Mijn gegevens wissen" also deletes a signed-in parent's account.
  private var deletesAccount: Bool {
    !FeatureFlags.separateAccountDelete && teacher.role == .parent
  }

  /// First the account on the server (after the typed word), then what this phone keeps.
  private func deleteMyData() {
    let withAccount = deletesAccount
    if withAccount
      && deleteWord.trimmingCharacters(in: .whitespaces).caseInsensitiveCompare("WISSEN") != .orderedSame
    {
      deleteWordWrong = true
      return
    }
    Task {
      if withAccount {
        do {
          try await teacher.deleteAccount()
        } catch {
          deleteAccountFailed = true
          return
        }
      }
      deleteDataFailed = !(await school.deleteMyData())
    }
  }

  /// The account, as Android's `AccountSection`: signed out "Ik ben docent" and "Ik ben ouder";
  /// signed in what the kind of account does, then signing out.
  @ViewBuilder
  private var accountCards: some View {
    switch teacher.role {
    case nil:
      SettingsCard {
        if FeatureFlags.parentControls {
          SettingsRow(
            icon: "figure.and.child.holdinghands",
            title: String(localized: "Ik ben ouder"),
            subtitle: String(localized: "Zie of NOTIS van je kind gelocked is"),
            action: { loginRole = .parent }
          )
        }
        SettingsRow(
          icon: "person.crop.square",
          title: String(localized: "Ik ben docent"),
          subtitle: String(localized: "Log in om je lokaal te zien"),
          action: { loginRole = .teacher }
        )
      }
    case .teacher:
      SettingsCard {
        SettingsRow(
          icon: "wave.3.right",
          title: String(localized: "Zie wie er gelocked is in je lokaal"),
          subtitle: String(
            localized:
              "Tik op Home op de steen van het lokaal waar je lesgeeft. Of houd de steen op Home ingedrukt en kies het lokaal."
          ),
          showsChevron: false
        )
        SettingsRow(
          icon: "key",
          title: String(localized: "Herstelcode"),
          subtitle: String(localized: "Voor een leerling wiens telefoon op slot blijft"),
          action: { showRecoveryCode = true }
        )
      }
      // Teachers are removed by a NOTIS admin.
      signOutCard(String(localized: "Docent: \(teacher.email ?? "")"))
    case .parent:
      childrenCard
      signOutCard(String(localized: "Ouder: \(teacher.email ?? "")"), canDelete: true)
    case .admin:
      // NOTIS admins (hidden login): prepare stones, then link the school stones.
      SettingsCard {
        if FeatureFlags.sealedStones {
          SettingsRow(
            icon: "checkmark.seal",
            title: String(localized: "Stenen voorbereiden"),
            subtitle: String(localized: "Nieuwe stenen verzegelen bij de productie, zodat alleen NOTIS-stenen werken"),
            action: { showStonePrepare = true }
          )
        }
        SettingsRow(
          icon: "wave.3.right",
          title: String(localized: "Stenen koppelen"),
          subtitle: String(localized: "De stenen van een school koppelen, lokaal na lokaal"),
          action: { showStoneLink = true }
        )
      }
      signOutCard(String(localized: "NOTIS-beheerder: \(teacher.email ?? "")"))
    }
  }

  /// Signing out; teachers and parents can also delete their account (the stores require it).
  /// NOTIS admins are removed by hand.
  private func signOutCard(_ subtitle: String, canDelete: Bool = false) -> some View {
    SettingsCard {
      SettingsRow(
        icon: "rectangle.portrait.and.arrow.right",
        title: String(localized: "Uitloggen"),
        subtitle: subtitle,
        showsChevron: false,
        action: { Task { await teacher.signOut() } }
      )
      if canDelete && FeatureFlags.separateAccountDelete {
        SettingsRow(
          icon: "trash",
          title: String(localized: "Account verwijderen"),
          subtitle: String(localized: "Verwijdert \(teacher.email ?? "") en alles wat eraan gekoppeld is"),
          action: { showDeleteAccount = true }
        )
      }
    }
  }

  /// The parent's children with their live status, and adding a child with its link code.
  private var childrenCard: some View {
    SettingsCard {
      ForEach(children) { child in
        if let unlinkedAt = child.unlinkedAt {
          SettingsRow(
            icon: "link",
            iconColor: NotisBrand.inkSoft,
            title: child.name,
            subtitle: String(
              localized: "Ontkoppeld door je kind op \(unlinkedAt.formatted(date: .abbreviated, time: .shortened))"
            ),
            showsChevron: false,
            onRemove: { removingChild = child }
          )
        } else if let visual = ChildStatusVisual(child: child, now: Date()) {
          SettingsRow(
            icon: visual.icon,
            iconColor: visual.tint,
            title: child.name,
            subtitle: visual.subtitle,
            action: FeatureFlags.allowList ? { childApps = child } : nil,
            onRemove: { removingChild = child }
          )
        } else {
          SettingsRow(
            icon: "figure.and.child.holdinghands",
            title: child.name,
            subtitle: String(localized: "Gekoppeld · wacht op de eerste status"),
            action: FeatureFlags.allowList ? { childApps = child } : nil,
            onRemove: { removingChild = child }
          )
        }
      }
      SettingsRow(
        icon: "person.badge.plus",
        title: String(localized: "Kind toevoegen"),
        subtitle: children.isEmpty ? String(localized: "Koppel met de telefoon van je kind via een code") : nil,
        action: { showAddChild = true }
      )
    }
  }

  private func openPermissions() {
    if isAuthorized {
      if let url = URL(string: UIApplication.openSettingsURLString) {
        openURL(url)
      }
    } else {
      requestAuthorizer.requestAuthorization()
    }
  }
}

/// The session notification: on iOS, a Live Activity on the lock screen.
enum NotisNotifications {
  static let key = "notisNotificationsEnabled"

  static var isEnabled: Bool {
    UserDefaults.standard.object(forKey: key) as? Bool ?? true
  }

  static func apply(_ isOn: Bool, context: ModelContext, strategyManager: StrategyManager) {
    for stone in BlockedProfiles.fetchNotisProfiles(in: context) {
      stone.enableLiveActivity = isOn
      BlockedProfiles.updateSnapshot(for: stone)
    }
    try? context.save()

    if isOn, let session = strategyManager.activeSession {
      LiveActivityManager.shared.startSessionActivity(session: session)
    } else if !isOn {
      LiveActivityManager.shared.endSessionActivity()
    }
  }
}

private struct SettingsIcon: View {
  let systemName: String
  var color: Color = NotisBrand.mandarinDark

  var body: some View {
    Image(systemName: systemName)
      .font(.system(size: 18))
      .foregroundStyle(color)
      .frame(width: 40, height: 40)
      .background(color.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))
  }
}

private struct SettingsCard<Content: View>: View {
  @ViewBuilder let content: Content

  var body: some View {
    VStack(spacing: 0) {
      content
    }
    .notisCard()
  }
}

/// Android's `SettingsRow`.
private struct SettingsRow: View {
  let icon: String
  var iconColor: Color = NotisBrand.mandarinDark
  let title: String
  var titleColor: Color = NotisBrand.ink
  var subtitle: String? = nil
  var subtitleColor: Color = NotisBrand.inkSoft
  var trailingSystemImage: String? = nil
  var showsChevron = true
  var action: (() -> Void)? = nil
  /// A small cross at the end, as on Android (unlink a parent, remove a child).
  var onRemove: (() -> Void)? = nil

  var body: some View {
    if let action {
      Button(action: action) { row }
        .buttonStyle(.plain)
    } else {
      row
    }
  }

  private var row: some View {
    HStack(spacing: 12) {
      SettingsIcon(systemName: icon, color: iconColor)
      VStack(alignment: .leading, spacing: 1) {
        Text(title)
          .font(.satoshi(16, .bold))
          .foregroundStyle(titleColor)
        if let subtitle {
          Text(subtitle)
            .font(.satoshi(13))
            .foregroundStyle(subtitleColor)
        }
      }
      Spacer(minLength: 0)
      if let onRemove {
        Button(action: onRemove) {
          Image(systemName: "xmark")
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(NotisBrand.inkSoft)
            .frame(width: 36, height: 36)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Verwijderen")
      } else if let trailingSystemImage {
        Image(systemName: trailingSystemImage)
          .font(.system(size: 14))
          .foregroundStyle(NotisBrand.inkSoft)
      } else if action != nil && showsChevron {
        Image(systemName: "chevron.right")
          .font(.system(size: 13, weight: .semibold))
          .foregroundStyle(NotisBrand.inkSoft)
      }
    }
    .padding(.horizontal, 16)
    .padding(.vertical, 10)
    .frame(minHeight: 62)
    .contentShape(Rectangle())
  }
}

#Preview {
  NotisSettingsView()
    .environmentObject(RequestAuthorizer())
    .environmentObject(StrategyManager())
}
