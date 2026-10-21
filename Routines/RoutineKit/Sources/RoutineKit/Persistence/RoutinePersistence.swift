import Foundation
import SwiftData

/// Erzeugt die SwiftData-Container für App, Testdaten und Previews.
public enum RoutinePersistence {

    public static func schema() -> Schema {
        Schema([RoutineList.self, RoutineTask.self, TaskRecord.self])
    }

    /// `groupContainer: .automatic` nutzt automatisch die App Group, sobald sie in den
    /// Capabilities eingetragen ist (Phase 5). CloudKit bleibt bis Phase 6 aus.
    public static func makeContainer(inMemory: Bool = false) throws -> ModelContainer {
        let configuration = ModelConfiguration(
            schema: schema(),
            isStoredInMemoryOnly: inMemory,
            groupContainer: .automatic,
            cloudKitDatabase: .none
        )
        return try ModelContainer(for: schema(), configurations: configuration)
    }

    /// Container für die App. Mit `sampleMode` (Startargument `-sampleData`) eine frische,
    /// getrennte In-Memory-Datenbank voller Testdaten. Die echten Daten bleiben unberührt.
    @MainActor
    public static func makeAppContainer(sampleMode: Bool) -> ModelContainer {
        if sampleMode {
            return previewContainer()
        }
        do {
            return try makeContainer()
        } catch {
            assertionFailure("Datenbank konnte nicht geöffnet werden: \(error)")
            // Notfall: App startet trotzdem, Daten werden dann nicht gespeichert.
            return (try? makeContainer(inMemory: true)) ?? previewContainer()
        }
    }

    /// In-Memory-Container mit Testdaten für Previews und den Testdaten-Modus.
    @MainActor
    public static func previewContainer(now: Date = Date()) -> ModelContainer {
        do {
            let container = try makeContainer(inMemory: true)
            SampleData.populate(container.mainContext, now: now)
            return container
        } catch {
            fatalError("Preview-Container konnte nicht erstellt werden: \(error)")
        }
    }
}
