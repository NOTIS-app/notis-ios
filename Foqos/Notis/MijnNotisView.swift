import FamilyControls
import SwiftData
import SwiftUI

/// "Mijn NOTIS", like Android's `NfcTagsScreen` with profiles hidden: one card per stone (tap to
/// change its apps, ⋮ to rename or remove) and a big pair button, for as many stones as you like.
struct MijnNotisView: View {
  @Environment(\.modelContext) private var context

  @EnvironmentObject private var strategyManager: StrategyManager

  @Query(sort: [
    SortDescriptor(\BlockedProfiles.order, order: .forward),
    SortDescriptor(\BlockedProfiles.createdAt, order: .forward),
  ]) private var profiles: [BlockedProfiles]

  @State private var scanner = NFCScannerUtil()
  @State private var isPairingSuccess = false
  @State private var newStone: PairingTag?
  @State private var pendingTag: String?
  @State private var newStoneChoice: NewStoneChoice?
  @State private var stoneToEdit: BlockedProfiles?
  @State private var stoneToRename: BlockedProfiles?
  @State private var renameText = ""
  @State private var showHelp = false
  @State private var errorMessage: String?

  private var stones: [BlockedProfiles] {
    profiles.filter(\.isNotisStone)
  }

  private var isLocked: Bool {
    strategyManager.isBlocking
  }

  private var defaultName: String {
    stones.isEmpty ? String(localized: "Mijn NOTIS") : String(localized: "NOTIS \(stones.count + 1)")
  }

  var body: some View {
    ZStack {
      NotisBrand.paper.ignoresSafeArea()

      ScrollView {
        VStack(alignment: .leading, spacing: 10) {
          header
            .padding(.bottom, 8)

          if isPairingSuccess {
            NotisPairedCard()
              .transition(.scale(scale: 0.95).combined(with: .opacity))
          }

          if stones.isEmpty && !isPairingSuccess {
            EmptyStonesCard()
          }

          ForEach(stones) { stone in
            StoneCard(
              stone: stone,
              isActive: strategyManager.activeSession?.blockedProfile.id == stone.id,
              isLocked: isLocked,
              onOpen: { stoneToEdit = stone },
              onRename: {
                renameText = stone.name
                stoneToRename = stone
              },
              onDelete: { delete(stone) }
            )
          }

          if !isPairingSuccess {
            Button(action: startPairing) {
              Label("Nieuwe NOTIS koppelen", systemImage: "plus")
            }
            .buttonStyle(NotisPrimaryButtonStyle())
            .disabled(isLocked)
            .padding(.top, 6)
          }

          if !stones.isEmpty {
            Text("Tik op een steen om de apps te wijzigen. Met elke steen kun je het slot weer openen.")
              .font(.satoshi(13))
              .foregroundStyle(NotisBrand.inkSoft)
              .padding(.horizontal, 4)
              .padding(.vertical, 4)
          }
        }
        .padding(.horizontal, 16)
        .padding(.top, 16)
        .padding(.bottom, 104)
        .animation(.easeInOut(duration: 0.3), value: isPairingSuccess)
      }
    }
    .sheet(item: $newStone, onDismiss: finishNewStone) { pairing in
      NewStoneSheet(
        defaultName: defaultName,
        otherStones: stones,
        onConfirm: { name, copyFrom in
          newStoneChoice = NewStoneChoice(tag: pairing.tag, name: name, copyFrom: copyFrom)
          newStone = nil
        }
      )
      .presentationDetents([.large])
      .presentationBackground(NotisBrand.paper)
    }
    .sheet(item: $stoneToEdit) { stone in
      NotisAppPickerSheet(stone: stone)
    }
    .sheet(isPresented: $showHelp) {
      StonesHelpSheet { showHelp = false }
        .presentationDetents([.height(420)])
        .presentationBackground(NotisBrand.boneLight)
    }
    .alert(
      "Steen hernoemen",
      isPresented: Binding(
        get: { stoneToRename != nil },
        set: { if !$0 { stoneToRename = nil } }
      )
    ) {
      TextField("Naam", text: $renameText)
      Button("Bevestigen", action: rename)
      Button("Annuleren", role: .cancel) {}
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
  }

  private var header: some View {
    HStack(alignment: .center, spacing: 4) {
      VStack(alignment: .leading, spacing: 2) {
        Text("Mijn NOTIS")
          .font(.satoshi(28, .bold))
          .tracking(-0.5)
          .foregroundStyle(NotisBrand.ink)
        Text("Elke NOTIS blokkeert zijn eigen apps")
          .font(.satoshi(14))
          .foregroundStyle(NotisBrand.inkSoft)
      }
      Spacer()
      Button {
        showHelp = true
      } label: {
        Image(systemName: "info.circle")
          .font(.system(size: 18))
          .foregroundStyle(NotisBrand.inkSoft)
          .frame(width: 40, height: 40)
          .background(NotisBrand.card, in: Circle())
      }
      .accessibilityLabel("Info")
    }
  }

  // MARK: - Pairing

  private func startPairing() {
    scanner.onTagScanned = { result in
      scanner.resultErrorMessage = nil
      if let existing = BlockedProfiles.findNotisStone(withTag: result.id, in: context) {
        errorMessage = String(localized: "Deze NOTIS is al gekoppeld: \(existing.name)")
        return
      }
      if let refusal = StoneSeal.pairingRefusal(result) {
        scanner.resultErrorMessage = refusal
        errorMessage = refusal
        return
      }
      isPairingSuccess = true
      Task {
        // Let the success card show, then name the stone (Android: after the animation).
        try? await Task.sleep(for: .seconds(1.4))
        isPairingSuccess = false
        pendingTag = result.id
        newStone = PairingTag(tag: result.id)
      }
    }
    scanner.onError = { message in
      errorMessage = message
    }
    scanner.resultMessage = String(localized: "NOTIS gekoppeld!")
    scanner.scan(alertMessage: String(localized: "Houd de bovenkant van je iPhone tegen je NOTIS"))
  }

  /// Closing the sheet still keeps the stone, as on Android: paired without copied apps.
  private func finishNewStone() {
    defer {
      newStoneChoice = nil
      pendingTag = nil
    }
    if let choice = newStoneChoice {
      if let stone = createStone(tag: choice.tag, name: choice.name, copyFrom: choice.copyFrom) {
        // Straight on to choosing its apps.
        stoneToEdit = stone
      }
    } else if let tag = pendingTag {
      _ = createStone(tag: tag, name: defaultName, copyFrom: nil)
    }
  }

  private func createStone(tag: String, name: String, copyFrom: BlockedProfiles?) -> BlockedProfiles? {
    do {
      // The first stone takes the apps chosen during onboarding, as on Android.
      let onboardingApps = stones.isEmpty ? BlockedProfiles.takeOnboardingApps() : nil
      let selection =
        copyFrom?.selectedActivity
        ?? onboardingApps
        ?? FamilyActivitySelection(includeEntireCategory: FeatureFlags.allowList)
      return try BlockedProfiles.createNotisStone(in: context, name: name, tag: tag, selection: selection)
    } catch {
      errorMessage = error.localizedDescription
      return nil
    }
  }

  // MARK: - Editing

  private func rename() {
    guard let stone = stoneToRename else { return }
    let trimmed = renameText.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else { return }
    do {
      try BlockedProfiles.renameNotisStone(stone, to: String(trimmed.prefix(100)), in: context)
    } catch {
      errorMessage = error.localizedDescription
    }
  }

  private func delete(_ stone: BlockedProfiles) {
    guard strategyManager.activeSession?.blockedProfile.id != stone.id else {
      errorMessage = String(localized: "Ontgrendel eerst om deze steen te verwijderen.")
      return
    }
    do {
      try BlockedProfiles.deleteProfile(stone, in: context)
      try context.save()
    } catch {
      errorMessage = error.localizedDescription
    }
  }
}

private struct PairingTag: Identifiable {
  let tag: String
  var id: String { tag }
}

/// What the new-stone sheet decided; acted on once the sheet is gone.
private struct NewStoneChoice {
  let tag: String
  let name: String
  let copyFrom: BlockedProfiles?
}

// MARK: - Cards

struct EmptyStonesCard: View {
  var body: some View {
    VStack(spacing: 12) {
      NotisStoneGlyph(width: 120)
        .padding(.bottom, 4)
      Text("Nog geen NOTIS gekoppeld")
        .font(.satoshi(20, .bold))
        .foregroundStyle(NotisBrand.ink)
      Text(
        FeatureFlags.homeProfilePicker
          ? "Koppel je steen. Eén tik zet je apps op slot met het profiel dat op Home gekozen is, nog een tik geeft ze weer vrij."
          : FeatureFlags.stoneProfiles
          ? "Koppel je steen en kies welk profiel hij start. Eén tik zet je apps op slot, nog een tik geeft ze weer vrij."
          : "Koppel je steen, kies de apps en zet ze met één tik op slot of weer vrij."
      )
        .font(.satoshi(14))
        .foregroundStyle(NotisBrand.inkSoft)
        .multilineTextAlignment(.center)
    }
    .frame(maxWidth: .infinity)
    .padding(.horizontal, 24)
    .padding(.vertical, 32)
    .notisCard(radius: 28)
  }
}

/// Android's `NfcScanCard` in its success state.
struct NotisPairedCard: View {
  var body: some View {
    HStack(spacing: 14) {
      Image(systemName: "checkmark")
        .font(.system(size: 20, weight: .bold))
        .foregroundStyle(.white)
        .frame(width: 44, height: 44)
        .background(NotisBrand.mandarinDark, in: Circle())
      VStack(alignment: .leading, spacing: 2) {
        Text("NOTIS gekoppeld!")
          .font(.satoshi(17, .bold))
          .foregroundStyle(NotisBrand.ink)
        Text("Je steen is klaar voor gebruik.")
          .font(.satoshi(14))
          .foregroundStyle(NotisBrand.inkSoft)
      }
      Spacer(minLength: 0)
    }
    .padding(20)
    .notisCard(radius: 20)
  }
}

private struct StoneCard: View {
  let stone: BlockedProfiles
  let isActive: Bool
  let isLocked: Bool
  let onOpen: () -> Void
  let onRename: () -> Void
  let onDelete: () -> Void

  var body: some View {
    HStack(spacing: 14) {
      Button(action: onOpen) {
        HStack(spacing: 14) {
          NotisStoneGlyph(width: 52)
          VStack(alignment: .leading, spacing: 2) {
            Text(stone.name)
              .font(.satoshi(17, .bold))
              .foregroundStyle(NotisBrand.ink)
            Text(subtitle)
              .font(.satoshi(14))
              .foregroundStyle(isActive ? NotisBrand.mandarinDark : NotisBrand.inkSoft)
          }
          Spacer(minLength: 0)
        }
        .contentShape(Rectangle())
      }
      .buttonStyle(.plain)
      .disabled(isLocked)

      Menu {
        Button(action: onRename) {
          Label("Hernoemen", systemImage: "pencil")
        }
        Button(role: .destructive, action: onDelete) {
          Label("Verwijderen", systemImage: "trash")
        }
      } label: {
        Image(systemName: "ellipsis")
          .rotationEffect(.degrees(90))
          .font(.system(size: 16, weight: .semibold))
          .foregroundStyle(NotisBrand.inkSoft)
          .frame(width: 40, height: 44)
          .contentShape(Rectangle())
      }
      .accessibilityLabel("Meer opties")
      .disabled(isLocked)
    }
    .padding(.leading, 16)
    .padding(.vertical, 16)
    .padding(.trailing, 4)
    .notisCard()
  }

  private var subtitle: String {
    isActive ? String(localized: "Nu op slot") : stone.notisAppsSummary
  }
}

// MARK: - Sheets

/// Android's `NewStoneSheet`: name the stone and choose where its apps come from.
private struct NewStoneSheet: View {
  let defaultName: String
  let otherStones: [BlockedProfiles]
  let onConfirm: (String, BlockedProfiles?) -> Void

  @State private var name = ""
  @State private var copyFrom: BlockedProfiles?

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 12) {
        HStack(spacing: 12) {
          NotisStoneGlyph(width: 48)
          Text("Je nieuwe NOTIS")
            .font(.satoshi(22, .bold))
            .foregroundStyle(NotisBrand.ink)
        }
        .padding(.top, 28)

        VStack(alignment: .leading, spacing: 4) {
          Text("Naam")
            .font(.satoshi(12, .medium))
            .foregroundStyle(NotisBrand.inkSoft)
          TextField("Naam", text: $name)
            .font(.satoshi(17))
            .foregroundStyle(NotisBrand.ink)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .notisCard(radius: 12)

        if !otherStones.isEmpty {
          Text(FeatureFlags.allowList ? "Welke apps mogen gebruikt worden?" : "Welke apps moet deze blokkeren?")
            .font(.satoshi(16, .bold))
            .foregroundStyle(NotisBrand.ink)
            .padding(.top, 4)

          sourceOption(
            title: String(localized: "Nieuwe apps kiezen"),
            subtitle: String(localized: "Begin met een lege lijst"),
            isSelected: copyFrom == nil
          ) { copyFrom = nil }

          ForEach(otherStones) { stone in
            let count = FamilyActivityUtil.countSelectedActivities(stone.selectedActivity)
            sourceOption(
              title: String(localized: "Zelfde als \(stone.name)"),
              subtitle: String(localized: "Neem de \(count) apps over en pas ze daarna aan"),
              isSelected: copyFrom?.id == stone.id
            ) { copyFrom = stone }
          }
        }

        Button("Apps kiezen") {
          let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
          onConfirm(trimmed.isEmpty ? defaultName : String(trimmed.prefix(100)), copyFrom)
        }
        .buttonStyle(NotisPrimaryButtonStyle())
        .padding(.top, 4)
      }
      .padding(.horizontal, 20)
      .padding(.bottom, 16)
    }
    .onAppear {
      if name.isEmpty { name = defaultName }
    }
  }

  private func sourceOption(title: String, subtitle: String, isSelected: Bool, onTap: @escaping () -> Void)
    -> some View
  {
    Button(action: onTap) {
      HStack(spacing: 12) {
        VStack(alignment: .leading, spacing: 2) {
          Text(title)
            .font(.satoshi(15, .bold))
            .foregroundStyle(NotisBrand.ink)
          Text(subtitle)
            .font(.satoshi(13))
            .foregroundStyle(NotisBrand.inkSoft)
        }
        Spacer(minLength: 0)
        ZStack {
          Circle()
            .strokeBorder(isSelected ? NotisBrand.mandarinDark : NotisBrand.inkSoft.opacity(0.3), lineWidth: 2)
            .background(Circle().fill(isSelected ? NotisBrand.mandarinDark : .clear))
          if isSelected {
            Image(systemName: "checkmark")
              .font(.system(size: 11, weight: .bold))
              .foregroundStyle(.white)
          }
        }
        .frame(width: 22, height: 22)
      }
      .padding(16)
      .background(NotisBrand.card, in: RoundedRectangle(cornerRadius: 18))
      .overlay(
        RoundedRectangle(cornerRadius: 18)
          .strokeBorder(
            isSelected ? NotisBrand.mandarinDark : NotisBrand.ink.opacity(0.12), lineWidth: isSelected ? 2 : 1)
      )
    }
    .buttonStyle(.plain)
  }
}

/// Android's `TagHelpSheet`.
struct StonesHelpSheet: View {
  let onDismiss: () -> Void

  /// `FeatureFlags.bedtimeInMyNotis`: the evening lock lives on this screen too.
  static var explainsBedtime: Bool { FeatureFlags.bedtimeLock && FeatureFlags.bedtimeInMyNotis }

  var body: some View {
    VStack(spacing: 16) {
      Image(systemName: "wave.3.right")
        .font(.system(size: 24))
        .foregroundStyle(NotisBrand.mandarinDark)
        .frame(width: 56, height: 56)
        .background(NotisBrand.mandarinDark.opacity(0.1), in: Circle())
        .padding(.top, 24)
      Text(Self.explainsBedtime ? "Hoe werkt Mijn NOTIS?" : "Hoe werken de stenen?")
        .font(.satoshi(20, .bold))
        .foregroundStyle(NotisBrand.ink)
      if FeatureFlags.homeProfilePicker {
        rule(
          icon: "arrow.triangle.2.circlepath",
          title: String(localized: "Je kiest het profiel op Home"),
          body: String(
            localized:
              "Een profiel is een lijst apps die je mag gebruiken. Kies er een bovenaan Home; elke steen zet je telefoon op slot met dat profiel."
          )
        )
      } else if FeatureFlags.stoneProfiles {
        rule(
          icon: "arrow.triangle.2.circlepath",
          title: String(localized: "Elke steen start een profiel"),
          body: String(
            localized:
              "Een profiel is een lijst apps die je mag gebruiken. Tik je op een steen, dan gaat al het andere op slot, met het profiel dat je voor die steen hebt gekozen."
          )
        )
      } else {
        rule(
          icon: "arrow.triangle.2.circlepath",
          title: String(localized: "Elke steen heeft eigen apps"),
          body: String(localized: "Tik je op een steen, dan gaan de apps op slot die je voor die steen hebt gekozen.")
        )
      }
      rule(
        icon: "lock",
        title: String(localized: "Elke steen ontgrendelt"),
        body: String(localized: "Tik op een van je stenen om het slot te openen.")
      )
      if Self.explainsBedtime {
        rule(
          icon: "moon",
          title: String(localized: "Avondslot op vaste tijden"),
          body: String(
            localized:
              "Kies een tijd en de dagen: dan gaat je telefoon vanzelf op slot met het profiel dat je kiest. Met een eindtijd is hij 's ochtends weer vrij, anders haalt alleen je NOTIS hem eraf."
          )
        )
      }
      Spacer(minLength: 0)
      Button("Begrepen", action: onDismiss)
        .buttonStyle(NotisPrimaryButtonStyle())
        .padding(.bottom, 8)
    }
    .padding(.horizontal, 24)
  }

  private func rule(icon: String, title: String, body: String) -> some View {
    HStack(alignment: .top, spacing: 12) {
      Image(systemName: icon)
        .font(.system(size: 18))
        .foregroundStyle(NotisBrand.mandarinDark)
        .frame(width: 22)
        .padding(.top, 2)
      VStack(alignment: .leading, spacing: 2) {
        Text(title)
          .font(.satoshi(15, .bold))
          .foregroundStyle(NotisBrand.ink)
        Text(body)
          .font(.satoshi(13))
          .foregroundStyle(NotisBrand.inkSoft)
      }
      Spacer(minLength: 0)
    }
  }
}

#Preview {
  MijnNotisView()
    .environmentObject(StrategyManager())
}
