import SwiftUI
import SwiftData
import RoutineKit

#if DEBUG
extension View {
    /// Stellt Testdaten, Uhr und Einstellungen für `#Preview` bereit.
    /// Ohne `container` wird ein neuer Container mit Testdaten erzeugt.
    @MainActor
    func previewEnvironment(container: ModelContainer? = nil) -> some View {
        self
            .modelContainer(container ?? RoutinePersistence.previewContainer())
            .environment(AppClock(fixed: .now))
            .environment(AppSettings(defaults: AppSettings.sampleDefaults()))
    }
}

@MainActor
enum PreviewData {
    /// Erste Liste mit dem angegebenen Namen aus einem Preview-Container.
    static func list(named name: String, in container: ModelContainer) -> RoutineList {
        let lists = (try? container.mainContext.fetch(FetchDescriptor<RoutineList>())) ?? []
        return lists.first { $0.name == name } ?? lists[0]
    }
}
#endif
