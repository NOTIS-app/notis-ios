import FamilyControls
import SwiftData
import SwiftUI

/// The four onboarding steps of the Android app: welcome, permissions, apps and, last, scan your
/// NOTIS (or, without `FeatureFlags.onboardingPairing`, pair it later in "Mijn NOTIS"). The first
/// stone takes the apps chosen on the apps step.
struct NotisOnboardingView: View {
  let onComplete: () -> Void

  @Environment(\.modelContext) private var context
  @EnvironmentObject private var requestAuthorizer: RequestAuthorizer

  private enum Page: Int, CaseIterable {
    case welcome, permissions, apps, pairing
  }

  /// Without `onboardingApps` and `onboardingPairLater`, onboarding ends on the permissions page.
  private static let pages: [Page] = Page.allCases.filter { page in
    switch page {
    case .apps: return FeatureFlags.onboardingApps
    case .pairing: return FeatureFlags.onboardingPairing || FeatureFlags.onboardingPairLater
    default: return true
    }
  }

  @State private var page: Page = .welcome
  @State private var selection = FamilyActivitySelection(includeEntireCategory: FeatureFlags.allowList)
  @State private var showAppPicker = false
  @State private var scanner = NFCScannerUtil()
  @State private var isPairingSuccess = false
  @State private var errorMessage: String?

  private var isAuthorized: Bool {
    requestAuthorizer.isAuthorized || NotisDevice.isSimulator
  }

  private var appCount: Int {
    FamilyActivityUtil.countSelectedActivities(selection, allowMode: FeatureFlags.allowList)
  }

  var body: some View {
    ZStack(alignment: .bottom) {
      NotisBrand.paper.ignoresSafeArea()

      Group {
        switch page {
        case .welcome: welcome
        case .permissions: permissions
        case .apps: apps
        case .pairing:
          if FeatureFlags.onboardingPairing { pairing } else { pairLater }
        }
      }
      .transition(.asymmetric(insertion: .move(edge: .trailing), removal: .move(edge: .leading)))
      .padding(.horizontal, 32)

      HStack(spacing: 8) {
        ForEach(Self.pages, id: \.self) { item in
          Circle()
            .fill(item == page ? NotisBrand.mandarinDark : NotisBrand.inkSoft.opacity(0.2))
            .frame(width: 8, height: 8)
        }
      }
      .padding(.bottom, 32)
    }
    .preferredColorScheme(.light)
    .sheet(isPresented: $showAppPicker) {
      NotisAppPicker(selection: $selection) { showAppPicker = false }
    }
    .alert(
      errorMessage ?? "",
      isPresented: Binding(
        get: { errorMessage != nil },
        set: { if !$0 { errorMessage = nil } }
      )
    ) {
      Button("Oké", role: .cancel) {}
    }
    .onAppear {
      requestAuthorizer.refreshAuthorizationStatus()
    }
  }

  private func go(to next: Page) {
    withAnimation(.easeInOut(duration: 0.35)) { page = next }
  }

  /// The next shown page; after the last one, onboarding is done.
  private func goNext() {
    guard let index = Self.pages.firstIndex(of: page), index + 1 < Self.pages.count else {
      onComplete()
      return
    }
    go(to: Self.pages[index + 1])
  }

  // MARK: - Welcome

  private var welcome: some View {
    VStack(spacing: 0) {
      HStack(spacing: 2) {
        Text("NOTIS")
          .font(.satoshi(18, .medium))
          .tracking(18 * 0.38)
          .foregroundStyle(NotisBrand.ink)
        Circle()
          .fill(NotisBrand.mandarin)
          .frame(width: 7, height: 7)
      }
      .padding(.top, 36)

      Spacer()
      NotisStoneView(isLocked: false, width: 280)
      Spacer()

      VStack(alignment: .leading, spacing: 12) {
        Text("Tik.\nFocus.\nKlaar.")
          .font(.satoshi(34, .bold))
          .tracking(-0.7)
          .lineSpacing(0)
          .foregroundStyle(NotisBrand.ink)
        Text("Zet afleidende apps op slot met een tik op je NOTIS. Tik nog een keer om ze weer vrij te geven.")
          .font(.satoshi(17))
          .lineSpacing(4)
          .foregroundStyle(NotisBrand.inkSoft)
        Button("Beginnen", action: goNext)
          .buttonStyle(NotisPrimaryButtonStyle())
          .padding(.top, 12)
      }
      .frame(maxWidth: .infinity, alignment: .leading)
      .padding(.bottom, 72)
    }
  }

  // MARK: - Permissions

  private var permissions: some View {
    VStack(alignment: .leading, spacing: 0) {
      Text("Toestemmingen")
        .font(.satoshi(28, .bold))
        .foregroundStyle(NotisBrand.ink)
        .padding(.top, 48)
      Text("NOTIS heeft deze toestemming nodig. Tik op de kaart om hem aan te zetten.")
        .font(.satoshi(15))
        .foregroundStyle(NotisBrand.inkSoft)
        .padding(.top, 8)

      Button {
        requestAuthorizer.requestAuthorization()
      } label: {
        HStack(spacing: 14) {
          Image(systemName: "hourglass")
            .font(.system(size: 18))
            .foregroundStyle(NotisBrand.mandarinDark)
            .frame(width: 44, height: 44)
            .background(NotisBrand.mandarinDark.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))
          VStack(alignment: .leading, spacing: 2) {
            Text("Schermtijd")
              .font(.satoshi(16, .bold))
              .foregroundStyle(NotisBrand.ink)
            Text("Zet de apps die je kiest op slot")
              .font(.satoshi(13))
              .foregroundStyle(NotisBrand.inkSoft)
          }
          Spacer(minLength: 0)
          Image(systemName: isAuthorized ? "checkmark.circle.fill" : "chevron.right")
            .font(.system(size: isAuthorized ? 22 : 14, weight: .semibold))
            .foregroundStyle(isAuthorized ? NotisBrand.mandarinDark : NotisBrand.inkSoft)
        }
        .padding(16)
        .notisCard()
      }
      .buttonStyle(.plain)
      .padding(.top, 24)

      HStack(alignment: .top, spacing: 8) {
        Image(systemName: "info.circle")
          .foregroundStyle(NotisBrand.inkSoft)
        Text("Je geeft de toestemming zelf, in een venster van Apple. Er worden geen gegevens verzameld.")
          .font(.satoshi(13))
          .foregroundStyle(NotisBrand.inkSoft)
      }
      .padding(.top, 16)

      Spacer()

      Button(isAuthorized ? "Doorgaan" : "Toestemmingen instellen") {
        if isAuthorized {
          goNext()
        } else {
          requestAuthorizer.requestAuthorization()
        }
      }
      .buttonStyle(NotisPrimaryButtonStyle())

      skipButton("Later instellen") { goNext() }
        .padding(.bottom, 64)
    }
  }

  // MARK: - Apps

  private var apps: some View {
    VStack(alignment: .leading, spacing: 0) {
      Text(FeatureFlags.allowList ? "Welke apps mag je\ngebruiken?" : "Welke apps wil je\nop slot zetten?")
        .font(.satoshi(28, .bold))
        .foregroundStyle(NotisBrand.ink)
        .padding(.top, 48)
      Text("Je kunt dit later altijd aanpassen")
        .font(.satoshi(15))
        .foregroundStyle(NotisBrand.inkSoft)
        .padding(.top, 8)

      Button {
        showAppPicker = true
      } label: {
        HStack(spacing: 14) {
          Image(systemName: "square.grid.2x2")
            .font(.system(size: 18))
            .foregroundStyle(NotisBrand.mandarinDark)
            .frame(width: 44, height: 44)
            .background(NotisBrand.mandarinDark.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))
          VStack(alignment: .leading, spacing: 2) {
            Text("Apps kiezen")
              .font(.satoshi(16, .bold))
              .foregroundStyle(NotisBrand.ink)
            Text(appCount == 1 ? "1 app gekozen" : "\(appCount) apps gekozen")
              .font(.satoshi(13))
              .foregroundStyle(NotisBrand.inkSoft)
          }
          Spacer(minLength: 0)
          Image(systemName: "chevron.right")
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(NotisBrand.inkSoft)
        }
        .padding(16)
        .notisCard()
      }
      .buttonStyle(.plain)
      .padding(.top, 24)

      if FeatureFlags.allowList {
        Text("Al het andere gaat op slot als je je NOTIS scant.")
          .font(.satoshi(13))
          .foregroundStyle(NotisBrand.inkSoft)
          .padding(.top, 12)
      }

      Spacer()

      Button(appCount == 1 ? "Doorgaan · 1 app" : "Doorgaan · \(appCount) apps") {
        BlockedProfiles.saveOnboardingApps(selection)
        goNext()
      }
        .buttonStyle(NotisPrimaryButtonStyle())

      skipButton("Later kiezen") {
        selection = FamilyActivitySelection(includeEntireCategory: FeatureFlags.allowList)
        goNext()
      }
      .padding(.bottom, 64)
    }
  }

  // MARK: - Pairing

  private var pairing: some View {
    VStack(spacing: 0) {
      Spacer()

      Button(action: startPairing) {
        NotisStoneView(isLocked: false, showScanHint: !isPairingSuccess, width: 240)
      }
      .buttonStyle(.plain)

      Text("Scan je NOTIS")
        .font(.satoshi(26, .bold))
        .foregroundStyle(NotisBrand.ink)
        .padding(.top, 32)
      Text("Tik op de steen en houd de bovenkant van je iPhone tegen je NOTIS om hem te koppelen.")
        .font(.satoshi(14))
        .lineSpacing(6)
        .foregroundStyle(NotisBrand.inkSoft)
        .multilineTextAlignment(.center)
        .padding(.top, 12)

      Group {
        if isPairingSuccess {
          NotisPairedCard()
        } else {
          Button("Scannen", action: startPairing)
            .buttonStyle(NotisPrimaryButtonStyle())
        }
      }
      .padding(.top, 32)

      Text("Je kunt zoveel stenen koppelen als je wilt, bijvoorbeeld thuis, op je werk of op school.")
        .font(.satoshi(13))
        .foregroundStyle(NotisBrand.inkSoft)
        .multilineTextAlignment(.center)
        .padding(.top, 16)

      Spacer()

      skipButton("Later koppelen", action: onComplete)
        .padding(.bottom, 64)
    }
    .animation(.easeInOut(duration: 0.3), value: isPairingSuccess)
  }

  // MARK: - Pair later

  /// Android's `PairLaterPage`: how to pair a stone in "Mijn NOTIS", in three steps, then
  /// "Aan de slag" goes home. With `FeatureFlags.stoneProfiles`: make a profile, pair a stone,
  /// choose the profile it starts.
  private var pairLater: some View {
    VStack(spacing: 0) {
      Spacer()

      NotisStoneView(isLocked: false, width: 180)

      Text(FeatureFlags.stoneProfiles ? "Zo stel je je NOTIS in" : "Zo koppel je je NOTIS")
        .font(.satoshi(26, .bold))
        .foregroundStyle(NotisBrand.ink)
        .multilineTextAlignment(.center)
        .padding(.top, 28)

      VStack(alignment: .leading, spacing: 14) {
        if FeatureFlags.anyNotisStone {
          pairStep(1, "Maak bij Profielen een profiel met de apps die je mag gebruiken")
          pairStep(2, "Kies bovenaan Home je profiel")
          pairStep(3, "Tik op de steen en houd je iPhone tegen je NOTIS: op slot. Nog een keer: weer vrij")
        } else if FeatureFlags.stoneProfiles {
          pairStep(1, "Maak bij Mijn NOTIS een profiel met de apps die je mag gebruiken")
          pairStep(2, "Tik op Nieuwe NOTIS koppelen en houd je iPhone tegen je steen")
          if FeatureFlags.homeProfilePicker {
            pairStep(3, "Kies bovenaan Home je profiel en tik je steen")
          } else {
            pairStep(3, "Kies welk profiel je steen start")
          }
        } else {
          pairStep(1, "Tik bij Mijn NOTIS op Nieuwe NOTIS koppelen")
          pairStep(2, "Geef je NOTIS een naam")
          pairStep(3, "Kies de apps die jij wilt gebruiken")
        }
      }
      .frame(maxWidth: .infinity, alignment: .leading)
      .padding(16)
      .notisCard()
      .padding(.top, 24)

      Spacer()

      Button("Aan de slag", action: onComplete)
        .buttonStyle(NotisPrimaryButtonStyle())
        .padding(.bottom, 72)
    }
  }

  private func pairStep(_ number: Int, _ text: LocalizedStringKey) -> some View {
    HStack(spacing: 14) {
      Text("\(number)")
        .font(.satoshi(14, .bold))
        .foregroundStyle(.white)
        .frame(width: 28, height: 28)
        .background(NotisBrand.mandarinDark, in: Circle())
      Text(text)
        .font(.satoshi(15))
        .foregroundStyle(NotisBrand.ink)
    }
  }

  private func startPairing() {
    guard !isPairingSuccess else { return }
    scanner.onTagScanned = { result in
      let isPaired = BlockedProfiles.findNotisStone(withTag: result.id, in: context) != nil
      if !isPaired, let refusal = StoneSeal.pairingRefusal(result) {
        scanner.resultErrorMessage = refusal
        errorMessage = refusal
        return
      }
      do {
        if !isPaired && FeatureFlags.stoneProfiles {
          // The stone starts the profile at the top, or a new one with the apps chosen here.
          BlockedProfiles.saveOnboardingApps(selection)
          _ = try BlockedProfiles.pairNotisStone(
            tag: result.id, name: String(localized: "Mijn NOTIS"), profile: nil, in: context)
        } else if !isPaired {
          _ = try BlockedProfiles.createNotisStone(
            in: context,
            name: String(localized: "Mijn NOTIS"),
            tag: result.id,
            selection: selection
          )
        }
        isPairingSuccess = true
        Task {
          try? await Task.sleep(for: .seconds(1.4))
          onComplete()
        }
      } catch {
        errorMessage = error.localizedDescription
      }
    }
    scanner.onError = { message in
      errorMessage = message
    }
    scanner.resultMessage = String(localized: "NOTIS gekoppeld!")
    scanner.scan(alertMessage: String(localized: "Houd de bovenkant van je iPhone tegen je NOTIS"))
  }

  private func skipButton(_ title: LocalizedStringKey, action: @escaping () -> Void) -> some View {
    Button(title, action: action)
      .font(.satoshi(14))
      .foregroundStyle(NotisBrand.inkSoft.opacity(0.6))
      .frame(maxWidth: .infinity)
      .padding(.top, 16)
  }
}

#Preview {
  NotisOnboardingView {}
    .environmentObject(RequestAuthorizer())
}
