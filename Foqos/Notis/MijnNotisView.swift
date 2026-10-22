import FamilyControls
import SwiftData
import SwiftUI

/// "Mijn NOTIS": pair, rename and remove stones, and pick each stone's apps.
struct MijnNotisView: View {
  @Environment(\.modelContext) private var context
  @Environment(\.dismiss) private var dismiss

  @EnvironmentObject private var strategyManager: StrategyManager

  @Query(sort: [
    SortDescriptor(\BlockedProfiles.order, order: .forward),
    SortDescriptor(\BlockedProfiles.createdAt, order: .forward),
  ]) private var profiles: [BlockedProfiles]

  @State private var scanner = NFCScannerUtil()
  @State private var pairingTag: PairingTag?
  @State private var errorMessage: String?

  private var stones: [BlockedProfiles] {
    profiles.filter(\.isNotisStone)
  }

  var body: some View {
    NavigationStack {
      List {
        if stones.isEmpty {
          Section {
            Text("Koppel je eerste steen. Daarna kies je welke apps je tijdens een sessie nog mag gebruiken.")
              .foregroundStyle(NotisTheme.ink.opacity(0.7))
          }
        } else {
          Section("Mijn stenen") {
            ForEach(stones) { stone in
              NavigationLink {
                NotisStoneDetailView(stone: stone)
              } label: {
                StoneRow(stone: stone, isActive: strategyManager.activeSession?.blockedProfile.id == stone.id)
              }
            }
          }
        }

        Section {
          Button {
            startPairing()
          } label: {
            Label("Steen koppelen", systemImage: "plus.circle.fill")
          }
          .disabled(strategyManager.isBlocking)
        } footer: {
          if strategyManager.isBlocking {
            Text("Ontgrendel eerst om een steen te koppelen.")
          }
        }
      }
      .scrollContentBackground(.hidden)
      .background(NotisTheme.paper)
      .navigationTitle("Mijn NOTIS")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .topBarTrailing) {
          Button("Klaar") { dismiss() }
        }
      }
      .tint(NotisTheme.ink)
      .sheet(item: $pairingTag) { pairing in
        PairStoneView(tag: pairing.tag, existingStones: stones)
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
    }
  }

  private func startPairing() {
    scanner.onTagScanned = { result in
      if let existing = BlockedProfiles.findNotisStone(withTag: result.id, in: context) {
        errorMessage = String(localized: "Deze steen is al gekoppeld als \(existing.name).")
        return
      }
      pairingTag = PairingTag(tag: result.id)
    }
    scanner.onError = { message in
      errorMessage = message
    }
    scanner.scan(alertMessage: String(localized: "Houd je iPhone bij de nieuwe NOTIS-steen"))
  }
}

private struct PairingTag: Identifiable {
  let tag: String
  var id: String { tag }
}

private struct StoneRow: View {
  let stone: BlockedProfiles
  let isActive: Bool

  var body: some View {
    HStack(spacing: 12) {
      NotisStoneShape()
        .fill(isActive ? NotisTheme.mandarin : NotisTheme.card)
        .overlay(NotisStoneShape().strokeBorder(NotisTheme.mandarin, lineWidth: 2))
        .frame(width: 34, height: 28)
      VStack(alignment: .leading, spacing: 2) {
        Text(stone.name)
          .font(.body.weight(.semibold))
        Text(appSummary)
          .font(.caption)
          .foregroundStyle(.secondary)
      }
    }
  }

  private var appSummary: String {
    let count = FamilyActivityUtil.countSelectedActivities(
      stone.selectedActivity, allowMode: stone.enableAllowMode)
    if isActive {
      return String(localized: "Nu vergrendeld")
    }
    return stone.enableAllowMode
      ? String(localized: "\(count) apps blijven bruikbaar")
      : String(localized: "\(count) apps op slot")
  }
}

/// Name the new stone, optionally copy another stone's apps, then edit the selection.
private struct PairStoneView: View {
  @Environment(\.modelContext) private var context
  @Environment(\.dismiss) private var dismiss

  let tag: String
  let existingStones: [BlockedProfiles]

  @State private var name: String = ""
  @State private var selection = FamilyActivitySelection(includeEntireCategory: FeatureFlags.allowList)
  @State private var showAppPicker = false
  @State private var errorMessage: String?

  var body: some View {
    NavigationStack {
      Form {
        Section("Naam") {
          TextField("Bijvoorbeeld: Bureau", text: $name)
        }

        if !existingStones.isEmpty {
          Section {
            Menu {
              ForEach(existingStones) { stone in
                Button(stone.name) {
                  // A copy, not a link: later edits to either stone stay separate.
                  selection = stone.selectedActivity
                }
              }
            } label: {
              Label("Apps kopiëren van een andere steen", systemImage: "doc.on.doc")
            }
          }
        }

        Section {
          Button {
            showAppPicker = true
          } label: {
            Label(appsButtonTitle, systemImage: "square.grid.2x2")
          }
        } footer: {
          Text(
            FeatureFlags.allowList
              ? "Kies de apps die je tijdens een sessie nog mag gebruiken. Al het andere gaat op slot."
              : "Kies de apps die tijdens een sessie op slot gaan."
          )
        }
      }
      .scrollContentBackground(.hidden)
      .background(NotisTheme.paper)
      .navigationTitle("Nieuwe steen")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .topBarLeading) {
          Button("Annuleer") { dismiss() }
        }
        ToolbarItem(placement: .topBarTrailing) {
          Button("Opslaan") { save() }
            .disabled(trimmedName.isEmpty)
        }
      }
      .tint(NotisTheme.ink)
      .sheet(isPresented: $showAppPicker) {
        AppPicker(
          selection: $selection,
          isPresented: $showAppPicker,
          allowMode: FeatureFlags.allowList
        )
      }
      .alert(
        "Opslaan lukte niet",
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
        if name.isEmpty {
          name =
            existingStones.isEmpty
            ? String(localized: "Mijn NOTIS")
            : String(localized: "Steen \(existingStones.count + 1)")
        }
      }
    }
  }

  private var trimmedName: String {
    name.trimmingCharacters(in: .whitespacesAndNewlines)
  }

  private var appsButtonTitle: String {
    let count = FamilyActivityUtil.countSelectedActivities(selection, allowMode: FeatureFlags.allowList)
    return count == 0 ? String(localized: "Apps kiezen") : String(localized: "Apps kiezen (\(count))")
  }

  private func save() {
    do {
      _ = try BlockedProfiles.createNotisStone(
        in: context,
        name: trimmedName,
        tag: tag,
        selection: selection
      )
      dismiss()
    } catch {
      errorMessage = error.localizedDescription
    }
  }
}

#Preview {
  MijnNotisView()
    .environmentObject(StrategyManager())
    .environmentObject(ThemeManager())
}
