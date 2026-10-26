/// The app icon. Foqos offered alternate icons; NOTIS has one, so only the default is left.
enum AppIconOption: String, CaseIterable, Identifiable {
  case defaultIcon

  var id: String { rawValue }

  var displayName: String { "Default" }

  var alternateIconName: String? { nil }

  var previewAssetName: String { "AppIconDefaultPreview" }

  var liveActivityAssetName: String { "FoqosStickerLogo" }
}
