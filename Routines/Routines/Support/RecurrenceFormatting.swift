import Foundation
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

    /// Kurzbeschreibung für Listenzeilen, z. B. „Alle 2 Wochen · Do“.
    static func summary(for list: RoutineList) -> String {
        let n = list.interval
        switch list.recurrence {
        case .none:
            return "Einmalig"
        case .daily:
            return n == 1 ? "Täglich" : "Alle \(n) Tage"
        case .weekly:
            let day = weekdayName(list.weekday)
            return n == 1 ? "Wöchentlich · \(day)" : "Alle \(n) Wochen · \(day)"
        case .monthly:
            let day = Calendar.current.component(.day, from: list.anchorDate)
            return n == 1 ? "Monatlich · am \(day)." : "Alle \(n) Monate · am \(day)."
        case .yearly:
            let date = list.anchorDate.formatted(.dateTime.day().month(.abbreviated))
            return n == 1 ? "Jährlich · \(date)" : "Alle \(n) Jahre · \(date)"
        }
    }

    /// Zeile unter dem Listennamen auf dem Startbildschirm.
    static func rowSubtitle(for list: RoutineList, isActive: Bool) -> String {
        guard isActive else {
            return "Ab \(list.anchorDate.formatted(.dateTime.day().month(.abbreviated)))"
        }
        var parts: [String] = []
        if !(list.recurrence == .daily && list.interval == 1) {
            parts.append(summary(for: list))
        }
        if let minutes = list.startTimeMinutes {
            parts.append(startTime(minutes: minutes))
        }
        return parts.isEmpty ? "Täglich" : parts.joined(separator: " · ")
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
