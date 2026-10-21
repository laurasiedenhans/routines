import Foundation

/// Darstellung des Tagesfortschritts auf dem Startbildschirm.
public enum RingStyle: String, CaseIterable, Codable, Sendable {
    /// D · ein Ring in Akzentfarbe
    case simple
    /// E · ein Segment pro Liste
    case segmented
    /// F · Ringe ineinander
    case nested

    /// Maximale Anzahl Listen in der Auswahl, `nil` = unbegrenzt.
    public var maxLists: Int? {
        switch self {
        case .simple: nil
        case .segmented: 5
        case .nested: 3
        }
    }
}

/// Eine Liste, die in den Ring aufgenommen werden kann.
public struct RingCandidate: Hashable, Sendable {
    public let id: UUID
    public let interval: Int
    public let sortOrder: Int

    public init(id: UUID, interval: Int, sortOrder: Int) {
        self.id = id
        self.interval = interval
        self.sortOrder = sortOrder
    }
}

/// Regeln für die automatische Pflege der Ringauswahl (siehe Docs/PROJECT.md, 7.1).
public enum RingSelectionPolicy {

    /// - Entfernt Listen, die nicht mehr wählbar sind.
    /// - Nimmt neue Listen automatisch auf, solange Platz ist: zuerst täglich (n = 1), dann alle n Tage.
    /// - Verdrängt nie eine bereits ausgewählte Liste.
    /// - Bereits bekannte, manuell abgewählte Listen werden nicht wieder aufgenommen.
    public static func reconcile(
        selected: [UUID],
        seen: Set<UUID>,
        candidates: [RingCandidate],
        maxLists: Int?
    ) -> (selected: [UUID], seen: Set<UUID>) {
        let candidateIDs = Set(candidates.map(\.id))
        var newSelected = selected.filter { candidateIDs.contains($0) }
        let newSeen = seen.intersection(candidateIDs)

        let fresh = candidates
            .filter { !newSeen.contains($0.id) && !newSelected.contains($0.id) }
            .sorted { lhs, rhs in
                let l = lhs.interval == 1 ? 0 : 1
                let r = rhs.interval == 1 ? 0 : 1
                return l != r ? l < r : lhs.sortOrder < rhs.sortOrder
            }

        for candidate in fresh {
            if let maxLists, newSelected.count >= maxLists { break }
            newSelected.append(candidate.id)
        }

        return (newSelected, candidateIDs)
    }

    public static func canSelectMore(selectedCount: Int, maxLists: Int?) -> Bool {
        guard let maxLists else { return true }
        return selectedCount < maxLists
    }
}
