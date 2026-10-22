import SwiftUI
import SwiftData
import RoutineKit

/// Bereich „Routinen“ oder „Listen“: aktuelle Einträge, darunter einklappbar „Geplant“
/// und (nur bei Listen) „Abgeschlossen“ mit „Alle löschen“.
struct CollectionView: View {
    let kind: ListKind

    @Environment(\.modelContext) private var context
    @Environment(AppClock.self) private var clock
    @Environment(AppSettings.self) private var settings
    @Query(sort: \RoutineList.sortOrder) private var lists: [RoutineList]
    @State private var showPlanned = false
    @State private var showCompleted = false
    @State private var confirmDeleteCompleted = false

    init(kind: ListKind) {
        self.kind = kind
    }

    var body: some View {
        let engine = RecurrenceEngine.current
        let now = clock.now
        let mine = lists.filter { kind.matches($0) }
        let statuses = Dictionary(uniqueKeysWithValues: mine.map {
            ($0.id, ListStatus(list: $0, now: now, engine: engine))
        })

        let completed = kind == .list
            ? mine.filter { statuses[$0.id]?.isActive == true && statuses[$0.id]?.isComplete == true }
            : []
        let current = mine.filter { list in
            statuses[list.id]?.isActive == true && !completed.contains { $0.id == list.id }
        }
        // Geplant: die nächste zuerst
        let planned = mine
            .filter { statuses[$0.id]?.isActive == false }
            .sorted { $0.anchorDate < $1.anchorDate }

        List {
            if !current.isEmpty {
                Section {
                    ForEach(current) { list in
                        row(for: list, status: statuses[list.id])
                    }
                    .onMove { reorder(current, from: $0, to: $1) }
                }
            }

            if !planned.isEmpty {
                CollapsibleSection(title: "Geplant", count: planned.count, isExpanded: $showPlanned) {
                    ForEach(planned) { list in
                        row(for: list, status: statuses[list.id])
                    }
                }
            }

            if !completed.isEmpty {
                CollapsibleSection(
                    title: "Abgeschlossen",
                    count: completed.count,
                    isExpanded: $showCompleted,
                    actionTitle: "Alle löschen",
                    action: { confirmDeleteCompleted = true }
                ) {
                    ForEach(completed) { list in
                        row(for: list, status: statuses[list.id], footnote: deletionNote(for: list, now: now, engine: engine))
                    }
                }
            }
        }
        .navigationTitle(kind.title)
        .settingsToolbar()
        .overlay {
            if mine.isEmpty {
                ContentUnavailableView {
                    Label(kind == .routine ? "Noch keine Routinen" : "Noch keine Listen", systemImage: "checklist")
                } description: {
                    Text(kind == .routine
                         ? "Tippe auf „+“, um z. B. eine Morgenroutine anzulegen."
                         : "Tippe auf „+“, um z. B. eine Packliste anzulegen.")
                }
            }
        }
        .confirmationDialog(
            "Alle abgeschlossenen Listen löschen?",
            isPresented: $confirmDeleteCompleted,
            titleVisibility: .visible
        ) {
            Button(completed.count == 1 ? "1 Liste löschen" : "\(completed.count) Listen löschen", role: .destructive) {
                withAnimation(Theme.Motion.check) {
                    for list in completed { context.delete(list) }
                }
                try? context.save()
            }
            Button("Abbrechen", role: .cancel) {}
        } message: {
            Text("Die Listen und ihre To-dos werden endgültig gelöscht.")
        }
    }

    @ViewBuilder
    private func row(for list: RoutineList, status: ListStatus?, footnote: String? = nil) -> some View {
        NavigationLink(value: list.id) {
            ListRow(list: list, status: status ?? ListStatus(list: list, now: clock.now), footnote: footnote)
        }
    }

    /// „Wird in 3 Tagen gelöscht“, wenn automatisches Aufräumen aktiv ist.
    private func deletionNote(for list: RoutineList, now: Date, engine: RecurrenceEngine) -> String? {
        guard let date = CompletedListCleanup.deletionDate(
            of: list,
            retention: settings.completedListRetention,
            now: now,
            engine: engine
        ) else { return nil }

        let days = engine.calendar.dateComponents(
            [.day],
            from: engine.startOfDay(now),
            to: engine.startOfDay(date)
        ).day ?? 0
        switch days {
        case ..<1: return "Wird heute gelöscht"
        case 1: return "Wird morgen gelöscht"
        default: return "Wird in \(days) Tagen gelöscht"
        }
    }
}

#Preview("Routinen") {
    SectionStack {
        CollectionView(kind: .routine)
    }
    .previewEnvironment()
}

#Preview("Listen") {
    SectionStack {
        CollectionView(kind: .list)
    }
    .previewEnvironment()
}
