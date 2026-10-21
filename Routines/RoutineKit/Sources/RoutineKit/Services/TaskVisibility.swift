import Foundation

/// Regeln, ob ein To-do in einem Zeitraum sichtbar ist (reine Logik, testbar ohne SwiftData).
public enum TaskVisibility {
    public static func isVisible(
        deletedAt: Date?,
        oneOffPeriodKey: String?,
        isSkipped: Bool,
        in period: Period
    ) -> Bool {
        // „Nur heute / diesmal löschen“
        if isSkipped { return false }

        // „Einmalig“ hinzugefügt: nur im eigenen Zeitraum
        if let oneOffPeriodKey, oneOffPeriodKey != period.key { return false }

        // „Alle zukünftigen löschen“: sichtbar nur in Zeiträumen, die vor dem Löschen endeten
        if let deletedAt {
            guard let end = period.end else { return false }
            return end <= deletedAt
        }
        return true
    }
}
