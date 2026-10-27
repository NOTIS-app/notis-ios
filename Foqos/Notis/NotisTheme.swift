import CoreText
import SwiftUI

/// NOTIS brand tokens, the same values as website/style.css and the Android app
/// (`ui/theme/Color.kt`).
enum NotisBrand {
  static let bone = Color(hex: 0xCBC6B8)
  static let boneLight = Color(hex: 0xE7E3D9)
  static let paper = Color(hex: 0xF4F2EC)
  static let card = Color(hex: 0xFBFAF7)
  static let ink = Color(hex: 0x2B2A27)
  static let inkSoft = Color(hex: 0x66625A)
  static let mandarin = Color(hex: 0xF99963)
  static let mandarinDark = Color(hex: 0xC4612B)
}

/// Android's `LockColors`: the light palette, and the ink palette used while locked.
struct NotisPalette {
  let primary: Color
  let surface: Color
  let surfaceContainer: Color
  let surfaceContainerHigh: Color
  let card: Color
  let onSurface: Color
  let onSurfaceVariant: Color
  let error: Color

  static let light = NotisPalette(
    primary: NotisBrand.mandarinDark,
    surface: NotisBrand.paper,
    surfaceContainer: NotisBrand.boneLight,
    surfaceContainerHigh: Color(hex: 0xDEDACE),
    card: NotisBrand.card,
    onSurface: NotisBrand.ink,
    onSurfaceVariant: NotisBrand.inkSoft,
    error: Color(hex: 0xBA1A1A)
  )

  static let ink = NotisPalette(
    primary: NotisBrand.mandarin,
    surface: Color(hex: 0x1E1D1B),
    surfaceContainer: NotisBrand.ink,
    surfaceContainerHigh: Color(hex: 0x33322E),
    card: NotisBrand.ink,
    onSurface: NotisBrand.paper,
    onSurfaceVariant: NotisBrand.bone,
    error: Color(hex: 0xFFB4AB)
  )
}

/// Older call sites; prefer `NotisBrand` / `NotisPalette`.
enum NotisTheme {
  static let paper = NotisBrand.paper
  static let card = NotisBrand.card
  static let ink = NotisBrand.ink
  static let mandarin = NotisBrand.mandarin
}

extension Color {
  init(hex: UInt32, opacity: Double = 1) {
    self.init(
      .sRGB,
      red: Double((hex >> 16) & 0xFF) / 255,
      green: Double((hex >> 8) & 0xFF) / 255,
      blue: Double(hex & 0xFF) / 255,
      opacity: opacity
    )
  }
}

/// Satoshi, the Android app's typeface. The .otf files live in Notis/Fonts and are registered
/// at launch, so no Info.plist entry is needed.
enum NotisFont {
  static func register() {
    let urls = Bundle.main.urls(forResourcesWithExtension: "otf", subdirectory: nil) ?? []
    for url in urls where url.lastPathComponent.hasPrefix("Satoshi-") {
      CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
    }
  }
}

extension Font {
  static func satoshi(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font {
    let name: String
    switch weight {
    case .light, .thin, .ultraLight: name = "Satoshi-Light"
    case .medium: name = "Satoshi-Medium"
    case .semibold, .bold: name = "Satoshi-Bold"
    case .heavy, .black: name = "Satoshi-Black"
    default: name = "Satoshi-Regular"
    }
    return .custom(name, size: size)
  }
}

/// The website's pill button (Android `OnboardingButton`): mandarin-dark fill, white bold text.
struct NotisPrimaryButtonStyle: ButtonStyle {
  @Environment(\.isEnabled) private var isEnabled

  func makeBody(configuration: Configuration) -> some View {
    configuration.label
      .font(.satoshi(16, .bold))
      .foregroundStyle(.white.opacity(isEnabled ? 1 : 0.5))
      .frame(maxWidth: .infinity, minHeight: 56)
      .background(
        Capsule().fill(NotisBrand.mandarinDark.opacity(isEnabled ? 1 : 0.3))
      )
      .scaleEffect(configuration.isPressed ? 0.98 : 1)
      .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
  }
}

/// Android's FilledTonalButton ("Blokkeren hervatten").
struct NotisTonalButtonStyle: ButtonStyle {
  func makeBody(configuration: Configuration) -> some View {
    configuration.label
      .font(.satoshi(14, .medium))
      .foregroundStyle(NotisBrand.ink)
      .padding(.horizontal, 24)
      .frame(minHeight: 40)
      .background(Capsule().fill(NotisBrand.boneLight))
      .opacity(configuration.isPressed ? 0.8 : 1)
  }
}

/// Android's OutlinedButton ("Nieuw profiel").
struct NotisOutlinedButtonStyle: ButtonStyle {
  @Environment(\.isEnabled) private var isEnabled

  func makeBody(configuration: Configuration) -> some View {
    configuration.label
      .font(.satoshi(16, .bold))
      .foregroundStyle(NotisBrand.mandarinDark.opacity(isEnabled ? 1 : 0.4))
      .frame(maxWidth: .infinity, minHeight: 52)
      .overlay(
        Capsule().strokeBorder(NotisBrand.inkSoft.opacity(isEnabled ? 0.5 : 0.2), lineWidth: 1)
      )
      .contentShape(Capsule())
      .opacity(configuration.isPressed ? 0.7 : 1)
  }
}

/// Light card on paper with the website's thin line, as on Android.
struct NotisCardModifier: ViewModifier {
  var radius: CGFloat = 18

  func body(content: Content) -> some View {
    content
      .background(NotisBrand.card, in: RoundedRectangle(cornerRadius: radius))
      .overlay(
        RoundedRectangle(cornerRadius: radius).strokeBorder(NotisBrand.ink.opacity(0.12), lineWidth: 1)
      )
  }
}

extension View {
  func notisCard(radius: CGFloat = 18) -> some View {
    modifier(NotisCardModifier(radius: radius))
  }
}
