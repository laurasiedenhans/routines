import Foundation
@testable import RoutineKit

extension Calendar {
    /// Fester Kalender, damit Tests nicht von den Geräteeinstellungen abhängen.
    static var berlin: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Berlin")!
        calendar.locale = Locale(identifier: "de_DE")
        return calendar
    }
}

let engine = RecurrenceEngine(calendar: .berlin)

func date(_ year: Int, _ month: Int, _ day: Int, _ hour: Int = 12, _ minute: Int = 0) -> Date {
    var components = DateComponents()
    components.year = year
    components.month = month
    components.day = day
    components.hour = hour
    components.minute = minute
    return Calendar.berlin.date(from: components)!
}

func key(_ year: Int, _ month: Int, _ day: Int) -> String {
    String(format: "%04d-%02d-%02d", year, month, day)
}

func rule(
    _ kind: RecurrenceKind,
    every interval: Int = 1,
    weekday: Int = 2,
    from anchor: Date
) -> RecurrenceRule {
    RecurrenceRule(kind: kind, interval: interval, weekday: weekday, anchor: anchor)
}
