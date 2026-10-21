import Foundation
import RoutineKit

/// Routinen (mit Wiederholung) und Listen (ohne Wiederholung) sind dasselbe Modell.
/// Die Art ergibt sich aus der Wiederholung, eine Liste kann also jederzeit zur Routine werden und umgekehrt.
enum ListKind: String, Identifiable {
    case routine
    case list

    var id: String { rawValue }

    var title: String {
        switch self {
        case .routine: "Routinen"
        case .list: "Listen"
        }
    }

    var newTitle: String {
        switch self {
        case .routine: "Neue Routine"
        case .list: "Neue Liste"
        }
    }

    /// Voreinstellung im Formular „Neue …“
    var defaultRecurrence: RecurrenceKind {
        switch self {
        case .routine: .daily
        case .list: .none
        }
    }

    func matches(_ list: RoutineList) -> Bool {
        switch self {
        case .routine: list.recurrence != .none
        case .list: list.recurrence == .none
        }
    }
}
