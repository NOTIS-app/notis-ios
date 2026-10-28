import SwiftData
import SwiftUI

/// Top of Home (`FeatureFlags.homeProfilePicker`), like Android's `ProfileBar`: the profile every
/// stone locks with, in a capsule like the nav bar. A tap opens the profiles.
struct NotisProfileBar: View {
  let profiles: [BlockedProfiles]
  let selected: BlockedProfiles?
  let onSelect: (BlockedProfiles) -> Void

  var body: some View {
    Menu {
      ForEach(profiles) { profile in
        Button {
          onSelect(profile)
        } label: {
          if profile.id == selected?.id {
            Label(profile.name, systemImage: "checkmark")
          } else {
            Label(profile.name, systemImage: profile.notisIcon.symbol)
          }
          Text(profile.notisAppsSummary)
        }
      }
    } label: {
      HStack(spacing: 12) {
        NotisProfileGlyph(icon: selected?.notisIcon ?? .apps, size: 40)
        VStack(alignment: .leading, spacing: 0) {
          Text("Profiel")
            .font(.satoshi(11))
            .foregroundStyle(NotisBrand.inkSoft)
          Text(selected?.name ?? "")
            .font(.satoshi(16, .bold))
            .foregroundStyle(NotisBrand.ink)
            .lineLimit(1)
        }
        Spacer(minLength: 0)
        Image(systemName: "chevron.down")
          .font(.system(size: 14, weight: .semibold))
          .foregroundStyle(NotisBrand.inkSoft)
      }
      .padding(.leading, 8)
      .padding(.trailing, 16)
      .padding(.vertical, 8)
      .background(Capsule().fill(NotisBrand.boneLight.opacity(0.95)))
      .shadow(color: .black.opacity(0.12), radius: 6, y: 2)
      .contentShape(Capsule())
    }
    .buttonStyle(.plain)
    .accessibilityLabel("Profiel kiezen")
  }
}

/// While locked (`FeatureFlags.lockedWithBar`): what the phone is locked with, in the same capsule
/// as `NotisProfileBar`, without a menu. As Android's `LockedBar`.
struct NotisLockedBar: View {
  let label: String
  let name: String
  let icon: NotisProfileIcon
  let palette: NotisPalette

  var body: some View {
    HStack(spacing: 12) {
      NotisProfileGlyph(icon: icon, size: 40)
      VStack(alignment: .leading, spacing: 0) {
        Text(label)
          .font(.satoshi(11))
          .foregroundStyle(palette.onSurfaceVariant)
        Text(name)
          .font(.satoshi(16, .bold))
          .foregroundStyle(palette.onSurface)
          .lineLimit(1)
      }
      Spacer(minLength: 0)
    }
    .padding(.leading, 8)
    .padding(.trailing, 16)
    .padding(.vertical, 8)
    .background(Capsule().fill(palette.surfaceContainer.opacity(0.95)))
    .shadow(color: .black.opacity(0.12), radius: 6, y: 2)
  }
}
