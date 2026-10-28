import SwiftUI

/// The Home status as a padlock instead of the words VRIJ / OP SLOT: closed when locked, open
/// when free. Between the two the shackle springs up and swings open (or drops shut). Same as
/// `LockGlyph` on Android.
struct NotisLockGlyph: View {
  let isLocked: Bool
  let color: Color
  var size: CGFloat = 72

  var body: some View {
    let w = size
    let h = size
    let stroke = w * 0.1
    let bodyTop = h * 0.46
    let shackleWidth = w * 0.46
    let shackleTop = h * 0.1
    let legBottom = bodyTop + stroke
    let open: CGFloat = isLocked ? 0 : 1

    ZStack(alignment: .topLeading) {
      // Shackle: a U whose legs go into the body. Opening lifts it and swings it round its left leg.
      Shackle()
        .stroke(color, style: StrokeStyle(lineWidth: stroke, lineCap: .round))
        .frame(width: shackleWidth, height: legBottom - shackleTop)
        .rotationEffect(.degrees(-28 * open), anchor: .bottomLeading)
        .offset(x: (w - shackleWidth) / 2, y: shackleTop - h * 0.1 * open)

      // Body, with a keyhole cut out.
      ZStack {
        RoundedRectangle(cornerRadius: w * 0.12)
          .fill(color)
        VStack(spacing: 0) {
          Circle().frame(width: w * 0.11, height: w * 0.11)
          Capsule().frame(width: w * 0.06, height: h * 0.1)
            .offset(y: -w * 0.02)
        }
        .offset(y: -h * 0.02)
        .blendMode(.destinationOut)
      }
      .compositingGroup()
      .frame(width: w * 0.72, height: h * 0.46)
      .offset(x: w * 0.14, y: bodyTop)
    }
    .frame(width: w, height: h, alignment: .topLeading)
    .animation(.spring(response: 0.5, dampingFraction: 0.55), value: isLocked)
    .accessibilityElement()
    .accessibilityLabel(isLocked ? String(localized: "OP SLOT") : String(localized: "VRIJ"))
  }

  private struct Shackle: Shape {
    func path(in rect: CGRect) -> Path {
      let r = rect.width / 2
      var path = Path()
      path.move(to: CGPoint(x: rect.minX, y: rect.maxY))
      path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + r))
      path.addArc(
        tangent1End: CGPoint(x: rect.minX, y: rect.minY),
        tangent2End: CGPoint(x: rect.minX + r, y: rect.minY), radius: r)
      path.addArc(
        tangent1End: CGPoint(x: rect.maxX, y: rect.minY),
        tangent2End: CGPoint(x: rect.maxX, y: rect.minY + r), radius: r)
      path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
      return path
    }
  }
}
