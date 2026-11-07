import Foundation
import SwiftData
import Testing
@testable import RoutineKit

@Suite("Kategorien")
@MainActor
struct CategoryTests {
    let container: ModelContainer
    var context: ModelContext { container.mainContext }

    init() throws {
        container = try ModelContainer(
            for: RoutinePersistence.schema(),
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
    }

    /// Liste mit `done` erledigten von `total` To-dos am 23.10.2026.
    private func makeList(done: Int, of total: Int, recurrence: RecurrenceKind = .daily) -> (RoutineList, ListStatus) {
        let now = date(2026, 10, 23)
        let list = RoutineList(name: "Test", recurrence: recurrence, anchorDate: date(2026, 10, 1, 0))
        context.insert(list)
        let period = engine.period(for: list.rule, containing: now)!
        for index in 0..<total {
            let task = context.addTask("To-do \(index)", to: list, at: date(2026, 10, 1, 0))
            if index < done { context.complete(task, in: period, at: now) }
        }
        return (list, ListStatus(list: list, now: now, engine: engine))
    }

    @Test func percentAddsUpAllTasks() {
        // 2/4 + 3/6 = 5/10 = 50 % (nicht der Durchschnitt 50 % + 50 %, hier zufällig gleich)
        let a = makeList(done: 2, of: 4).1
        let b = makeList(done: 3, of: 6, recurrence: .none).1
        #expect(CategoryProgress.percent(of: [a, b]) == 50)
        // 1/1 + 0/3 = 25 %, der Durchschnitt wäre 50 %
        let c = makeList(done: 1, of: 1).1
        let d = makeList(done: 0, of: 3).1
        #expect(CategoryProgress.percent(of: [c, d]) == 25)
    }

    @Test func percentIsNilWithoutTasks() {
        #expect(CategoryProgress.percent(of: []) == nil)
        #expect(CategoryProgress.percent(of: [makeList(done: 0, of: 0).1]) == nil)
    }

    @Test func newCategoriesAreAppended() {
        let first = context.addCategory("Workout")
        let second = context.addCategory("Uni")
        #expect(second.sortOrder > first.sortOrder)
    }

    @Test func deletingCategoryKeepsLists() throws {
        let category = context.addCategory("Workout", emoji: "💪")
        let (list, _) = makeList(done: 0, of: 2)
        list.category = category
        try context.save()

        context.deleteCategory(category)
        try context.save()

        let lists = try context.fetch(FetchDescriptor<RoutineList>())
        #expect(lists.count == 1)
        #expect(lists.first?.category == nil)
        #expect(try context.fetch(FetchDescriptor<ListCategory>()).isEmpty)
    }

    @Test func displayNameShowsEmoji() {
        #expect(ListCategory(name: "Workout", emoji: "💪").displayName == "💪 Workout")
        #expect(ListCategory(name: "Uni").displayName == "Uni")
    }
}
