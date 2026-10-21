import SwiftUI
import SwiftData
import RoutineKit

/// Neue Liste anlegen oder bestehende bearbeiten (Zahnrad oben rechts in der Liste).
struct ListSettingsView: View {
    enum Mode {
        case create
        case edit(RoutineList)
    }

    let mode: Mode
    var onDelete: (() -> Void)?

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Query(sort: \RoutineList.sortOrder) private var lists: [RoutineList]
    @State private var draft: ListDraft
    @State private var customEmoji = ""
    @State private var confirmDelete = false

    init(mode: Mode, onDelete: (() -> Void)? = nil) {
        self.mode = mode
        self.onDelete = onDelete
        switch mode {
        case .create:
            _draft = State(initialValue: ListDraft())
        case .edit(let list):
            _draft = State(initialValue: ListDraft(list: list))
        }
    }

    private var isEditing: Bool {
        if case .edit = mode { return true }
        return false
    }

    var body: some View {
        Form {
            Section {
                HStack(spacing: Theme.Spacing.l) {
                    ListIcon(emoji: draft.emoji, color: draft.color.color, size: Theme.Icon.largeSize)
                    TextField("Name der Liste", text: $draft.name)
                        .font(.title3.weight(.semibold))
                }
                .padding(.vertical, Theme.Spacing.xs)
            }

            Section("Symbol") {
                TextField("Eigenes Emoji eingeben", text: $customEmoji)
                    .onChange(of: customEmoji) { _, newValue in
                        if let emoji = EmojiInput.lastEmoji(in: newValue) {
                            draft.emoji = emoji
                            customEmoji = ""
                        }
                    }
                EmojiGrid(selection: $draft.emoji)
            }

            Section("Farbe") {
                ColorGrid(selection: $draft.color)
            }

            Section {
                Picker("Wiederholung", selection: $draft.recurrence) {
                    ForEach(RecurrenceKind.allCases, id: \.self) { kind in
                        Text(kind.displayName).tag(kind)
                    }
                }
                if draft.recurrence != .none {
                    Stepper(value: $draft.interval, in: 1...99) {
                        Text(RecurrenceFormatting.intervalLabel(kind: draft.recurrence, interval: draft.interval))
                    }
                }
                if draft.recurrence == .weekly {
                    Picker("Zurücksetzen am", selection: $draft.weekday) {
                        ForEach(RecurrenceFormatting.weekdayOrder, id: \.self) { day in
                            Text(RecurrenceFormatting.weekdayName(day, short: false)).tag(day)
                        }
                    }
                }
                DatePicker(
                    draft.recurrence == .none ? "Datum" : "Starttag",
                    selection: $draft.anchorDate,
                    displayedComponents: .date
                )
            } header: {
                Text("Wiederholung")
            } footer: {
                Text(recurrenceFooter)
            }

            Section {
                Toggle("Startzeit", isOn: $draft.hasStartTime.animation())
                if draft.hasStartTime {
                    DatePicker("Uhrzeit", selection: $draft.startTime, displayedComponents: .hourAndMinute)
                }
                Toggle("Mitteilung", isOn: $draft.notificationEnabled)
                    .disabled(!draft.hasStartTime)
                #if os(iOS)
                Toggle("Live-Aktivität", isOn: $draft.liveActivityEnabled)
                    .disabled(!draft.hasStartTime)
                #endif
            } header: {
                Text("Erinnerung")
            } footer: {
                Text("Mitteilungen und Live-Aktivitäten werden in einer späteren Version aktiv.")
            }

            if isEditing {
                Section {
                    Button("Liste löschen", role: .destructive) {
                        confirmDelete = true
                    }
                }
            }
        }
        .formStyle(.grouped)
        .navigationTitle(isEditing ? "Liste bearbeiten" : "Neue Liste")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Abbrechen") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button(isEditing ? "Fertig" : "Hinzufügen") { save() }
                    .disabled(draft.trimmedName.isEmpty)
            }
        }
        .onChange(of: draft.recurrence) { _, newValue in
            if newValue == .weekly, !isEditing {
                draft.weekday = Calendar.current.component(.weekday, from: draft.anchorDate)
            }
        }
        .confirmationDialog("Liste löschen?", isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("Liste löschen", role: .destructive) {
                dismiss()
                onDelete?()
            }
            Button("Abbrechen", role: .cancel) {}
        } message: {
            Text("Alle To-dos und der Verlauf dieser Liste werden gelöscht.")
        }
    }

    private var recurrenceFooter: String {
        switch draft.recurrence {
        case .none:
            "Die Liste wird nicht zurückgesetzt. Erledigte To-dos bleiben erledigt."
        case .daily:
            "Alle To-dos sind jeweils um 0 Uhr wieder offen."
        case .weekly:
            "Alle To-dos sind am gewählten Wochentag um 0 Uhr wieder offen."
        case .monthly:
            "Wiederholt am Tag des Starttags. Hat ein Monat weniger Tage, am letzten Tag des Monats."
        case .yearly:
            "Wiederholt am Datum des Starttags. Der 29. Februar wird in Nicht-Schaltjahren zum 28."
        }
    }

    private func save() {
        switch mode {
        case .create:
            let list = RoutineList()
            list.sortOrder = (lists.map(\.sortOrder).max() ?? -1) + 1
            context.insert(list)
            draft.apply(to: list)
        case .edit(let list):
            draft.apply(to: list)
        }
        try? context.save()
        dismiss()
    }
}

/// Bearbeitbare Kopie einer Liste. Änderungen werden erst beim Speichern übernommen.
struct ListDraft {
    var name = ""
    var emoji = "✅"
    var color: ListColor = .blue
    var recurrence: RecurrenceKind = .daily
    var interval = 1
    var weekday = Calendar.current.component(.weekday, from: .now)
    var anchorDate = Date.now
    var hasStartTime = false
    var startTime = ListDraft.date(fromMinutes: 8 * 60)
    var notificationEnabled = false
    var liveActivityEnabled = false

    init() {}

    init(list: RoutineList) {
        name = list.name
        emoji = list.emoji
        color = list.color
        recurrence = list.recurrence
        interval = list.interval
        weekday = list.weekday
        anchorDate = list.anchorDate
        hasStartTime = list.startTimeMinutes != nil
        startTime = Self.date(fromMinutes: list.startTimeMinutes ?? 8 * 60)
        notificationEnabled = list.notificationEnabled
        liveActivityEnabled = list.liveActivityEnabled
    }

    var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func apply(to list: RoutineList) {
        list.name = trimmedName
        list.emoji = emoji
        list.color = color
        list.recurrence = recurrence
        list.interval = max(1, interval)
        list.weekday = weekday
        list.anchorDate = Calendar.current.startOfDay(for: anchorDate)
        list.startTimeMinutes = hasStartTime ? Self.minutes(from: startTime) : nil
        list.notificationEnabled = hasStartTime && notificationEnabled
        list.liveActivityEnabled = hasStartTime && liveActivityEnabled
    }

    static func date(fromMinutes minutes: Int) -> Date {
        let calendar = Calendar.current
        return calendar.date(bySettingHour: minutes / 60, minute: minutes % 60, second: 0, of: .now) ?? .now
    }

    static func minutes(from date: Date) -> Int {
        let components = Calendar.current.dateComponents([.hour, .minute], from: date)
        return (components.hour ?? 0) * 60 + (components.minute ?? 0)
    }
}

/// Raster mit Emoji-Vorschlägen.
struct EmojiGrid: View {
    @Binding var selection: String

    private let columns = [GridItem(.adaptive(minimum: 40), spacing: Theme.Spacing.s)]

    var body: some View {
        LazyVGrid(columns: columns, spacing: Theme.Spacing.s) {
            ForEach(EmojiInput.suggestions, id: \.self) { emoji in
                Button {
                    selection = emoji
                } label: {
                    Text(emoji)
                        .font(.title2)
                        .frame(width: 40, height: 40)
                        .background(
                            selection == emoji ? Color.secondary.opacity(0.2) : Color.clear,
                            in: Circle()
                        )
                }
                .buttonStyle(.plain)
                .accessibilityLabel(emoji)
                .accessibilityAddTraits(selection == emoji ? .isSelected : [])
            }
        }
        .padding(.vertical, Theme.Spacing.xs)
    }
}

/// Farbauswahl wie in der Erinnerungen-App.
struct ColorGrid: View {
    @Binding var selection: ListColor

    private let columns = [GridItem(.adaptive(minimum: Theme.Icon.swatchSize + 8), spacing: Theme.Spacing.m)]

    var body: some View {
        LazyVGrid(columns: columns, spacing: Theme.Spacing.m) {
            ForEach(ListColor.allCases) { listColor in
                Button {
                    selection = listColor
                } label: {
                    Circle()
                        .fill(listColor.color)
                        .frame(width: Theme.Icon.swatchSize, height: Theme.Icon.swatchSize)
                        .padding(4)
                        .overlay {
                            if selection == listColor {
                                Circle().strokeBorder(Color.secondary, lineWidth: 2)
                            }
                        }
                }
                .buttonStyle(.plain)
                .accessibilityLabel(listColor.displayName)
                .accessibilityAddTraits(selection == listColor ? .isSelected : [])
            }
        }
        .padding(.vertical, Theme.Spacing.xs)
    }
}

#Preview("Neue Liste") {
    NavigationStack {
        ListSettingsView(mode: .create)
    }
    .previewEnvironment()
}

#Preview("Bearbeiten") {
    let container = RoutinePersistence.previewContainer()
    let list = PreviewData.list(named: "Pflanzen gießen", in: container)
    NavigationStack {
        ListSettingsView(mode: .edit(list))
    }
    .previewEnvironment(container: container)
}
