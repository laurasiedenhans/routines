import SwiftUI
import SwiftData
import RoutineKit

/// Allgemeine Einstellungen (Zahnrad oben links, auf dem Mac zusätzlich ⌘,).
struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppSettings.self) private var settings
    @Query(sort: \RoutineList.sortOrder) private var lists: [RoutineList]

    var body: some View {
        @Bindable var settings = settings
        let style = settings.ringStyle

        Form {
            Section {
                Picker("Ringstil", selection: $settings.ringStyle) {
                    ForEach(RingStyle.allCases, id: \.self) { ringStyle in
                        Label(ringStyle.displayName, systemImage: ringStyle.systemImage)
                            .tag(ringStyle)
                    }
                }
                .pickerStyle(.inline)
                .labelsHidden()
            } header: {
                Text("Tagesfortschritt")
            }

            Section {
                if eligibleLists.isEmpty {
                    Text("Noch keine täglichen Listen vorhanden.")
                        .foregroundStyle(.secondary)
                }
                ForEach(eligibleLists) { list in
                    let isSelected = settings.isSelected(list.id, for: style)
                    Button {
                        settings.toggle(list.id, for: style)
                    } label: {
                        HStack(spacing: Theme.Spacing.m) {
                            ListIcon(emoji: list.emoji, color: list.color.color, size: Theme.Icon.smallSize)
                            VStack(alignment: .leading, spacing: Theme.Spacing.xxs) {
                                Text(list.name)
                                    .foregroundStyle(Color.primary)
                                Text(RecurrenceFormatting.summary(for: list))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            if isSelected {
                                Image(systemName: "checkmark")
                                    .fontWeight(.semibold)
                                    .foregroundStyle(.tint)
                            }
                        }
                        .contentShape(.rect)
                    }
                    .buttonStyle(.plain)
                    .disabled(!isSelected && !settings.canSelectMore(for: style))
                    .accessibilityAddTraits(isSelected ? .isSelected : [])
                }
            } header: {
                Text("Listen im Ring")
            } footer: {
                Text(selectionFooter(for: style))
            }

            #if DEBUG
            DeveloperSection()
            #endif
        }
        .formStyle(.grouped)
        .navigationTitle("Einstellungen")
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Fertig") { dismiss() }
            }
        }
        .task(id: candidates) {
            settings.reconcile(candidates: candidates)
        }
    }

    private var eligibleLists: [RoutineList] {
        lists.filter(\.isRingEligible)
    }

    private var candidates: [RingCandidate] {
        eligibleLists.map(\.ringCandidate)
    }

    private func selectionFooter(for style: RingStyle) -> String {
        let count = settings.selection(for: style).count
        let rule = "Im Ring erscheinen nur Listen, die heute fällig sind."
        if let max = style.maxLists {
            return "\(count) von max. \(max) ausgewählt. \(rule)"
        }
        return "\(count) ausgewählt, beliebig viele möglich. \(rule)"
    }
}

#if DEBUG
/// Nur in Debug-Builds: Testdaten und Zeitreise.
private struct DeveloperSection: View {
    @Environment(\.modelContext) private var context
    @Environment(AppClock.self) private var clock
    @State private var confirmWipe = false

    var body: some View {
        Section {
            LabeledContent("Zeit") {
                Text(clock.now.formatted(date: .abbreviated, time: .shortened))
                    .foregroundStyle(clock.isTimeTravelling ? Color.orange : Color.secondary)
            }
            Button("+1 Stunde") { clock.travel(by: 3_600) }
            Button("+1 Tag") { clock.travel(by: 86_400) }
            Button("Auf heute 23:59 setzen") {
                let calendar = Calendar.current
                if let target = calendar.date(bySettingHour: 23, minute: 59, second: 0, of: clock.now) {
                    clock.travel(to: target)
                }
            }
            Button("Zeit zurücksetzen") { clock.resetTravel() }
                .disabled(!clock.isTimeTravelling)

            Button("Testdaten hinzufügen") {
                SampleData.populate(context, now: clock.now)
            }
            Button("Alle Daten löschen", role: .destructive) {
                confirmWipe = true
            }
        } header: {
            Text("Entwickler")
        } footer: {
            Text("Nur in Debug-Builds sichtbar. Für eine frische Testdatenbank das Scheme „Routines (Testdaten)“ starten.")
        }
        .confirmationDialog("Alle Daten löschen?", isPresented: $confirmWipe, titleVisibility: .visible) {
            Button("Alles löschen", role: .destructive) {
                try? context.deleteAllRoutineData()
            }
            Button("Abbrechen", role: .cancel) {}
        } message: {
            Text("Alle Listen, To-dos und der Verlauf werden gelöscht.")
        }
    }
}
#endif

#Preview {
    NavigationStack {
        SettingsView()
    }
    .previewEnvironment()
}
