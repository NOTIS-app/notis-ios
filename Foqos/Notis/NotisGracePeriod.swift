import SwiftUI

/// Android's grace period ("bedenktijd"): right after locking you can still cancel without a
/// stone, in case you locked by accident. Android's default is 30 seconds.
enum NotisGracePeriod {
  static let duration: TimeInterval = 30

  static func endDate(forSessionStartedAt start: Date) -> Date {
    start.addingTimeInterval(duration)
  }
}

/// Android's `GracePeriodIndicator`: a round "Annuleren" button whose ring runs down.
struct NotisGraceButton: View {
  let endsAt: Date
  let palette: NotisPalette
  let onCancel: () -> Void

  var body: some View {
    TimelineView(.periodic(from: .now, by: 1)) { timeline in
      let remaining = max(0, endsAt.timeIntervalSince(timeline.date))
      Button {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        onCancel()
      } label: {
        ZStack {
          Circle()
            .stroke(palette.onSurface.opacity(0.1), lineWidth: 3)
          Circle()
            .trim(from: 0, to: remaining / NotisGracePeriod.duration)
            .stroke(palette.onSurface.opacity(0.7), style: StrokeStyle(lineWidth: 3, lineCap: .round))
            .rotationEffect(.degrees(-90))
            .animation(.linear(duration: 1), value: remaining)
          Text("Annuleren")
            .font(.satoshi(11, .medium))
            .foregroundStyle(palette.onSurface.opacity(0.7))
        }
        .frame(width: 72, height: 72)
        .contentShape(Circle())
      }
      .buttonStyle(StoneCancelPressStyle())
    }
  }
}

/// Android: the cancel button shrinks to 0.9 while pressed.
private struct StoneCancelPressStyle: ButtonStyle {
  func makeBody(configuration: Configuration) -> some View {
    configuration.label
      .scaleEffect(configuration.isPressed ? 0.9 : 1)
      .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
  }
}
