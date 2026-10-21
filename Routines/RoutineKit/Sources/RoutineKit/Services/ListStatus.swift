import Foundation

/// Zustand einer Liste zu einem Zeitpunkt: aktueller Zeitraum, offene und erledigte To-dos.
public struct ListStatus {
    /// `nil`, wenn die Liste noch nicht aktiv ist (Starttag in der Zukunft).
    public let period: Period?
    public let open: [RoutineTask]
    public let done: [RoutineTask]
    /// Heute beginnt ein neuer Zeitraum.
    public let isDueToday: Bool

    public var isActive: Bool { period != nil }
    public var total: Int { open.count + done.count }
    public var fraction: Double { total == 0 ? 0 : Double(done.count) / Double(total) }
    public var isComplete: Bool { total > 0 && open.isEmpty }

    public init(list: RoutineList, now: Date, engine: RecurrenceEngine = .current) {
        let rule = list.rule
        let tasks = list.sortedTasks

        guard let period = engine.period(for: rule, containing: now) else {
            // Vorschau vor dem Start: nur dauerhafte, nicht gelöschte To-dos, nicht abhakbar.
            self.period = nil
            self.open = tasks.filter { $0.deletedAt == nil && $0.oneOffPeriodKey == nil }
            self.done = []
            self.isDueToday = false
            return
        }

        let visible = tasks.filter { $0.isVisible(in: period) }
        self.period = period
        self.open = visible.filter { !$0.isCompleted(in: period) }
        self.done = visible.filter { $0.isCompleted(in: period) }
        self.isDueToday = period.start == engine.startOfDay(now)
    }
}
