import Foundation
import SwiftData

// CloudKit-Regeln (siehe Docs/PROJECT.md, Abschnitt 5):
// keine Unique-Constraints, jedes Attribut mit Standardwert oder optional,
// alle Beziehungen optional und mit Inverse.

/// Eine Routinen-Liste, z. B. „Morgenroutine“.
@Model
public final class RoutineList {
    public var id: UUID = UUID()
    public var name: String = ""
    public var emoji: String = "✅"
    /// Rohwert von `ListColor`.
    public var colorRaw: String = "blue"
    public var sortOrder: Int = 0
    public var createdAt: Date = Date()

    // Wiederholung
    public var recurrenceRaw: String = "daily"
    public var interval: Int = 1
    public var weekday: Int = 2
    public var anchorDate: Date = Date()

    // Startzeit & Erinnerung
    /// Minuten seit 0:00, `nil` = keine Startzeit.
    public var startTimeMinutes: Int? = nil
    public var notificationEnabled: Bool = false
    public var liveActivityEnabled: Bool = false

    @Relationship(deleteRule: .cascade, inverse: \RoutineTask.list)
    public var tasks: [RoutineTask]? = []

    public init(
        name: String = "",
        emoji: String = "✅",
        color: ListColor = .blue,
        sortOrder: Int = 0,
        recurrence: RecurrenceKind = .daily,
        interval: Int = 1,
        weekday: Int = 2,
        anchorDate: Date = Date(),
        startTimeMinutes: Int? = nil,
        notificationEnabled: Bool = false,
        liveActivityEnabled: Bool = false
    ) {
        self.id = UUID()
        self.name = name
        self.emoji = emoji
        self.colorRaw = color.rawValue
        self.sortOrder = sortOrder
        self.createdAt = Date()
        self.recurrenceRaw = recurrence.rawValue
        self.interval = max(1, interval)
        self.weekday = weekday
        self.anchorDate = anchorDate
        self.startTimeMinutes = startTimeMinutes
        self.notificationEnabled = notificationEnabled
        self.liveActivityEnabled = liveActivityEnabled
        self.tasks = []
    }
}

/// Ein dauerhaftes To-do (Vorlage) einer Liste.
@Model
public final class RoutineTask {
    public var id: UUID = UUID()
    public var title: String = ""
    public var sortOrder: Int = 0
    public var createdAt: Date = Date()
    /// Soft Delete für „Alle zukünftigen löschen“. Die Historie bleibt erhalten.
    public var deletedAt: Date? = nil
    /// Gesetzt = To-do gilt nur in diesem einen Zeitraum („Einmalig“).
    public var oneOffPeriodKey: String? = nil
    public var list: RoutineList?

    @Relationship(deleteRule: .cascade, inverse: \TaskRecord.task)
    public var records: [TaskRecord]? = []

    public init(title: String, sortOrder: Int = 0, createdAt: Date = Date(), oneOffPeriodKey: String? = nil) {
        self.id = UUID()
        self.title = title
        self.sortOrder = sortOrder
        self.createdAt = createdAt
        self.oneOffPeriodKey = oneOffPeriodKey
        self.records = []
    }
}

/// Ein Eintrag „erledigt“ oder „übersprungen“ für einen Zeitraum.
@Model
public final class TaskRecord {
    public var id: UUID = UUID()
    public var periodKey: String = ""
    public var kindRaw: String = "completed"
    public var createdAt: Date = Date()
    public var task: RoutineTask?

    public init(periodKey: String, kind: RecordKind, createdAt: Date = Date()) {
        self.id = UUID()
        self.periodKey = periodKey
        self.kindRaw = kind.rawValue
        self.createdAt = createdAt
    }
}

public enum RecordKind: String, Codable, Sendable {
    case completed
    case skipped
}

// MARK: - Komfort

public extension RoutineList {
    var recurrence: RecurrenceKind {
        get { RecurrenceKind(rawValue: recurrenceRaw) ?? .daily }
        set { recurrenceRaw = newValue.rawValue }
    }

    var color: ListColor {
        get { ListColor(rawValue: colorRaw) ?? .blue }
        set { colorRaw = newValue.rawValue }
    }

    var rule: RecurrenceRule {
        RecurrenceRule(kind: recurrence, interval: interval, weekday: weekday, anchor: anchorDate)
    }

    /// Alle To-dos nach Reihenfolge sortiert.
    var sortedTasks: [RoutineTask] {
        (tasks ?? []).sorted { lhs, rhs in
            lhs.sortOrder != rhs.sortOrder ? lhs.sortOrder < rhs.sortOrder : lhs.createdAt < rhs.createdAt
        }
    }

    /// Kann in den Tagesring aufgenommen werden (täglich oder alle n Tage).
    var isRingEligible: Bool { recurrence == .daily }

    var ringCandidate: RingCandidate {
        RingCandidate(id: id, interval: interval, sortOrder: sortOrder)
    }
}

public extension RoutineTask {
    func matchingRecords(key: String, kind: RecordKind) -> [TaskRecord] {
        (records ?? []).filter { !$0.isDeleted && $0.periodKey == key && $0.kindRaw == kind.rawValue }
    }

    /// Mehrere Erledigt-Einträge (z. B. nach Sync) zählen einfach als erledigt.
    func isCompleted(in period: Period) -> Bool {
        !matchingRecords(key: period.key, kind: .completed).isEmpty
    }

    func isSkipped(in period: Period) -> Bool {
        !matchingRecords(key: period.key, kind: .skipped).isEmpty
    }

    func isVisible(in period: Period) -> Bool {
        TaskVisibility.isVisible(
            createdAt: createdAt,
            deletedAt: deletedAt,
            oneOffPeriodKey: oneOffPeriodKey,
            isSkipped: isSkipped(in: period),
            in: period
        )
    }
}
