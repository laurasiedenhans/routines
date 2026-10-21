import Foundation
import Observation
#if canImport(UIKit)
import UIKit
#endif

/// Zentrale Uhr der App. Views lesen die Zeit nur über `now`, nie über `Date()`.
///
/// `now` wird aktualisiert
/// 1. beim Aktivwerden der App (`refresh()` aus `scenePhase`),
/// 2. per einmaligem Timer zur nächsten Mitternacht (alle Zeitraumgrenzen liegen auf 0:00),
/// 3. bei Tageswechsel, Uhrzeit- oder Zeitzonenänderung.
///
/// Im Entwicklerbereich lässt sich die Zeit vorspulen (`travel(by:)`).
@MainActor
@Observable
public final class AppClock {
    public private(set) var now: Date
    /// Simulierter Zeitversatz in Sekunden (nur für Tests).
    public private(set) var offset: TimeInterval = 0

    @ObservationIgnored private var timer: Timer?
    @ObservationIgnored private var observers: [NSObjectProtocol] = []
    @ObservationIgnored private let isLive: Bool

    /// Live-Uhr für die App.
    public init() {
        self.now = Date()
        self.isLive = true
        startObserving()
        scheduleMidnightTimer()
    }

    /// Feste Zeit für Previews und Tests, ohne Timer.
    public init(fixed date: Date) {
        self.now = date
        self.isLive = false
    }

    public var isTimeTravelling: Bool { offset != 0 }

    public func refresh() {
        guard isLive else { return }
        now = Date().addingTimeInterval(offset)
        scheduleMidnightTimer()
    }

    public func travel(by seconds: TimeInterval) {
        if isLive {
            offset += seconds
            refresh()
        } else {
            now = now.addingTimeInterval(seconds)
        }
    }

    /// Springt auf eine bestimmte simulierte Uhrzeit.
    public func travel(to date: Date) {
        travel(by: date.timeIntervalSince(now))
    }

    public func resetTravel() {
        offset = 0
        refresh()
    }

    // MARK: - Intern

    private func scheduleMidnightTimer() {
        timer?.invalidate()
        let calendar = Calendar.current
        guard let nextMidnight = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: now)) else { return }
        let interval = max(nextMidnight.timeIntervalSince(now) + 1, 1)
        let newTimer = Timer(timeInterval: interval, repeats: false) { [weak self] _ in
            Task { @MainActor in self?.refresh() }
        }
        RunLoop.main.add(newTimer, forMode: .common)
        timer = newTimer
    }

    private func startObserving() {
        var names: [Notification.Name] = [
            .NSCalendarDayChanged,
            .NSSystemClockDidChange,
            .NSSystemTimeZoneDidChange
        ]
        #if canImport(UIKit)
        names.append(UIApplication.significantTimeChangeNotification)
        #endif

        for name in names {
            let token = NotificationCenter.default.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                Task { @MainActor in self?.refresh() }
            }
            observers.append(token)
        }
    }
}
