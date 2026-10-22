import Foundation
import Observation

public enum RoutineConstants {
    /// Wird ab Phase 5 (Live Activity) gebraucht, wenn App und Widget Daten teilen.
    public static let appGroupID = "group.de.laurasiedenhans.routines"
}

/// Allgemeine Einstellungen der App. Bewusst nicht in SwiftData (gerätenah, klein, ohne Historie).
@MainActor
@Observable
public final class AppSettings {

    public var ringStyle: RingStyle {
        didSet { save() }
    }

    /// Abgeschlossene einmalige Listen löschen nach … (Standard: nie)
    public var completedListRetention: ListRetention {
        didSet { save() }
    }

    /// Ausgewählte Listen je Ringstil (Schlüssel = `RingStyle.rawValue`).
    private var selections: [String: [UUID]] {
        didSet { save() }
    }

    /// Bereits bekannte Listen je Ringstil, damit abgewählte Listen nicht wieder auftauchen.
    private var seen: [String: [UUID]] {
        didSet { save() }
    }

    @ObservationIgnored private let defaults: UserDefaults
    private static let storageKey = "appSettings.v1"

    public init(defaults: UserDefaults = AppSettings.sharedDefaults) {
        self.defaults = defaults
        let stored = defaults.data(forKey: Self.storageKey)
            .flatMap { try? JSONDecoder().decode(Stored.self, from: $0) }
        self.ringStyle = stored?.ringStyle ?? .segmented
        self.completedListRetention = stored?.completedListRetention ?? .never
        self.selections = stored?.selections ?? [:]
        self.seen = stored?.seen ?? [:]
    }

    /// Standard-Speicher. Ab Phase 5 auf `UserDefaults(suiteName: RoutineConstants.appGroupID)` umstellen.
    public static var sharedDefaults: UserDefaults { .standard }

    /// Eigener, beim Start geleerter Speicher für Testdaten und Previews.
    public static func sampleDefaults() -> UserDefaults {
        let name = "de.laurasiedenhans.routines.sample"
        let defaults = UserDefaults(suiteName: name) ?? .standard
        defaults.removePersistentDomain(forName: name)
        return defaults
    }

    // MARK: - Ringauswahl

    public func selection(for style: RingStyle) -> [UUID] {
        selections[style.rawValue] ?? []
    }

    public func isSelected(_ id: UUID, for style: RingStyle) -> Bool {
        selection(for: style).contains(id)
    }

    public func canSelectMore(for style: RingStyle) -> Bool {
        RingSelectionPolicy.canSelectMore(selectedCount: selection(for: style).count, maxLists: style.maxLists)
    }

    public func toggle(_ id: UUID, for style: RingStyle) {
        var current = selection(for: style)
        if let index = current.firstIndex(of: id) {
            current.remove(at: index)
        } else if canSelectMore(for: style) {
            current.append(id)
        }
        selections[style.rawValue] = current
    }

    /// Gleicht die Auswahl aller Stile mit den aktuell wählbaren Listen ab.
    public func reconcile(candidates: [RingCandidate]) {
        var newSelections = selections
        var newSeen = seen
        for style in RingStyle.allCases {
            let result = RingSelectionPolicy.reconcile(
                selected: selections[style.rawValue] ?? [],
                seen: Set(seen[style.rawValue] ?? []),
                candidates: candidates,
                maxLists: style.maxLists
            )
            newSelections[style.rawValue] = result.selected
            newSeen[style.rawValue] = Array(result.seen)
        }
        if newSelections != selections { selections = newSelections }
        if newSeen.mapValues({ Set($0) }) != seen.mapValues({ Set($0) }) { seen = newSeen }
    }

    // MARK: - Speichern

    private struct Stored: Codable {
        var ringStyle: RingStyle
        var selections: [String: [UUID]]
        var seen: [String: [UUID]]
        /// Optional, damit ältere gespeicherte Einstellungen weiter lesbar sind.
        var completedListRetention: ListRetention?
    }

    private func save() {
        let stored = Stored(
            ringStyle: ringStyle,
            selections: selections,
            seen: seen,
            completedListRetention: completedListRetention
        )
        if let data = try? JSONEncoder().encode(stored) {
            defaults.set(data, forKey: Self.storageKey)
        }
    }
}
