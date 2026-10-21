import Foundation

/// Wie oft eine Liste wiederholt wird. Zusammen mit `RecurrenceRule.interval`
/// ergibt sich z. B. „alle 3 Tage“ oder „alle 2 Wochen“.
public enum RecurrenceKind: String, CaseIterable, Codable, Sendable {
    /// Einmalige Liste: genau ein Zeitraum ab dem Starttag, ohne Ende.
    case none
    case daily
    case weekly
    case monthly
    case yearly
}

/// Vollständige Wiederholungsregel einer Liste (reiner Wert, unabhängig von SwiftData).
public struct RecurrenceRule: Hashable, Sendable {
    public var kind: RecurrenceKind
    /// Alle n Tage/Wochen/Monate/Jahre, immer ≥ 1.
    public var interval: Int
    /// Nur für `.weekly`: 1 = Sonntag … 7 = Samstag (wie `Calendar.component(.weekday)`).
    public var weekday: Int
    /// Starttag. Bei monatlich/jährlich zugleich der Ankertag.
    public var anchor: Date

    public init(kind: RecurrenceKind, interval: Int = 1, weekday: Int = 2, anchor: Date) {
        self.kind = kind
        self.interval = max(1, interval)
        self.weekday = min(max(weekday, 1), 7)
        self.anchor = anchor
    }
}

/// Ein Zeitraum `[start, end)`. Grenzen liegen immer auf 0:00 Uhr lokaler Zeit.
public struct Period: Hashable, Sendable {
    public let start: Date
    /// `nil` bei Listen ohne Wiederholung.
    public let end: Date?
    /// Stabiler Schlüssel `yyyy-MM-dd` des Zeitraumbeginns, wird in `TaskRecord` gespeichert.
    public let key: String

    public init(start: Date, end: Date?, key: String) {
        self.start = start
        self.end = end
        self.key = key
    }

    public func contains(_ date: Date) -> Bool {
        guard date >= start else { return false }
        guard let end else { return true }
        return date < end
    }
}
