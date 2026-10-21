import SwiftUI
import SwiftData
import RoutineKit

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
        }
        #endif
    }
}
