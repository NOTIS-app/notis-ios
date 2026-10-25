import SwiftUI

/// Green for a stone that is ready, as on Android.
private let notisSuccess = Color(hex: 0x2E9E5B)

private func kindName(_ kind: StoneKind?) -> String {
  switch kind {
  case .school: return String(localized: "schoolsteen")
  case .personal: return String(localized: "persoonlijke steen")
  case nil: return String(localized: "steen zonder NOTIS-zegel")
  }
}

/// Header of the full-screen admin tools: title and a close button.
private struct AdminHeader: View {
  let title: String
  let onClose: () -> Void

  var body: some View {
    HStack {
      Text(title)
        .font(.satoshi(28, .bold))
        .foregroundStyle(NotisBrand.ink)
      Spacer()
      Button(action: onClose) {
        Image(systemName: "xmark")
          .font(.system(size: 17, weight: .semibold))
          .foregroundStyle(NotisBrand.ink)
          .frame(width: 40, height: 40)
      }
      .accessibilityLabel("Sluiten")
    }
    .padding(.top, 12)
  }
}

/// The big green check or red cross after a stone, with what happened.
private struct OutcomeBadge: View {
  let isSuccess: Bool
  let text: String

  var body: some View {
    VStack(spacing: 8) {
      Image(systemName: isSuccess ? "checkmark.circle.fill" : "xmark.circle.fill")
        .font(.system(size: 64))
        .foregroundStyle(isSuccess ? notisSuccess : NotisPalette.light.error)
      Text(text)
        .font(.satoshi(17, .bold))
        .foregroundStyle(NotisBrand.ink)
        .multilineTextAlignment(.center)
    }
  }
}

// MARK: - Stenen voorbereiden

/// Full-screen "Stenen voorbereiden" for NOTIS admins (production), as on Android: pick
/// personal or school, then the stones one by one. Each gets a seal ([StoneSeal]); a stone with
/// the other seal is rewritten.
struct NotisStonePrepareView: View {
  let onClose: () -> Void

  @State private var kind = StoneKind.personal
  /// Off by default: a locked stone can never be rewritten between personal and school.
  @State private var lock = false
  @State private var isBusy = false
  @State private var outcome: StonePrepareOutcome?
  @State private var count = 0
  @State private var writer = NotisStoneWriter()

  var body: some View {
    ZStack {
      NotisBrand.paper.ignoresSafeArea()
      ScrollView {
        VStack(alignment: .leading, spacing: 12) {
          AdminHeader(title: String(localized: "Stenen voorbereiden"), onClose: onClose)
          Text(
            "Kies waar de stenen voor zijn en houd ze daarna een voor een tegen je iPhone. Elke steen krijgt een NOTIS-zegel: een persoonlijke steen koppelt alleen als eigen steen, een schoolsteen alleen aan een lokaal."
          )
          .font(.satoshi(15))
          .foregroundStyle(NotisBrand.inkSoft)

          HStack(spacing: 8) {
            kindOption(.personal, icon: "person", title: String(localized: "Persoonlijke steen"))
            kindOption(.school, icon: "door.left.hand.open", title: String(localized: "Schoolsteen"))
          }

          HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
              Text("Steen vergrendelen")
                .font(.satoshi(16, .bold))
                .foregroundStyle(NotisBrand.ink)
              Text(
                "Maakt de chip voorgoed alleen-lezen, zodat niemand hem kan wissen of wijzigen. Een vergrendelde steen kun je nooit meer omzetten tussen persoonlijk en school. Laat dit uit zolang je nog test."
              )
              .font(.satoshi(13))
              .foregroundStyle(NotisBrand.inkSoft)
            }
            Spacer(minLength: 0)
            Toggle("", isOn: $lock)
              .labelsHidden()
              .tint(NotisBrand.mandarinDark)
              .disabled(isBusy)
          }
          .padding(16)
          .notisCard()

          resultCard
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 32)
      }
    }
  }

  private func kindOption(_ option: StoneKind, icon: String, title: String) -> some View {
    let isSelected = kind == option
    return Button {
      kind = option
      outcome = nil
    } label: {
      VStack(spacing: 6) {
        Image(systemName: icon)
          .font(.system(size: 20))
          .foregroundStyle(isSelected ? NotisBrand.mandarinDark : NotisBrand.inkSoft)
        Text(title)
          .font(.satoshi(15, .bold))
          .foregroundStyle(NotisBrand.ink)
      }
      .frame(maxWidth: .infinity)
      .padding(16)
      .background(
        isSelected ? NotisBrand.mandarinDark.opacity(0.1) : NotisBrand.card,
        in: RoundedRectangle(cornerRadius: 18)
      )
      .overlay(
        RoundedRectangle(cornerRadius: 18)
          .strokeBorder(isSelected ? NotisBrand.mandarinDark : NotisBrand.ink.opacity(0.12), lineWidth: isSelected ? 2 : 1)
      )
    }
    .buttonStyle(.plain)
    .disabled(isBusy)
  }

  private var resultCard: some View {
    let tint: Color = {
      guard let outcome else { return NotisBrand.mandarinDark }
      return outcome.isSuccess ? notisSuccess : NotisPalette.light.error
    }()
    return VStack(spacing: 16) {
      if let outcome, outcome != .cancelled {
        OutcomeBadge(isSuccess: outcome.isSuccess, text: text(for: outcome))
      }
      NotisPrimaryButton(
        title: kind == .school
          ? String(localized: "Schoolsteen scannen") : String(localized: "Persoonlijke steen scannen"),
        isBusy: isBusy,
        isEnabled: true
      ) {
        Task { await prepare() }
      }
      if count > 0 {
        Text(count == 1 ? "1 steen voorbereid" : "\(count) stenen voorbereid")
          .font(.satoshi(14, .bold))
          .foregroundStyle(NotisBrand.inkSoft)
      }
    }
    .frame(maxWidth: .infinity)
    .padding(24)
    .background(tint.opacity(0.12), in: RoundedRectangle(cornerRadius: 24))
  }

  private func prepare() async {
    isBusy = true
    let result = await writer.prepare(kind: kind, lock: lock) { uid, kind in
      try await NotisAdmin.shared.sealStone(uid: uid, kind: kind)
    }
    outcome = result
    if case .prepared = result { count += 1 }
    isBusy = false
  }

  private func text(for outcome: StonePrepareOutcome) -> String {
    switch outcome {
    case .prepared(let kind, let locked, let previous, let unlinkedRoom):
      var lines: [String] = []
      if let previous {
        lines.append(String(localized: "Omgezet: \(kindName(previous)) → \(kindName(kind))"))
      } else if locked {
        lines.append(String(localized: "Klaar en vergrendeld: \(kindName(kind))"))
      } else {
        lines.append(String(localized: "Klaar: \(kindName(kind))"))
      }
      if let unlinkedRoom {
        lines.append(String(localized: "Niet meer gekoppeld aan \(unlinkedRoom)."))
      }
      return lines.joined(separator: "\n")
    case .alreadySealed(let kind):
      return String(localized: "Deze steen is al een \(kindName(kind)).")
    case .readOnly(let kind):
      return String(localized: "Deze steen is vergrendeld als \(kindName(kind)) en kan niet meer veranderen.")
    case .lost:
      return String(localized: "Te snel weggehaald. Houd de steen nog eens tegen je iPhone.")
    case .unsupported:
      return String(localized: "Op deze chip past geen NOTIS-zegel.")
    case .wrongKey:
      return String(localized: "De sleutel van de server past niet bij deze app. Er is niets geschreven.")
    case .failed(let message):
      return message
    case .cancelled:
      return ""
    }
  }
}

// MARK: - Stenen koppelen

/// Full-screen "Stenen koppelen" for NOTIS admins, as on Android: pick a school, then link its
/// stones room after room. After each stone the next room without one becomes the target; tap a
/// room to pick it yourself. Only a sealed school stone links.
struct NotisStoneLinkView: View {
  let onClose: () -> Void

  private enum Feedback: Equatable {
    case linked(String)
    /// The stone [uid] already belongs to [room]; the admin decides.
    case taken(uid: String, room: String)
    case failed(String)
  }

  @State private var schools: [AdminSchool]?
  @State private var school: AdminSchool?
  @State private var rooms: [LinkRoom]?
  @State private var targetId: String?
  @State private var isBusy = false
  @State private var feedback: Feedback?
  @State private var scanner = NFCScannerUtil()

  private var target: LinkRoom? { rooms?.first { $0.id == targetId } }

  var body: some View {
    ZStack {
      NotisBrand.paper.ignoresSafeArea()
      ScrollView {
        VStack(alignment: .leading, spacing: 12) {
          AdminHeader(title: String(localized: "Stenen koppelen"), onClose: onClose)
          if let school {
            HStack {
              Text(school.name).font(.satoshi(14)).foregroundStyle(NotisBrand.inkSoft)
              Button("Andere school") {
                self.school = nil
                rooms = nil
                targetId = nil
                feedback = nil
              }
              .font(.satoshi(14, .medium))
              .foregroundStyle(NotisBrand.mandarinDark)
              .disabled(isBusy)
            }
            roomsContent
          } else {
            schoolPicker
          }
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 32)
      }
    }
    .task { await loadSchools() }
  }

  @ViewBuilder
  private var schoolPicker: some View {
    if let schools {
      if schools.isEmpty {
        message("Nog geen scholen. Voeg ze toe op de beheerpagina.")
      } else {
        Text("Kies de school waarvan je de stenen koppelt.")
          .font(.satoshi(15))
          .foregroundStyle(NotisBrand.inkSoft)
        ForEach(schools) { option in
          listRow(icon: "graduationcap", title: option.name, subtitle: nil, isHighlighted: false) {
            Task { await choose(option) }
          }
        }
      }
    } else if case .failed(let text) = feedback {
      message(text, isError: true)
    } else {
      ProgressView().tint(NotisBrand.mandarinDark).frame(maxWidth: .infinity).padding(32)
    }
  }

  @ViewBuilder
  private var roomsContent: some View {
    if let rooms {
      if rooms.isEmpty {
        message("Deze school heeft nog geen lokalen. Voeg ze toe op de beheerpagina.")
      } else {
        targetCard(rooms)
        Text("Lokalen")
          .font(.satoshi(15, .bold))
          .foregroundStyle(NotisBrand.ink)
          .padding(.top, 16)
        ForEach(rooms) { room in
          listRow(
            icon: room.stoneCount > 0 ? "checkmark.circle" : "door.left.hand.open",
            title: room.name,
            subtitle: room.stoneCount == 0
              ? String(localized: "Nog geen steen")
              : room.stoneCount == 1 ? String(localized: "1 steen") : String(localized: "\(room.stoneCount) stenen"),
            isHighlighted: room.id == targetId
          ) {
            targetId = room.id
            feedback = nil
          }
        }
      }
    } else if case .failed(let text) = feedback {
      message(text, isError: true)
    } else {
      ProgressView().tint(NotisBrand.mandarinDark).frame(maxWidth: .infinity).padding(32)
    }
  }

  /// What the next stone does: "Tik de steen voor B1.02", or what just happened.
  private func targetCard(_ rooms: [LinkRoom]) -> some View {
    VStack(spacing: 12) {
      if let feedback {
        switch feedback {
        case .linked(let room):
          OutcomeBadge(isSuccess: true, text: String(localized: "\(room) gekoppeld"))
        case .taken(_, let room):
          OutcomeBadge(isSuccess: false, text: String(localized: "Deze steen hoort al bij \(room)."))
        case .failed(let text):
          OutcomeBadge(isSuccess: false, text: text)
        }
      }
      if let target {
        if case .taken(let uid, _) = feedback {
          NotisPrimaryButton(title: String(localized: "Toch koppelen aan \(target.name)"), isBusy: isBusy, isEnabled: true) {
            Task { await link(uid: uid, to: target, replace: true) }
          }
          Button("Overslaan") { feedback = nil }
            .font(.satoshi(15, .medium))
            .foregroundStyle(NotisBrand.inkSoft)
        } else {
          Text("Tik de steen voor")
            .font(.satoshi(15))
            .foregroundStyle(NotisBrand.inkSoft)
          Text(target.name)
            .font(.satoshi(40, .bold))
            .foregroundStyle(NotisBrand.ink)
            .multilineTextAlignment(.center)
          NotisPrimaryButton(title: String(localized: "Steen scannen"), isBusy: isBusy, isEnabled: true) {
            scan(for: target)
          }
        }
      } else {
        Text(
          rooms.allSatisfy { $0.stoneCount > 0 }
            ? "Alle lokalen hebben een steen. Tik hieronder op een lokaal om er nog een steen aan te koppelen."
            : "Tik hieronder op een lokaal en houd dan de steen tegen je iPhone."
        )
        .font(.satoshi(15))
        .foregroundStyle(NotisBrand.ink)
        .multilineTextAlignment(.center)
      }
    }
    .frame(maxWidth: .infinity)
    .padding(24)
    .background(
      targetId != nil ? NotisBrand.mandarinDark.opacity(0.1) : NotisBrand.card,
      in: RoundedRectangle(cornerRadius: 24)
    )
  }

  private func message(_ text: String, isError: Bool = false) -> some View {
    Text(text)
      .font(.satoshi(15))
      .foregroundStyle(isError ? NotisPalette.light.error : NotisBrand.inkSoft)
      .multilineTextAlignment(.center)
      .frame(maxWidth: .infinity)
      .padding(32)
  }

  private func listRow(
    icon: String, title: String, subtitle: String?, isHighlighted: Bool, action: @escaping () -> Void
  ) -> some View {
    Button(action: action) {
      HStack(spacing: 14) {
        Image(systemName: icon)
          .font(.system(size: 18))
          .foregroundStyle(NotisBrand.mandarinDark)
          .frame(width: 36, height: 36)
          .background(NotisBrand.mandarinDark.opacity(0.1), in: RoundedRectangle(cornerRadius: 10))
        VStack(alignment: .leading, spacing: 1) {
          Text(title).font(.satoshi(16, .medium)).foregroundStyle(NotisBrand.ink)
          if let subtitle {
            Text(subtitle).font(.satoshi(13)).foregroundStyle(NotisBrand.inkSoft)
          }
        }
        Spacer(minLength: 0)
      }
      .padding(.horizontal, 16)
      .padding(.vertical, 12)
      .background(NotisBrand.card, in: RoundedRectangle(cornerRadius: 18))
      .overlay(
        RoundedRectangle(cornerRadius: 18)
          .strokeBorder(isHighlighted ? NotisBrand.mandarinDark : NotisBrand.ink.opacity(0.12), lineWidth: isHighlighted ? 2 : 1)
      )
    }
    .buttonStyle(.plain)
    .disabled(isBusy)
  }

  // MARK: Actions

  private func loadSchools() async {
    do {
      schools = try await NotisAdmin.shared.schools()
    } catch {
      feedback = .failed(error.localizedDescription)
    }
  }

  private func choose(_ option: AdminSchool) async {
    isBusy = true
    defer { isBusy = false }
    feedback = nil
    school = option
    do {
      let loaded = try await NotisAdmin.shared.rooms(schoolId: option.id)
      rooms = loaded
      targetId = loaded.first { $0.stoneCount == 0 }?.id
    } catch {
      feedback = .failed(error.localizedDescription)
    }
  }

  private func scan(for room: LinkRoom) {
    feedback = nil
    scanner.onTagScanned = { result in
      // Only a sealed school stone links to a room (the server checks this too).
      if FeatureFlags.sealedStones && result.seal != .school {
        let refusal = result.seal == .personal
          ? String(localized: "Dit is een persoonlijke steen, geen schoolsteen")
          : String(localized: "Dit is geen NOTIS-steen")
        scanner.resultErrorMessage = refusal
        feedback = .failed(refusal)
        return
      }
      scanner.resultMessage = String(localized: "Steen gelezen")
      Task { await link(uid: result.id, to: room, replace: false) }
    }
    scanner.onError = { message in
      if feedback == nil { feedback = .failed(message) }
    }
    scanner.resultMessage = nil
    scanner.scan(alertMessage: String(localized: "Houd de steen voor \(room.name) tegen de bovenkant van je iPhone"))
  }

  private func link(uid: String, to room: LinkRoom, replace: Bool) async {
    guard let school else { return }
    isBusy = true
    defer { isBusy = false }
    do {
      switch try await NotisAdmin.shared.linkStone(roomId: room.id, uid: uid, replace: replace) {
      case .linked:
        let loaded = try await NotisAdmin.shared.rooms(schoolId: school.id)
        rooms = loaded
        targetId = nextRoomWithoutStone(loaded, after: room.id)?.id
        feedback = .linked(room.name)
      case .taken(let current):
        feedback = .taken(uid: uid, room: current)
      case .otherSchool:
        feedback = .failed(String(localized: "Deze steen hoort bij een andere school."))
      case .notSchoolStone:
        feedback = .failed(String(localized: "Dit is geen schoolsteen van NOTIS. Bereid hem eerst voor als schoolsteen."))
      }
    } catch {
      feedback = .failed(error.localizedDescription)
    }
  }
}
