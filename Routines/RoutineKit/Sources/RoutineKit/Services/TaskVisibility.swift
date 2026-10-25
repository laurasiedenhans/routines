import Foundation

/// Regeln, ob ein To-do in einem Zeitraum sichtbar ist (reine Logik, testbar ohne SwiftData).
public enum TaskVisibility {
    public static func isVisible(
        createdAt: Date? = nil,
        deletedAt: Date?,
        oneOffPeriodKey: String?,
        isSkipped: Bool,
        in period: Period
    ) -> Bool {
        // „Nur heute / diesmal löschen“
        if isSkipped { return false }

        // „Einmalig“ hinzugefügt: nur im eigenen Zeitraum (auch nachträglich in der Vergangenheit)
        if let oneOffPeriodKey, oneOffPeriodKey != period.key { return false }

        // Dauerhafte To-dos erst ab dem Zeitraum, in dem sie angelegt wurden (wichtig beim Zurückblättern)
        if oneOffPeriodKey == nil, let createdAt, let end = period.end, createdAt >= end {
            return false
        }

        // „Alle zukünftigen löschen“: sichtbar nur in Zeiträumen, die vor dem Löschen endeten
        if let deletedAt {
            guard let end = period.end else { return false }
            return end <= deletedAt
        }
        return true
    }
}
