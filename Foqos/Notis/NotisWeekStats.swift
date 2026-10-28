import SwiftUI

/// This week and the streak, from the finished sessions. Mirrors Android's `computeDailyStats`,
/// `getWeekForDate` and `computeStreak`: a session counts on the day it started.
struct NotisWeekStats {
  struct Day: Identifiable {
    let date: Date
    let seconds: TimeInterval
    var id: Date { date }
  }

  let days: [Day]
  let totalSeconds: TimeInterval
  let streak: Int

  init(sessions: [BlockedProfileSession], now: Date = Date()) {
    var calendar = Calendar(identifier: .iso8601)
    calendar.timeZone = .current

    var perDay: [Date: TimeInterval] = [:]
    for session in sessions {
      guard let end = session.endTime else { continue }
      let day = calendar.startOfDay(for: session.startTime)
      perDay[day, default: 0] += max(0, end.timeIntervalSince(session.startTime))
    }

    let today = calendar.startOfDay(for: now)
    let monday = calendar.dateInterval(of: .weekOfYear, for: today)?.start ?? today
    days = (0..<7).map { offset in
      let date = calendar.date(byAdding: .day, value: offset, to: monday) ?? monday
      return Day(date: date, seconds: perDay[date] ?? 0)
    }
    totalSeconds = days.reduce(0) { $0 + $1.seconds }

    // Today still empty: the streak runs up to yesterday.
    var day = (perDay[today] ?? 0) > 0 ? today : calendar.date(byAdding: .day, value: -1, to: today)!
    var count = 0
    while (perDay[day] ?? 0) > 0 {
      count += 1
      day = calendar.date(byAdding: .day, value: -1, to: day)!
    }
    streak = count
  }
}

/// Android's `HomeStatsSheet` (`FeatureFlags.homeStats`): this week, growing out of the floating
/// nav bar. As wide as the nav bar and reaching down behind it, its bottom corners rounded like the
/// nav bar's ends so the two outlines meet. Closed it's a low strip with the handle and the flame
/// with the streak; open it adds the week total, the streak top right and a bar per day with its
/// time above it. Tap the top or drag to toggle. The caller draws the nav bar on top.
struct NotisWeekStatsSheet: View {
  let sessions: [BlockedProfileSession]
  @Binding var isExpanded: Bool
  /// Height of the nav bar's pill.
  let pillHeight: CGFloat

  /// How far a drag has to travel before the sheet opens or closes.
  private let dragThreshold: CGFloat = 32
  /// Height of the tallest bar; the time sits above it.
  private let barMaxHeight: CGFloat = 88
  /// The sheet stays this much inside the nav bar's outline, so no rim shows around its ends.
  private let outlineInset: CGFloat = 1

  private static let dayFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "nl_NL")
    formatter.dateFormat = "EEE"
    return formatter
  }()

  var body: some View {
    let stats = NotisWeekStats(sessions: sessions)
    let today = Calendar.current.startOfDay(for: Date())
    let bottomRadius = max(0, pillHeight / 2 - outlineInset)
    let shape = UnevenRoundedRectangle(
      topLeadingRadius: 24,
      bottomLeadingRadius: bottomRadius,
      bottomTrailingRadius: bottomRadius,
      topTrailingRadius: 24
    )

    VStack(alignment: .leading, spacing: 0) {
      header(stats: stats)

      if isExpanded {
        VStack(alignment: .leading, spacing: 0) {
          Text(totalText(stats.totalSeconds))
            .font(.satoshi(26, .medium))
            .foregroundStyle(NotisBrand.ink)
            .padding(.top, 4)
          bars(stats.days, today: today)
            .padding(.top, 16)
            .padding(.bottom, 14)
        }
        .transition(.move(edge: .bottom).combined(with: .opacity))
      }
    }
    .padding(.horizontal, 24)
    .padding(.bottom, pillHeight)
    .frame(maxWidth: .infinity)
    .background(shape.fill(NotisBrand.card))
    .clipShape(shape)
    .shadow(color: .black.opacity(0.12), radius: 6, y: 2)
    .padding(.horizontal, 32 + outlineInset)
    .padding(.bottom, 8 + outlineInset)
    .gesture(
      DragGesture(minimumDistance: 10).onEnded { value in
        if value.translation.height < -dragThreshold { setExpanded(true) }
        if value.translation.height > dragThreshold { setExpanded(false) }
      }
    )
  }

  /// Handle row: tapping it toggles the sheet. Equal space on both sides keeps the handle in the
  /// middle. Closed, the streak number sits right of it; open, "Deze week" takes the left half and
  /// the streak the right, their tops level with the handle's.
  private func header(stats: NotisWeekStats) -> some View {
    HStack(alignment: isExpanded ? .top : .center, spacing: 0) {
      ZStack(alignment: .topLeading) {
        if isExpanded {
          Text("Deze week")
            .font(.satoshi(14))
            .foregroundStyle(NotisBrand.inkSoft)
            .lineLimit(1)
        }
      }
      .frame(maxWidth: .infinity, alignment: .leading)

      Capsule()
        .fill(NotisPalette.light.surfaceContainerHigh)
        .frame(width: 36, height: 4)
        // The label's cap height starts a little below its line top.
        .padding(.top, isExpanded ? 4 : 0)

      ZStack(alignment: isExpanded ? .topTrailing : .leading) {
        if isExpanded {
          if stats.streak > 0 { streakLabel(stats.streak) }
        } else {
          streakChip(stats.streak).padding(.leading, 10)
        }
      }
      .frame(maxWidth: .infinity, alignment: isExpanded ? .trailing : .leading)
    }
    .padding(.top, isExpanded ? 14 : 8)
    .padding(.bottom, isExpanded ? 0 : 8)
    .contentShape(Rectangle())
    .onTapGesture { setExpanded(!isExpanded) }
    .accessibilityElement(children: .combine)
    .accessibilityAddTraits(.isButton)
    .accessibilityHint(isExpanded ? "Deze week verbergen" : "Deze week tonen")
  }

  private func bars(_ days: [NotisWeekStats.Day], today: Date) -> some View {
    let maxSeconds = max(days.map(\.seconds).max() ?? 0, 1)
    return VStack(spacing: 6) {
      HStack(alignment: .bottom, spacing: 6) {
        ForEach(days) { day in
          let isToday = day.date == today
          // An empty day keeps a thin stripe, so the week always reads as seven days.
          let fraction = day.seconds == 0 ? 0.04 : max(day.seconds / maxSeconds, 0.08)
          VStack(spacing: 4) {
            if day.seconds > 0 {
              Text(barTimeText(day.seconds))
                .font(.satoshi(11, isToday ? .bold : .regular))
                .foregroundStyle(isToday ? NotisBrand.ink : NotisBrand.inkSoft)
                .lineLimit(1)
                .fixedSize()
            }
            RoundedRectangle(cornerRadius: 6)
              .fill(
                day.seconds == 0
                  ? Color(hex: 0xEFECE4)
                  : NotisBrand.mandarin.opacity(isToday ? 1 : 0.4)
              )
              .frame(height: barMaxHeight * fraction)
          }
          .frame(maxWidth: .infinity)
        }
      }
      HStack(spacing: 6) {
        ForEach(days) { day in
          let isToday = day.date == today
          Text(Self.dayFormatter.string(from: day.date).replacingOccurrences(of: ".", with: ""))
            .font(.satoshi(12, isToday ? .bold : .regular))
            .foregroundStyle(isToday ? NotisBrand.ink : NotisBrand.inkSoft)
            .frame(maxWidth: .infinity)
        }
      }
    }
  }

  /// Flame and the streak number, next to the handle while the sheet is closed.
  private func streakChip(_ streak: Int) -> some View {
    HStack(spacing: 4) {
      Image(systemName: "flame")
        .font(.system(size: 15))
        .foregroundStyle(streak > 0 ? NotisBrand.mandarin : NotisBrand.inkSoft.opacity(0.5))
      Text("\(streak)")
        .font(.satoshi(14, .medium))
        .foregroundStyle(streak > 0 ? NotisBrand.ink : NotisBrand.inkSoft)
    }
  }

  /// Flame plus "5 dagen op rij".
  private func streakLabel(_ streak: Int) -> some View {
    HStack(alignment: .top, spacing: 4) {
      Image(systemName: "flame")
        .font(.system(size: 14))
        .foregroundStyle(NotisBrand.mandarin)
      Text(streak == 1 ? "1 dag op rij" : "\(streak) dagen op rij")
        .font(.satoshi(14))
        .foregroundStyle(NotisBrand.inkSoft)
        .lineLimit(1)
    }
  }

  private func setExpanded(_ expanded: Bool) {
    withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) { isExpanded = expanded }
  }

  /// "14 min", "3u 20m".
  private func totalText(_ seconds: TimeInterval) -> String {
    let totalMinutes = Int(seconds / 60)
    let hours = totalMinutes / 60
    let minutes = totalMinutes % 60
    return hours > 0 ? "\(hours)u \(minutes)m" : "\(minutes) min"
  }

  /// Short enough for a bar: "<1m", "12m", "1,5u".
  private func barTimeText(_ seconds: TimeInterval) -> String {
    let minutes = Int(seconds / 60)
    if minutes < 1 { return "<1m" }
    if minutes < 60 { return "\(minutes)m" }
    let hours = Double(minutes) / 60
    let format = minutes % 60 == 0 ? "%.0f" : "%.1f"
    return String(format: format, locale: Locale(identifier: "nl_NL"), hours) + "u"
  }
}
