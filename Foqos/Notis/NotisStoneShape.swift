import SwiftUI

/// The NOTIS stone as drawn on the website and in the Android app (`NotisStone.kt`): the hero
/// SVG outline (viewBox 0 0 400 340) shifted into a 360 × 260 box.
enum NotisStoneGeometry {
  static let width: CGFloat = 360
  static let height: CGFloat = 260
  static let dotCenter = CGPoint(x: 276, y: 180)
  static let wordCenter = CGPoint(x: 180, y: 126)
  static let wordColor = Color(hex: 0x8A867C)

  static let path: Path = {
    var path = Path()
    path.move(to: CGPoint(x: 180, y: 6))
    path.addCurve(
      to: CGPoint(x: 328, y: 126), control1: CGPoint(x: 230, y: 2), control2: CGPoint(x: 284, y: 48))
    path.addCurve(
      to: CGPoint(x: 270, y: 250), control1: CGPoint(x: 368, y: 196), control2: CGPoint(x: 344, y: 242))
    path.addCurve(
      to: CGPoint(x: 96, y: 249), control1: CGPoint(x: 216, y: 256), control2: CGPoint(x: 150, y: 256))
    path.addCurve(
      to: CGPoint(x: 42, y: 130), control1: CGPoint(x: 28, y: 240), control2: CGPoint(x: 4, y: 196))
    path.addCurve(
      to: CGPoint(x: 180, y: 6), control1: CGPoint(x: 86, y: 52), control2: CGPoint(x: 132, y: 10))
    path.closeSubpath()
    return path
  }()

  static func boneGradient(scale s: CGFloat, origin: CGPoint) -> GraphicsContext.Shading {
    .radialGradient(
      Gradient(stops: [
        .init(color: Color(hex: 0xF3F1EB), location: 0),
        .init(color: Color(hex: 0xE2DED3), location: 0.6),
        .init(color: NotisBrand.bone, location: 1),
      ]),
      center: CGPoint(x: origin.x + width * 0.42 * s, y: origin.y + height * 0.3 * s),
      startRadius: 0,
      endRadius: width * 0.75 * s
    )
  }
}

/// The home screen's big stone. Animations follow Android: a slow float while free, a mandarin
/// glow and dot halo while locked (900 ms to switch), and travelling rings as the scan hint.
struct NotisStoneView: View {
  var isLocked: Bool
  var showScanHint: Bool = false
  var width: CGFloat = 290

  @State private var lockFrom: Double
  @State private var lockChangedAt = Date.distantPast
  @State private var hintFrom: Double = 0
  @State private var hintChangedAt = Date.distantPast

  init(isLocked: Bool, showScanHint: Bool = false, width: CGFloat = 290) {
    self.isLocked = isLocked
    self.showScanHint = showScanHint
    self.width = width
    _lockFrom = State(initialValue: isLocked ? 1 : 0)
  }

  private var height: CGFloat {
    width * (NotisStoneGeometry.height / NotisStoneGeometry.width) * 1.25
  }

  var body: some View {
    TimelineView(.animation) { timeline in
      let now = timeline.date
      let lp = progress(from: lockFrom, to: isLocked ? 1 : 0, since: lockChangedAt, duration: 0.9, at: now)
      let hint = progress(from: hintFrom, to: showScanHint ? 1 : 0, since: hintChangedAt, duration: 0.3, at: now)
      let seconds = now.timeIntervalSinceReferenceDate
      let breath = (1 - cos(seconds / 4 * .pi)) / 2
      let wave = (seconds / 1.8).truncatingRemainder(dividingBy: 1)

      Canvas { context, size in
        draw(in: &context, size: size, lp: lp, hint: hint, breath: breath, wave: wave)
      }
    }
    .frame(width: width, height: height)
    .onChange(of: isLocked) { _, newValue in
      lockFrom = progress(from: lockFrom, to: newValue ? 0 : 1, since: lockChangedAt, duration: 0.9, at: Date())
      lockChangedAt = Date()
    }
    .onChange(of: showScanHint) { _, newValue in
      hintFrom = progress(from: hintFrom, to: newValue ? 0 : 1, since: hintChangedAt, duration: 0.3, at: Date())
      hintChangedAt = Date()
    }
    .accessibilityHidden(true)
  }

  private func progress(from: Double, to: Double, since: Date, duration: Double, at now: Date) -> Double {
    let t = min(1, max(0, now.timeIntervalSince(since) / duration))
    let eased = t < 0.5 ? 4 * t * t * t : 1 - pow(-2 * t + 2, 3) / 2
    return from + (to - from) * eased
  }

  private func draw(
    in context: inout GraphicsContext, size: CGSize, lp: Double, hint: Double, breath: Double, wave: Double
  ) {
    typealias G = NotisStoneGeometry
    let s = size.width / (G.width * 1.12)
    let stoneW = G.width * s
    let stoneH = G.height * s
    let origin = CGPoint(x: (size.width - stoneW) / 2, y: (size.height - stoneH) / 2)
    let center = CGPoint(x: origin.x + stoneW / 2, y: origin.y + stoneH * 0.6)
    let float = (1 - lp) * (breath - 0.5) * 6

    // Mandarin glow behind the stone while locked.
    if lp > 0 {
      let r = stoneW * (0.55 + 0.08 * breath)
      context.fill(
        Path(ellipseIn: CGRect(x: center.x - r, y: center.y - r, width: r * 2, height: r * 2)),
        with: .radialGradient(
          Gradient(colors: [NotisBrand.mandarin.opacity(0.35 * lp), .clear]),
          center: center, startRadius: 0, endRadius: r)
      )
    }

    // Scan hint: outlines growing outward from the stone's visual center.
    if hint > 0 {
      for i in 0..<3 {
        let t = (wave + Double(i) / 3).truncatingRemainder(dividingBy: 1)
        let k = 1 + 0.35 * t
        let transform = CGAffineTransform(scaleX: s, y: s)
          .concatenating(CGAffineTransform(translationX: origin.x - center.x, y: origin.y - center.y))
          .concatenating(CGAffineTransform(scaleX: k, y: k))
          .concatenating(CGAffineTransform(translationX: center.x, y: center.y))
        context.stroke(
          G.path.applying(transform),
          with: .color(NotisBrand.mandarin.opacity(hint * (1 - t) * 0.8)),
          lineWidth: 2.5
        )
      }
    }

    // Soft shadow under the stone.
    let shadowCenter = CGPoint(x: origin.x + stoneW * 0.52, y: origin.y + stoneH * 0.97)
    let rx = stoneW * 0.46
    context.fill(
      Path(ellipseIn: CGRect(x: shadowCenter.x - rx, y: shadowCenter.y - rx * 0.16, width: rx * 2, height: rx * 0.32)),
      with: .radialGradient(
        Gradient(colors: [NotisBrand.ink.opacity(0.18 + 0.1 * lp), .clear]),
        center: shadowCenter, startRadius: 0, endRadius: rx)
    )

    let stoneOrigin = CGPoint(x: origin.x, y: origin.y + float)
    let toStone = CGAffineTransform(scaleX: s, y: s)
      .concatenating(CGAffineTransform(translationX: stoneOrigin.x, y: stoneOrigin.y))
    context.fill(G.path.applying(toStone), with: G.boneGradient(scale: s, origin: stoneOrigin))

    context.draw(
      Text("NOTIS")
        .font(.satoshi(22 * s, .medium))
        .tracking(9 * s)
        .foregroundColor(G.wordColor),
      at: G.wordCenter.applying(toStone)
    )

    // The mandarin dot grows a halo while locked.
    let dot = G.dotCenter.applying(toStone)
    if lp > 0 {
      let r = (6 + 8 * lp * (0.7 + 0.3 * breath)) * s
      context.fill(
        Path(ellipseIn: CGRect(x: dot.x - r, y: dot.y - r, width: r * 2, height: r * 2)),
        with: .color(NotisBrand.mandarin.opacity(0.3 * lp)))
    }
    let dotR = 6 * s * (1 + 0.25 * lp)
    context.fill(
      Path(ellipseIn: CGRect(x: dot.x - dotR, y: dot.y - dotR, width: dotR * 2, height: dotR * 2)),
      with: .color(NotisBrand.mandarin))
  }
}

/// Small static stone for lists (Android `StoneGlyph`).
struct NotisStoneGlyph: View {
  var width: CGFloat = 44

  var body: some View {
    Canvas { context, size in
      typealias G = NotisStoneGeometry
      let s = size.width / G.width
      let transform = CGAffineTransform(scaleX: s, y: s)
      context.fill(G.path.applying(transform), with: G.boneGradient(scale: s, origin: .zero))
      let dot = G.dotCenter.applying(transform)
      let r = 14 * s
      context.fill(
        Path(ellipseIn: CGRect(x: dot.x - r, y: dot.y - r, width: r * 2, height: r * 2)),
        with: .color(NotisBrand.mandarin))
    }
    .frame(width: width, height: width * NotisStoneGeometry.height / NotisStoneGeometry.width)
    .accessibilityHidden(true)
  }
}
