import SwiftData
import SwiftUI

/// "Avondslot" under Meldingen in settings, as Android's `BedtimeSection`: a list of lock times
/// like Apple's alarms (big time, days and profile, a switch), "+" for a new one.
struct NotisBedtimeSheet: View {
  @Environment(\.modelContext) private var context
  @Environment(\.dismiss) private var dismiss

  @Query(sort: [
    SortDescriptor(\BlockedProfiles.order, order: .forward),
    SortDescriptor(\BlockedProfiles.createdAt, order: .forward),
  ]) private var allProfiles: [BlockedProfiles]

  @State private var alarms = NotisBedtime.load()
  @State private var editing: EditingAlarm?

  private var profiles: [BlockedProfiles] {
    allProfiles.filter(\.isNotisProfile)
  }


  var body: some View {
    NavigationStack {
      ScrollView {
        VStack(alignment: .leading, spacing: 10) {
          Text("Op deze tijd gaat je telefoon op slot met het profiel dat je kiest. Alleen je NOTIS haalt hem eraf.")
            .font(.satoshi(14))
            .foregroundStyle(NotisBrand.inkSoft)
            .padding(.bottom, 4)

          if alarms.isEmpty {
            Text("Nog geen avondslot. Tik op + om een tijd te kiezen.")
              .font(.satoshi(15))
              .foregroundStyle(NotisBrand.inkSoft)
              .multilineTextAlignment(.center)
              .frame(maxWidth: .infinity)
              .padding(.vertical, 24)
          }

          ForEach(alarms) { alarm in
            alarmRow(alarm)
          }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
      }
      .background(NotisBrand.paper.ignoresSafeArea())
      .navigationTitle("Avondslot")
      .toolbar {
        ToolbarItem(placement: .topBarLeading) {
          Button("Klaar") { dismiss() }
        }
        ToolbarItem(placement: .topBarTrailing) {
          Button {
            let free = NotisBedtime.allDays & ~NotisBedtime.takenDays(alarms, exceptId: nil)
            editing = EditingAlarm(
              alarm: NotisBedtimeAlarm(
                minuteOfDay: 21 * 60 + 30, days: free, profileId: profiles.first?.id.uuidString),
              isNew: true)
          } label: {
            Image(systemName: "plus")
          }
          .accessibilityLabel("Tijd toevoegen")
        }
      }
      .tint(NotisBrand.mandarinDark)
    }
    .sheet(item: $editing) { editing in
      NotisBedtimeEditView(
        alarm: editing.alarm,
        isNew: editing.isNew,
        profiles: profiles,
        onSave: { alarms = NotisBedtime.save($0, in: context) },
        onDelete: { alarms = NotisBedtime.delete(editing.alarm.id, in: context) }
      )
    }
  }

  private func alarmRow(_ alarm: NotisBedtimeAlarm) -> some View {
    let profileName =
      profiles.first { $0.id.uuidString == alarm.profileId }?.name ?? profiles.first?.name ?? ""
    return HStack {
      Button {
        editing = EditingAlarm(alarm: alarm, isNew: false)
      } label: {
        VStack(alignment: .leading, spacing: 0) {
          Text(alarm.timeText)
            .font(.satoshi(46, .light))
            .foregroundStyle(NotisBrand.ink)
          Text("\(NotisBedtime.daysText(alarm.days)) · \(profileName)\(untilText(alarm))")
            .font(.satoshi(14))
            .foregroundStyle(NotisBrand.inkSoft)
        }
        .opacity(alarm.enabled ? 1 : 0.45)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
      }
      .buttonStyle(.plain)
      Toggle(
        "",
        isOn: Binding(
          get: { alarm.enabled },
          set: { alarms = NotisBedtime.setEnabled(alarm.id, $0, in: context) }
        )
      )
      .labelsHidden()
      .tint(NotisBrand.mandarinDark)
    }
    .padding(.horizontal, 18)
    .padding(.vertical, 14)
    .notisCard()
  }
}

/// " · tot 07:00" for an alarm with an end time.
private func untilText(_ alarm: NotisBedtimeAlarm) -> String {
  guard let end = alarm.endMinuteOfDay else { return "" }
  return " · " + String(localized: "tot \(String(format: "%02d:%02d", end / 60, end % 60))")
}

private struct EditingAlarm: Identifiable {
  let alarm: NotisBedtimeAlarm
  let isNew: Bool
  var id: String { alarm.id }
}

/// New or edited lock time: Apple's time wheels, the days (each day only once) and the profile.
private struct NotisBedtimeEditView: View {
  @Environment(\.dismiss) private var dismiss

  let alarm: NotisBedtimeAlarm
  let isNew: Bool
  let profiles: [BlockedProfiles]
  let onSave: (NotisBedtimeAlarm) -> Void
  let onDelete: () -> Void

  @State private var time = Date()
  @State private var days = 0
  @State private var profileId: String?
  @State private var hasEnd = false
  @State private var endTime = Date()
  @State private var isLoaded = false

  private var canSave: Bool {
    days != 0 && profileId != nil
  }

  var body: some View {
    NavigationStack {
      ScrollView {
        VStack(alignment: .leading, spacing: 12) {
          DatePicker("", selection: $time, displayedComponents: .hourAndMinute)
            .datePickerStyle(.wheel)
            .labelsHidden()
            .frame(maxWidth: .infinity)

          Text("Herhaal")
            .font(.satoshi(16, .bold))
            .foregroundStyle(NotisBrand.ink)
          HStack(spacing: 6) {
            ForEach(NotisBedtime.dayOrder, id: \.self) { dayIndex in
              dayChip(dayIndex)
            }
          }

          // Optional: unlock by itself the next morning.
          Toggle(isOn: $hasEnd) {
            VStack(alignment: .leading, spacing: 2) {
              Text("Eindtijd")
                .font(.satoshi(16, .bold))
                .foregroundStyle(NotisBrand.ink)
              Text("Vanzelf weer vrij, de volgende ochtend als die vóór de slottijd ligt")
                .font(.satoshi(13))
                .foregroundStyle(NotisBrand.inkSoft)
            }
          }
          .tint(NotisBrand.mandarinDark)
          .padding(.top, 4)
          if hasEnd {
            DatePicker("", selection: $endTime, displayedComponents: .hourAndMinute)
              .datePickerStyle(.wheel)
              .labelsHidden()
              .frame(maxWidth: .infinity)
          }

          Text("Profiel")
            .font(.satoshi(16, .bold))
            .foregroundStyle(NotisBrand.ink)
            .padding(.top, 4)
          if profiles.isEmpty {
            Text("Maak eerst een profiel bij Profielen.")
              .font(.satoshi(14))
              .foregroundStyle(NotisBrand.inkSoft)
          }
          ForEach(profiles) { profile in
            NotisChoiceRow(
              title: profile.name,
              subtitle: profile.notisAppsSummary,
              isSelected: profileId == profile.id.uuidString
            ) { profileId = profile.id.uuidString }
          }

          if !isNew {
            Button(role: .destructive) {
              onDelete()
              dismiss()
            } label: {
              Text("Tijd verwijderen")
                .font(.satoshi(16, .bold))
                .frame(maxWidth: .infinity, minHeight: 52)
                .background(NotisPalette.light.error.opacity(0.1), in: Capsule())
            }
            .padding(.top, 8)
          }
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 16)
      }
      .background(NotisBrand.paper.ignoresSafeArea())
      .navigationTitle(isNew ? "Nieuwe tijd" : "Tijd wijzigen")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .topBarLeading) {
          Button("Annuleren") { dismiss() }
        }
        ToolbarItem(placement: .topBarTrailing) {
          Button("Bewaar") {
            let parts = Calendar.current.dateComponents([.hour, .minute], from: time)
            var saved = alarm
            saved.minuteOfDay = (parts.hour ?? 0) * 60 + (parts.minute ?? 0)
            saved.days = days
            saved.profileId = profileId
            saved.enabled = true
            let endParts = Calendar.current.dateComponents([.hour, .minute], from: endTime)
            saved.endMinuteOfDay = hasEnd ? (endParts.hour ?? 7) * 60 + (endParts.minute ?? 0) : nil
            onSave(saved)
            dismiss()
          }
          .font(.satoshi(16, .bold))
          .disabled(!canSave)
        }
      }
      .tint(NotisBrand.mandarinDark)
    }
    .onAppear {
      guard !isLoaded else { return }
      time = Calendar.current.date(bySettingHour: alarm.hour, minute: alarm.minute, second: 0, of: Date()) ?? Date()
      days = alarm.days
      profileId = alarm.profileId ?? profiles.first?.id.uuidString
      hasEnd = alarm.endMinuteOfDay != nil
      let end = alarm.endMinuteOfDay ?? 7 * 60
      endTime = Calendar.current.date(bySettingHour: end / 60, minute: end % 60, second: 0, of: Date()) ?? Date()
      isLoaded = true
    }
  }

  private func dayChip(_ dayIndex: Int) -> some View {
    let bit = 1 << dayIndex
    let isOn = days & bit != 0
    return Button {
      days ^= bit
    } label: {
      Text(NotisBedtime.dayShort(dayIndex))
        .font(.satoshi(13, .bold))
        .foregroundStyle(isOn ? .white : NotisBrand.mandarinDark)
        .frame(maxWidth: .infinity)
        .aspectRatio(1, contentMode: .fit)
        .background(Circle().fill(isOn ? NotisBrand.mandarinDark : NotisBrand.mandarinDark.opacity(0.1)))
    }
    .buttonStyle(.plain)
  }
}
