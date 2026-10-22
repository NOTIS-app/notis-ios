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

  @AppStorage(NotisEmergencyUnlock.endsAtKey) private var emergencyEndsAt: Double = 0
  @AppStorage(NotisEmergencyUnlock.remainingKey) private var emergencyRemaining: Int =
    NotisEmergencyUnlock.maxPerSession

  private var stones: [BlockedProfiles] {
    profiles.filter(\.isNotisStone)
  }

  private var isLocked: Bool {
    strategyManager.isBlocking
  }

  private var isAuthorized: Bool {
    // Screen Time can't be authorized in the simulator; let the UI be explored there anyway.
    requestAuthorizer.isAuthorized || NotisDevice.isSimulator
  }

  private var emergencyEndDate: Date {
    Date(timeIntervalSince1970: emergencyEndsAt)
  }

  private var isEmergencyActive: Bool {
    isLocked && emergencyEndDate > Date()
  }

  /// Dark ink only while apps are really blocked; an emergency unlock looks neutral, as on Android.
  private var isDark: Bool {
    isLocked && !isEmergencyActive
  }

  var body: some View {
    NavigationStack {
      ZStack {
        (isDark ? NotisTheme.ink : NotisTheme.paper).ignoresSafeArea()

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
      .animation(.easeInOut(duration: 0.3), value: isDark)
      .toolbar {
        ToolbarItem(placement: .topBarLeading) {
          Text("NOTIS")
            .font(.system(.title3, design: .rounded).weight(.bold))
            .foregroundStyle(isDark ? NotisTheme.paper : NotisTheme.ink)
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
      .tint(isDark ? NotisTheme.mandarin : NotisTheme.ink)
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
        Button("Ontgrendelen bevestigen", role: .destructive, action: startEmergencyUnlock)
        Button("Annuleer", role: .cancel) {}
      } message: {
        Text(
          "Je krijgt \(NotisEmergencyUnlock.durationInMinutes) minuten toegang tot je apps. Daarna gaat alles weer op slot. Nog \(emergencyRemaining) over deze sessie."
        )
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
      refresh()
    }
    .task(id: emergencyEndsAt) {
      // When the emergency minutes are up the DeviceMonitor extension relocks; follow it here.
      let remaining = emergencyEndDate.timeIntervalSinceNow
      guard emergencyEndsAt > 0 else { return }
      if remaining > 0 {
        try? await Task.sleep(for: .seconds(remaining + 1))
        guard !Task.isCancelled else { return }
      }
      NotisEmergencyUnlock.clear()
      refresh()
    }
  }

  private var stoneButton: some View {
    Button(action: stoneTapped) {
      ZStack {
        NotisStoneShape()
          .fill(isDark ? NotisTheme.mandarin : NotisTheme.card)
          .shadow(color: .black.opacity(isDark ? 0.35 : 0.12), radius: 18, y: 10)

        NotisStoneShape()
          .strokeBorder(isDark ? NotisTheme.paper.opacity(0.4) : NotisTheme.mandarin, lineWidth: 3)

        Image(systemName: isEmergencyActive ? "lock.open" : isLocked ? "lock.fill" : "wave.3.right")
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
        guard isLocked, !isEmergencyActive, FeatureFlags.emergencyUnlock, emergencyRemaining > 0
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
      if isEmergencyActive {
        Text("Terug over")
          .font(.title3.weight(.semibold))
          .foregroundStyle(NotisTheme.ink)
        Text(emergencyEndDate, style: .timer)
          .font(.system(.title, design: .rounded).monospacedDigit())
          .foregroundStyle(NotisTheme.mandarin)
        Button("Blokkeren hervatten", action: resumeBlocking)
          .buttonStyle(.bordered)
          .tint(NotisTheme.ink)
          .padding(.top, 8)
      } else if isLocked, let session = strategyManager.activeSession {
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

  private func startEmergencyUnlock() {
    guard let session = strategyManager.activeSession else { return }
    do {
      try NotisEmergencyUnlock.start(session: session, context: context)
    } catch {
      errorMessage = String(localized: "Noodontgrendeling lukte niet: \(error.localizedDescription)")
    }
    // The extension starts the pause a moment later; reload so the session reflects it.
    Task {
      try? await Task.sleep(for: .seconds(2))
      refresh()
    }
  }

  private func resumeBlocking() {
    guard let session = strategyManager.activeSession else { return }
    NotisEmergencyUnlock.resume(session: session, context: context)
    refresh()
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
