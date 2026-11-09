import SwiftUI
import SwiftData
import RoutineKit

/// Daily Dashboard: Tageskarte mit Ring (Ringauswahl aus den Einstellungen), darunter
/// alle täglichen Routinen, die heute fällig sind, und die heute fälligen und überfälligen To-dos.
struct DashboardView: View {
    @Environment(\.modelContext) private var context
    @Environment(AppClock.self) private var clock
    @Environment(AppSettings.self) private var settings
    @Query(sort: \RoutineList.sortOrder) private var lists: [RoutineList]

    var body: some View {
        let engine = RecurrenceEngine.current
        let now = clock.now
        let summary = DayRingSummary.make(
            lists: lists,
            selection: settings.selection(for: settings.ringStyle),
            todoItem: DueDates.ringItem(lists: lists, color: settings.todoColor, now: now, engine: engine),
            now: now,
            engine: engine
        )
        // Einmalige To-dos mit Datum: überfällige zuerst, sonst eigene Reihenfolge
        let todos = DueDates.openEntries(lists: lists, now: now, engine: engine)
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

            if !todos.isEmpty {
                Section("To-dos") {
                    ForEach(todos) { entry in
                        DueTodoRow(entry: entry) {
                            withAnimation(Theme.Motion.check) {
                                context.complete(entry.task, in: entry.period, at: now)
                            }
                            try? context.save()
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
