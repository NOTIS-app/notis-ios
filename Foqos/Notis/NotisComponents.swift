import SwiftUI
import UIKit

// MARK: - Emergency unlock button

/// Android's `EmergencyUnlockButton`: a round button at the bottom of the locked screen. Hold it
/// for a second (with accelerating haptic ticks) to open the emergency sheet; letting go early
/// shakes it.
struct NotisEmergencyButton: View {
  let remaining: Int
  let palette: NotisPalette
  let onLongPress: () -> Void

  @State private var isPressed = false
  @State private var didComplete = false
  @State private var shake: CGFloat = 0

  var body: some View {
    VStack(spacing: 8) {
      Circle()
        .fill(palette.onSurface.opacity(isPressed ? 0.16 : 0.08))
        .frame(width: 72, height: 72)
        .overlay(
          Image(systemName: "lock.open.fill")
            .font(.system(size: 22))
            .foregroundStyle(palette.onSurface.opacity(0.7))
        )
        .scaleEffect(isPressed ? 0.9 : 1)
        .offset(x: shake)
        .animation(.easeOut(duration: 0.15), value: isPressed)
        .onLongPressGesture(minimumDuration: 1, maximumDistance: 40) {
          didComplete = true
          UINotificationFeedbackGenerator().notificationOccurred(.success)
          onLongPress()
        } onPressingChanged: { pressing in
          isPressed = pressing
          if pressing {
            didComplete = false
            tickWhilePressed()
          } else {
            // The gesture reports the release before or after completing; give it a moment.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
              if !didComplete { shakeButton() }
            }
          }
        }
        .accessibilityLabel("Noodontgrendeling")
        .accessibilityAddTraits(.isButton)
        .accessibilityAction { onLongPress() }

      Text("nog \(remaining)")
        .font(.satoshi(11, .medium))
        .foregroundStyle(palette.onSurfaceVariant.opacity(0.7))
    }
  }

  private func tickWhilePressed() {
    Task { @MainActor in
      let generator = UIImpactFeedbackGenerator(style: .light)
      let start = Date()
      try? await Task.sleep(for: .milliseconds(80))
      while isPressed && !didComplete {
        generator.impactOccurred()
        let progress = min(1, Date().timeIntervalSince(start))
        // Accelerate from 120 ms to 30 ms, as on Android.
        let interval = max(30, 120 - 90 * progress)
        try? await Task.sleep(for: .milliseconds(Int(interval)))
      }
    }
  }

  private func shakeButton() {
    UINotificationFeedbackGenerator().notificationOccurred(.error)
    Task { @MainActor in
      for value in [-10.0, 10, -7, 7, -4, 4, 0] {
        withAnimation(.linear(duration: 0.05)) { shake = value }
        try? await Task.sleep(for: .milliseconds(50))
      }
    }
  }
}

/// Android's `EmergencyBottomSheet`.
struct NotisEmergencySheet: View {
  let remaining: Int
  let minutes: Int
  let onConfirm: () -> Void
  let onCancel: () -> Void

  var body: some View {
    VStack(spacing: 16) {
      Image(systemName: "lock.open.fill")
        .font(.system(size: 24))
        .foregroundStyle(NotisBrand.mandarinDark)
        .frame(width: 56, height: 56)
        .background(NotisBrand.mandarinDark.opacity(0.1), in: Circle())
        .padding(.top, 24)

      Text("Noodontgrendeling")
        .font(.satoshi(20, .bold))
        .foregroundStyle(NotisBrand.ink)

      Text(
        "Je hebt \(minutes) minuten toegang tot al je apps, daarna gaat het blokkeren vanzelf verder.\n\n"
          + (remaining == 1
            ? String(localized: "Nog 1 noodontgrendeling over")
            : String(localized: "Nog \(remaining) noodontgrendelingen over"))
      )
      .font(.satoshi(15))
      .foregroundStyle(NotisBrand.inkSoft)
      .multilineTextAlignment(.center)

      Spacer(minLength: 0)

      Button("Ontgrendelen bevestigen", action: onConfirm)
        .buttonStyle(NotisPrimaryButtonStyle())

      Button("Annuleren", action: onCancel)
        .font(.satoshi(15, .medium))
        .foregroundStyle(NotisBrand.mandarinDark)
        .padding(.bottom, 8)
    }
    .padding(.horizontal, 24)
  }
}

// MARK: - Floating nav bar

enum NotisTab: Hashable {
  case stones
  case home
  case settings
}

/// Android's `FloatingNavBar`: a pill at the bottom, My NOTIS · Home · Settings.
struct NotisNavBar: View {
  @Binding var selection: NotisTab

  var body: some View {
    HStack(spacing: 0) {
      item(.stones, label: "Mijn NOTIS", icon: "wave.3.right.circle", selectedIcon: "wave.3.right.circle.fill")
      item(.home, label: "Home", icon: "house", selectedIcon: "house.fill")
      item(.settings, label: "Instellingen", icon: "gearshape", selectedIcon: "gearshape.fill")
    }
    .padding(8)
    .background(Capsule().fill(NotisBrand.boneLight.opacity(0.95)))
    .shadow(color: .black.opacity(0.12), radius: 6, y: 2)
    .padding(.horizontal, 32)
    .padding(.bottom, 8)
  }

  private func item(_ tab: NotisTab, label: LocalizedStringKey, icon: String, selectedIcon: String) -> some View {
    let isSelected = selection == tab
    let color = isSelected ? NotisBrand.mandarinDark : NotisBrand.inkSoft.opacity(0.7)
    return Button {
      selection = tab
    } label: {
      VStack(spacing: 2) {
        Image(systemName: isSelected ? selectedIcon : icon)
          .font(.system(size: 19))
          .frame(height: 22)
        Text(label)
          .font(.satoshi(11, isSelected ? .bold : .regular))
      }
      .foregroundStyle(color)
      .frame(maxWidth: .infinity)
      .padding(.vertical, 6)
      .background(Capsule().fill(isSelected ? NotisBrand.mandarinDark.opacity(0.12) : .clear))
      .contentShape(Capsule())
    }
    .buttonStyle(.plain)
    .animation(.spring(response: 0.35), value: isSelected)
  }
}

// MARK: - Root

/// The NOTIS app: onboarding the first time, then the three tabs. Light only, like Android.
struct NotisRootView: View {
  @AppStorage("notisOnboardingDone") private var isOnboardingDone = false

  var body: some View {
    Group {
      if isOnboardingDone {
        NotisTabsView()
      } else {
        NotisOnboardingView {
          withAnimation(.easeInOut) { isOnboardingDone = true }
        }
      }
    }
  }
}

struct NotisTabsView: View {
  @EnvironmentObject private var strategyManager: StrategyManager

  @State private var tab: NotisTab = .home
  @AppStorage(NotisEmergencyUnlock.endsAtKey) private var emergencyEndsAt: Double = 0

  private var isEmergencyActive: Bool {
    strategyManager.isBlocking && Date(timeIntervalSince1970: emergencyEndsAt) > Date()
  }

  /// Android hides the bar while locked, except during the emergency pause.
  private var showsNavBar: Bool {
    !strategyManager.isBlocking || isEmergencyActive
  }

  var body: some View {
    ZStack(alignment: .bottom) {
      Group {
        switch tab {
        case .stones:
          if FeatureFlags.stoneProfiles { MijnNotisProfilesView() } else { MijnNotisView() }
        case .home:
          NotisHomeView(onPairFirstStone: { tab = .stones })
        case .settings:
          NotisSettingsView()
        }
      }
      .frame(maxWidth: .infinity, maxHeight: .infinity)

      if showsNavBar {
        NotisNavBar(selection: $tab)
          .transition(.move(edge: .bottom).combined(with: .opacity))
      }
    }
    .animation(.spring(response: 0.5, dampingFraction: 0.8), value: showsNavBar)
    // Light status bar text on the ink screen, dark text everywhere else.
    .preferredColorScheme(strategyManager.isBlocking && !isEmergencyActive ? .dark : .light)
    .onChange(of: strategyManager.isBlocking) { _, isBlocking in
      if isBlocking { tab = .home }
    }
  }
}
