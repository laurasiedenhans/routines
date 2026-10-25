import Foundation
import Observation

/// Verbindet das „+“ der Navigationsleiste mit der gerade geöffneten Liste:
/// Ist eine Liste offen, öffnet das „+“ dort die Eingabezeile, sonst legt es eine neue Liste an.
@MainActor
@Observable
final class QuickAddCenter {
    /// Die gerade angezeigte Liste, `nil` auf den Übersichtsseiten.
    var activeListID: UUID?
    /// Wird bei jedem Tipp auf „+“ erhöht, die Liste reagiert auf die Änderung.
    private(set) var requestToken = 0

    func requestAdd() {
        requestToken += 1
    }
}
