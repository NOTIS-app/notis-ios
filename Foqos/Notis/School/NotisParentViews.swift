import CodeScanner
import SwiftUI

// MARK: - Child's phone: "Ouder koppelen"

/// Child's phone: shows the code a parent enters, and confirms once they linked. The server
/// can't push to this phone, so it checks every few seconds while the sheet is open, as on
/// Android.
struct NotisParentLinkSheet: View {
  @ObservedObject var school: NotisSchool
  /// Whether NOTIS is locked right now: the first status the parent sees.
  let isLocked: Bool
  let onDone: () -> Void

  private enum Phase: Equatable {
    case loading
    case showing(ParentLinkCode)
    case linked
    case expired
    case offline
  }

  @State private var phase = Phase.loading
  @State private var attempt = 0

  var body: some View {
    VStack(spacing: 14) {
      Text("Ouder koppelen")
        .font(.satoshi(22, .bold))
        .foregroundStyle(NotisBrand.ink)
        .frame(maxWidth: .infinity, alignment: .leading)

      switch phase {
      case .loading:
        ProgressView().tint(NotisBrand.mandarinDark).padding(24)
      case .showing(let code):
        Text("Je ouder scant deze QR-code, of vult de code in, in de eigen NOTIS-app bij Instellingen → Ik ben ouder → Kind toevoegen.")
          .font(.satoshi(14))
          .foregroundStyle(NotisBrand.inkSoft)
          .multilineTextAlignment(.center)
        if let qr = ParentLinkQR.image(code.code) {
          Image(uiImage: qr)
            .interpolation(.none)
            .resizable()
            .scaledToFit()
            .frame(width: 200, height: 200)
            .padding(8)
            .background(.white, in: RoundedRectangle(cornerRadius: 12))
            .accessibilityLabel("QR-code om een ouder te koppelen")
        }
        Text(code.code)
          .font(.satoshi(40, .bold))
          .tracking(6)
          .foregroundStyle(NotisBrand.ink)
        Text("Geldig tot \(code.expiresAt.formatted(date: .omitted, time: .shortened))")
          .font(.satoshi(13))
          .foregroundStyle(NotisBrand.inkSoft)
        // An iPhone can't share its apps, so a parent only sees the lock status.
        Text("Je ouder ziet alleen of NOTIS gelocked is, nooit welke apps je gebruikt. Je kunt altijd ontkoppelen.")
          .font(.satoshi(13))
          .foregroundStyle(NotisBrand.inkSoft)
          .multilineTextAlignment(.center)
      case .linked:
        Text("Gekoppeld! Je ouder kan nu zien of NOTIS gelocked is.")
          .font(.satoshi(15))
          .foregroundStyle(NotisBrand.ink)
          .multilineTextAlignment(.center)
      case .expired:
        Text("Deze code is verlopen.")
          .font(.satoshi(15))
          .foregroundStyle(NotisBrand.inkSoft)
      case .offline:
        Text("Geen verbinding. Controleer je internet en probeer het opnieuw.")
          .font(.satoshi(15))
          .foregroundStyle(NotisPalette.light.error)
          .multilineTextAlignment(.center)
      }

      if phase == .expired || phase == .offline {
        NotisPrimaryButton(title: String(localized: "Nieuwe code"), isBusy: false, isEnabled: true) {
          attempt += 1
        }
      }
      Button(phase == .expired || phase == .offline ? "Annuleren" : "Sluiten", action: onDone)
        .font(.satoshi(15, .medium))
        .foregroundStyle(NotisBrand.inkSoft)
        .frame(maxWidth: .infinity)
    }
    .padding(24)
    .task(id: attempt) { await run() }
  }

  private func run() async {
    phase = .loading
    let before = Set(school.guardians.map(\.guardianUserId))
    guard let code = await school.createLinkCode() else {
      phase = .offline
      return
    }
    phase = .showing(code)
    while Date() < code.expiresAt && !Task.isCancelled {
      try? await Task.sleep(for: .seconds(3))
      await school.refreshGuardians()
      if school.guardians.contains(where: { !before.contains($0.guardianUserId) }) {
        phase = .linked
        // Starts reporting right away, so the parent sees a status.
        await school.report(isLocked ? .locked : .unlocked)
        return
      }
    }
    if !Task.isCancelled { phase = .expired }
  }
}

// MARK: - Parent's phone: "Kind toevoegen"

/// Parent's phone: the code from the child's phone and the child's name.
struct NotisAddChildSheet: View {
  let onDone: (_ linked: Bool) -> Void

  @State private var code = ""
  @State private var name = ""
  @State private var parentName = ""
  @State private var isBusy = false
  @State private var errorText: String?
  @State private var isScanning = false

  var body: some View {
    VStack(alignment: .leading, spacing: 14) {
      Text("Kind toevoegen")
        .font(.satoshi(22, .bold))
        .foregroundStyle(NotisBrand.ink)
      Text("Ga op de telefoon van je kind naar Instellingen → Ouder koppelen. Scan de QR-code die daar verschijnt, of vul de code in.")
        .font(.satoshi(14))
        .foregroundStyle(NotisBrand.inkSoft)
      Button {
        errorText = nil
        isScanning = true
      } label: {
        Label("QR-code scannen", systemImage: "qrcode.viewfinder")
      }
      .buttonStyle(NotisOutlinedButtonStyle())
      .disabled(isBusy)
      NotisTextField(title: "Koppelcode", text: $code, isSecure: false)
        .textInputAutocapitalization(.characters)
        .autocorrectionDisabled()
      NotisTextField(title: "Naam van je kind", text: $name, isSecure: false)
        .textInputAutocapitalization(.words)
      // Shown on the child's phone ("Mama").
      NotisTextField(title: "Jouw naam, zoals je kind je noemt", text: $parentName, isSecure: false)
        .textInputAutocapitalization(.words)
      if let errorText {
        Text(errorText).font(.satoshi(13)).foregroundStyle(.red)
      }
      NotisPrimaryButton(
        title: String(localized: "Koppelen"),
        isBusy: isBusy,
        isEnabled: !code.trimmingCharacters(in: .whitespaces).isEmpty
          && !name.trimmingCharacters(in: .whitespaces).isEmpty
          && !parentName.trimmingCharacters(in: .whitespaces).isEmpty
      ) {
        Task { await link() }
      }
      Button("Annuleren") { onDone(false) }
        .font(.satoshi(15, .medium))
        .foregroundStyle(NotisBrand.inkSoft)
        .frame(maxWidth: .infinity)
        .disabled(isBusy)
    }
    .padding(24)
    .sheet(isPresented: $isScanning) {
      LabeledCodeScannerView(
        heading: String(localized: "QR-code scannen"),
        subtitle: String(localized: "Richt je camera op de QR-code op de telefoon van je kind.")
      ) { result in
        isScanning = false
        guard case .success(let scan) = result else { return }
        if let scanned = ParentLinkQR.parse(scan.string) {
          code = scanned
        } else {
          errorText = String(localized: "Dit is geen NOTIS-koppelcode. Scan de QR-code bij Ouder koppelen.")
        }
      }
    }
  }

  private func link() async {
    isBusy = true
    errorText = nil
    do {
      try await NotisParent.shared.linkChild(code: code, name: String(name.prefix(40)), parentName: parentName)
      onDone(true)
    } catch NotisParent.LinkError.codeInvalid {
      errorText = String(localized: "Deze code is onbekend of verlopen. Vraag om een nieuwe code.")
    } catch NotisParent.LinkError.notParent {
      errorText = NotisTeacherLoginSheet.message(for: .notParent)
    } catch {
      errorText = String(localized: "Koppelen lukte niet. Controleer je internet.")
    }
    isBusy = false
  }
}

// MARK: - Parent's phone: the child's apps

/// Parent's phone: which apps the child may use on their own stones, chosen from the apps the
/// child's Android phone reported. An iPhone reports no apps (Apple doesn't allow it).
struct NotisChildAppsSheet: View {
  let child: ChildStatus
  let onDone: () -> Void

  @State private var apps: [ReportedApp]?
  @State private var rule: [String]?
  @State private var selection: Set<String> = []
  @State private var isBusy = false
  @State private var errorText: String?

  var body: some View {
    NavigationStack {
      Group {
        if let apps {
          List {
            Section {
              Text(
                apps.isEmpty
                  ? "De telefoon van \(child.name) heeft nog geen app-lijst doorgegeven. Open NOTIS op die telefoon en probeer het daarna opnieuw. Een iPhone geeft geen apps door."
                  : "Kies welke apps \(child.name) mag gebruiken als de telefoon op slot staat. \(child.name) kan apps uitzetten, maar niet toevoegen. Wijzigingen staan binnen 15 minuten op de telefoon, of zodra NOTIS daar opent."
              )
              .font(.satoshi(14))
              .foregroundStyle(NotisBrand.inkSoft)
              if let errorText {
                Text(errorText).font(.satoshi(13)).foregroundStyle(.red)
              }
            }
            Section {
              ForEach(apps) { app in
                Toggle(isOn: binding(for: app.packageName)) {
                  Text(app.label).font(.satoshi(16))
                }
                .tint(NotisBrand.mandarinDark)
              }
            }
            if rule != nil {
              Section {
                Button("Lijst verwijderen, \(child.name) kiest weer zelf", role: .destructive) {
                  Task { await save(nil) }
                }
              }
            }
          }
        } else if let errorText {
          Text(errorText).font(.satoshi(15)).foregroundStyle(NotisPalette.light.error).padding(24)
        } else {
          ProgressView().tint(NotisBrand.mandarinDark)
        }
      }
      .navigationTitle("Apps voor \(child.name)")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("Annuleren", action: onDone)
        }
        ToolbarItem(placement: .confirmationAction) {
          Button("Opslaan") { Task { await save(Array(selection)) } }
            .disabled(isBusy || apps?.isEmpty != false)
        }
      }
    }
    .task { await load() }
  }

  private func binding(for package: String) -> Binding<Bool> {
    Binding(
      get: { selection.contains(package) },
      set: { isOn in
        if isOn { selection.insert(package) } else { selection.remove(package) }
      }
    )
  }

  private func load() async {
    do {
      let reported = try await NotisParent.shared.childApps(child)
      let current = try await NotisParent.shared.childRule(child)
      // Apps on the list the child's phone no longer reports still show, so they can go off.
      let known = Set(reported.map(\.packageName))
      apps = reported + (current ?? []).filter { !known.contains($0) }.map { ReportedApp(packageName: $0, label: $0) }
      rule = current
      selection = Set(current ?? [])
    } catch {
      errorText = String(localized: "Geen verbinding. Controleer je internet en probeer het opnieuw.")
    }
  }

  private func save(_ packages: [String]?) async {
    isBusy = true
    do {
      try await NotisParent.shared.setChildRule(child, packages: packages)
      onDone()
    } catch {
      errorText = String(localized: "Opslaan lukte niet. Controleer je internet.")
    }
    isBusy = false
  }
}

// MARK: - Status of a child

/// How a child's row looks: same symbols and texts as the live lists and Android's
/// `statusVisual`.
struct ChildStatusVisual {
  let icon: String
  let tint: Color
  let subtitle: String

  /// A phone silent for longer than this shows "geen contact", as on Android.
  private static let staleAfter: TimeInterval = 45 * 60

  init?(child: ChildStatus, now: Date) {
    guard let state = child.state, let changedAt = child.stateChangedAt, let lastSeen = child.lastSeen else {
      return nil
    }
    let since = changedAt.formatted(date: .omitted, time: .shortened)
    if now.timeIntervalSince(lastSeen) > Self.staleAfter {
      icon = "questionmark.circle"
      tint = NotisBrand.inkSoft
      subtitle = String(localized: "Geen contact sinds \(lastSeen.formatted(date: .omitted, time: .shortened))")
      return
    }
    switch state {
    case "locked":
      icon = "lock"
      tint = NotisBrand.mandarinDark
      subtitle = String(localized: "Gelocked sinds \(since)")
    case "emergency":
      icon = "exclamationmark.triangle"
      tint = Color(hex: 0xE0A030)
      subtitle = String(localized: "Noodontgrendeling sinds \(since)")
    default:
      icon = "lock.open"
      tint = NotisBrand.inkSoft
      subtitle = String(localized: "Niet gelocked · sinds \(since)")
    }
  }
}
