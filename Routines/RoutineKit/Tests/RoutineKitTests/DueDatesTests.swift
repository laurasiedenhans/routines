import Foundation
import SwiftData
import Testing
@testable import RoutineKit

@Suite("Fälligkeitsdaten")
@MainActor
struct DueDatesTests {
    let container: ModelContainer
    var context: ModelContext { container.mainContext }
    let now = date(2026, 11, 9, 13)

    init() throws {
        container = try ModelContainer(
            for: RoutinePersistence.schema(),
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
    }

    /// Einmalige Liste mit To-dos, die an den angegebenen Tagen (relativ zu heute) fällig sind.
    private func oneOffList(_ name: String, sortOrder: Int, due: [Int?]) -> (RoutineList, [RoutineTask]) {
        let list = RoutineList(name: name, sortOrder: sortOrder, recurrence: .none, anchorDate: date(2026, 11, 1, 0))
        context.insert(list)
        let tasks = due.enumerated().map { index, offset in
            context.addTask(
                "\(name) \(index)",
                to: list,
                dueDate: offset.map { date(2026, 11, 9 + $0, 0) },
                at: date(2026, 11, 1, 0)
            )
        }
        return (list, tasks)
    }

    @Test func statusComparesDaysOnly() {
        #expect(DueDates.status(of: date(2026, 11, 8, 0), now: now, engine: engine) == .overdue)
        #expect(DueDates.status(of: date(2026, 11, 9, 0), now: now, engine: engine) == .today)
        #expect(DueDates.status(of: date(2026, 11, 9, 23), now: now, engine: engine) == .today)
        #expect(DueDates.status(of: date(2026, 11, 10, 0), now: now, engine: engine) == .upcoming)
    }

    @Test func onlyOneOffTasksAllowDueDates() {
        #expect(DueDates.allowsDueDate(recurrence: .none, oneOffPeriodKey: nil))
        #expect(DueDates.allowsDueDate(recurrence: .daily, oneOffPeriodKey: "2026-11-09"))
        #expect(!DueDates.allowsDueDate(recurrence: .weekly, oneOffPeriodKey: nil))
    }

    @Test func todayListShowsOverdueFirstThenOwnOrder() {
        // Liste A: heute, ohne Datum, morgen · Liste B: überfällig, heute
        let (_, a) = oneOffList("A", sortOrder: 0, due: [0, nil, 1])
        let (_, b) = oneOffList("B", sortOrder: 1, due: [-2, 0])
        let entries = DueDates.openEntries(lists: [], now: now, engine: engine)
        #expect(entries.isEmpty)

        let lists = try! context.fetch(FetchDescriptor<RoutineList>())
        let titles = DueDates.openEntries(lists: lists, now: now, engine: engine).map(\.task.title)
        #expect(titles == [b[0].title, a[0].title, b[1].title])
    }

    @Test func completedTasksLeaveTodayButCountInRingWhenDoneToday() throws {
        let (list, tasks) = oneOffList("A", sortOrder: 0, due: [0, -1, 0])
        let period = try #require(engine.period(for: list.rule, containing: now))
        context.complete(tasks[0], in: period, at: now)                   // heute erledigt
        context.complete(tasks[1], in: period, at: date(2026, 11, 7, 9))  // früher erledigt

        let open = DueDates.openEntries(lists: [list], now: now, engine: engine)
        #expect(open.map(\.task.title) == [tasks[2].title])

        let item = try #require(DueDates.ringItem(lists: [list], color: .red, now: now, engine: engine))
        #expect(item.done == 1)
        #expect(item.total == 2)
    }

    @Test func overdueCountPerList() {
        let (list, _) = oneOffList("A", sortOrder: 0, due: [-3, -1, 0, nil])
        #expect(DueDates.overdueCount(in: list, now: now, engine: engine) == 2)
    }

    @Test func ringShowsTodosWhenSelected() {
        let (list, _) = oneOffList("A", sortOrder: 0, due: [0])
        let item = DueDates.ringItem(lists: [list], color: .red, now: now, engine: engine)
        let summary = DayRingSummary.make(lists: [list], selection: [DueDates.ringID], todoItem: item, now: now, engine: engine)
        #expect(summary.state == .ready)
        #expect(summary.items.map(\.id) == [DueDates.ringID])

        let without = DayRingSummary.make(lists: [list], selection: [], todoItem: item, now: now, engine: engine)
        #expect(without.state == .noSelection)
    }
}
