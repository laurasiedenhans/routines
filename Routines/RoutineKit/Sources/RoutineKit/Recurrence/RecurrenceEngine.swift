import Foundation

/// Berechnet Zeiträume für Wiederholungsregeln. Reine, synchrone Logik ohne Zustand.
///
/// Wichtig: Jeder Zeitraumbeginn wird immer neu aus dem Ankertag berechnet
/// (`periodStart(index:)`), nie aus dem vorherigen Zeitraum. Nur so bleibt der
/// Ankertag erhalten (30.01. → 28.02. → 30.03.).
public struct RecurrenceEngine: Sendable {
    public let calendar: Calendar

    public init(calendar: Calendar = .current) {
        self.calendar = calendar
    }

    /// Engine mit dem aktuellen Systemkalender (Zeitzone/Locale des Geräts).
    public static var current: RecurrenceEngine { RecurrenceEngine(calendar: .current) }

    // MARK: - Öffentliche API

    /// Der Zeitraum, der `date` enthält, oder `nil`, wenn die Liste an diesem Tag noch nicht aktiv ist.
    public func period(for rule: RecurrenceRule, containing date: Date) -> Period? {
        let day = startOfDay(date)
        guard day >= startOfDay(rule.anchor) else { return nil }

        let first = firstPeriodStart(for: rule)
        if rule.kind == .none {
            return Period(start: first, end: nil, key: key(for: first))
        }

        var k = estimatedIndex(for: rule, first: first, day: day)
        while k > 0, let start = periodStart(index: k, for: rule), start > day { k -= 1 }
        while let next = periodStart(index: k + 1, for: rule), next <= day { k += 1 }

        guard let start = periodStart(index: k, for: rule) else { return nil }
        let end = periodStart(index: k + 1, for: rule)
        return Period(start: start, end: end, key: key(for: start))
    }

    /// `true`, wenn an `date` ein neuer Zeitraum beginnt („heute fällig“).
    public func isDue(_ rule: RecurrenceRule, on date: Date) -> Bool {
        guard let period = period(for: rule, containing: date) else { return false }
        return period.start == startOfDay(date)
    }

    /// Beginn des nächsten Zeitraums nach `date`, z. B. für Mitteilungen.
    public func nextPeriodStart(after date: Date, for rule: RecurrenceRule) -> Date? {
        if let current = period(for: rule, containing: date) {
            return current.end
        }
        // Liste noch nicht aktiv: der erste Zeitraum beginnt am Starttag.
        let anchorDay = startOfDay(rule.anchor)
        return anchorDay > date ? anchorDay : nil
    }

    /// Beginn des k-ten Zeitraums (k = 0 ist der erste).
    public func periodStart(index k: Int, for rule: RecurrenceRule) -> Date? {
        guard k >= 0 else { return nil }
        let n = rule.interval
        let first = firstPeriodStart(for: rule)
        switch rule.kind {
        case .none:
            return k == 0 ? first : nil
        case .daily:
            return addDays(k * n, to: first)
        case .weekly:
            return addDays(k * n * 7, to: first)
        case .monthly:
            return clampedDate(from: first, addingMonths: k * n)
        case .yearly:
            return clampedDate(from: first, addingMonths: k * n * 12)
        }
    }

    /// Erster Zeitraumbeginn. Bei wöchentlich: der letzte gewählte Wochentag am oder vor dem Starttag,
    /// damit eine Liste sofort nutzbar ist und am nächsten gewählten Wochentag zurückgesetzt wird.
    public func firstPeriodStart(for rule: RecurrenceRule) -> Date {
        let anchorDay = startOfDay(rule.anchor)
        guard rule.kind == .weekly else { return anchorDay }
        let anchorWeekday = calendar.component(.weekday, from: anchorDay)
        let diff = (anchorWeekday - rule.weekday + 7) % 7
        return addDays(-diff, to: anchorDay)
    }

    /// Schlüssel `yyyy-MM-dd` für einen Tag.
    public func key(for date: Date) -> String {
        let c = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
    }

    public func startOfDay(_ date: Date) -> Date {
        calendar.startOfDay(for: date)
    }

    // MARK: - Hilfsfunktionen

    private func estimatedIndex(for rule: RecurrenceRule, first: Date, day: Date) -> Int {
        let n = rule.interval
        let index: Int
        switch rule.kind {
        case .none: index = 0
        case .daily: index = daysBetween(first, day) / n
        case .weekly: index = daysBetween(first, day) / (7 * n)
        case .monthly: index = monthsBetween(first, day) / n
        case .yearly: index = monthsBetween(first, day) / (12 * n)
        }
        return max(0, index)
    }

    private func addDays(_ days: Int, to date: Date) -> Date {
        calendar.date(byAdding: .day, value: days, to: date) ?? date
    }

    /// Tage zwischen zwei Tagen, unabhängig von Sommer-/Winterzeit.
    private func daysBetween(_ a: Date, _ b: Date) -> Int {
        guard let da = calendar.ordinality(of: .day, in: .era, for: a),
              let db = calendar.ordinality(of: .day, in: .era, for: b) else { return 0 }
        return db - da
    }

    private func monthsBetween(_ a: Date, _ b: Date) -> Int {
        let ca = calendar.dateComponents([.year, .month], from: a)
        let cb = calendar.dateComponents([.year, .month], from: b)
        return ((cb.year ?? 0) - (ca.year ?? 0)) * 12 + ((cb.month ?? 0) - (ca.month ?? 0))
    }

    /// Ankertag von `first` im Monat `first + months`; fehlt der Tag, der letzte Tag des Monats.
    private func clampedDate(from first: Date, addingMonths months: Int) -> Date? {
        let c = calendar.dateComponents([.year, .month, .day], from: first)
        guard let year = c.year, let month = c.month, let anchorDay = c.day else { return nil }

        let total = year * 12 + (month - 1) + months
        var target = DateComponents()
        target.year = total / 12
        target.month = total % 12 + 1
        target.day = 1

        guard let firstOfMonth = calendar.date(from: target),
              let range = calendar.range(of: .day, in: .month, for: firstOfMonth) else { return nil }
        target.day = min(anchorDay, range.count)
        return calendar.date(from: target)
    }
}
