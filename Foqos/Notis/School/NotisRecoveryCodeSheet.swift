import SwiftUI

/// School lock, when the room's stone doesn't work: the student enters the 6-digit recovery
/// code a teacher gives (8d). Each code works once; the server then makes a new one. Mirrors
/// `UnlockCodeDialog` on Android.
struct NotisRecoveryCodeSheet: View {
  @ObservedObject var school: NotisSchool
  /// Called when the code was right; ends the school lock.
  let onUnlocked: () -> Void
  let onCancel: () -> Void

  @State private var code = ""
  @State private var isBusy = false
  @State private var errorText: String?

  var body: some View {
    VStack(alignment: .leading, spacing: 16) {
      Text("Herstelcode")
        .font(.satoshi(22, .bold))
        .foregroundStyle(NotisBrand.ink)
      Text("Werkt de steen van je lokaal niet? Vraag je docent om de herstelcode. Elke code werkt één keer.")
        .font(.satoshi(15))
        .foregroundStyle(NotisBrand.inkSoft)

      TextField("Code van 6 cijfers", text: $code)
        .font(.satoshi(24, .bold))
        .keyboardType(.numberPad)
        .textContentType(.oneTimeCode)
        .padding(14)
        .background(NotisBrand.card, in: RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(NotisBrand.ink.opacity(0.12)))
        .onChange(of: code) { _, value in
          let digits = String(value.filter(\.isNumber).prefix(6))
          if digits != value { code = digits }
        }

      if let errorText {
        Text(errorText).font(.satoshi(13)).foregroundStyle(.red)
      }

      Button {
        Task { await submit() }
      } label: {
        Group {
          if isBusy {
            ProgressView().tint(.white)
          } else {
            Text("Ontgrendelen").font(.satoshi(16, .bold))
          }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 52)
        .background(
          NotisBrand.mandarinDark.opacity(code.count == 6 && !isBusy ? 1 : 0.4),
          in: RoundedRectangle(cornerRadius: 16)
        )
        .foregroundStyle(.white)
      }
      .disabled(code.count != 6 || isBusy)

      Button("Annuleren", action: onCancel)
        .font(.satoshi(15, .medium))
        .foregroundStyle(NotisBrand.inkSoft)
        .frame(maxWidth: .infinity)
        .disabled(isBusy)
    }
    .padding(24)
  }

  private func submit() async {
    isBusy = true
    errorText = nil
    switch await school.useUnlockCode(code) {
    case .ok:
      onUnlocked()
    case .wrong:
      errorText = String(localized: "Deze code klopt niet (meer). Vraag je docent om de huidige code.")
    case .tooMany:
      errorText = String(localized: "Te vaak een verkeerde code. Wacht 10 minuten en probeer het opnieuw.")
    case .failed:
      errorText = String(localized: "Controleren lukte niet. De code kan alleen online worden gecontroleerd.")
    }
    isBusy = false
  }
}
