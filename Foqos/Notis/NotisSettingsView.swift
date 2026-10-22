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

          if FeatureFlags.schoolLive || FeatureFlags.parentControls {
            Text("KLAS & OUDERS")
              .font(.satoshi(12, .bold))
              .tracking(1)
              .foregroundStyle(NotisBrand.inkSoft)
              .padding(.top, 4)
            SettingsCard {
              if FeatureFlags.schoolLive {
                SettingsRow(
                  icon: "person.3",
                  title: String(localized: "Aansluiten bij een klas"),
                  subtitle: String(localized: "Komt in een volgende testversie")
                )
              }
              if FeatureFlags.parentControls {
                SettingsRow(
                  icon: "figure.and.child.holdinghands",
                  title: String(localized: "Ouder koppelen"),
                  subtitle: String(localized: "Komt in een volgende testversie")
                )
              }
            }
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
          }

          // "Over NOTIS" stands on its own, without a card, as on Android.
          SettingsRow(
            icon: "info.circle",
            title: String(localized: "Over NOTIS"),
            subtitle: appVersion,
            showsChevron: false
          )
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 104)
      }
    }
    .onAppear {
      requestAuthorizer.refreshAuthorizationStatus()
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
    for stone in BlockedProfiles.fetchNotisStones(in: context) {
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

  var body: some View {
    Image(systemName: systemName)
      .font(.system(size: 18))
      .foregroundStyle(NotisBrand.mandarinDark)
      .frame(width: 40, height: 40)
      .background(NotisBrand.mandarinDark.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))
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
  let title: String
  var subtitle: String? = nil
  var subtitleColor: Color = NotisBrand.inkSoft
  var trailingSystemImage: String? = nil
  var showsChevron = true
  var action: (() -> Void)? = nil

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
      SettingsIcon(systemName: icon)
      VStack(alignment: .leading, spacing: 1) {
        Text(title)
          .font(.satoshi(16, .bold))
          .foregroundStyle(NotisBrand.ink)
        if let subtitle {
          Text(subtitle)
            .font(.satoshi(13))
            .foregroundStyle(subtitleColor)
        }
      }
      Spacer(minLength: 0)
      if let trailingSystemImage {
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
