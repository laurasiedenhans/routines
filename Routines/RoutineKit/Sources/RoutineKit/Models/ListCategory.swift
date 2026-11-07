import Foundation
import SwiftData

/// Kategorie, in die Routinen und Listen einsortiert werden, z. B. „💪 Workout“.
/// Eine Liste gehört zu höchstens einer Kategorie. Wird die Kategorie gelöscht,
/// bleiben ihre Listen erhalten und verlieren nur die Zuordnung (`.nullify`).
@Model
public final class ListCategory {
    public var id: UUID = UUID()
    public var name: String = ""
    /// Leer = kein Emoji
    public var emoji: String = ""
    public var sortOrder: Int = 0
    public var createdAt: Date = Date()

    @Relationship(deleteRule: .nullify, inverse: \RoutineList.category)
    public var lists: [RoutineList]? = []

    public init(name: String = "", emoji: String = "", sortOrder: Int = 0, createdAt: Date = Date()) {
        self.id = UUID()
        self.name = name
        self.emoji = emoji
        self.sortOrder = sortOrder
        self.createdAt = createdAt
        self.lists = []
    }

    /// Name mit Emoji davor, z. B. „💪 Workout“.
    public var displayName: String {
        let title = name.isEmpty ? "Ohne Namen" : name
        return emoji.isEmpty ? title : "\(emoji) \(title)"
    }
}

/// Fortschritt einer Kategorie in Prozent.
public enum CategoryProgress {
    /// Alle To-dos der Listen im jeweils aktuellen Zeitraum zusammengezählt
    /// (2/4 + 3/6 = 5/10 = 50 %). Noch nicht gestartete Listen zählen nicht mit.
    /// `nil`, wenn es keine To-dos gibt.
    public static func percent(of statuses: [ListStatus]) -> Int? {
        let active = statuses.filter(\.isActive)
        let total = active.reduce(0) { $0 + $1.total }
        guard total > 0 else { return nil }
        let done = active.reduce(0) { $0 + $1.done.count }
        return Int((Double(done) / Double(total) * 100).rounded())
    }
}
