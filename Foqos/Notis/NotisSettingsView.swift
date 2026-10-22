import FamilyControls
import SwiftUI

/// Minimal settings: permissions, emergency unlocks and app info. School and parent sections
/// only show when their feature flag is on.
struct NotisSettingsView: View {
  @Environment(\.dismiss) private var dismiss

  @EnvironmentObject private var requestAuthorizer: RequestAuthorizer
  @EnvironmentObject private var strategyManager: StrategyManager

  private var appVersion: String {
    let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?"
    let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "?"
    return "\(version) (\(build))"
  }

  var body: some View {
    NavigationStack {
      Form {
        Section("Toestemming") {
          HStack {
            Label("Schermtijd", systemImage: "hourglass")
            Spacer()
            if requestAuthorizer.isAuthorized {
              Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
                .accessibilityLabel("Toegestaan")
            } else {
              Button("Toegang geven") {
                requestAuthorizer.requestAuthorization()
              }
            }
          }
        }

        if FeatureFlags.emergencyUnlock {
          Section {
            LabeledContent("Per sessie", value: "\(NotisEmergencyUnlock.maxPerSession)×")
            LabeledContent("Duur", value: "\(NotisEmergencyUnlock.durationInMinutes) min")
            if strategyManager.isBlocking {
              LabeledContent("Nog over deze sessie", value: "\(NotisEmergencyUnlock.remaining)")
            }
          } header: {
            Text("Noodontgrendeling")
          } footer: {
            Text(
              "Houd tijdens een sessie de steen op het beginscherm lang ingedrukt. Je krijgt dan even toegang tot je apps; daarna gaat alles vanzelf weer op slot."
            )
          }
        }

        if FeatureFlags.schoolLive {
          Section("School") {
            Text("Klas koppelen komt in een volgende testversie.")
              .foregroundStyle(.secondary)
          }
        }

        if FeatureFlags.parentControls {
          Section("Ouders") {
            Text("Ouderinstellingen komen in een volgende testversie.")
              .foregroundStyle(.secondary)
          }
        }

        Section("Over NOTIS") {
          LabeledContent("Versie", value: appVersion)
          Link("Privacy", destination: URL(string: "https://notisapp.nl/privacy.html")!)
        }
      }
      .scrollContentBackground(.hidden)
      .background(NotisTheme.paper)
      .navigationTitle("Instellingen")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .topBarTrailing) {
          Button("Klaar") { dismiss() }
        }
      }
      .tint(NotisTheme.ink)
    }
    .onAppear {
      requestAuthorizer.refreshAuthorizationStatus()
    }
  }
}

#Preview {
  NotisSettingsView()
    .environmentObject(RequestAuthorizer())
    .environmentObject(StrategyManager())
}
