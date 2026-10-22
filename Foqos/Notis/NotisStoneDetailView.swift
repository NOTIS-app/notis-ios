import FamilyControls
import SwiftData
import SwiftUI

/// Rename a stone, change its apps or remove it. Nothing can change while it is locking the
/// phone, so a session can't be loosened from inside.
struct NotisStoneDetailView: View {
  @Environment(\.modelContext) private var context
  @Environment(\.dismiss) private var dismiss

  @EnvironmentObject private var strategyManager: StrategyManager

  let stone: BlockedProfiles

  @State private var name: String = ""
  @State private var selection = FamilyActivitySelection()
  @State private var showAppPicker = false
  @State private var showRemoveConfirm = false
  @State private var errorMessage: String?
  @State private var isRemoved = false

  private var isLocked: Bool {
    strategyManager.isBlocking
  }

  var body: some View {
    Form {
      Section("Naam") {
        TextField("Naam", text: $name)
          .onSubmit(saveName)
          .disabled(isLocked)
      }

      Section {
        Button {
          showAppPicker = true
        } label: {
          Label(appsTitle, systemImage: "square.grid.2x2")
        }
        .disabled(isLocked)
      } footer: {
        Text(
          stone.enableAllowMode
            ? "Deze apps blijven bruikbaar als je met deze steen vergrendelt."
            : "Deze apps gaan op slot als je met deze steen vergrendelt."
        )
      }

      Section {
        Button("Steen verwijderen", role: .destructive) {
          showRemoveConfirm = true
        }
        .disabled(isLocked)
      } footer: {
        if isLocked {
          Text("Ontgrendel eerst om deze steen aan te passen.")
        }
      }
    }
    .scrollContentBackground(.hidden)
    .background(NotisTheme.paper)
    .navigationTitle(name)
    .navigationBarTitleDisplayMode(.inline)
    .sheet(isPresented: $showAppPicker, onDismiss: saveApps) {
      AppPicker(
        selection: $selection,
        isPresented: $showAppPicker,
        allowMode: stone.enableAllowMode
      )
    }
    .confirmationDialog(
      "Steen verwijderen?",
      isPresented: $showRemoveConfirm,
      titleVisibility: .visible
    ) {
      Button("Verwijderen", role: .destructive, action: remove)
      Button("Annuleer", role: .cancel) {}
    } message: {
      Text("Je kunt de steen later opnieuw koppelen.")
    }
    .alert(
      "Dat lukte niet",
      isPresented: Binding(
        get: { errorMessage != nil },
        set: { if !$0 { errorMessage = nil } }
      )
    ) {
      Button("OK", role: .cancel) {}
    } message: {
      Text(errorMessage ?? "")
    }
    .onAppear {
      name = stone.name
      selection = stone.selectedActivity
    }
    .onDisappear(perform: saveName)
  }

  private var appsTitle: String {
    let count = FamilyActivityUtil.countSelectedActivities(selection, allowMode: stone.enableAllowMode)
    return String(localized: "Apps kiezen (\(count))")
  }

  private func saveName() {
    guard !isRemoved else { return }
    let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty, trimmed != stone.name else { return }
    do {
      try BlockedProfiles.renameNotisStone(stone, to: trimmed, in: context)
    } catch {
      errorMessage = error.localizedDescription
    }
  }

  private func saveApps() {
    guard !isRemoved else { return }
    do {
      try BlockedProfiles.updateNotisStoneApps(stone, selection: selection, in: context)
    } catch {
      errorMessage = error.localizedDescription
    }
  }

  private func remove() {
    isRemoved = true
    do {
      try BlockedProfiles.deleteProfile(stone, in: context)
      try context.save()
      dismiss()
    } catch {
      errorMessage = error.localizedDescription
    }
  }
}
