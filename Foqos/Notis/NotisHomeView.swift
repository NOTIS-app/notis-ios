import FamilyControls
import SwiftData
import SwiftUI

/// NOTIS home: one big stone button. Tapping it opens the iPhone NFC sheet; holding the phone to
/// a paired stone locks, holding it to any paired stone again unlocks.
struct NotisHomeView: View {
  @Environment(\.modelContext) private var context
  @Environment(\.scenePhase) private var scenePhase

  @EnvironmentObject private var requestAuthorizer: RequestAuthorizer
  @EnvironmentObject private var strategyManager: StrategyManager

  @Query(sort: [
    SortDescriptor(\BlockedProfiles.order, order: .forward),
    SortDescriptor(\BlockedProfiles.createdAt, order: .forward),
  ]) private var profiles: [BlockedProfiles]

  @State private var showMijnNotis = false
  @State private var showSettings = false
  @State private var showEmergencyConfirm = false
  @State private var didLongPress = false
  @State private var errorMessage: String?

  private var stones: [BlockedProfiles] {
    profiles.filter(\.isNotisStone)
  }

  private var isLocked: Bool {
    strategyManager.isBlocking
  }

  private var isAuthorized: Bool {
    requestAuthorizer.isAuthorized
  }

  var body: some View {
    NavigationStack {
      ZStack {
        (isLocked ? NotisTheme.ink : NotisTheme.paper).ignoresSafeArea()

        VStack(spacing: 28) {
          Spacer()

          if !isAuthorized {
            permissionCard
          }

          stoneButton

          statusText

          Spacer()
        }
        .padding(.horizontal, 24)
      }
      .animation(.easeInOut(duration: 0.3), value: isLocked)
      .toolbar {
        ToolbarItem(placement: .topBarLeading) {
          Text("NOTIS")
            .font(.system(.title3, design: .rounded).weight(.bold))
            .foregroundStyle(isLocked ? NotisTheme.paper : NotisTheme.ink)
        }
        ToolbarItemGroup(placement: .topBarTrailing) {
          Button {
            showMijnNotis = true
          } label: {
            Image(systemName: "circle.hexagongrid")
          }
          .accessibilityLabel("Mijn NOTIS")

          Button {
            showSettings = true
          } label: {
            Image(systemName: "gearshape")
          }
          .accessibilityLabel("Instellingen")
        }
      }
      .tint(isLocked ? NotisTheme.mandarin : NotisTheme.ink)
      .sheet(isPresented: $showMijnNotis) {
        MijnNotisView()
      }
      .sheet(isPresented: $showSettings) {
        NotisSettingsView()
      }
      .confirmationDialog(
        "Noodontgrendeling",
        isPresented: $showEmergencyConfirm,
        titleVisibility: .visible
      ) {
        Button("Ontgrendel zonder steen", role: .destructive) {
          strategyManager.emergencyUnblock(context: context)
        }
        Button("Annuleer", role: .cancel) {}
      } message: {
        Text("Je hebt er nog \(strategyManager.getRemainingEmergencyUnblocks()) over.")
      }
      .alert(
        "Dat lukte niet",
        isPresented: Binding(
          get: { errorMessage != nil },
          set: { if !$0 { dismissError() } }
        )
      ) {
        Button("OK", role: .cancel) { dismissError() }
      } message: {
        Text(errorMessage ?? "")
      }
    }
    .onReceive(strategyManager.$errorMessage) { message in
      errorMessage = message
    }
    .onChange(of: scenePhase) { _, newPhase in
      if newPhase == .active {
        refresh()
      }
    }
    .onAppear {
      strategyManager.checkAndResetEmergencyUnblocks()
      refresh()
    }
  }

  private var stoneButton: some View {
    Button(action: stoneTapped) {
      ZStack {
        NotisStoneShape()
          .fill(isLocked ? NotisTheme.mandarin : NotisTheme.card)
          .shadow(color: .black.opacity(isLocked ? 0.35 : 0.12), radius: 18, y: 10)

        NotisStoneShape()
          .strokeBorder(isLocked ? NotisTheme.paper.opacity(0.4) : NotisTheme.mandarin, lineWidth: 3)

        Image(systemName: isLocked ? "lock.fill" : "wave.3.right")
          .font(.system(size: 48, weight: .semibold))
          .foregroundStyle(NotisTheme.ink)
          .offset(y: 12)
      }
      .frame(width: 260, height: 220)
      .contentShape(NotisStoneShape())
    }
    .buttonStyle(.plain)
    .simultaneousGesture(
      LongPressGesture(minimumDuration: 1.2).onEnded { _ in
        guard isLocked, FeatureFlags.emergencyUnlock,
          strategyManager.getRemainingEmergencyUnblocks() > 0
        else { return }
        // The button still fires on release; this keeps that tap from opening the NFC sheet.
        didLongPress = true
        showEmergencyConfirm = true
      }
    )
    .accessibilityLabel(isLocked ? "Ontgrendel met je steen" : "Vergrendel met je steen")
  }

  @ViewBuilder
  private var statusText: some View {
    VStack(spacing: 8) {
      if isLocked, let session = strategyManager.activeSession {
        Text("Vergrendeld met \(session.blockedProfile.name)")
          .font(.title3.weight(.semibold))
          .foregroundStyle(NotisTheme.paper)
        Text(session.startTime, style: .timer)
          .font(.system(.title, design: .rounded).monospacedDigit())
          .foregroundStyle(NotisTheme.mandarin)
        Text("Tik en houd je iPhone bij een steen om te ontgrendelen.")
          .font(.subheadline)
          .foregroundStyle(NotisTheme.paper.opacity(0.75))
      } else if stones.isEmpty {
        Text("Nog geen steen gekoppeld")
          .font(.title3.weight(.semibold))
          .foregroundStyle(NotisTheme.ink)
        Text("Tik op de steen om je eerste NOTIS te koppelen.")
          .font(.subheadline)
          .foregroundStyle(NotisTheme.ink.opacity(0.7))
      } else {
        Text("Tik en houd je iPhone bij NOTIS")
          .font(.title3.weight(.semibold))
          .foregroundStyle(NotisTheme.ink)
        Text("Je apps gaan op slot tot je weer scant.")
          .font(.subheadline)
          .foregroundStyle(NotisTheme.ink.opacity(0.7))
      }
    }
    .multilineTextAlignment(.center)
  }

  private var permissionCard: some View {
    VStack(alignment: .leading, spacing: 10) {
      Text("Geef NOTIS toegang tot Schermtijd")
        .font(.headline)
      Text("Zonder deze toestemming kan NOTIS geen apps op slot zetten.")
        .font(.subheadline)
        .foregroundStyle(NotisTheme.ink.opacity(0.7))
      Button("Toegang geven") {
        requestAuthorizer.requestAuthorization()
      }
      .buttonStyle(.borderedProminent)
      .tint(NotisTheme.mandarin)
      .foregroundStyle(NotisTheme.ink)
    }
    .padding(18)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(NotisTheme.card, in: RoundedRectangle(cornerRadius: 18))
    .foregroundStyle(NotisTheme.ink)
  }

  private func stoneTapped() {
    if didLongPress {
      didLongPress = false
      return
    }

    if isLocked {
      strategyManager.toggleBlocking(context: context, activeProfile: nil)
      return
    }

    guard isAuthorized else {
      requestAuthorizer.requestAuthorization()
      return
    }

    guard let anyStone = stones.first else {
      showMijnNotis = true
      return
    }

    // The scanned stone picks its own app list; `anyStone` only routes to the NOTIS strategy.
    strategyManager.toggleBlocking(context: context, activeProfile: anyStone)
  }

  private func refresh() {
    requestAuthorizer.refreshAuthorizationStatus()
    strategyManager.loadActiveSession(context: context)
  }

  private func dismissError() {
    errorMessage = nil
    strategyManager.errorMessage = nil
  }
}

#Preview {
  NotisHomeView()
    .environmentObject(RequestAuthorizer())
    .environmentObject(StrategyManager())
    .environmentObject(ThemeManager())
    .defaultAppStorage(UserDefaults(suiteName: "preview")!)
}
