import SwiftUI
import SwiftData
import RoutineKit

/// Einklappbarer Abschnitt mit Anzahl und Pfeil, z. B. „Geplant (2)“.
struct CollapsibleSection<Content: View>: View {
    let title: String
    let count: Int
    @Binding var isExpanded: Bool
    @ViewBuilder var content: () -> Content

    var body: some View {
        Section {
            if isExpanded {
                content()
            }
        } header: {
            Button {
                withAnimation(Theme.Motion.check) { isExpanded.toggle() }
            } label: {
                HStack {
                    Text("\(title) (\(count))")
                    Spacer()
                    Image(systemName: "chevron.right")
                        .rotationEffect(.degrees(isExpanded ? 90 : 0))
                }
                .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("\(title), \(count)")
            .accessibilityHint(isExpanded ? "Einklappen" : "Ausklappen")
        }
    }
}

/// Navigationsstapel eines Bereichs. Öffnet Listen per `NavigationLink(value: list.id)`
/// und kümmert sich ums Löschen (erst zurück, dann löschen).
struct SectionStack<Content: View>: View {
    @ViewBuilder var content: () -> Content

    @Environment(\.modelContext) private var context
    @Query(sort: \RoutineList.sortOrder) private var lists: [RoutineList]
    @State private var path: [UUID] = []

    init(@ViewBuilder content: @escaping () -> Content) {
        self.content = content
    }

    var body: some View {
        NavigationStack(path: $path) {
            content()
                .navigationDestination(for: UUID.self) { id in
                    if let list = lists.first(where: { $0.id == id }) {
                        ListDetailView(list: list, onDelete: { delete(list) })
                    }
                }
        }
    }

    private func delete(_ list: RoutineList) {
        path.removeAll()
        Task {
            try? await Task.sleep(for: .milliseconds(450))
            context.delete(list)
            try? context.save()
        }
    }
}

/// Zahnrad oben rechts, öffnet die allgemeinen Einstellungen.
private struct SettingsToolbarModifier: ViewModifier {
    @State private var showSettings = false

    func body(content: Content) -> some View {
        content
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showSettings = true
                    } label: {
                        Label("Einstellungen", systemImage: "gearshape")
                    }
                }
            }
            .sheet(isPresented: $showSettings) {
                NavigationStack {
                    SettingsView()
                }
            }
    }
}

extension View {
    func settingsToolbar() -> some View {
        modifier(SettingsToolbarModifier())
    }
}

/// Ordnet einen Teil der Listen neu an und verwendet dabei deren bisherige Reihenfolge-Plätze,
/// damit Listen in anderen Bereichen ihre Position behalten.
func reorder(_ items: [RoutineList], from source: IndexSet, to destination: Int) {
    let slots = items.map(\.sortOrder).sorted()
    var reordered = items
    reordered.move(fromOffsets: source, toOffset: destination)
    for (index, list) in reordered.enumerated() {
        list.sortOrder = slots[index]
    }
}
