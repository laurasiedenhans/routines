import SwiftUI
import SwiftData
import RoutineKit

/// Daily Dashboard: Tageskarte mit Ring und die Routinen, die heute in den Ring zählen.
/// Später personalisierbar (welche Routinen hier erscheinen).
struct DashboardView: View {
    @Environment(AppClock.self) private var clock
    @Environment(AppSettings.self) private var settings
    @Query(sort: \RoutineList.sortOrder) private var lists: [RoutineList]

    var body: some View {
        let engine = RecurrenceEngine.current
        let now = clock.now
        let summary = DayRingSummary.make(
            lists: lists,
            selection: settings.selection(for: settings.ringStyle),
            now: now,
            engine: engine
        )
        let dueToday = summary.items.compactMap { item in lists.first { $0.id == item.id } }

        List {
            Section {
                DayProgressCard(summary: summary, style: settings.ringStyle)
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
            }

            if !dueToday.isEmpty {
                Section("Heute fällig") {
                    ForEach(dueToday) { list in
                        NavigationLink(value: list.id) {
                            ListRow(list: list, status: ListStatus(list: list, now: now, engine: engine))
                        }
                    }
                }
            }
        }
        .navigationTitle("Heute")
        .settingsToolbar()
    }
}

#Preview {
    SectionStack {
        DashboardView()
    }
    .previewEnvironment()
}
