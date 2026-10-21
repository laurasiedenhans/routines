import Foundation

/// Eine Liste, wie sie heute im Tagesring erscheint.
public struct DayRingItem: Identifiable, Hashable, Sendable {
    public let id: UUID
    public let name: String
    public let emoji: String
    public let color: ListColor
    public let done: Int
    public let total: Int
    public let startTimeMinutes: Int?

    public var fraction: Double { total == 0 ? 0 : Double(done) / Double(total) }
    public var isComplete: Bool { done >= total }

    public init(id: UUID, name: String, emoji: String, color: ListColor, done: Int, total: Int, startTimeMinutes: Int?) {
        self.id = id
        self.name = name
        self.emoji = emoji
        self.color = color
        self.done = done
        self.total = total
        self.startTimeMinutes = startTimeMinutes
    }
}

/// Inhalt der Tageskarte auf dem Startbildschirm.
public struct DayRingSummary: Sendable {
    public enum State: Sendable {
        case ready
        /// Keine wählbare Liste ausgewählt.
        case noSelection
        /// Ausgewählte Listen sind heute alle nicht fällig.
        case nothingDue
    }

    /// Heute sichtbare Listen in Reihenfolge (`sortOrder`), ohne Lücken.
    public let items: [DayRingItem]
    public let state: State

    public var done: Int { items.reduce(0) { $0 + $1.done } }
    public var total: Int { items.reduce(0) { $0 + $1.total } }
    public var fraction: Double { total == 0 ? 0 : Double(done) / Double(total) }

    /// Nächste offene Liste: früheste Startzeit zuerst, Listen ohne Startzeit danach.
    public var nextUp: DayRingItem? {
        items
            .enumerated()
            .filter { !$0.element.isComplete }
            .min { lhs, rhs in
                let l = lhs.element.startTimeMinutes ?? Int.max
                let r = rhs.element.startTimeMinutes ?? Int.max
                return l != r ? l < r : lhs.offset < rhs.offset
            }?
            .element
    }

    public init(items: [DayRingItem], state: State) {
        self.items = items
        self.state = state
    }

    /// Nur Listen, die ausgewählt **und** heute fällig sind, zählen.
    public static func make(
        lists: [RoutineList],
        selection: [UUID],
        now: Date,
        engine: RecurrenceEngine = .current
    ) -> DayRingSummary {
        let selected = Set(selection)
        let candidates = lists
            .filter { selected.contains($0.id) && $0.isRingEligible }
            .sorted { $0.sortOrder < $1.sortOrder }

        guard !candidates.isEmpty else {
            return DayRingSummary(items: [], state: .noSelection)
        }

        var items: [DayRingItem] = []
        for list in candidates where engine.isDue(list.rule, on: now) {
            let status = ListStatus(list: list, now: now, engine: engine)
            guard status.total > 0 else { continue }
            items.append(DayRingItem(
                id: list.id,
                name: list.name,
                emoji: list.emoji,
                color: list.color,
                done: status.done.count,
                total: status.total,
                startTimeMinutes: list.startTimeMinutes
            ))
        }

        return DayRingSummary(items: items, state: items.isEmpty ? .nothingDue : .ready)
    }
}
