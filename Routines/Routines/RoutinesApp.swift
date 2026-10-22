import SwiftUI
import SwiftData
import RoutineKit

extension View {
    /// Hell/Dunkel und Akzentfarbe aus den Einstellungen.
    /// Wird zusätzlich in Sheets gesetzt, damit offene Fenster sofort mitwechseln.
    func appearance(from settings: AppSettings) -> some View {
        self
            .preferredColorScheme(settings.appearance.colorScheme)
            .tint(settings.accentColor.color)
    }
}

@main
struct RoutinesApp: App {
    @State private var clock = AppClock()
    @State private var settings: AppSettings
    private let container: ModelContainer

    init() {
        // Startargument `-sampleData` (Scheme „Routines (Testdaten)“): frische Testdatenbank,
        // eigene Einstellungen. Die echten Daten bleiben unberührt.
        let sampleMode = SampleData.isSampleModeLaunch
        container = RoutinePersistence.makeAppContainer(sampleMode: sampleMode)
        _settings = State(initialValue: AppSettings(
            defaults: sampleMode ? AppSettings.sampleDefaults() : AppSettings.sharedDefaults
        ))
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(clock)
                .environment(settings)
                .appearance(from: settings)
        }
        .modelContainer(container)

        #if os(macOS)
        Settings {
            NavigationStack {
                SettingsView()
            }
            .frame(minWidth: 440, minHeight: 520)
            .environment(clock)
            .environment(settings)
            .modelContainer(container)
            .appearance(from: settings)
        }
        #endif
    }
}
