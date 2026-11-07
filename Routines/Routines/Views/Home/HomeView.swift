import SwiftUI
import SwiftData
import RoutineKit

/// Startbildschirm (iPad/Mac): Tageskarte, aktive Listen ohne Kategorie, die Kategorien
/// und darunter einklappbar die geplanten Listen.
struct HomeView: View {
    @Binding var selection: UUID?

    @Environment(AppClock.self) private var clock
    @Environment(AppSettings.self) private var settings
    @Query(sort: \RoutineList.sortOrder) private var lists: [RoutineList]
    @Query(sort: \ListCategory.sortOrder) private var categories: [ListCategory]
    @State private var categoryUI = CategoryUIState()
    @State private var showNewCategory = false
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
        let grouped = CategoryGrouping.make(active, categories: categories)

        List(selection: $selection) {
            if !lists.isEmpty {
                Section {
                    DayProgressCard(summary: summary, style: settings.ringStyle)
                        .listRowInsets(EdgeInsets())
                        .listRowBackground(Color.clear)
                }
            }

            if !grouped.uncategorized.isEmpty {
                Section("Listen") {
                    ForEach(grouped.uncategorized) { list in
                        NavigationLink(value: list.id) {
                            ListRow(list: list, status: ListStatus(list: list, now: now, engine: engine))
                        }
                        .id("none-\(list.id)")
                    }
                    .onMove { reorder(grouped.uncategorized, from: $0, to: $1) }
                }
            }

            ForEach(grouped.groups) { group in
                CategorySection(
                    category: group.category,
                    count: group.lists.count,
                    percent: CategoryProgress.percent(of: group.lists.map { ListStatus(list: $0, now: now, engine: engine) }),
                    isExpanded: settings.expandedBinding(for: group.category),
                    onEditEmoji: { categoryUI.emojiFor = group.category },
                    onReorder: { categoryUI.showOrder = true },
                    onDelete: { categoryUI.deleting = group.category }
                ) {
                    if group.lists.isEmpty {
                        Text("Noch leer. Ordne Listen in ihren Einstellungen dieser Kategorie zu.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                    ForEach(group.lists) { list in
                        NavigationLink(value: list.id) {
                            ListRow(list: list, status: ListStatus(list: list, now: now, engine: engine))
                        }
                        .id("\(group.id)-\(list.id)")
                    }
                    .onMove { reorder(group.lists, from: $0, to: $1) }
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
                Menu {
                    Button("Neue Liste", systemImage: "checklist") { showNewList = true }
                    Button("Neue Kategorie", systemImage: "folder") { showNewCategory = true }
                } label: {
                    Label("Hinzufügen", systemImage: "plus")
                }
            }
        }
        .categoryDialogs($categoryUI)
        .newCategoryAlert(isPresented: $showNewCategory)
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
