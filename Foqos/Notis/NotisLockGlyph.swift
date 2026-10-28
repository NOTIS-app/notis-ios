import SwiftUI

/// The Home status as a padlock instead of the words VRIJ / OP SLOT: shut when locked, open when
/// free. Opening, the shackle springs straight up and its right leg comes out of the body, like
/// a real padlock; shutting, it drops back in. Everything stays inside the glyph's own frame.
/// Same as `LockGlyph` on Android.
struct NotisLockGlyph: View {
  let isLocked: Bool
  let color: Color
  var size: CGFloat = 64

  var body: some View {
    let w = size
    let h = size * 1.25
    ZStack(alignment: .topLeading) {
      Shackle(open: isLocked ? 0 : 1)
        .stroke(color, style: StrokeStyle(lineWidth: w * 0.13, lineCap: .round))
      RoundedRectangle(cornerRadius: w * 0.16)
        .fill(color)
        .frame(width: w * 0.8, height: h * 0.5)
        .offset(x: w * 0.1, y: h * 0.5)
    }
    .frame(width: w, height: h, alignment: .topLeading)
    .animation(.spring(response: 0.45, dampingFraction: 0.6), value: isLocked)
    .accessibilityElement()
    .accessibilityLabel(isLocked ? String(localized: "OP SLOT") : String(localized: "VRIJ"))
  }

  /// The arch, drawn in the glyph's whole frame. Its left leg stays in the body; open, the arch
  /// is lifted and the right leg ends above the body.
  private struct Shackle: Shape {
    var open: CGFloat

    var animatableData: CGFloat {
      get { open }
      set { open = newValue }
    }

    func path(in rect: CGRect) -> Path {
      let w = rect.width
      let h = rect.height
      let stroke = w * 0.13
      let shackleWidth = w * 0.5
      let r = shackleWidth / 2
      let left = (w - shackleWidth) / 2
      let lift = h * 0.16 * open
      let archTop = h * 0.2 - lift + stroke / 2
      let inBody = h * 0.5 + stroke / 2

      var path = Path()
      path.move(to: CGPoint(x: left, y: inBody))
      path.addLine(to: CGPoint(x: left, y: archTop + r))
      path.addArc(
        tangent1End: CGPoint(x: left, y: archTop),
        tangent2End: CGPoint(x: left + r, y: archTop), radius: r)
      path.addArc(
        tangent1End: CGPoint(x: left + shackleWidth, y: archTop),
        tangent2End: CGPoint(x: left + shackleWidth, y: archTop + r), radius: r)
      path.addLine(to: CGPoint(x: left + shackleWidth, y: inBody - lift * 1.15))
      return path
    }
  }
}
