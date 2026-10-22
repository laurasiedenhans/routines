import Foundation
import SwiftData

/// Alle Änderungen an Listen und To-dos laufen über diese Funktionen.
public extension ModelContext {

    func complete(_ task: RoutineTask, in period: Period, at date: Date = Date()) {
        guard !task.isCompleted(in: period) else { return }
        let record = TaskRecord(periodKey: period.key, kind: .completed, createdAt: date)
        insert(record)
        record.task = task
    }

    func uncomplete(_ task: RoutineTask, in period: Period) {
        for record in task.matchingRecords(key: period.key, kind: .completed) {
            delete(record)
        }
    }

    /// „Nur heute / diesmal löschen“
    func skip(_ task: RoutineTask, in period: Period, at date: Date = Date()) {
        guard !task.isSkipped(in: period) else { return }
        let record = TaskRecord(periodKey: period.key, kind: .skipped, createdAt: date)
        insert(record)
        record.task = task
    }

    /// „Alle zukünftigen löschen“ – Soft Delete, Historie bleibt.
    func deleteFutureOccurrences(of task: RoutineTask, at date: Date = Date()) {
        task.deletedAt = date
    }

    /// Für Listen ohne Wiederholung und einmalige To-dos.
    func deletePermanently(_ task: RoutineTask) {
        delete(task)
    }

    @discardableResult
    func addTask(
        _ title: String,
        to list: RoutineList,
        oneOffPeriodKey: String? = nil,
        at date: Date = Date()
    ) -> RoutineTask {
        let nextOrder = ((list.tasks ?? []).map(\.sortOrder).max() ?? -1) + 1
        let task = RoutineTask(title: title, sortOrder: nextOrder, createdAt: date, oneOffPeriodKey: oneOffPeriodKey)
        insert(task)
        task.list = list
        return task
    }

    /// „Alle löschen“ im Erledigt-Bereich einer einmaligen Liste.
    func deleteCompletedTasks(of list: RoutineList, in period: Period) {
        for task in list.tasks ?? [] where task.isCompleted(in: period) {
            delete(task)
        }
    }

    /// „Wiederverwenden“: entfernt alle To-dos, die Liste ist danach leer.
    func deleteAllTasks(of list: RoutineList) {
        for task in list.tasks ?? [] {
            delete(task)
        }
    }

    /// Löscht alle Listen, To-dos und Einträge (Entwicklerbereich).
    func deleteAllRoutineData() throws {
        try delete(model: TaskRecord.self)
        try delete(model: RoutineTask.self)
        try delete(model: RoutineList.self)
        try save()
    }
}
