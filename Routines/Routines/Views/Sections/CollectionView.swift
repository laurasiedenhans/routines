import SwiftUI
import SwiftData
import RoutineKit

/// Bereich „Routinen“ oder „Listen“: aktuelle Einträge, darunter einklappbar „Geplant“
/// und (nur bei Listen) „Abgeschlossen“.
struct CollectionView: View {
    let kind: ListKind

    @Environment(AppClock.self) private var clock
    @Query(sort: \RoutineList.sortOrder) private var lists: [RoutineList]
    @State private var showPlanned = false
    @State private var showCompleted = false

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
                CollapsibleSection(title: "Abgeschlossen", count: completed.count, isExpanded: $showCompleted) {
                    ForEach(completed) { list in
                        row(for: list, status: statuses[list.id])
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
    }

    @ViewBuilder
    private func row(for list: RoutineList, status: ListStatus?) -> some View {
        NavigationLink(value: list.id) {
            ListRow(list: list, status: status ?? ListStatus(list: list, now: clock.now))
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
