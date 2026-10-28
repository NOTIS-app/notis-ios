import SwiftUI

/// "Dit lokaal nu" (8e): who is checked in to the room today and whether they are locked.
/// Same order, symbols and texts as Android's `ClassLiveScreen` for a room. Refreshes every
/// 10 seconds while open.
struct NotisRoomLiveView: View {
  let room: TeacherRoom
  @ObservedObject var teacher: NotisTeacher
  let onClose: () -> Void

  @State private var students: [RoomStudent]?
  @State private var isOffline = false
  @State private var choiceOpenUntil: Date?
  @State private var checkoutOpenUntil: Date?
  @State private var confirmCheckout = false

  /// A phone silent for longer than this shows "geen contact", as on Android.
  private static let staleAfter: TimeInterval = 45 * 60

  private enum Kind: Int {
    case unlocked = 0, emergency, noContact, locked
  }

  private func isStale(_ student: RoomStudent, now: Date) -> Bool {
    now.timeIntervalSince(student.lastSeen) > Self.staleAfter
  }

  private func kind(_ student: RoomStudent, now: Date) -> Kind {
    // An iPhone can't report in the background: its last state stands ("laatst gezien").
    if !student.isIphone && isStale(student, now: now) { return .noContact }
    switch student.state {
    case "locked": return .locked
    case "emergency": return .emergency
    default: return .unlocked
    }
  }

  var body: some View {
    ZStack {
      NotisBrand.paper.ignoresSafeArea()
      VStack(alignment: .leading, spacing: 0) {
        HStack(alignment: .top) {
          VStack(alignment: .leading, spacing: 2) {
            Text(room.name)
              .font(.satoshi(28, .bold))
              .foregroundStyle(NotisBrand.ink)
            Text("LIVE")
              .font(.satoshi(12, .bold))
              .tracking(1)
              .foregroundStyle(NotisBrand.mandarinDark)
          }
          Spacer()
          Button(action: onClose) {
            Image(systemName: "xmark")
              .font(.system(size: 18, weight: .semibold))
              .foregroundStyle(NotisBrand.ink)
              .frame(width: 44, height: 44)
          }
          .accessibilityLabel("Sluiten")
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)

        TimelineView(.periodic(from: .now, by: 30)) { timeline in
          content(now: timeline.date)
        }
      }
    }
    .task(id: room.id) {
      while !Task.isCancelled {
        await reload()
        try? await Task.sleep(for: .seconds(10))
      }
    }
  }

  @ViewBuilder
  private func content(now: Date) -> some View {
    if let students {
      let sorted = students.sorted {
        let a = kind($0, now: now)
        let b = kind($1, now: now)
        if a != b { return a.rawValue < b.rawValue }
        if $0.tooMany != $1.tooMany { return $0.tooMany }
        return $0.displayName.localizedStandardCompare($1.displayName) == .orderedAscending
      }
      let lockedCount = students.filter { kind($0, now: now) == .locked }.count

      VStack(alignment: .leading, spacing: 8) {
        HStack(alignment: .lastTextBaseline, spacing: 4) {
          Text("\(lockedCount)")
            .font(.satoshi(48, .bold))
            .foregroundStyle(NotisBrand.ink)
          Text("/ \(students.count)")
            .font(.satoshi(24, .bold))
            .foregroundStyle(NotisBrand.inkSoft)
          Text("gelocked")
            .font(.satoshi(16))
            .foregroundStyle(NotisBrand.inkSoft)
            .padding(.leading, 6)
        }

        HStack(spacing: 8) {
          Button("Keuze openen") {
            Task { choiceOpenUntil = await teacher.openChoice(in: room) }
          }
          .font(.satoshi(15, .bold))
          .foregroundStyle(NotisBrand.mandarinDark)
          if let choiceOpenUntil {
            Text("Open tot \(choiceOpenUntil.formatted(date: .omitted, time: .shortened))")
              .font(.satoshi(13))
              .foregroundStyle(NotisBrand.inkSoft)
          }
        }

        // After the last lesson: 10 minutes to tap the stone and check out for the day.
        if FeatureFlags.roomCheckout {
          HStack(spacing: 8) {
            Button("Laatste les: uitchecken") { confirmCheckout = true }
              .font(.satoshi(15, .bold))
              .foregroundStyle(NotisBrand.mandarinDark)
            if let checkoutOpenUntil {
              Text("Open tot \(checkoutOpenUntil.formatted(date: .omitted, time: .shortened))")
                .font(.satoshi(13))
                .foregroundStyle(NotisBrand.inkSoft)
            }
          }
          .alert("Uitchecken voor vandaag?", isPresented: $confirmCheckout) {
            Button("Uitchecken openen") {
              Task { checkoutOpenUntil = await teacher.openCheckout(in: room) }
            }
            Button("Annuleren", role: .cancel) {}
          } message: {
            Text(
              "De leerlingen die in \(room.name) zijn ingecheckt, kunnen 10 minuten lang de steen van dit lokaal tikken: hun telefoon gaat dan van het slot en de stenen van school zetten hem vandaag niet meer op slot."
            )
          }
        }

        if isOffline {
          Text("Geen verbinding. De lijst wordt bijgewerkt zodra er weer internet is.")
            .font(.satoshi(13))
            .foregroundStyle(.red)
        }
      }
      .padding(.horizontal, 20)
      .padding(.vertical, 16)

      if students.isEmpty {
        Text("Nog niemand ingecheckt. Leerlingen tikken bij binnenkomst op de steen van dit lokaal.")
          .font(.satoshi(15))
          .foregroundStyle(NotisBrand.inkSoft)
          .multilineTextAlignment(.center)
          .frame(maxWidth: .infinity)
          .padding(32)
        Spacer()
      } else {
        ScrollView {
          LazyVStack(spacing: 8) {
            ForEach(sorted) { student in
              row(student, kind: kind(student, now: now))
            }
          }
          .padding(.horizontal, 16)
          .padding(.bottom, 24)
        }
      }
    } else {
      ProgressView()
        .tint(NotisBrand.mandarinDark)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
  }

  private func row(_ student: RoomStudent, kind: Kind) -> some View {
    let since = student.stateChangedAt.formatted(date: .omitted, time: .shortened)
    let (icon, tint, subtitle): (String, Color, String) =
      switch kind {
      case .locked: ("lock", NotisBrand.mandarinDark, String(localized: "Gelocked sinds \(since)"))
      case .emergency:
        ("exclamationmark.triangle", Color(hex: 0xE0A030), String(localized: "Noodontgrendeling sinds \(since)"))
      case .unlocked: ("lock.open", NotisBrand.inkSoft, String(localized: "Niet gelocked · sinds \(since)"))
      case .noContact:
        (
          "questionmark.circle", NotisBrand.inkSoft,
          String(localized: "Geen contact sinds \(student.lastSeen.formatted(date: .omitted, time: .shortened))")
        )
      }

    return HStack(spacing: 12) {
      Image(systemName: icon)
        .font(.system(size: 18))
        .foregroundStyle(tint)
        .frame(width: 40, height: 40)
        .background(tint.opacity(0.12), in: RoundedRectangle(cornerRadius: 12))
      VStack(alignment: .leading, spacing: 1) {
        Text(student.displayName)
          .font(.satoshi(16, .bold))
          .foregroundStyle(NotisBrand.ink)
        Text(subtitle)
          .font(.satoshi(13))
          .foregroundStyle(kind == .emergency ? Color(hex: 0xE0A030) : NotisBrand.inkSoft)
        if student.isIphone && isStale(student, now: Date()) {
          Text("iPhone · laatst gezien \(student.lastSeen.formatted(date: .omitted, time: .shortened))")
            .font(.satoshi(13))
            .foregroundStyle(NotisBrand.inkSoft)
        }
        if student.tooMany {
          Text("Meer apps gekozen dan toegestaan")
            .font(.satoshi(13))
            .foregroundStyle(Color(hex: 0xE0A030))
        }
      }
      Spacer(minLength: 0)
    }
    .padding(.horizontal, 14)
    .padding(.vertical, 10)
    .background(NotisBrand.card, in: RoundedRectangle(cornerRadius: 18))
    .overlay(RoundedRectangle(cornerRadius: 18).stroke(NotisBrand.ink.opacity(0.12)))
  }

  private func reload() async {
    if let fresh = await teacher.students(in: room) {
      students = fresh
      isOffline = false
    } else {
      isOffline = true
      if students == nil { students = [] }
    }
  }
}
