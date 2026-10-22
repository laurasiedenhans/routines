import SwiftUI
import SwiftData
import RoutineKit

/// Startbildschirm: Tageskarte, aktive Listen und darunter einklappbar die geplanten Listen.
struct HomeView: View {
    @Binding var selection: UUID?

    @Environment(AppClock.self) private var clock
    @Environment(AppSettings.self) private var settings
    @Query(sort: \RoutineList.sortOrder) private var lists: [RoutineList]
    @State private var showNewList = false
    @State private var showSettings = false
    @State private var showPlanned = false

    init(selection: Binding<UUID?>) {
        _selection = selection
    }

    var body: some View {
        let engine = RecurrenceEngine.current
        let now = clock.now
        let summary = DayRingSummary.make(
            lists: lists,
            selection: settings.selection(for: settings.ringStyle),
            now: now,
            engine: engine
        )
        let active = lists.filter { engine.period(for: $0.rule, containing: now) != nil }
        // Geplante Listen: die nächste zuerst
        let planned = lists
            .filter { engine.period(for: $0.rule, containing: now) == nil }
            .sorted { $0.anchorDate < $1.anchorDate }

        List(selection: $selection) {
            if !lists.isEmpty {
                Section {
                    DayProgressCard(summary: summary, style: settings.ringStyle)
                        .listRowInsets(EdgeInsets())
                        .listRowBackground(Color.clear)
                }
            }

            if !active.isEmpty {
                Section("Listen") {
                    ForEach(active) { list in
                        NavigationLink(value: list.id) {
                            ListRow(list: list, status: ListStatus(list: list, now: now, engine: engine))
                        }
                    }
                    .onMove { source, destination in
                        move(active: active, planned: planned, from: source, to: destination)
                    }
                }
            }

            if !planned.isEmpty {
                Section {
                    if showPlanned {
                        ForEach(planned) { list in
                            NavigationLink(value: list.id) {
                                ListRow(list: list, status: ListStatus(list: list, now: now, engine: engine))
                            }
                        }
                    }
                } header: {
                    Button {
                        withAnimation(Theme.Motion.check) { showPlanned.toggle() }
                    } label: {
                        HStack {
                            Text("Geplant (\(planned.count))")
                            Spacer()
                            Image(systemName: "chevron.right")
                                .rotationEffect(.degrees(showPlanned ? 90 : 0))
                        }
                        .contentShape(.rect)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(showPlanned ? "Geplante Listen ausblenden" : "Geplante Listen anzeigen")
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
                ListSettingsView(mode: .create(.routine))
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

    /// Sortiert die aktiven Listen um. Geplante Listen behalten ihre Reihenfolge dahinter.
    private func move(active: [RoutineList], planned: [RoutineList], from source: IndexSet, to destination: Int) {
        var reordered = active
        reordered.move(fromOffsets: source, toOffset: destination)
        let plannedInOrder = planned.sorted { $0.sortOrder < $1.sortOrder }
        for (index, list) in (reordered + plannedInOrder).enumerated() {
            list.sortOrder = index
        }
    }
}

/// Eine Zeile in der Listenübersicht.
struct ListRow: View {
    let list: RoutineList
    let status: ListStatus
    /// Ersetzt den Fortschrittsbalken, z. B. „Wird in 3 Tagen gelöscht“.
    var footnote: String? = nil

    var body: some View {
        HStack(spacing: Theme.Spacing.m) {
            ListIcon(emoji: list.emoji, color: list.color.color)
            VStack(alignment: .leading, spacing: Theme.Spacing.s) {
                HStack(alignment: .firstTextBaseline, spacing: Theme.Spacing.s) {
                    Text(list.name.isEmpty ? "Ohne Namen" : list.name)
                        .font(.body.weight(.semibold))
                        .lineLimit(1)
                        .layoutPriority(1)
                    Spacer(minLength: 0)
                    RecurrenceLabel(list: list)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                if let footnote {
                    Text(footnote)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else if status.isActive {
                    ListProgressBar(fraction: status.fraction, color: list.color.color)
                } else {
                    Text("Startet am \(RecurrenceFormatting.startDate(list.anchorDate))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, Theme.Spacing.xs)
        .accessibilityElement(children: .combine)
    }
}

/// Wiederholungsinfo `Rhythmus · Detail · Uhrzeit`. Wird bei Platzmangel stufenweise gekürzt:
/// erst ohne Detail, dann nur der Rhythmus.
struct RecurrenceLabel: View {
    let list: RoutineList

    var body: some View {
        let variants = RecurrenceFormatting.parts(for: list).variants
        ViewThatFits(in: .horizontal) {
            Text(variants[0]).lineLimit(1)
            Text(variants[1]).lineLimit(1)
            Text(variants[2]).lineLimit(1)
        }
    }
}

#Preview {
    NavigationStack {
        HomeView(selection: .constant(nil))
    }
    .previewEnvironment()
}
