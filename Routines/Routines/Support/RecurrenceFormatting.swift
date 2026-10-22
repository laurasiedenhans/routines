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
