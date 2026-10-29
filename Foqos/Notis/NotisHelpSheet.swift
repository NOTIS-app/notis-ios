import SwiftUI

/// One explained item in a `NotisHelpSheet`: an icon, a bold title and a short body.
struct NotisHelpItem: Identifiable {
  let icon: String
  let title: String
  let body: String
  var id: String { title }
}

/// The round "i" at the top right of a tab (Android's `HelpButton`); opens its help sheet.
struct NotisHelpButton: View {
  let action: () -> Void

  var body: some View {
    Button(action: action) {
      Image(systemName: "info.circle")
        .font(.system(size: 18))
        .foregroundStyle(NotisBrand.inkSoft)
        .frame(width: 40, height: 40)
        .background(NotisBrand.card, in: Circle())
    }
    .accessibilityLabel("Info")
  }
}

/// Android's `HelpSheet`: the "i" explanation of a tab, in the style of Mijn NOTIS's
/// (`StonesHelpSheet`): an icon in a circle, a title, the items one below the other and
/// "Begrepen". Scrolls when the items don't fit.
struct NotisHelpSheet: View {
  let icon: String
  let title: LocalizedStringKey
  let items: [NotisHelpItem]
  let onDismiss: () -> Void

  var body: some View {
    VStack(spacing: 0) {
      ScrollView {
        VStack(spacing: 16) {
          Image(systemName: icon)
            .font(.system(size: 24))
            .foregroundStyle(NotisBrand.mandarinDark)
            .frame(width: 56, height: 56)
            .background(NotisBrand.mandarinDark.opacity(0.1), in: Circle())
            .padding(.top, 24)
          Text(title)
            .font(.satoshi(20, .bold))
            .foregroundStyle(NotisBrand.ink)
          ForEach(items) { item in
            HStack(alignment: .top, spacing: 12) {
              Image(systemName: item.icon)
                .font(.system(size: 18))
                .foregroundStyle(NotisBrand.mandarinDark)
                .frame(width: 22)
                .padding(.top, 2)
              VStack(alignment: .leading, spacing: 2) {
                Text(item.title)
                  .font(.satoshi(15, .bold))
                  .foregroundStyle(NotisBrand.ink)
                Text(item.body)
                  .font(.satoshi(13))
                  .foregroundStyle(NotisBrand.inkSoft)
              }
              Spacer(minLength: 0)
            }
          }
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 16)
      }
      Button("Begrepen", action: onDismiss)
        .buttonStyle(NotisPrimaryButtonStyle())
        .padding(.horizontal, 24)
        .padding(.bottom, 8)
    }
  }
}
