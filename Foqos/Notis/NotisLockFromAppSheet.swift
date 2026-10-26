import SwiftUI

/// Android's `LockFromAppSheet`, opened by pressing and holding the home stone: pick the profile
/// (without `FeatureFlags.stoneProfiles`: the stone) to lock with. Unlocking still takes a stone.
/// iOS has no classes yet (`FeatureFlags.schoolLive` is off).
struct NotisLockFromAppSheet: View {
  let choices: [BlockedProfiles]
  let onChoose: (BlockedProfiles) -> Void

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 10) {
        Text(FeatureFlags.stoneProfiles ? "Op slot met welk profiel?" : "Op slot met welke steen?")
          .font(.satoshi(20, .bold))
          .foregroundStyle(NotisBrand.ink)
          .padding(.top, 28)
        Text(
          choices.isEmpty
            ? "Je hebt nog geen steen gekoppeld. Koppel er eerst een bij Mijn NOTIS."
            : FeatureFlags.stoneProfiles
              ? "De apps van dat profiel blijven bruikbaar. Weer vrij geven kan alleen door je telefoon tegen een NOTIS te houden."
              : "De apps van die steen blijven bruikbaar. Weer vrij geven kan alleen door je telefoon tegen een NOTIS te houden."
        )
        .font(.satoshi(14))
        .lineSpacing(4)
        .foregroundStyle(NotisBrand.inkSoft)
        .padding(.bottom, 6)

        ForEach(choices) { stone in
          Button {
            onChoose(stone)
          } label: {
            HStack(spacing: 14) {
              NotisStoneGlyph(width: 40)
              VStack(alignment: .leading, spacing: 2) {
                Text(stone.name)
                  .font(.satoshi(16, .bold))
                  .foregroundStyle(NotisBrand.ink)
                Text(stone.notisAppsSummary)
                  .font(.satoshi(13))
                  .foregroundStyle(NotisBrand.inkSoft)
              }
              Spacer(minLength: 0)
            }
            .padding(16)
            .contentShape(Rectangle())
            .notisCard()
          }
          .buttonStyle(.plain)
        }
      }
      .padding(.horizontal, 20)
      .padding(.bottom, 16)
    }
  }
}
