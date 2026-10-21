import SwiftUI
import SwiftData
import RoutineKit

/// Startbildschirm: Tageskarte und alle Listen mit Fortschrittsbalken.
struct HomeView: View {
    @Binding var selection: UUID?

    @Environment(AppClock.self) private var clock
    @Environment(AppSettings.self) private var settings
    @Query(sort: \RoutineList.sortOrder) private var lists: [RoutineList]
    @State private var showNewList = false
    @State private var showSettings = false

    init(selection: Binding<UUID?>) {
        _selection = selection
    }

    var body: some View {
        let engine = RecurrenceEngine.current
        let summary = DayRingSummary.make(
            lists: lists,
            selection: settings.selection(for: settings.ringStyle),
            now: clock.now,
            engine: engine
        )

        List(selection: $selection) {
            if !lists.isEmpty {
                Section {
                    DayProgressCard(summary: summary, style: settings.ringStyle)
                        .listRowInsets(EdgeInsets())
                        .listRowBackground(Color.clear)
                }

                Section("Listen") {
                    ForEach(lists) { list in
                        NavigationLink(value: list.id) {
                            ListRow(list: list, status: ListStatus(list: list, now: clock.now, engine: engine))
                        }
                    }
                    .onMove(perform: move)
                }
            }
        }
        .navigationTitle("Routinen")
        .overlay {
            if lists.isEmpty {
                ContentUnavailableView {
                    Label("Noch keine Routinen", systemImage: "checklist")
                } description: {
                    Text("Lege deine erste Liste an, z. B. eine Morgenroutine.")
                } actions: {
                    Button("Neue Liste") { showNewList = true }
                        .buttonStyle(.borderedProminent)
                }
            }
        }
        .toolbar {
            ToolbarItem(placement: .navigation) {
                Button {
                    showSettings = true
                } label: {
                    Label("Einstellungen", systemImage: "gearshape")
                }
            }
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showNewList = true
                } label: {
                    Label("Neue Liste", systemImage: "plus")
                }
            }
        }
        .sheet(isPresented: $showNewList) {
            NavigationStack {
                ListSettingsView(mode: .create)
            }
        }
        .sheet(isPresented: $showSettings) {
            NavigationStack {
                SettingsView()
            }
        }
        .task(id: ringCandidates) {
            settings.reconcile(candidates: ringCandidates)
        }
    }

    private var ringCandidates: [RingCandidate] {
        lists.filter(\.isRingEligible).map(\.ringCandidate)
    }

    private func move(from source: IndexSet, to destination: Int) {
        var reordered = lists
        reordered.move(fromOffsets: source, toOffset: destination)
        for (index, list) in reordered.enumerated() {
            list.sortOrder = index
        }
    }
}

/// Eine Zeile in der Listenübersicht.
struct ListRow: View {
    let list: RoutineList
    let status: ListStatus

    var body: some View {
        HStack(spacing: Theme.Spacing.m) {
            ListIcon(emoji: list.emoji, color: list.color.color)
            VStack(alignment: .leading, spacing: Theme.Spacing.s) {
                HStack(alignment: .firstTextBaseline) {
                    Text(list.name.isEmpty ? "Ohne Namen" : list.name)
                        .font(.body.weight(.semibold))
                        .lineLimit(1)
                    Spacer(minLength: Theme.Spacing.s)
                    Text(RecurrenceFormatting.rowSubtitle(for: list, isActive: status.isActive))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                ListProgressBar(fraction: status.fraction, color: list.color.color)
            }
        }
        .padding(.vertical, Theme.Spacing.xs)
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    NavigationStack {
        HomeView(selection: .constant(nil))
    }
    .previewEnvironment()
}
