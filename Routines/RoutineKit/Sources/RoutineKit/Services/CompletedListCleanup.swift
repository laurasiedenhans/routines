import Foundation

/// Wie lange abgeschlossene einmalige Listen erhalten bleiben.
public enum ListRetention: String, CaseIterable, Codable, Sendable {
    case never
    case oneDay
    case threeDays
    case oneWeek
    case twoWeeks
    case oneMonth

    /// Tage bis zum Löschen, `nil` = nie löschen.
    public var days: Int? {
        switch self {
        case .never: nil
        case .oneDay: 1
        case .threeDays: 3
        case .oneWeek: 7
        case .twoWeeks: 14
        case .oneMonth: 30
        }
    }
}

/// Automatisches Aufräumen abgeschlossener einmaliger Listen.
/// Gezählt wird ab dem letzten abgehakten To-do. Läuft beim Öffnen der App und beim Tageswechsel.
public enum CompletedListCleanup {

    /// Zeitpunkt des letzten Abhakens, wenn die Liste ohne Wiederholung ist und alle To-dos erledigt sind.
    public static func completionDate(of list: RoutineList, now: Date, engine: RecurrenceEngine = .current) -> Date? {
        guard list.recurrence == .none else { return nil }
        let status = ListStatus(list: list, now: now, engine: engine)
        guard status.isComplete, let period = status.period else { return nil }
        return status.done
            .flatMap { $0.matchingRecords(key: period.key, kind: .completed) }
            .map(\.createdAt)
            .max()
    }

    /// Wann eine Liste gelöscht wird, `nil` bei „Nie“.
    public static func deletionDate(completedAt: Date, retention: ListRetention, calendar: Calendar = .current) -> Date? {
        guard let days = retention.days else { return nil }
        return calendar.date(byAdding: .day, value: days, to: completedAt)
    }

    /// Wann diese Liste gelöscht wird, `nil` wenn sie nicht abgeschlossen ist oder nie gelöscht wird.
    public static func deletionDate(of list: RoutineList, retention: ListRetention, now: Date, engine: RecurrenceEngine = .current) -> Date? {
        guard let completedAt = completionDate(of: list, now: now, engine: engine) else { return nil }
        return deletionDate(completedAt: completedAt, retention: retention, calendar: engine.calendar)
    }

    /// Listen, deren Frist abgelaufen ist.
    public static func expiredLists(_ lists: [RoutineList], retention: ListRetention, now: Date, engine: RecurrenceEngine = .current) -> [RoutineList] {
        guard retention != .never else { return [] }
        return lists.filter { list in
            guard let date = deletionDate(of: list, retention: retention, now: now, engine: engine) else { return false }
            return date <= now
        }
    }
}
