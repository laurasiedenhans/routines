import SwiftUI
import SwiftData
import RoutineKit

/// Daily Dashboard: Tageskarte mit Ring (Ringauswahl aus den Einstellungen) und darunter
/// alle täglichen Routinen, die heute fällig sind. Später personalisierbar.
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
        // Alle täglichen Routinen (auch „alle n Tage“), die heute fällig sind – unabhängig von der Ringauswahl.
        // Wöchentliche, monatliche, jährliche und einmalige Listen erscheinen hier nicht.
        let dueToday = lists.filter { $0.recurrence == .daily && engine.isDue($0.rule, on: now) }

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
