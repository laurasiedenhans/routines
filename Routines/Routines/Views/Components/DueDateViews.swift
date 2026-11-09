import SwiftUI
import RoutineKit

// MARK: - Texte

enum DueDateFormatting {
    /// „Heute“, „Morgen“, „Fr 20.11.“ bzw. „Überfällig · Mo 02.11.“; in einem anderen Jahr mit Jahreszahl.
    static func text(for dueDate: Date, now: Date, engine: RecurrenceEngine = .current) -> String {
        let cal = engine.calendar
        let due = engine.startOfDay(dueDate)
        let today = engine.startOfDay(now)
        let sameYear = cal.component(.year, from: due) == cal.component(.year, from: today)
        let day = PeriodFormatting.dayString(due, calendar: cal, withYear: !sameYear)
        switch DueDates.status(of: due, now: now, engine: engine) {
        case .overdue:
            return "Überfällig · \(day)"
        case .today:
            return "Heute"
        case .upcoming:
            if let tomorrow = cal.date(byAdding: .day, value: 1, to: today), due == tomorrow {
                return "Morgen"
            }
            return day
        }
    }
}

// MARK: - Anzeige unter dem To-do

/// Kalender-Symbol mit Datum, rot wenn überfällig (und noch offen).
struct DueDateLabel: View {
    let dueDate: Date
    var isDone = false

    @Environment(AppClock.self) private var clock

    var body: some View {
        let isOverdue = !isDone && DueDates.status(of: dueDate, now: clock.now) == .overdue
        Label {
            Text(DueDateFormatting.text(for: dueDate, now: clock.now))
        } icon: {
            Image(systemName: "calendar")
        }
        .labelStyle(.titleAndIcon)
        .font(.subheadline)
        .foregroundStyle(isOverdue ? Color.red : Color.secondary)
        .accessibilityLabel("Fällig: \(DueDateFormatting.text(for: dueDate, now: clock.now))")
    }
}

/// Eingefärbtes Label mit dem Namen der Liste, z. B. „📦 Umzug“.
struct ListTag: View {
    let list: RoutineList

    var body: some View {
        Text("\(list.emoji) \(list.name.isEmpty ? "Ohne Namen" : list.name)")
            .font(.caption.weight(.semibold))
            .lineLimit(1)
            .foregroundStyle(list.color.color)
            .padding(.horizontal, Theme.Spacing.s)
            .padding(.vertical, Theme.Spacing.xxs)
            .background(list.color.color.opacity(Theme.DueDate.tagOpacity), in: Capsule())
    }
}

// MARK: - Datum setzen

/// Knöpfe unter dem Titel beim Bearbeiten: Heute · Morgen · Nächste Woche · Datum … · ✕
struct DueDateChips: View {
    private struct Preset {
        let title: String
        let date: Date
    }

    @Binding var dueDate: Date?
    let color: Color
    let onPickDate: () -> Void

    @Environment(AppClock.self) private var clock

    var body: some View {
        let engine = RecurrenceEngine.current
        let today = engine.startOfDay(clock.now)
        let presets = presetDates(today: today, calendar: engine.calendar)
        let current = dueDate.map(engine.startOfDay)
        let isCustom = current != nil && !presets.map { $0.date }.contains(current!)

        // Umbrechen, falls der Platz nicht reicht (große Schrift)
        ViewThatFits(in: .horizontal) {
            HStack(spacing: Theme.Spacing.s) { chips(presets: presets, current: current, isCustom: isCustom) }
            VStack(alignment: .leading, spacing: Theme.Spacing.s) {
                HStack(spacing: Theme.Spacing.s) { presetChips(presets, current: current) }
                HStack(spacing: Theme.Spacing.s) { pickChip(current: current, isCustom: isCustom); clearChip }
            }
        }
    }

    @ViewBuilder
    private func chips(presets: [Preset], current: Date?, isCustom: Bool) -> some View {
        presetChips(presets, current: current)
        pickChip(current: current, isCustom: isCustom)
        clearChip
    }

    @ViewBuilder
    private func presetChips(_ presets: [Preset], current: Date?) -> some View {
        ForEach(presets, id: \.title) { preset in
            chip(preset.title, isSelected: current == preset.date) {
                dueDate = current == preset.date ? nil : preset.date
            }
        }
    }

    private func pickChip(current: Date?, isCustom: Bool) -> some View {
        chip(
            isCustom ? DueDateFormatting.text(for: current!, now: clock.now) : "Datum …",
            systemImage: "calendar",
            isSelected: isCustom,
            action: onPickDate
        )
    }

    @ViewBuilder
    private var clearChip: some View {
        if dueDate != nil {
            Button {
                dueDate = nil
            } label: {
                Image(systemName: "xmark")
                    .font(.caption.weight(.bold))
                    .frame(width: Theme.DueDate.chipHeight, height: Theme.DueDate.chipHeight)
                    .background(Color.secondary.opacity(Theme.DueDate.chipOpacity), in: Circle())
            }
            .buttonStyle(.borderless)
            .foregroundStyle(.secondary)
            .accessibilityLabel("Datum entfernen")
        }
    }

    private func chip(_ title: String, systemImage: String? = nil, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: Theme.Spacing.xs) {
                if let systemImage { Image(systemName: systemImage) }
                Text(title).lineLimit(1)
            }
            .font(.subheadline.weight(isSelected ? .semibold : .regular))
            .padding(.horizontal, Theme.Spacing.m)
            .frame(height: Theme.DueDate.chipHeight)
            .foregroundStyle(isSelected ? Color.white : Color.primary)
            .background(isSelected ? color : Color.secondary.opacity(Theme.DueDate.chipOpacity), in: Capsule())
        }
        // Eigene Buttons in einer Listenzeile: sonst löst ein Tipp alle aus
        .buttonStyle(.borderless)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    /// Heute, Morgen und der nächste Montag.
    private func presetDates(today: Date, calendar: Calendar) -> [Preset] {
        let weekday = calendar.component(.weekday, from: today)
        let untilMonday = (9 - weekday) % 7 == 0 ? 7 : (9 - weekday) % 7
        return [
            Preset(title: "Heute", date: today),
            Preset(title: "Morgen", date: calendar.date(byAdding: .day, value: 1, to: today) ?? today),
            Preset(title: "Nächste Woche", date: calendar.date(byAdding: .day, value: untilMonday, to: today) ?? today)
        ]
    }
}

/// Kalender zum Wählen eines beliebigen Tags.
struct DueDatePickerSheet: View {
    @Binding var dueDate: Date?

    @Environment(\.dismiss) private var dismiss
    @Environment(AppClock.self) private var clock
    @State private var selection = Date()

    var body: some View {
        NavigationStack {
            DatePicker("Fällig am", selection: $selection, displayedComponents: .date)
                .datePickerStyle(.graphical)
                .labelsHidden()
                .padding(.horizontal)
                .navigationTitle("Fällig am")
                #if os(iOS)
                .navigationBarTitleDisplayMode(.inline)
                #endif
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Abbrechen") { dismiss() }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Fertig") {
                            dueDate = RecurrenceEngine.current.startOfDay(selection)
                            dismiss()
                        }
                    }
                }
        }
        .presentationDetents([.medium, .large])
        .onAppear { selection = dueDate ?? clock.now }
    }
}

// MARK: - Heute

/// Zeile in der Sektion „To-dos“ auf Heute: Titel, Label der Liste, Datum, Toggle.
struct DueTodoRow: View {
    let entry: DueDates.Entry
    let onToggle: () -> Void

    var body: some View {
        HStack(spacing: Theme.Spacing.m) {
            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                Text(entry.task.title)
                HStack(spacing: Theme.Spacing.s) {
                    ListTag(list: entry.list)
                    if let dueDate = entry.task.dueDate {
                        DueDateLabel(dueDate: dueDate)
                            .labelStyle(.titleOnly)
                    }
                }
            }
            Spacer(minLength: 0)
            CheckToggle(isOn: false, color: entry.list.color.color, action: onToggle)
        }
        .padding(.vertical, Theme.Spacing.xxs)
    }
}
