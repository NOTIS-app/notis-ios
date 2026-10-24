import SwiftData
import SwiftUI

/// NOTIS home, laid out like Android's `HomeScreen`: the stone, a big status word (VRIJ / OP SLOT
/// / PAUZE) and, while locked, the emergency button at the bottom. On iOS a tap on the stone is
/// also what opens the NFC sheet: apps can't read tags in the background here.
struct NotisHomeView: View {
  @Environment(\.modelContext) private var context
  @Environment(\.scenePhase) private var scenePhase

  @EnvironmentObject private var requestAuthorizer: RequestAuthorizer
  @EnvironmentObject private var strategyManager: StrategyManager

  /// No stone yet: the stone tap goes to "Mijn NOTIS" to pair one.
  var onPairFirstStone: () -> Void = {}

  @Query(sort: [
    SortDescriptor(\BlockedProfiles.order, order: .forward),
    SortDescriptor(\BlockedProfiles.createdAt, order: .forward),
  ]) private var profiles: [BlockedProfiles]

  @State private var showScanHint = false
  @State private var showEmergencySheet = false
  @State private var showLockFromAppSheet = false
  /// A long press also ends in the button's tap; this swallows that tap.
  @State private var didLongPressStone = false
  /// Set while the lock that just started can still be cancelled without a stone.
  @State private var graceEndsAt: Date?
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

  private var isGracePeriod: Bool {
    isLocked && !isEmergencyActive && graceEndsAt != nil
  }

  /// Locked with a stone: the dark ink screen, as on Android.
  private var isInkLocked: Bool {
    isLocked && !isEmergencyActive
  }

  private var palette: NotisPalette {
    isInkLocked ? .ink : .light
  }

  private var background: Color {
    if isInkLocked { return NotisBrand.ink }
    if isEmergencyActive { return NotisPalette.light.surfaceContainerHigh }
    return NotisBrand.paper
  }

  var body: some View {
    ZStack {
      background.ignoresSafeArea()

      ScrollView {
        VStack(spacing: 0) {
          Button(action: stoneTapped) {
            NotisStoneView(isLocked: isLocked, showScanHint: showScanHint)
          }
          .buttonStyle(StonePressStyle())
          .simultaneousGesture(
            LongPressGesture(minimumDuration: 0.5).onEnded { _ in stoneLongPressed() }
          )
          .accessibilityLabel(isLocked ? "Ontgrendel met je NOTIS" : "Vergrendel met je NOTIS")
          .accessibilityAction(named: "Kies een steen") { stoneLongPressed() }

          Spacer().frame(height: 32)

          status
        }
        .padding(.horizontal, 32)
        .padding(.vertical, 16)
        .frame(maxWidth: .infinity)
        .containerRelativeFrame(.vertical, alignment: .center)
      }
      .scrollBounceBehavior(.basedOnSize)

      if isGracePeriod, let endsAt = graceEndsAt {
        VStack {
          Spacer()
          NotisGraceButton(endsAt: endsAt, palette: palette) {
            graceEndsAt = nil
            strategyManager.cancelNotisSessionInGracePeriod(context: context)
          }
          .padding(.bottom, 48)
        }
      } else if isInkLocked && FeatureFlags.emergencyUnlock && emergencyRemaining > 0 {
        VStack {
          Spacer()
          NotisEmergencyButton(remaining: emergencyRemaining, palette: palette) {
            showEmergencySheet = true
          }
          .padding(.bottom, 48)
        }
      }
    }
    .animation(.easeInOut(duration: 0.6), value: isInkLocked)
    .animation(.easeInOut(duration: 0.4), value: isEmergencyActive)
    .sheet(isPresented: $showEmergencySheet) {
      NotisEmergencySheet(
        remaining: emergencyRemaining,
        minutes: NotisEmergencyUnlock.durationInMinutes,
        onConfirm: {
          showEmergencySheet = false
          startEmergencyUnlock()
        },
        onCancel: { showEmergencySheet = false }
      )
      .presentationDetents([.height(380)])
      .presentationBackground(NotisBrand.paper)
    }
    .sheet(isPresented: $showLockFromAppSheet) {
      NotisLockFromAppSheet(stones: stones) { stone in
        showLockFromAppSheet = false
        strategyManager.startNotisStoneWithoutScan(context: context, stone: stone)
      }
      .presentationDetents([.medium, .large])
      .presentationBackground(NotisBrand.paper)
    }
    .alert(
      errorMessage ?? "",
      isPresented: Binding(
        get: { errorMessage != nil },
        set: { if !$0 { dismissError() } }
      )
    ) {
      Button("Oké", role: .cancel) { dismissError() }
    }
    .onReceive(strategyManager.$errorMessage) { message in
      errorMessage = message
    }
    .onChange(of: scenePhase) { _, newPhase in
      if newPhase == .active {
        refresh()
      }
    }
    .onChange(of: isLocked) { _, _ in
      showScanHint = false
    }
    .task(id: showScanHint) {
      // The hint fades out by itself, as on Android.
      guard showScanHint else { return }
      try? await Task.sleep(for: .seconds(6))
      if !Task.isCancelled { showScanHint = false }
    }
    .task(id: emergencyEndsAt) {
      // When the emergency minutes are up the DeviceMonitor extension relocks; follow it here.
      guard emergencyEndsAt > 0 else { return }
      let remaining = emergencyEndDate.timeIntervalSinceNow
      if remaining > 0 {
        try? await Task.sleep(for: .seconds(remaining + 1))
        guard !Task.isCancelled else { return }
      }
      NotisEmergencyUnlock.clear()
      refresh()
    }
    .task(id: strategyManager.activeSession?.startTime) {
      // Android's grace period: the cancel button replaces the emergency one until it runs out.
      guard let start = strategyManager.activeSession?.startTime else {
        graceEndsAt = nil
        return
      }
      let endsAt = NotisGracePeriod.endDate(forSessionStartedAt: start)
      guard endsAt > Date() else {
        graceEndsAt = nil
        return
      }
      graceEndsAt = endsAt
      try? await Task.sleep(for: .seconds(endsAt.timeIntervalSinceNow))
      if !Task.isCancelled { graceEndsAt = nil }
    }
    .onAppear(perform: refresh)
  }

  // MARK: - Status

  @ViewBuilder
  private var status: some View {
    VStack(spacing: 0) {
      if !isLocked && !isAuthorized {
        NotisPermissionsCard {
          requestAuthorizer.requestAuthorization()
        }
      } else {
        Text(statusWord)
          .font(.satoshi(44, .bold))
          .tracking(-1)
          .foregroundStyle(palette.onSurface)
          .multilineTextAlignment(.center)

        if isInkLocked, let name = strategyManager.activeSession?.blockedProfile.name {
          Text("met \(name)")
            .font(.satoshi(18, .medium))
            .foregroundStyle(palette.primary)
            .multilineTextAlignment(.center)
            .padding(.top, 8)
        }

        Spacer().frame(height: 16)

        if isEmergencyActive {
          TimelineView(.periodic(from: .now, by: 1)) { timeline in
            Text("Terug over \(Self.minutesSeconds(emergencyEndDate.timeIntervalSince(timeline.date)))")
              .font(.satoshi(24, .regular))
              .foregroundStyle(palette.onSurface)
          }
          Spacer().frame(height: 24)
          Button("Blokkeren hervatten", action: resumeBlocking)
            .buttonStyle(NotisTonalButtonStyle())
        } else if isLocked, let start = strategyManager.activeSession?.startTime {
          TimelineView(.periodic(from: .now, by: 1)) { timeline in
            Text(Self.elapsed(timeline.date.timeIntervalSince(start)))
              .font(.satoshi(36, .light))
              .monospacedDigit()
              .foregroundStyle(palette.onSurface.opacity(0.7))
          }
          Text(showScanHint ? "Houd de bovenkant van je iPhone tegen je NOTIS" : "Tik op de steen om te ontgrendelen")
            .font(.satoshi(14, showScanHint ? .medium : .regular))
            .foregroundStyle(showScanHint ? palette.primary : palette.onSurfaceVariant.opacity(0.6))
            .multilineTextAlignment(.center)
            .padding(.top, 16)
        } else {
          Text(freeHint)
            .font(.satoshi(14, showScanHint ? .medium : .regular))
            .foregroundStyle(showScanHint ? palette.primary : palette.onSurfaceVariant.opacity(0.6))
            .multilineTextAlignment(.center)
          if canChooseStone && !stones.isEmpty && !showScanHint {
            Text("Of houd de steen ingedrukt om er een te kiezen")
              .font(.satoshi(14))
              .foregroundStyle(palette.onSurfaceVariant.opacity(0.6))
              .multilineTextAlignment(.center)
              .padding(.top, 4)
          }
        }
      }
    }
    .padding(.bottom, isInkLocked ? 140 : 104)
  }

  private var statusWord: String {
    if isEmergencyActive { return String(localized: "PAUZE") }
    if isLocked { return String(localized: "OP SLOT") }
    return String(localized: "VRIJ")
  }

  /// Press and hold the free stone to pick the stone to lock with (Android: same gesture). With no
  /// stone yet the sheet says to pair one.
  private var canChooseStone: Bool {
    FeatureFlags.lockFromApp && !isLocked && isAuthorized
  }

  private var freeHint: String {
    if showScanHint { return String(localized: "Houd de bovenkant van je iPhone tegen je NOTIS") }
    if stones.isEmpty { return String(localized: "Koppel je NOTIS om te kunnen blokkeren") }
    return String(localized: "Tik op de steen en houd je iPhone ertegen")
  }

  static func elapsed(_ interval: TimeInterval) -> String {
    let total = max(0, Int(interval))
    let hours = total / 3600
    let mmss = String(format: "%02d:%02d", (total % 3600) / 60, total % 60)
    return hours > 0 ? "\(hours)h \(mmss)" : mmss
  }

  static func minutesSeconds(_ interval: TimeInterval) -> String {
    let total = max(0, Int(interval.rounded(.up)))
    return String(format: "%d:%02d", total / 60, total % 60)
  }

  // MARK: - Actions

  private func stoneLongPressed() {
    guard canChooseStone else { return }
    didLongPressStone = true
    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    showLockFromAppSheet = true
  }

  private func stoneTapped() {
    if didLongPressStone {
      didLongPressStone = false
      return
    }
    if isLocked {
      // Also during the emergency pause: a scan ends the whole session, like Android.
      showScanHint = true
      strategyManager.toggleBlocking(context: context, activeProfile: nil)
      return
    }

    guard isAuthorized else {
      requestAuthorizer.requestAuthorization()
      return
    }

    guard let anyStone = stones.first else {
      onPairFirstStone()
      return
    }

    showScanHint = true
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

/// The stone shrinks a little while pressed (Android: 0.96, 160 ms).
private struct StonePressStyle: ButtonStyle {
  func makeBody(configuration: Configuration) -> some View {
    configuration.label
      .scaleEffect(configuration.isPressed ? 0.96 : 1)
      .animation(.easeOut(duration: 0.16), value: configuration.isPressed)
  }
}

/// Android's `PermissionsSetupCard`: replaces the status while NOTIS may not block yet.
struct NotisPermissionsCard: View {
  let onSetUp: () -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      HStack(spacing: 12) {
        Image(systemName: "checkmark.shield")
          .font(.system(size: 18, weight: .medium))
          .foregroundStyle(NotisBrand.mandarinDark)
          .frame(width: 40, height: 40)
          .background(NotisBrand.mandarinDark.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))
        VStack(alignment: .leading, spacing: 2) {
          Text("Toestemmingen aanzetten")
            .font(.satoshi(16, .bold))
            .foregroundStyle(NotisBrand.ink)
          Text("Nodig om NOTIS te laten werken")
            .font(.satoshi(13))
            .foregroundStyle(NotisBrand.inkSoft)
        }
      }
      Button("Instellen", action: onSetUp)
        .buttonStyle(NotisPrimaryButtonStyle())
    }
    .padding(16)
    .notisCard(radius: 16)
  }
}

#Preview {
  NotisHomeView()
    .environmentObject(RequestAuthorizer())
    .environmentObject(StrategyManager())
    .defaultAppStorage(UserDefaults(suiteName: "preview")!)
}
