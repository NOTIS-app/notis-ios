import SwiftUI

/// The NOTIS stone outline from website/favicon.svg (64×64 viewBox), scaled to fit any rect.
struct NotisStoneShape: InsettableShape {
  var insetAmount: CGFloat = 0

  // Bounding box of the favicon path, so the stone fills the rect edge to edge.
  private static let minX: CGFloat = 5.6
  private static let maxX: CGFloat = 57.2
  private static let minY: CGFloat = 6
  private static let maxY: CGFloat = 49.8

  func path(in rect: CGRect) -> Path {
    let rect = rect.insetBy(dx: insetAmount, dy: insetAmount)
    let sx = rect.width / (Self.maxX - Self.minX)
    let sy = rect.height / (Self.maxY - Self.minY)
    func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
      CGPoint(x: rect.minX + (x - Self.minX) * sx, y: rect.minY + (y - Self.minY) * sy)
    }

    var path = Path()
    path.move(to: p(32, 6))
    path.addCurve(to: p(53, 28), control1: p(39, 6), control2: p(45, 14))
    path.addCurve(to: p(45, 49), control1: p(60, 41), control2: p(56, 48))
    path.addCurve(to: p(19, 49), control1: p(37, 50), control2: p(27, 50))
    path.addCurve(to: p(11, 28), control1: p(8, 48), control2: p(4, 41))
    path.addCurve(to: p(32, 6), control1: p(19, 14), control2: p(25, 6))
    path.closeSubpath()
    return path
  }

  func inset(by amount: CGFloat) -> NotisStoneShape {
    var shape = self
    shape.insetAmount += amount
    return shape
  }
}
