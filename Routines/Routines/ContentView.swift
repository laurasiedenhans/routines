import SwiftUI
import SwiftData
import RoutineKit
#if os(iOS)
import UIKit
#endif

/// Wurzelansicht. iPhone: drei Bereiche mit Navigationsleiste unten (`PhoneRootView`).
/// iPad/Mac (noch nicht überarbeitet): Listenübersicht links, Liste rechts.
struct ContentView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.scenePhase) private var scenePhase
    @Environment(AppClock.self) private var clock
    @Query(sort: \RoutineList.sortOrder) private var lists: [RoutineList]
    @State private var selection: UUID?

    var body: some View {
        root
            .onChange(of: scenePhase) { _, phase in
                // Pflicht: Apps werden im Hintergrund eingefroren, Timer laufen dann nicht.
                if phase == .active { clock.refresh() }
            }
    }

    @ViewBuilder
    private var root: some View {
        #if os(iOS)
        if UIDevice.current.userInterfaceIdiom == .phone {
            PhoneRootView()
        } else {
            splitView
        }
        #else
        splitView
        #endif
    }

    private var splitView: some View {
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
