import Foundation
import SwiftUI
import RoutineKit

/// Texte rund um Wiederholungen. Liegt in der App (nicht im Package), damit sie
/// später über den String Catalog übersetzt werden können.
enum RecurrenceFormatting {

    /// Reihenfolge der Wochentage für Picker (Montag zuerst).
    static let weekdayOrder = [2, 3, 4, 5, 6, 7, 1]

    static func weekdayName(_ weekday: Int, short: Bool = true) -> String {
        let calendar = Calendar.current
        let symbols = short ? calendar.shortWeekdaySymbols : calendar.weekdaySymbols
        let index = (weekday - 1) % 7
        return symbols.indices.contains(index) ? symbols[index] : ""
    }

    static func startTime(minutes: Int) -> String {
        String(format: "%02d:%02d", minutes / 60, minutes % 60)
    }

    /// z. B. „Jeden Tag“, „Alle 3 Tage“, „Jede Woche“.
    static func intervalLabel(kind: RecurrenceKind, interval n: Int) -> String {
        switch kind {
        case .none: return "Einmalig"
        case .daily: return n == 1 ? "Jeden Tag" : "Alle \(n) Tage"
        case .weekly: return n == 1 ? "Jede Woche" : "Alle \(n) Wochen"
        case .monthly: return n == 1 ? "Jeden Monat" : "Alle \(n) Monate"
        case .yearly: return n == 1 ? "Jedes Jahr" : "Alle \(n) Jahre"
        }
    }

    /// Bausteine der Wiederholungsinfo: `Rhythmus · Detail · Uhrzeit`.
    struct Parts {
        /// z. B. „Täglich“, „Alle 2 Wochen“, „Einmalig“ – immer vorhanden
        let rhythm: String
        /// z. B. „Do“, „am 30.“, „29. Feb.“ – nur bei wöchentlich/monatlich/jährlich
        let detail: String?
        /// z. B. „06:30“ – nur mit Startzeit
        let time: String?

        /// Varianten von ausführlich bis knapp, für `ViewThatFits`.
        var variants: [String] {
            [
                [rhythm, detail, time],
                [rhythm, time],
                [rhythm]
            ].map { $0.compactMap { $0 }.joined(separator: " · ") }
        }
    }

    static func parts(for list: RoutineList) -> Parts {
        let n = list.interval
        let rhythm: String
        var detail: String?
        switch list.recurrence {
        case .none:
            rhythm = "Einmalig"
        case .daily:
            rhythm = n == 1 ? "Täglich" : "Alle \(n) Tage"
        case .weekly:
            rhythm = n == 1 ? "Wöchentlich" : "Alle \(n) Wochen"
            detail = weekdayName(list.weekday)
        case .monthly:
            rhythm = n == 1 ? "Monatlich" : "Alle \(n) Monate"
            detail = "am \(Calendar.current.component(.day, from: list.anchorDate))."
        case .yearly:
            rhythm = n == 1 ? "Jährlich" : "Alle \(n) Jahre"
            detail = list.anchorDate.formatted(.dateTime.day().month(.abbreviated))
        }
        return Parts(rhythm: rhythm, detail: detail, time: list.startTimeMinutes.map(startTime(minutes:)))
    }

    /// Rhythmus mit Detail, ohne Uhrzeit, z. B. „Alle 2 Wochen · Do“.
    static func summary(for list: RoutineList) -> String {
        let p = parts(for: list)
        return [p.rhythm, p.detail].compactMap { $0 }.joined(separator: " · ")
    }

    static func startDate(_ date: Date) -> String {
        date.formatted(.dateTime.day().month(.abbreviated))
    }
}

// MARK: - Zeiträume benennen (Blättern)

/// Texte für die Zeitraum-Leiste. Wochen, Monate und Jahre werden nach der Einheit benannt,
/// in der der Zeitraum größtenteils liegt (`RecurrenceEngine.representativeDate`).
enum PeriodFormatting {
    private static let weekdays = ["So", "Mo", "Di", "Mi", "Do", "Fr", "Sa"]
    private static let months = ["Jan", "Feb", "Mär", "Apr", "Mai", "Jun", "Jul", "Aug", "Sep", "Okt", "Nov", "Dez"]

    /// Wie viele Zeiträume die Leiste auf einmal zeigt.
    static func stripCount(for kind: RecurrenceKind) -> Int {
        switch kind {
        case .monthly, .yearly: 5
        default: 7
        }
    }

    /// Überschrift über der Leiste: „Heute“, „Diese Woche“ … bzw. „Do 23.10.2026“, „KW 44 2026“, „Okt 2026“, „2027“.
    static func title(kind: RecurrenceKind, period: Period, isCurrent: Bool, engine: RecurrenceEngine) -> String {
        if isCurrent { return currentTitle(kind: kind) }
        let cal = engine.calendar
        let middle = engine.representativeDate(of: period)
        switch kind {
        case .none:
            return ""
        case .daily:
            return dayString(period.start, calendar: cal, withYear: true)
        case .weekly:
            let (week, year) = isoWeek(of: middle, calendar: cal)
            return "KW \(week) \(year)"
        case .monthly:
            return "\(months[cal.component(.month, from: middle) - 1]) \(cal.component(.year, from: middle))"
        case .yearly:
            return "\(cal.component(.year, from: middle))"
        }
    }

    static func currentTitle(kind: RecurrenceKind) -> String {
        switch kind {
        case .none, .daily: "Heute"
        case .weekly: "Diese Woche"
        case .monthly: "Diesen Monat"
        case .yearly: "Dieses Jahr"
        }
    }

    /// Beschriftung eines Kästchens in der Leiste: klein oben, groß darunter.
    static func chip(kind: RecurrenceKind, period: Period, engine: RecurrenceEngine) -> (top: String, main: String) {
        let cal = engine.calendar
        let middle = engine.representativeDate(of: period)
        switch kind {
        case .none:
            return ("", "")
        case .daily:
            return (weekdays[cal.component(.weekday, from: period.start) - 1], "\(cal.component(.day, from: period.start))")
        case .weekly:
            return ("KW", "\(isoWeek(of: middle, calendar: cal).week)")
        case .monthly:
            return ("\(cal.component(.year, from: middle))", months[cal.component(.month, from: middle) - 1])
        case .yearly:
            let c = cal.dateComponents([.day, .month], from: period.start)
            return (String(format: "%02d.%02d.", c.day ?? 0, c.month ?? 0), "\(cal.component(.year, from: middle))")
        }
    }

    /// Genauer Zeitraum unter der Leiste, z. B. „Do 22.10. – Mi 28.10.“. `nil` bei eintägigen Zeiträumen.
    static func range(kind: RecurrenceKind, period: Period, engine: RecurrenceEngine) -> String? {
        guard let last = engine.lastDay(of: period), last > period.start else { return nil }
        let cal = engine.calendar
        switch kind {
        case .none:
            return nil
        case .daily, .weekly:
            return "\(dayString(period.start, calendar: cal, withYear: false)) – \(dayString(last, calendar: cal, withYear: false))"
        case .monthly:
            return "\(shortDate(period.start, calendar: cal)) – \(shortDate(last, calendar: cal))"
        case .yearly:
            return "\(shortDate(period.start, calendar: cal))\(cal.component(.year, from: period.start)) – \(shortDate(last, calendar: cal))\(cal.component(.year, from: last))"
        }
    }

    // MARK: Hilfen

    static func dayString(_ date: Date, calendar: Calendar, withYear: Bool) -> String {
        let c = calendar.dateComponents([.weekday, .day, .month, .year], from: date)
        let weekday = weekdays[(c.weekday ?? 1) - 1]
        let base = String(format: "%@ %02d.%02d.", weekday, c.day ?? 0, c.month ?? 0)
        return withYear ? base + String(format: "%04d", c.year ?? 0) : base
    }

    private static func shortDate(_ date: Date, calendar: Calendar) -> String {
        let c = calendar.dateComponents([.day, .month], from: date)
        return String(format: "%02d.%02d.", c.day ?? 0, c.month ?? 0)
    }

    private static func isoWeek(of date: Date, calendar: Calendar) -> (week: Int, year: Int) {
        var iso = Calendar(identifier: .iso8601)
        iso.timeZone = calendar.timeZone
        return (iso.component(.weekOfYear, from: date), iso.component(.yearForWeekOfYear, from: date))
    }
}

extension RecurrenceKind {
    var displayName: String {
        switch self {
        case .none: "Keine"
        case .daily: "Täglich"
        case .weekly: "Wöchentlich"
        case .monthly: "Monatlich"
        case .yearly: "Jährlich"
        }
    }
}

extension AppAppearance {
    var displayName: String {
        switch self {
        case .system: "System"
        case .light: "Hell"
        case .dark: "Dunkel"
        }
    }

    /// `nil` = dem System folgen
    var colorScheme: ColorScheme? {
        switch self {
        case .system: nil
        case .light: .light
        case .dark: .dark
        }
    }
}

extension ListRetention {
    var displayName: String {
        switch self {
        case .never: "Nie"
        case .oneDay: "Nach 1 Tag"
        case .threeDays: "Nach 3 Tagen"
        case .oneWeek: "Nach 1 Woche"
        case .twoWeeks: "Nach 2 Wochen"
        case .oneMonth: "Nach 1 Monat"
        }
    }
}

extension RingStyle {
    var displayName: String {
        switch self {
        case .simple: "Einfacher Ring"
        case .segmented: "Segmente je Liste"
        case .nested: "Ringe ineinander"
        }
    }

    var systemImage: String {
        switch self {
        case .simple: "circle"
        case .segmented: "circle.dashed"
        case .nested: "circle.circle"
        }
    }
}
