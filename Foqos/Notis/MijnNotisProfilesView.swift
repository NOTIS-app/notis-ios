import FamilyControls
import SwiftData
import SwiftUI

/// "Mijn NOTIS" with profiles apart from stones (`FeatureFlags.stoneProfiles`), like Android's
/// `NfcTagsScreen`: the profiles (tap to choose apps, ⋮ to rename or delete, "Nieuw profiel"),
/// then the stones (tap to choose the profile a stone starts, ⋮ to rename or remove) and the
/// big pair button.
struct MijnNotisProfilesView: View {
  @Environment(\.modelContext) private var context

  @EnvironmentObject private var strategyManager: StrategyManager

  @Query(sort: [
    SortDescriptor(\BlockedProfiles.order, order: .forward),
    SortDescriptor(\BlockedProfiles.createdAt, order: .forward),
  ]) private var allProfiles: [BlockedProfiles]

  @State private var scanner = NFCScannerUtil()
  @State private var showBedtime = false
  /// Re-read when the evening lock sheet closes.
  @State private var bedtimeAlarms = NotisBedtime.load()
  @State private var isPairingSuccess = false
  @State private var newStone: PairingTag?
  @State private var pendingTag: String?
  @State private var newStoneChoice: NewStoneChoice?
  @State private var profileToEdit: BlockedProfiles?
  @State private var stoneForProfile: StoneRef?
  @State private var stoneToRename: StoneRef?
  @State private var profileEdit: ProfileEdit?
  /// A profile made in the edit sheet: its apps are chosen once the sheet is gone.
  @State private var newProfile: BlockedProfiles?
  @State private var profileToDelete: BlockedProfiles?
  @State private var nameText = ""
  @State private var showHelp = false
  @State private var errorMessage: String?

  private var profiles: [BlockedProfiles] {
    allProfiles.filter(\.isNotisProfile)
  }

  private var stones: [StoneRef] {
    profiles.flatMap { profile in
      profile.notisStones.map { StoneRef(tag: $0.codeValue, name: $0.name, profile: profile) }
    }
  }

  private var isLocked: Bool {
    strategyManager.isBlocking
  }

  private var defaultStoneName: String {
    stones.isEmpty ? String(localized: "Mijn NOTIS") : String(localized: "NOTIS \(stones.count + 1)")
  }

  var body: some View {
    ZStack {
      NotisBrand.paper.ignoresSafeArea()

      ScrollView {
        VStack(alignment: .leading, spacing: 10) {
          header
            .padding(.bottom, 8)

          // `FeatureFlags.bedtimeInMyNotis`: the evening lock heads the screen, the profiles follow.
          if FeatureFlags.bedtimeLock && FeatureFlags.bedtimeInMyNotis {
            bedtimeButton
              .padding(.bottom, 6)
          }

          // Without stones on this screen, the section title would repeat the screen's.
          if !FeatureFlags.anyNotisStone {
            sectionTitle("Profielen")
          }

          if profiles.isEmpty {
            Text("Nog geen profielen. Een profiel is een lijst apps die je mag gebruiken; elke steen start er een.")
              .font(.satoshi(14))
              .foregroundStyle(NotisBrand.inkSoft)
              .padding(.horizontal, 4)
          }

          ForEach(profiles) { profile in
            let isActive = strategyManager.activeSession?.blockedProfile.id == profile.id
            NotisItemCard(
              name: profile.name,
              subtitle: isActive ? String(localized: "Nu op slot") : profile.notisAppsSummary,
              highlight: isActive,
              isLocked: isLocked,
              onOpen: { profileToEdit = profile },
              renameLabel: "Bewerken",
              onRename: { profileEdit = ProfileEdit(profile: profile) },
              onDelete: { profileToDelete = profile }
            ) {
              NotisProfileGlyph(icon: profile.notisIcon)
            }
          }

          if FeatureFlags.anyNotisStone {
            // No pairing any more: this is the screen's main button.
            Button {
              profileEdit = ProfileEdit(profile: nil)
            } label: {
              Label("Nieuw profiel", systemImage: "plus")
            }
            .buttonStyle(NotisPrimaryButtonStyle())
            .disabled(isLocked)
            .padding(.top, 6)

            if !FeatureFlags.lessText {
              Text(
                "Tik op een profiel om de apps te wijzigen. Op Home kies je met welk profiel je NOTIS op slot gaat. Elke NOTIS-steen zet op slot en weer vrij, koppelen hoeft niet."
              )
              .font(.satoshi(13))
              .foregroundStyle(NotisBrand.inkSoft)
              .padding(.horizontal, 4)
              .padding(.vertical, 4)
            }
          } else {
            Button {
              profileEdit = ProfileEdit(profile: nil)
            } label: {
              Label("Nieuw profiel", systemImage: "plus")
            }
            .buttonStyle(NotisOutlinedButtonStyle())
            .disabled(isLocked)

            stonesSection
          }

        }
        .padding(.horizontal, 16)
        .padding(.top, 16)
        .padding(.bottom, 104)
        .animation(.easeInOut(duration: 0.3), value: isPairingSuccess)
      }
    }
    .sheet(isPresented: $showBedtime, onDismiss: { bedtimeAlarms = NotisBedtime.load() }) {
      NotisBedtimeSheet()
    }
    .sheet(item: $newStone, onDismiss: finishNewStone) { pairing in
      NewStoneProfileSheet(
        defaultName: defaultStoneName,
        profiles: profiles,
        askProfile: !FeatureFlags.homeProfilePicker,
        onConfirm: { name, profile in
          newStoneChoice = NewStoneChoice(tag: pairing.tag, name: name, profile: profile)
          newStone = nil
        }
      )
      .presentationDetents([.large])
      .presentationBackground(NotisBrand.paper)
    }
    .sheet(item: $profileToEdit) { profile in
      NotisAppPickerSheet(stone: profile)
    }
    .sheet(item: $stoneForProfile) { stone in
      StoneProfileSheet(stone: stone, profiles: profiles) { profile in
        move(stone, to: profile)
        stoneForProfile = nil
      }
      .presentationDetents([.medium, .large])
      .presentationBackground(NotisBrand.paper)
    }
    .sheet(isPresented: $showHelp) {
      StonesHelpSheet { showHelp = false }
        .presentationDetents([.height(StonesHelpSheet.explainsBedtime ? 560 : 440)])
        .presentationBackground(NotisBrand.boneLight)
    }
    .alert(
      "Steen hernoemen",
      isPresented: Binding(
        get: { stoneToRename != nil },
        set: { if !$0 { stoneToRename = nil } }
      )
    ) {
      TextField("Naam", text: $nameText)
      Button("Bevestigen", action: renameStone)
      Button("Annuleren", role: .cancel) {}
    }
    .sheet(item: $profileEdit, onDismiss: openNewProfileApps) { edit in
      NotisProfileEditSheet(
        title: edit.profile == nil ? "Nieuw profiel" : "Profiel bewerken",
        initialName: edit.profile?.name ?? String(localized: "Profiel \(profiles.count + 1)"),
        initialIcon: edit.profile?.notisIcon ?? .apps
      ) { name, icon in
        saveProfile(edit, name: name, icon: icon)
        profileEdit = nil
      }
      .presentationDetents([.large])
      .presentationBackground(NotisBrand.paper)
    }
    .alert(
      Text("\(profileToDelete?.name ?? "") verwijderen?"),
      isPresented: Binding(
        get: { profileToDelete != nil },
        set: { if !$0 { profileToDelete = nil } }
      ),
      presenting: profileToDelete
    ) { profile in
      Button("Verwijderen", role: .destructive) { deleteProfile(profile) }
      Button("Annuleren", role: .cancel) {}
    } message: { profile in
      Text(deleteMessage(for: profile))
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

  /// The stones and the pair button (without `FeatureFlags.anyNotisStone`).
  @ViewBuilder private var stonesSection: some View {
    sectionTitle("Stenen")
      .padding(.top, 14)

    if isPairingSuccess {
      NotisPairedCard()
        .transition(.scale(scale: 0.95).combined(with: .opacity))
    }

    if stones.isEmpty && !isPairingSuccess {
      EmptyStonesCard()
    }

    ForEach(stones) { stone in
      NotisItemCard(
        name: stone.name,
        subtitle: FeatureFlags.homeProfilePicker
          ? String(localized: "Gekoppeld") : String(localized: "Start \(stone.profile.name)"),
        highlight: false,
        isLocked: isLocked,
        // With the Home picker a stone has no profile of its own: tap renames it.
        onOpen: {
          if FeatureFlags.homeProfilePicker {
            nameText = stone.name
            stoneToRename = stone
          } else {
            stoneForProfile = stone
          }
        },
        renameLabel: "Hernoemen",
        onRename: {
          nameText = stone.name
          stoneToRename = stone
        },
        onDelete: { removeStone(stone) }
      ) {
        NotisStoneGlyph(width: 52)
      }
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
      Text(
        FeatureFlags.homeProfilePicker
          ? "Tik op een profiel om de apps te wijzigen. Op Home kies je met welk profiel je stenen op slot gaan. Met elke steen kun je het slot weer openen."
          : "Tik op een profiel om de apps te wijzigen, of op een steen om te kiezen welk profiel hij start. Met elke steen kun je het slot weer openen."
      )
      .font(.satoshi(13))
      .foregroundStyle(NotisBrand.inkSoft)
      .padding(.horizontal, 4)
      .padding(.vertical, 4)
    }
  }

  /// "Avondslot" as the orange button, with the times that are on; opens the lock times.
  private var bedtimeButton: some View {
    let on = bedtimeAlarms.filter(\.enabled).map(\.timeText).joined(separator: " · ")
    return Button {
      showBedtime = true
    } label: {
      Label(on.isEmpty ? "Avondslot" : "Avondslot · \(on)", systemImage: "moon")
        .lineLimit(1)
    }
    .buttonStyle(NotisPrimaryButtonStyle())
  }

  private var header: some View {
    HStack(alignment: .center, spacing: 4) {
      VStack(alignment: .leading, spacing: 2) {
        Text(FeatureFlags.anyNotisStone && !FeatureFlags.bedtimeInMyNotis ? "Profielen" : "Mijn NOTIS")
          .font(.satoshi(28, .bold))
          .tracking(-0.5)
          .foregroundStyle(NotisBrand.ink)
        if !FeatureFlags.anyNotisStone {
          Text("Je profielen en stenen")
            .font(.satoshi(14))
            .foregroundStyle(NotisBrand.inkSoft)
        }
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

  private func sectionTitle(_ title: LocalizedStringKey) -> some View {
    Text(title)
      .font(.satoshi(18, .bold))
      .foregroundStyle(NotisBrand.ink)
      .padding(.horizontal, 4)
  }

  // MARK: - Pairing

  private func startPairing() {
    scanner.onTagScanned = { result in
      scanner.resultErrorMessage = nil
      if let existing = BlockedProfiles.findNotisStone(withTag: result.id, in: context) {
        let name = existing.notisStoneName(tag: result.id) ?? existing.name
        errorMessage = String(localized: "Deze NOTIS is al gekoppeld: \(name)")
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

  /// Closing the sheet still keeps the stone, as on Android: it starts the top profile.
  private func finishNewStone() {
    defer {
      newStoneChoice = nil
      pendingTag = nil
    }
    let hadProfiles = !profiles.isEmpty
    let tag = newStoneChoice?.tag ?? pendingTag
    guard let tag else { return }
    do {
      let profile = try BlockedProfiles.pairNotisStone(
        tag: tag,
        name: newStoneChoice?.name ?? defaultStoneName,
        profile: newStoneChoice?.profile,
        in: context
      )
      // Without any profile the stone got a fresh one: choose its apps now.
      if !hadProfiles && newStoneChoice != nil {
        profileToEdit = profile
      }
    } catch {
      errorMessage = error.localizedDescription
    }
  }

  // MARK: - Editing

  private func move(_ stone: StoneRef, to profile: BlockedProfiles) {
    do {
      try BlockedProfiles.moveNotisStone(tag: stone.tag, to: profile, in: context)
    } catch {
      errorMessage = error.localizedDescription
    }
  }

  private func renameStone() {
    guard let stone = stoneToRename, let name = trimmedName else { return }
    do {
      try BlockedProfiles.renameNotisStone(tag: stone.tag, to: name, in: context)
    } catch {
      errorMessage = error.localizedDescription
    }
  }

  private func removeStone(_ stone: StoneRef) {
    do {
      try BlockedProfiles.removeNotisStone(tag: stone.tag, in: context)
    } catch {
      errorMessage = error.localizedDescription
    }
  }

  private func saveProfile(_ edit: ProfileEdit, name: String, icon: NotisProfileIcon) {
    do {
      if let profile = edit.profile {
        try BlockedProfiles.renameNotisProfile(profile, to: name, in: context)
        BlockedProfiles.setNotisIcon(icon, for: profile)
      } else {
        let profile = try BlockedProfiles.createNotisProfile(in: context, name: name)
        BlockedProfiles.setNotisIcon(icon, for: profile)
        newProfile = profile
      }
    } catch {
      errorMessage = error.localizedDescription
    }
  }

  /// Straight on to choosing a new profile's apps.
  private func openNewProfileApps() {
    guard let profile = newProfile else { return }
    newProfile = nil
    profileToEdit = profile
  }

  private var trimmedName: String? {
    let trimmed = nameText.trimmingCharacters(in: .whitespacesAndNewlines)
    return trimmed.isEmpty ? nil : String(trimmed.prefix(100))
  }

  private func deleteMessage(for profile: BlockedProfiles) -> String {
    if !FeatureFlags.homeProfilePicker, !profile.notisStones.isEmpty, let heir = BlockedProfiles.notisProfileHeir(of: profile, in: context) {
      return String(localized: "De stenen ervan starten voortaan \(heir.name).")
    }
    return String(localized: "De apps die je ervoor hebt gekozen, verdwijnen.")
  }

  private func deleteProfile(_ profile: BlockedProfiles) {
    guard !isLocked else {
      errorMessage = String(localized: "Een profiel kan niet worden verwijderd tijdens een actieve sessie.")
      return
    }
    do {
      try BlockedProfiles.deleteNotisProfile(profile, in: context)
    } catch {
      errorMessage = error.localizedDescription
    }
  }
}

/// A stone in "Mijn NOTIS": its tag, its name and the profile it starts.
private struct StoneRef: Identifiable {
  let tag: String
  let name: String
  let profile: BlockedProfiles
  var id: String { tag }
}

private struct PairingTag: Identifiable {
  let tag: String
  var id: String { tag }
}

/// What the new-stone sheet decided; acted on once the sheet is gone.
private struct NewStoneChoice {
  let tag: String
  let name: String
  let profile: BlockedProfiles?
}

/// What the profile edit sheet edits: a new profile (`profile` nil) or an existing one.
private struct ProfileEdit: Identifiable {
  let profile: BlockedProfiles?
  let id = UUID()
}

// MARK: - Cards

/// A profile's icon beside its name, the size of a stone glyph (Android: `ProfileGlyph`).
struct NotisProfileGlyph: View {
  var icon: NotisProfileIcon = .apps
  var size: CGFloat = 52

  var body: some View {
    Image(systemName: icon.symbol)
      .font(.system(size: size * 0.42))
      .foregroundStyle(NotisBrand.mandarinDark)
      .frame(width: size, height: size)
      .background(NotisBrand.mandarinDark.opacity(0.1), in: Circle())
  }
}

/// A stone or a profile in "Mijn NOTIS": tap to open, ⋮ to rename or delete.
private struct NotisItemCard<Leading: View>: View {
  let name: String
  let subtitle: String
  let highlight: Bool
  let isLocked: Bool
  let onOpen: () -> Void
  let renameLabel: LocalizedStringKey
  let onRename: () -> Void
  let onDelete: () -> Void
  @ViewBuilder let leading: () -> Leading

  var body: some View {
    HStack(spacing: 14) {
      Button(action: onOpen) {
        HStack(spacing: 14) {
          leading()
          VStack(alignment: .leading, spacing: 2) {
            Text(name)
              .font(.satoshi(17, .bold))
              .foregroundStyle(NotisBrand.ink)
            Text(subtitle)
              .font(.satoshi(14))
              .foregroundStyle(highlight ? NotisBrand.mandarinDark : NotisBrand.inkSoft)
          }
          Spacer(minLength: 0)
        }
        .contentShape(Rectangle())
      }
      .buttonStyle(.plain)
      .disabled(isLocked)

      Menu {
        Button(action: onRename) {
          Label(renameLabel, systemImage: "pencil")
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
}

// MARK: - Sheets

/// Android's `NewStoneProfileSheet`: name the stone and choose the profile it starts.
private struct NewStoneProfileSheet: View {
  let defaultName: String
  let profiles: [BlockedProfiles]
  /// Off with the Home picker: a stone has no profile of its own then.
  let askProfile: Bool
  let onConfirm: (String, BlockedProfiles?) -> Void

  @State private var name = ""
  @State private var profile: BlockedProfiles?

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

        if profiles.isEmpty {
          Text("Deze steen krijgt een nieuw profiel. Daarna kies je de apps.")
            .font(.satoshi(14))
            .foregroundStyle(NotisBrand.inkSoft)
        } else if askProfile {
          Text("Welk profiel start deze steen?")
            .font(.satoshi(16, .bold))
            .foregroundStyle(NotisBrand.ink)
            .padding(.top, 4)

          ForEach(profiles) { option in
            NotisChoiceRow(
              title: option.name,
              subtitle: option.notisAppsSummary,
              isSelected: profile?.id == option.id
            ) { profile = option }
          }
        }

        Button(profiles.isEmpty ? "Apps kiezen" : "Koppelen") {
          let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
          onConfirm(trimmed.isEmpty ? defaultName : String(trimmed.prefix(100)), profile)
        }
        .buttonStyle(NotisPrimaryButtonStyle())
        .padding(.top, 4)
      }
      .padding(.horizontal, 20)
      .padding(.bottom, 16)
    }
    .onAppear {
      if name.isEmpty { name = defaultName }
      if profile == nil { profile = profiles.first }
    }
  }
}

/// New profile or "Bewerken": its name and icon (Android: `ProfileEditSheet`).
struct NotisProfileEditSheet: View {
  let title: LocalizedStringKey
  let initialName: String
  let initialIcon: NotisProfileIcon
  let onSave: (String, NotisProfileIcon) -> Void

  @State private var name = ""
  @State private var icon: NotisProfileIcon = .apps
  @State private var isLoaded = false

  private let columns = Array(repeating: GridItem(.flexible(), spacing: 10), count: 6)

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 12) {
        HStack(spacing: 12) {
          NotisProfileGlyph(icon: icon, size: 48)
          Text(title)
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

        Text("Icoon")
          .font(.satoshi(16, .bold))
          .foregroundStyle(NotisBrand.ink)
          .padding(.top, 4)

        LazyVGrid(columns: columns, spacing: 10) {
          ForEach(NotisProfileIcon.allCases) { option in
            let isSelected = option == icon
            Button {
              icon = option
            } label: {
              Image(systemName: option.symbol)
                .font(.system(size: 20))
                .foregroundStyle(isSelected ? .white : NotisBrand.mandarinDark)
                .frame(maxWidth: .infinity)
                .aspectRatio(1, contentMode: .fit)
                .background(
                  Circle().fill(isSelected ? NotisBrand.mandarinDark : NotisBrand.mandarinDark.opacity(0.1))
                )
            }
            .buttonStyle(.plain)
          }
        }

        Button("Opslaan") {
          let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
          onSave(trimmed.isEmpty ? initialName : String(trimmed.prefix(100)), icon)
        }
        .buttonStyle(NotisPrimaryButtonStyle())
        .padding(.top, 8)
      }
      .padding(.horizontal, 20)
      .padding(.bottom, 16)
    }
    .onAppear {
      guard !isLoaded else { return }
      name = initialName
      icon = initialIcon
      isLoaded = true
    }
  }
}

/// Tap a stone in "Mijn NOTIS": choose the profile it starts; a tap saves.
private struct StoneProfileSheet: View {
  let stone: StoneRef
  let profiles: [BlockedProfiles]
  let onChoose: (BlockedProfiles) -> Void

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 10) {
        Text("Profiel voor \(stone.name)")
          .font(.satoshi(20, .bold))
          .foregroundStyle(NotisBrand.ink)
          .padding(.top, 28)
        Text("Welk profiel start deze steen?")
          .font(.satoshi(14))
          .foregroundStyle(NotisBrand.inkSoft)
          .padding(.bottom, 6)

        ForEach(profiles) { profile in
          NotisChoiceRow(
            title: profile.name,
            subtitle: profile.notisAppsSummary,
            isSelected: stone.profile.id == profile.id
          ) { onChoose(profile) }
        }
      }
      .padding(.horizontal, 20)
      .padding(.bottom, 16)
    }
  }
}

/// A radio row (Android's `AppSourceOption`).
struct NotisChoiceRow: View {
  let title: String
  let subtitle: String
  let isSelected: Bool
  let onTap: () -> Void

  var body: some View {
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

#Preview {
  MijnNotisProfilesView()
    .environmentObject(StrategyManager())
}
