import SwiftUI
import SwiftData
import RoutineKit

/// Wurzelansicht: Listenübersicht links, Liste rechts (iPad/Mac), auf dem iPhone als Stapel.
struct ContentView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.scenePhase) private var scenePhase
    @Environment(AppClock.self) private var clock
    @Query(sort: \RoutineList.sortOrder) private var lists: [RoutineList]
    @State private var selection: UUID?

    var body: some View {
        NavigationSplitView {
            HomeView(selection: $selection)
                .navigationSplitViewColumnWidth(min: 300, ideal: 360)
        } detail: {
            if let selection, let list = lists.first(where: { $0.id == selection }) {
                NavigationStack {
                    ListDetailView(list: list, onDelete: { delete(list) })
                }
            } else {
                ContentUnavailableView(
                    "Keine Liste ausgewählt",
                    systemImage: "checklist",
                    description: Text("Wähle eine Liste aus oder lege eine neue an.")
                )
            }
        }
        .onChange(of: scenePhase) { _, phase in
            // Pflicht: Apps werden im Hintergrund eingefroren, Timer laufen dann nicht.
            if phase == .active { clock.refresh() }
        }
    }

    /// Erst zurücknavigieren, dann löschen, damit keine Ansicht ein gelöschtes Objekt anzeigt.
    private func delete(_ list: RoutineList) {
        selection = nil
        Task {
            try? await Task.sleep(for: .milliseconds(450))
            context.delete(list)
            try? context.save()
        }
    }
}

#Preview {
    ContentView()
        .previewEnvironment()
}
