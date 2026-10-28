import SwiftUI

/// The maths of `NotisTimeDial`: a 24-hour clock with midnight at the top, running clockwise.
/// Same as `TimeDialMath` on Android.
enum NotisTimeDialMath {
  static let day = 24 * 60

  /// The handles snap to this many minutes.
  static let step = 5

  /// The handles never come closer than this, so they can't pass each other.
  static let minGap = 15

  /// The minute of the day at a point, seen from the centre (dy grows downwards).
  static func minuteAt(dx: Double, dy: Double) -> Double {
    let degrees = atan2(dx, -dy) * 180 / .pi
    return (degrees + 360).truncatingRemainder(dividingBy: 360) / 360 * Double(day)
  }

  /// The shortest way from `from` to `to` round the clock, in minutes: -720 up to 720.
  static func delta(from: Double, to: Double) -> Double {
    var d = (to - from).truncatingRemainder(dividingBy: Double(day))
    if d > Double(day / 2) { d -= Double(day) }
    if d <= -Double(day / 2) { d += Double(day) }
    return d
  }

  /// Minutes from `start` clockwise to `end`.
  static func arc(_ start: Int, _ end: Int) -> Int {
    ((end - start) % day + day) % day
  }

  static func snap(_ minute: Double) -> Int {
    let snapped = Int((minute / Double(step)).rounded()) * step
    return (snapped % day + day) % day
  }

  /// One drag of a handle. `arc` follows the finger without jumps (it isn't wrapped), so a
  /// handle stops at the other one instead of jumping past it.
  struct Drag {
    let fixed: Int
    let isEnd: Bool
    var arc: Double
    var lastTouch: Double

    init(fixed: Int, startArc: Int, isEnd: Bool, lastTouch: Double) {
      self.fixed = fixed
      self.isEnd = isEnd
      self.arc = Double(startArc)
      self.lastTouch = lastTouch
    }

    /// The new minute of the dragged handle, or nil when it may not move there.
    mutating func move(to touch: Double) -> Int? {
      let d = delta(from: lastTouch, to: touch)
      lastTouch = touch
      arc = min(max(arc + (isEnd ? d : -d), Double(minGap)), Double(day - minGap))
      let minute = snap(isEnd ? Double(fixed) + arc : Double(fixed) - arc)
      let snappedArc = isEnd ? NotisTimeDialMath.arc(fixed, minute) : NotisTimeDialMath.arc(minute, fixed)
      return (minGap...(day - minGap)).contains(snappedArc) ? minute : nil
    }
  }
}

/// Lock time on a 24-hour ring, like the bedtime dial of a clock app. With `showsEnd` there
/// are two handles (lock and unlock) with the locked stretch between them; they can be dragged
/// round the ring but not past each other. Without an end there is only the lock handle.
struct NotisTimeDial<Centre: View>: View {
  @Binding var start: Int
  @Binding var end: Int
  let showsEnd: Bool
  let centre: () -> Centre

  @State private var drag: NotisTimeDialMath.Drag?
  @State private var isDragging = false
  @State private var isIgnored = false

  private let ring: CGFloat = 44

  init(start: Binding<Int>, end: Binding<Int>, showsEnd: Bool, @ViewBuilder centre: @escaping () -> Centre) {
    _start = start
    _end = end
    self.showsEnd = showsEnd
    self.centre = centre
  }

  var body: some View {
    GeometryReader { geo in
      let side = min(geo.size.width, geo.size.height)
      let radius = side / 2 - ring / 2
      let centrePoint = CGPoint(x: geo.size.width / 2, y: geo.size.height / 2)

      ZStack {
        Canvas { context, _ in
          context.stroke(
            Path(ellipseIn: CGRect(x: centrePoint.x - radius, y: centrePoint.y - radius, width: radius * 2, height: radius * 2)),
            with: .color(NotisBrand.ink.opacity(0.06)),
            lineWidth: ring)

          // Hour ticks and the labels 0, 3, 6 ... inside the ring.
          for hour in 0..<24 {
            let isMajor = hour % 3 == 0
            let outer = radius - ring / 2 - 6
            let inner = outer - (isMajor ? 8 : 4)
            var tick = Path()
            tick.move(to: point(hour * 60, inner, centrePoint))
            tick.addLine(to: point(hour * 60, outer, centrePoint))
            context.stroke(
              tick, with: .color(NotisBrand.inkSoft.opacity(isMajor ? 0.6 : 0.3)),
              style: StrokeStyle(lineWidth: 1.5, lineCap: .round))
            if isMajor {
              context.draw(
                Text("\(hour)").font(.satoshi(12, .medium)).foregroundColor(NotisBrand.inkSoft),
                at: point(hour * 60, inner - 14, centrePoint))
            }
          }

          // The locked stretch between the handles.
          if showsEnd {
            var stretch = Path()
            stretch.addArc(
              center: centrePoint, radius: radius,
              startAngle: angle(start), endAngle: angle(end), clockwise: false)
            context.stroke(
              stretch, with: .color(NotisBrand.mandarinDark),
              style: StrokeStyle(lineWidth: ring - 8, lineCap: .round))
          }
        }

        if showsEnd {
          handle("sun.max", at: point(end, radius, centrePoint))
        }
        handle("moon", at: point(start, radius, centrePoint))

        VStack(spacing: 2) { centre() }
          .position(centrePoint)
      }
      .contentShape(Rectangle())
      .gesture(
        DragGesture(minimumDistance: 0)
          .onChanged { value in
            follow(value, centre: centrePoint, radius: radius)
          }
          .onEnded { _ in
            drag = nil
            isDragging = false
            isIgnored = false
          }
      )
    }
    .aspectRatio(1, contentMode: .fit)
  }

  private func follow(_ value: DragGesture.Value, centre c: CGPoint, radius: CGFloat) {
    if isIgnored { return }
    let at = { (p: CGPoint) in NotisTimeDialMath.minuteAt(dx: p.x - c.x, dy: p.y - c.y) }
    if !isDragging {
      // Only a touch on the ring drags.
      let dx = value.startLocation.x - c.x
      let dy = value.startLocation.y - c.y
      if abs(hypot(dx, dy) - radius) > ring {
        isIgnored = true
        return
      }
      isDragging = true
      if showsEnd {
        // The nearest handle moves.
        let minute = at(value.startLocation)
        let toStart = abs(NotisTimeDialMath.delta(from: minute, to: Double(start)))
        let toEnd = abs(NotisTimeDialMath.delta(from: minute, to: Double(end)))
        let isEnd = toEnd < toStart
        drag = NotisTimeDialMath.Drag(
          fixed: isEnd ? start : end,
          startArc: NotisTimeDialMath.arc(start, end),
          isEnd: isEnd,
          lastTouch: Double(isEnd ? end : start))
      }
    }
    let minute = at(value.location)
    if var current = drag {
      if let moved = current.move(to: minute) {
        if current.isEnd { end = moved } else { start = moved }
      }
      drag = current
    } else {
      start = NotisTimeDialMath.snap(minute)
    }
  }

  private func handle(_ symbol: String, at position: CGPoint) -> some View {
    Image(systemName: symbol)
      .font(.system(size: 16, weight: .semibold))
      .foregroundStyle(NotisBrand.mandarinDark)
      .frame(width: ring - 14, height: ring - 14)
      .background(Circle().fill(Color.white))
      .position(position)
  }

  private func angle(_ minute: Int) -> Angle {
    .degrees(Double(minute) / Double(NotisTimeDialMath.day) * 360 - 90)
  }

  private func point(_ minute: Int, _ r: CGFloat, _ c: CGPoint) -> CGPoint {
    // CGFloat throughout: with a Double angle, `r * sin(…)` is ambiguous between overloads.
    let radians = CGFloat(minute) / CGFloat(NotisTimeDialMath.day) * 2 * .pi
    return CGPoint(x: c.x + r * sin(radians), y: c.y - r * cos(radians))
  }
}
