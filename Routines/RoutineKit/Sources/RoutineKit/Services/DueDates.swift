import Foundation

/// Fälligkeitsdaten einzelner To-dos.
///
/// Nur einmalige To-dos können ein Datum haben: alle To-dos in Listen ohne Wiederholung und
/// „Einmalig“-To-dos in Routinen. Routinen selbst haben ihre Fälligkeit schon über die Wiederholung.
/// Es zählt nur der Tag: überfällig ist ein To-do ab dem Tag nach seinem Datum.
public enum DueDates {
    /// Platzhalter-ID, mit der „Fällige To-dos“ wie eine eigene Liste im Tagesring ausgewählt werden.
    public static let ringID = UUID(uuidString: "D0E00000-0000-4000-8000-000000000001")!

    public enum Status: Equatable, Sendable {
        case upcoming
        case today
        case overdue
    }

    /// Eintrag in der Sektion „To-dos“ auf Heute.
    public struct Entry: Identifiable {
        public let task: RoutineTask
        public let list: RoutineList
        /// Zeitraum, in dem das To-do abgehakt wird
        public let period: Period
        public let status: Status
        public var id: UUID { task.id }
    }

    public static func allowsDueDate(recurrence: RecurrenceKind, oneOffPeriodKey: String?) -> Bool {
        recurrence == .none || oneOffPeriodKey != nil
    }

    public static func status(of dueDate: Date, now: Date, engine: RecurrenceEngine = .current) -> Status {
        let due = engine.startOfDay(dueDate)
        let today = engine.startOfDay(now)
        if due < today { return .overdue }
        if due == today { return .today }
        return .upcoming
    }

    /// Offene To-dos, die heute fällig oder überfällig sind. Überfällige zuerst,
    /// sonst in der eigenen Reihenfolge (Listen, dann To-dos).
    public static func openEntries(lists: [RoutineList], now: Date, engine: RecurrenceEngine = .current) -> [Entry] {
        let entries = candidates(lists: lists, now: now, engine: engine)
            .filter { !$0.task.isCompleted(in: $0.period) && $0.status != .upcoming }
        return entries.filter { $0.status == .overdue } + entries.filter { $0.status == .today }
    }

    /// Anzahl überfälliger, offener To-dos einer Liste (Hinweis in den Übersichten).
    public static func overdueCount(in list: RoutineList, now: Date, engine: RecurrenceEngine = .current) -> Int {
        candidates(lists: [list], now: now, engine: engine)
            .filter { $0.status == .overdue && !$0.task.isCompleted(in: $0.period) }
            .count
    }

    /// „To-dos“ als eigener Eintrag im Tagesring: alle heute fälligen und überfälligen To-dos.
    /// Erledigt zählt nur, was heute abgehakt wurde. `nil`, wenn es nichts gibt.
    public static func ringItem(lists: [RoutineList], color: ListColor, now: Date, engine: RecurrenceEngine = .current) -> DayRingItem? {
        let today = engine.startOfDay(now)
        var done = 0
        var total = 0
        for entry in candidates(lists: lists, now: now, engine: engine) where entry.status != .upcoming {
            let records = entry.task.matchingRecords(key: entry.period.key, kind: .completed)
            if records.isEmpty {
                total += 1
            } else if records.contains(where: { engine.startOfDay($0.createdAt) == today }) {
                done += 1
                total += 1
            }
        }
        guard total > 0 else { return nil }
        return DayRingItem(id: ringID, name: "To-dos", emoji: "✓", color: color, done: done, total: total, startTimeMinutes: nil)
    }

    // MARK: - Intern

    /// Alle To-dos mit Datum, die zu ihrem Zeitraum gehören (nicht gelöscht, nicht übersprungen),
    /// in Listen- und To-do-Reihenfolge.
    private static func candidates(lists: [RoutineList], now: Date, engine: RecurrenceEngine) -> [Entry] {
        var result: [Entry] = []
        for list in lists.sorted(by: { $0.sortOrder < $1.sortOrder }) {
            let current = engine.period(for: list.rule, containing: now)
            for task in list.sortedTasks {
                guard let dueDate = task.dueDate,
                      task.deletedAt == nil,
                      allowsDueDate(recurrence: list.recurrence, oneOffPeriodKey: task.oneOffPeriodKey),
                      let period = period(of: task, in: list, current: current, dueDate: dueDate),
                      !task.isSkipped(in: period)
                else { continue }
                result.append(Entry(task: task, list: list, period: period, status: status(of: dueDate, now: now, engine: engine)))
            }
        }
        return result
    }

    /// Liste ohne Wiederholung: ihr einziger Zeitraum (erst ab dem Start).
    /// Einmaliges To-do einer Routine: der Zeitraum, für den es eingeplant ist (Abhaken zählt dort).
    private static func period(of task: RoutineTask, in list: RoutineList, current: Period?, dueDate: Date) -> Period? {
        if list.recurrence == .none { return current }
        guard let key = task.oneOffPeriodKey else { return nil }
        if let current, current.key == key { return current }
        // Für Erledigt/Übersprungen zählt nur der Schlüssel.
        return Period(start: dueDate, end: nil, key: key)
    }
}
