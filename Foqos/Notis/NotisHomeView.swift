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
  /// Rooms: the school this phone joined, and a stone of a school to join.
  @ObservedObject private var school = NotisSchool.shared

  /// No stone yet: the stone tap goes to "Mijn NOTIS" to pair one.
  var onPairFirstStone: () -> Void = {}

  @Query(sort: [
    SortDescriptor(\BlockedProfiles.order, order: .forward),
    SortDescriptor(\BlockedProfiles.createdAt, order: .forward),
  ]) private var profiles: [BlockedProfiles]

  @State private var showScanHint = false
  @State private var showEmergencySheet = false
  @State private var showLockFromAppSheet = false
  @State private var showSchoolApps = false
  @State private var showRecoveryCode = false
  @State private var showTeacherRooms = false
  @State private var teacherScanner = NFCScannerUtil()
  @ObservedObject private var teacher = NotisTeacher.shared
  /// A long press also ends in the button's tap; this swallows that tap.
  @State private var didLongPressStone = false
  /// Set while the lock that just started can still be cancelled without a stone.
  @State private var graceEndsAt: Date?
  @State private var errorMessage: String?

  @AppStorage(NotisEmergencyUnlock.endsAtKey) private var emergencyEndsAt: Double = 0
  @AppStorage(NotisEmergencyUnlock.remainingKey) private var emergencyRemaining: Int =
    NotisEmergencyUnlock.maxPerSession

  /// The profiles with at least one stone (without `FeatureFlags.stoneProfiles`: the stones).
  private var stones: [BlockedProfiles] {
    profiles.filter(\.isNotisStone)
  }

  /// Can a stone end a lock? With `FeatureFlags.anyNotisStone` every NOTIS stone can.
  private var canUnlock: Bool {
    FeatureFlags.anyNotisStone || !stones.isEmpty
  }

  /// What the long-press offers: the profiles (you need a stone to unlock), or the stones.
  private var lockChoices: [BlockedProfiles] {
    guard FeatureFlags.stoneProfiles else { return stones }
    // Lock by hand with the profile picked on Home; you need a stone to unlock.
    if FeatureFlags.homeProfilePicker {
      return canUnlock ? [selectedProfile].compactMap { $0 } : []
    }
    return stones.isEmpty ? [] : profiles.filter(\.isNotisProfile)
  }

  private var isLocked: Bool {
    strategyManager.isBlocking
  }

  /// `FeatureFlags.homeProfilePicker`: the profile every stone locks with.
  @AppStorage(BlockedProfiles.selectedNotisProfileKey) private var selectedProfileId = ""

  private var notisProfiles: [BlockedProfiles] {
    profiles.filter(\.isNotisProfile)
  }

  private var selectedProfile: BlockedProfiles? {
    notisProfiles.first { $0.id.uuidString == selectedProfileId } ?? notisProfiles.first
  }

  private var isSchoolLocked: Bool {
    strategyManager.activeSession?.blockedProfile.isNotisSchoolProfile == true
  }

  /// "met <steen>", or the room a school lock is checked in to.
  /// What the bar at the top says while locked: the school and room, or the profile.
  private var lockedWith: (label: String, name: String, icon: NotisProfileIcon)? {
    if isSchoolLocked {
      let name = [school.school?.name, school.roomName(for: school.currentRoomId)]
        .compactMap { $0 }.joined(separator: " · ")
      return (String(localized: "Op slot door school"), name.isEmpty ? String(localized: "School") : name, .school)
    }
    guard let profile = strategyManager.activeSession?.blockedProfile else { return nil }
    return (String(localized: "Op slot met profiel"), profile.name, profile.notisIcon)
  }

  private var lockingName: String? {
    if isSchoolLocked { return school.roomName(for: school.currentRoomId) }
    return strategyManager.activeSession?.blockedProfile.name
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

      // Locked: what with, in the same place as the profile bar.
      if FeatureFlags.lockedWithBar && isLocked, let locked = lockedWith {
        VStack {
          NotisLockedBar(label: locked.label, name: locked.name, icon: locked.icon, palette: palette)
            .padding(.horizontal, 32)
            .padding(.top, 12)
          Spacer()
        }
      }

      if FeatureFlags.homeProfilePicker && !isLocked && !notisProfiles.isEmpty {
        VStack {
          NotisProfileBar(profiles: notisProfiles, selected: selectedProfile) { profile in
            selectedProfileId = profile.id.uuidString
          }
          .padding(.horizontal, 32)
          .padding(.top, 12)
          Spacer()
        }
      }

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
      NotisLockFromAppSheet(choices: lockChoices) { stone in
        showLockFromAppSheet = false
        strategyManager.startNotisStoneWithoutScan(context: context, stone: stone)
      }
      .presentationDetents([.medium, .large])
      .presentationBackground(NotisBrand.paper)
    }
    .sheet(item: $school.pendingInvite) { invite in
      NotisSchoolJoinSheet(
        schoolName: invite.schoolName,
        initialName: school.displayName,
        onJoin: { name in
          try await school.joinByStone(uid: invite.uid, displayName: name)
          school.pendingInvite = nil
          // The tap that brought up this sheet also locks, in that stone's room.
          if let room = school.roomFor(uid: invite.uid) {
            strategyManager.startNotisSchoolWithoutScan(context: context, room: room)
          }
          // Choosing is open right after joining: offer it once the join sheet has closed.
          Task {
            try? await Task.sleep(for: .milliseconds(700))
            showSchoolApps = true
          }
        },
        onCancel: { school.pendingInvite = nil }
      )
      .presentationDetents([.medium])
      .presentationBackground(NotisBrand.paper)
    }
    .sheet(isPresented: $showTeacherRooms) {
      NotisTeacherRoomsSheet(teacher: teacher) { room in
        showTeacherRooms = false
        Task {
          await teacher.checkIn(room)
          teacher.openRoom = room
        }
      }
      .presentationDetents([.medium, .large])
      .presentationBackground(NotisBrand.paper)
    }
    .fullScreenCover(item: $teacher.openRoom) { room in
      NotisRoomLiveView(room: room, teacher: teacher) { teacher.openRoom = nil }
    }
    .sheet(isPresented: $showRecoveryCode) {
      NotisRecoveryCodeSheet(
        school: school,
        onUnlocked: {
          showRecoveryCode = false
          strategyManager.endNotisSchoolLockWithCode(context: context)
        },
        onCancel: { showRecoveryCode = false }
      )
      .presentationDetents([.medium])
      .presentationBackground(NotisBrand.paper)
    }
    .sheet(isPresented: $showSchoolApps) {
      NotisSchoolAppsSheet(school: school, isSchoolLocked: isSchoolLocked)
        .presentationDetents([.large])
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
        if FeatureFlags.homeLockGlyph && !isEmergencyActive {
          NotisLockGlyph(isLocked: isLocked, color: palette.onSurface)
        } else {
          Text(statusWord)
            .font(.satoshi(44, .bold))
            .tracking(-1)
            .foregroundStyle(palette.onSurface)
            .multilineTextAlignment(.center)
        }

        if !FeatureFlags.lockedWithBar, isInkLocked, let name = lockingName {
          Text("met \(name)")
            .font(.satoshi(18, .medium))
            .foregroundStyle(palette.primary)
            .multilineTextAlignment(.center)
            .padding(.top, 8)
        }

        // Rooms: the apps for the school lock, chosen in Apple's picker (8c).
        if FeatureFlags.rooms && school.school != nil {
          Button(school.hasChosenForCurrentList ? "Apps voor school" : "Kies je apps voor school") {
            showSchoolApps = true
          }
          .font(.satoshi(15, .medium))
          .foregroundStyle(school.hasChosenForCurrentList ? palette.onSurface.opacity(0.6) : palette.primary)
          .padding(.top, 8)
        }

        // Rooms: when the room's stone doesn't work, a teacher gives a recovery code (8d).
        if isSchoolLocked {
          Button("Ontgrendelen met herstelcode") { showRecoveryCode = true }
            .font(.satoshi(15, .medium))
            .foregroundStyle(palette.onSurface.opacity(0.6))
            .padding(.top, 4)
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
          // With the padlock only the scan hint after a tap.
          if !FeatureFlags.homeLockGlyph || showScanHint {
            Text(showScanHint ? "Houd de bovenkant van je iPhone tegen je NOTIS" : "Tik op de steen om te ontgrendelen")
              .font(.satoshi(14, showScanHint ? .medium : .regular))
              .foregroundStyle(showScanHint ? palette.primary : palette.onSurfaceVariant.opacity(0.6))
              .multilineTextAlignment(.center)
              .padding(.top, 16)
          }
        } else {
          // With the padlock only the scan hint after a tap, or the call to link a stone.
          if !FeatureFlags.homeLockGlyph || showScanHint || !canUnlock {
            Text(freeHint)
              .font(.satoshi(14, showScanHint ? .medium : .regular))
              .foregroundStyle(showScanHint ? palette.primary : palette.onSurfaceVariant.opacity(0.6))
              .multilineTextAlignment(.center)
          }
          if !FeatureFlags.homeLockGlyph && canChooseStone && canUnlock && !showScanHint {
            Text(
              FeatureFlags.homeProfilePicker
                ? "Of houd de steen ingedrukt om handmatig op slot te gaan"
                : FeatureFlags.stoneProfiles
                  ? "Of houd de steen ingedrukt om een profiel te kiezen"
                  : "Of houd de steen ingedrukt om er een te kiezen"
            )
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
    if !canUnlock { return String(localized: "Koppel je NOTIS om te kunnen blokkeren") }
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
    guard FeatureFlags.lockFromApp && !isLocked else { return }
    didLongPressStone = true
    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    // Rooms: a teacher picks the room to watch; that needs no Screen Time.
    if FeatureFlags.rooms && teacher.isTeacher {
      showTeacherRooms = true
      return
    }
    // Without Screen Time nothing can be locked: ask for it first, as a tap does.
    guard isAuthorized else {
      requestAuthorizer.requestAuthorization()
      return
    }
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

    // Rooms: a signed-in teacher taps the room's stone to see who is locked there.
    if FeatureFlags.rooms && teacher.isTeacher {
      showScanHint = true
      scanForTeacherRoom()
      return
    }

    guard isAuthorized else {
      requestAuthorizer.requestAuthorization()
      return
    }

    // Rooms: also without own stones a tap scans, so a student can tap a school's stone.
    let schoolRoute = FeatureFlags.rooms ? (try? BlockedProfiles.notisSchoolProfile(in: context)) : nil
    // Every NOTIS stone: the picked profile routes to the NOTIS strategy; without one,
    // "Mijn NOTIS" is where you make it.
    let route = FeatureFlags.anyNotisStone ? (selectedProfile ?? schoolRoute) : (stones.first ?? schoolRoute)
    guard let route else {
      onPairFirstStone()
      return
    }

    showScanHint = true
    // The scanned stone picks its own app list; `route` only routes to the NOTIS strategy.
    strategyManager.toggleBlocking(context: context, activeProfile: route)
  }

  /// Teacher: scan a stone; a room of their school opens its live list (and couples the
  /// teacher to it for today, for the web page).
  private func scanForTeacherRoom() {
    teacherScanner.resultMessage = nil
    teacherScanner.onError = { message in errorMessage = message }
    teacherScanner.onTagScanned = { tag in
      teacherScanner.resultMessage = String(localized: "Steen gelezen")
      Task { @MainActor in
        if let room = await teacher.roomForStone(uid: tag.id) {
          teacher.openRoom = room
        } else {
          errorMessage = String(localized: "Deze steen hoort niet bij een lokaal van je school")
        }
      }
    }
    teacherScanner.scan(alertMessage: String(localized: "Houd de bovenkant van je iPhone tegen de steen van het lokaal"))
  }

  private func startEmergencyUnlock() {
    guard let session = strategyManager.activeSession else { return }
    do {
      try NotisEmergencyUnlock.start(session: session, context: context)
      Task { await school.report(.emergency) }
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
    Task { await school.report(.locked) }
    refresh()
  }

  private func refresh() {
    requestAuthorizer.refreshAuthorizationStatus()
    strategyManager.loadActiveSession(context: context)
    if FeatureFlags.rooms {
      school.appBecameActive(isLocked: isLocked, isSchoolLocked: isSchoolLocked, isEmergency: isEmergencyActive)
    }
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
