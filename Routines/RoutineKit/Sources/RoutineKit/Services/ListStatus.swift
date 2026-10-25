import Foundation

/// Zustand einer Liste in einem Zeitraum: offene und erledigte To-dos.
public struct ListStatus {
    /// `nil`, wenn die Liste noch nicht aktiv ist (Starttag in der Zukunft).
    public let period: Period?
    public let open: [RoutineTask]
    public let done: [RoutineTask]
    /// Der Zeitraum beginnt heute.
    public let isDueToday: Bool

    public var isActive: Bool { period != nil }
    public var total: Int { open.count + done.count }
    public var fraction: Double { total == 0 ? 0 : Double(done.count) / Double(total) }
    public var isComplete: Bool { total > 0 && open.isEmpty }

    /// Zustand im aktuellen Zeitraum.
    public init(list: RoutineList, now: Date, engine: RecurrenceEngine = .current) {
        if let period = engine.period(for: list.rule, containing: now) {
            self.init(list: list, period: period, now: now, engine: engine)
        } else {
            self.init(previewOf: list)
        }
    }

    /// Vorschau vor dem Start: nur dauerhafte, nicht gelöschte To-dos, nicht abhakbar.
    private init(previewOf list: RoutineList) {
        self.period = nil
        self.open = list.sortedTasks.filter { $0.deletedAt == nil && $0.oneOffPeriodKey == nil }
        self.done = []
        self.isDueToday = false
    }

    /// Zustand in einem beliebigen Zeitraum (zum Blättern in Vergangenheit und Zukunft).
    public init(list: RoutineList, period: Period, now: Date, engine: RecurrenceEngine = .current) {
        let visible = list.sortedTasks.filter { $0.isVisible(in: period) }
        self.period = period
        self.open = visible.filter { !$0.isCompleted(in: period) }
        self.done = visible.filter { $0.isCompleted(in: period) }
        self.isDueToday = period.start == engine.startOfDay(now)
    }
}
