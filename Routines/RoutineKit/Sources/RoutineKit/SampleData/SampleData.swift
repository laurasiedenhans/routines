import Foundation
import SwiftData

/// Testdatensatz, der möglichst alle Funktionen abdeckt.
///
/// Wird nie automatisch in die echte Datenbank geschrieben. Verwendung:
/// - Previews: `RoutinePersistence.previewContainer()`
/// - Simulator: Startargument `-sampleData` (frische In-Memory-Datenbank bei jedem Start)
/// - Entwicklerbereich in den Einstellungen: „Testdaten hinzufügen“ (nur Debug-Builds)
///
/// Alle Daten sind relativ zu `now` erzeugt, damit „heute fällig“ usw. immer stimmt.
@MainActor
public enum SampleData {

    public static let launchArgument = "-sampleData"

    public static var isSampleModeLaunch: Bool {
        ProcessInfo.processInfo.arguments.contains(launchArgument)
    }

    // swiftlint:disable:next function_body_length
    public static func populate(_ context: ModelContext, now: Date = Date(), calendar: Calendar = .current) {
        let engine = RecurrenceEngine(calendar: calendar)
        let today = calendar.startOfDay(for: now)
        let todayWeekday = calendar.component(.weekday, from: today)
        let existingMax = (try? context.fetch(FetchDescriptor<RoutineList>()))?.map(\.sortOrder).max() ?? -1
        var order = existingMax + 1

        func day(_ offset: Int) -> Date {
            calendar.date(byAdding: .day, value: offset, to: today) ?? today
        }

        func weekday(offsetFromToday offset: Int) -> Int {
            ((todayWeekday - 1 + offset) % 7 + 7) % 7 + 1
        }

        func makeList(
            _ name: String,
            _ emoji: String,
            _ color: ListColor,
            _ kind: RecurrenceKind,
            interval: Int = 1,
            weekday: Int = 2,
            anchor: Date,
            start: (hour: Int, minute: Int)? = nil,
            notify: Bool = false,
            live: Bool = false
        ) -> RoutineList {
            let list = RoutineList(
                name: name,
                emoji: emoji,
                color: color,
                sortOrder: order,
                recurrence: kind,
                interval: interval,
                weekday: weekday,
                anchorDate: anchor,
                startTimeMinutes: start.map { $0.hour * 60 + $0.minute },
                notificationEnabled: notify,
                liveActivityEnabled: live
            )
            order += 1
            context.insert(list)
            return list
        }

        func addTasks(_ titles: [String], to list: RoutineList) -> [RoutineTask] {
            titles.enumerated().map { index, title in
                let task = RoutineTask(title: title, sortOrder: index, createdAt: day(-60))
                context.insert(task)
                task.list = list
                return task
            }
        }

        func record(_ kind: RecordKind, _ task: RoutineTask, in list: RoutineList, on date: Date) {
            guard let period = engine.period(for: list.rule, containing: date) else { return }
            let entry = TaskRecord(periodKey: period.key, kind: kind, createdAt: date)
            context.insert(entry)
            entry.task = task
        }

        // 1 · Täglich mit Startzeit, Mitteilung, Live Activity, teils erledigt,
        //     einmaliges To-do und Verlauf der letzten Tage
        let morning = makeList("Morgenroutine", "☀️", .orange, .daily,
                               anchor: day(-60), start: (6, 30), notify: true, live: true)
        let morningTasks = addTasks(["Ein Glas Wasser trinken", "Zähne putzen", "10 Minuten Stretching", "Tagesplan checken"], to: morning)
        for task in morningTasks.prefix(2) { record(.completed, task, in: morning, on: now) }
        for offset in 1...6 {
            for (index, task) in morningTasks.enumerated() where (offset + index) % 4 != 0 {
                record(.completed, task, in: morning, on: day(-offset))
            }
        }
        if let period = engine.period(for: morning.rule, containing: now) {
            let parcel = RoutineTask(title: "Paket abholen", sortOrder: 10, createdAt: now, oneOffPeriodKey: period.key)
            context.insert(parcel)
            parcel.list = morning
        }

        // 2 · Täglich, nichts erledigt, ein To-do heute übersprungen, eins „alle zukünftigen“ gelöscht
        let evening = makeList("Abendroutine", "🌙", .indigo, .daily,
                               anchor: day(-60), start: (21, 30), notify: true)
        let eveningTasks = addTasks(["Handy weglegen", "Zähne putzen", "Lesen", "Wecker stellen"], to: evening)
        record(.skipped, eveningTasks[2], in: evening, on: now)
        let diary = RoutineTask(title: "Tagebuch schreiben", sortOrder: 4, createdAt: day(-60))
        context.insert(diary)
        diary.list = evening
        record(.completed, diary, in: evening, on: day(-5))
        record(.completed, diary, in: evening, on: day(-4))
        diary.deletedAt = day(-3)

        // 3 · Alle 2 Tage, heute fällig
        let training = makeList("Training", "🏃", .red, .daily, interval: 2,
                                anchor: day(-4), start: (18, 0))
        let trainingTasks = addTasks(["Aufwärmen", "5 km laufen", "Dehnen"], to: training)
        record(.completed, trainingTasks[0], in: training, on: now)

        // 4 · Alle 2 Tage, heute NICHT fällig (Zeitraum begann gestern)
        let meditation = makeList("Meditation", "🧘", .mint, .daily, interval: 2, anchor: day(-3))
        _ = addTasks(["10 Minuten atmen"], to: meditation)

        // 5 · Täglich, alles erledigt (100 %, Erledigt-Bereich)
        let vitamins = makeList("Vitamine", "💊", .green, .daily, anchor: day(-60))
        for task in addTasks(["Vitamin D", "Omega-3"], to: vitamins) {
            record(.completed, task, in: vitamins, on: now)
        }

        // 6 · Wöchentlich, Zeitraum begann vor 2 Tagen (nicht im Ring)
        let household = makeList("Haushalt", "🧺", .teal, .weekly,
                                 weekday: weekday(offsetFromToday: -2), anchor: day(-30))
        let householdTasks = addTasks(["Staubsaugen", "Bad putzen", "Wäsche waschen", "Müll rausbringen"], to: household)
        record(.completed, householdTasks[3], in: household, on: day(-1))

        // 7 · Alle 2 Wochen, heute beginnt ein neuer Zeitraum
        let plants = makeList("Pflanzen gießen", "🪴", .cyan, .weekly, interval: 2,
                              weekday: todayWeekday, anchor: day(-14), start: (9, 0))
        _ = addTasks(["Monstera", "Kräuter auf dem Balkon"], to: plants)

        // 8 · Monatlich mit Ankertag 30. (Februar → letzter Tag)
        var anchorComponents = DateComponents()
        anchorComponents.year = calendar.component(.year, from: today)
        anchorComponents.month = 1
        anchorComponents.day = 30
        var financeAnchor = calendar.date(from: anchorComponents) ?? day(-30)
        if financeAnchor > today {
            financeAnchor = calendar.date(byAdding: .year, value: -1, to: financeAnchor) ?? financeAnchor
        }
        let finance = makeList("Finanzen", "💳", .blue, .monthly, anchor: financeAnchor)
        let financeTasks = addTasks(["Kontoauszüge prüfen", "Budget aktualisieren"], to: finance)
        record(.completed, financeTasks[0], in: finance, on: now)

        // 9 · Alle 3 Monate
        let quarterly = makeList("Quartalsbericht", "📊", .gray, .monthly, interval: 3, anchor: day(-40))
        _ = addTasks(["Ausgaben auswerten"], to: quarterly)

        // 10 · Jährlich ab 29.02. (in Nicht-Schaltjahren am 28.02.)
        var leapComponents = DateComponents()
        leapComponents.year = 2024
        leapComponents.month = 2
        leapComponents.day = 29
        let dentist = makeList("Zahnarzt", "🦷", .pink, .yearly,
                               anchor: calendar.date(from: leapComponents) ?? day(-365))
        _ = addTasks(["Kontrolltermin vereinbaren"], to: dentist)

        // 11 · Ohne Wiederholung (einmalige Checkliste)
        let move = makeList("Umzug", "📦", .brown, .none, anchor: day(-10))
        let moveTasks = addTasks(["Kartons besorgen", "Nachsendeauftrag stellen", "Internet ummelden"], to: move)
        record(.completed, moveTasks[0], in: move, on: day(-8))

        // 12 · Starttag in der Zukunft („Startet am …“)
        let course = makeList("Spanischkurs", "🇪🇸", .purple, .daily,
                              anchor: day(5), start: (19, 0))
        _ = addTasks(["Vokabeln wiederholen", "Lektion durcharbeiten"], to: course)

        try? context.save()
    }
}
