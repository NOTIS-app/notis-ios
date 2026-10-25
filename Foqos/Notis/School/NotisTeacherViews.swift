import SwiftUI

/// Settings, "Ik ben docent": email + password. Teacher accounts are made by NOTIS.
struct NotisTeacherLoginSheet: View {
  @ObservedObject var teacher: NotisTeacher
  let onDone: () -> Void

  @State private var email = ""
  @State private var password = ""
  @State private var isBusy = false
  @State private var errorText: String?

  var body: some View {
    VStack(alignment: .leading, spacing: 14) {
      Text("Inloggen als docent")
        .font(.satoshi(22, .bold))
        .foregroundStyle(NotisBrand.ink)
      NotisTextField(title: "E-mailadres", text: $email, isSecure: false)
        .textContentType(.username)
        .keyboardType(.emailAddress)
        .textInputAutocapitalization(.never)
      NotisTextField(title: "Wachtwoord", text: $password, isSecure: true)
        .textContentType(.password)
      if let errorText {
        Text(errorText).font(.satoshi(13)).foregroundStyle(.red)
      }
      NotisPrimaryButton(title: "Inloggen", isBusy: isBusy, isEnabled: email.contains("@") && !password.isEmpty) {
        Task { await signIn() }
      }
      Button("Annuleren", action: onDone)
        .font(.satoshi(15, .medium))
        .foregroundStyle(NotisBrand.inkSoft)
        .frame(maxWidth: .infinity)
        .disabled(isBusy)
    }
    .padding(24)
  }

  private func signIn() async {
    isBusy = true
    errorText = nil
    do {
      try await teacher.signIn(email: email, password: password)
      onDone()
    } catch NotisTeacher.SignInError.notTeacher {
      errorText = String(localized: "Dit is geen docentaccount. Docentaccounts worden door NOTIS aangemaakt.")
    } catch NotisTeacher.SignInError.invalidLogin {
      errorText = String(localized: "E-mailadres of wachtwoord klopt niet.")
    } catch {
      errorText = String(localized: "Inloggen lukte niet. Controleer je internet.")
    }
    isBusy = false
  }
}

/// Long-press on the home stone, for a teacher: pick the room to watch.
struct NotisTeacherRoomsSheet: View {
  @ObservedObject var teacher: NotisTeacher
  let onPick: (TeacherRoom) -> Void

  @State private var rooms: [TeacherRoom]?

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      Text("Welk lokaal?")
        .font(.satoshi(20, .bold))
        .foregroundStyle(NotisBrand.ink)
      Text("Kies het lokaal waar je lesgeeft om te zien wie er gelocked is.")
        .font(.satoshi(14))
        .foregroundStyle(NotisBrand.inkSoft)
        .padding(.bottom, 6)
      if let rooms {
        if rooms.isEmpty {
          Text("Je school heeft nog geen lokalen, of er is geen internet.")
            .font(.satoshi(14))
            .foregroundStyle(NotisBrand.inkSoft)
        }
        ScrollView {
          VStack(spacing: 10) {
            ForEach(rooms) { room in
              Button {
                onPick(room)
              } label: {
                HStack {
                  Text(room.name).font(.satoshi(16, .bold)).foregroundStyle(NotisBrand.ink)
                  Spacer()
                  Text("Leerlingen bekijken").font(.satoshi(13)).foregroundStyle(NotisBrand.inkSoft)
                }
                .padding(16)
                .background(NotisBrand.card, in: RoundedRectangle(cornerRadius: 18))
                .overlay(RoundedRectangle(cornerRadius: 18).stroke(NotisBrand.ink.opacity(0.12)))
              }
              .buttonStyle(.plain)
            }
          }
        }
      } else {
        ProgressView().tint(NotisBrand.mandarinDark).frame(maxWidth: .infinity)
      }
    }
    .padding(20)
    .task { rooms = await teacher.rooms() }
  }
}

/// Settings, "Herstelcode": sign in again, then the school's code. It unlocks one student's
/// school lock and changes after every use.
struct NotisRecoveryCodeRevealSheet: View {
  @ObservedObject var teacher: NotisTeacher
  let onDone: () -> Void

  @State private var password = ""
  @State private var code: String?
  @State private var isBusy = false
  @State private var errorText: String?

  var body: some View {
    VStack(alignment: .leading, spacing: 14) {
      Text("Herstelcode")
        .font(.satoshi(22, .bold))
        .foregroundStyle(NotisBrand.ink)
      if let code {
        Text(code)
          .font(.satoshi(40, .bold))
          .tracking(6)
          .foregroundStyle(NotisBrand.ink)
          .frame(maxWidth: .infinity)
        Text("Werkt één keer. Zodra een leerling hem gebruikt, krijgt de school een nieuwe code.")
          .font(.satoshi(14))
          .foregroundStyle(NotisBrand.inkSoft)
        NotisPrimaryButton(title: "Sluiten", isBusy: false, isEnabled: true, action: onDone)
      } else {
        Text("Log opnieuw in om de code te zien. Een leerling ontgrendelt ermee als de steen van het lokaal niet werkt.")
          .font(.satoshi(14))
          .foregroundStyle(NotisBrand.inkSoft)
        Text(teacher.email ?? "")
          .font(.satoshi(15, .medium))
          .foregroundStyle(NotisBrand.ink)
        NotisTextField(title: "Wachtwoord", text: $password, isSecure: true)
          .textContentType(.password)
        if let errorText {
          Text(errorText).font(.satoshi(13)).foregroundStyle(.red)
        }
        NotisPrimaryButton(title: "Inloggen en tonen", isBusy: isBusy, isEnabled: !password.isEmpty) {
          Task { await reveal() }
        }
        Button("Annuleren", action: onDone)
          .font(.satoshi(15, .medium))
          .foregroundStyle(NotisBrand.inkSoft)
          .frame(maxWidth: .infinity)
          .disabled(isBusy)
      }
    }
    .padding(24)
  }

  private func reveal() async {
    isBusy = true
    errorText = nil
    do {
      code = try await teacher.recoveryCode(password: password)
    } catch NotisTeacher.SignInError.invalidLogin {
      errorText = String(localized: "Wachtwoord klopt niet.")
    } catch {
      errorText = String(localized: "De code ophalen lukte niet. Controleer je internet.")
    }
    password = ""
    isBusy = false
  }
}

/// A text field in the NOTIS card style.
struct NotisTextField: View {
  let title: String
  @Binding var text: String
  let isSecure: Bool

  var body: some View {
    Group {
      if isSecure {
        SecureField(title, text: $text)
      } else {
        TextField(title, text: $text)
      }
    }
    .font(.satoshi(17))
    .padding(14)
    .background(NotisBrand.card, in: RoundedRectangle(cornerRadius: 14))
    .overlay(RoundedRectangle(cornerRadius: 14).stroke(NotisBrand.ink.opacity(0.12)))
  }
}

/// The filled mandarin button used in NOTIS sheets.
struct NotisPrimaryButton: View {
  let title: String
  let isBusy: Bool
  let isEnabled: Bool
  let action: () -> Void

  var body: some View {
    Button(action: action) {
      Group {
        if isBusy {
          ProgressView().tint(.white)
        } else {
          Text(title).font(.satoshi(16, .bold))
        }
      }
      .frame(maxWidth: .infinity)
      .frame(height: 52)
      .background(NotisBrand.mandarinDark.opacity(isEnabled && !isBusy ? 1 : 0.4), in: RoundedRectangle(cornerRadius: 16))
      .foregroundStyle(.white)
    }
    .disabled(!isEnabled || isBusy)
  }
}
