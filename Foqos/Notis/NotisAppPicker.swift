import FamilyControls
import SwiftData
import SwiftUI

/// Apple's app picker in NOTIS colours. Unlike Foqos' picker there is no "x / 50" counter or
/// limit warning: NOTIS doesn't cap how many apps a stone lists.
struct NotisAppPicker: View {
  @Binding var selection: FamilyActivitySelection
  var allowMode: Bool = FeatureFlags.allowList
  let onDone: () -> Void

  // FamilyActivityPicker sometimes stops redrawing; a ticking invisible view and a refresh
  // button work around it (same workaround as Foqos' AppPicker).
  private let stateUpdateTimer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
  @State private var updateFlag = false
  @State private var refreshID = UUID()

  var body: some View {
    NavigationStack {
      ZStack {
        Text(verbatim: "Updating view state because of bug in iOS...")
          .foregroundStyle(.clear)
          .accessibilityHidden(true)
          .opacity(updateFlag ? 1 : 0)

        FamilyActivityPicker(selection: $selection)
          .id(refreshID)
      }
      .safeAreaInset(edge: .top) {
        Text(
          allowMode
            ? "Kies de apps die je tijdens een sessie mag gebruiken. Al het andere gaat op slot."
            : "Kies de apps die tijdens een sessie op slot gaan."
        )
        .font(.satoshi(13))
        .foregroundStyle(NotisBrand.inkSoft)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 20)
        .padding(.vertical, 8)
        .background(NotisBrand.paper)
      }
      .background(NotisBrand.paper.ignoresSafeArea())
      .navigationTitle(allowMode ? "Toegestane apps" : "Apps om te blokkeren")
      .navigationBarTitleDisplayMode(.inline)
      .toolbarBackground(NotisBrand.paper, for: .navigationBar)
      .toolbarBackground(.visible, for: .navigationBar)
      .toolbar {
        ToolbarItem(placement: .topBarLeading) {
          Button {
            refreshID = UUID()
          } label: {
            Image(systemName: "arrow.clockwise")
          }
          .accessibilityLabel("Vernieuwen")
        }
        ToolbarItem(placement: .topBarTrailing) {
          Button("Klaar", action: onDone)
            .font(.satoshi(16, .bold))
        }
      }
      .tint(NotisBrand.mandarinDark)
      .onReceive(stateUpdateTimer) { _ in
        updateFlag.toggle()
      }
    }
  }
}

/// Edits one stone's apps; saves when closed, however it is closed.
struct NotisAppPickerSheet: View {
  @Environment(\.modelContext) private var context
  @Environment(\.dismiss) private var dismiss

  let stone: BlockedProfiles

  @State private var selection = FamilyActivitySelection()
  @State private var isLoaded = false

  var body: some View {
    NotisAppPicker(selection: $selection, allowMode: stone.enableAllowMode) {
      dismiss()
    }
    .onAppear {
      guard !isLoaded else { return }
      selection = stone.selectedActivity
      isLoaded = true
    }
    .onDisappear {
      guard isLoaded, !stone.isDeleted else { return }
      try? BlockedProfiles.updateNotisStoneApps(stone, selection: selection, in: context)
    }
  }
}
