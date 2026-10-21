import SwiftUI
import SwiftData
import RoutineKit

/// Alle To-dos einer Liste. Erledigte wandern in den einklappbaren Bereich „Erledigt“.
struct ListDetailView: View {
    @Bindable var list: RoutineList
    var onDelete: () -> Void

    @Environment(\.modelContext) private var context
    @Environment(AppClock.self) private var clock
    @State private var showSettings = false
    @State private var showCompleted = false
    @State private var pendingDeletion: RoutineTask?
    @FocusState private var isAddingTask: Bool
    @State private var addRowFrame: CGRect = .zero

    init(list: RoutineList, onDelete: @escaping () -> Void) {
        _list = Bindable(list)
        self.onDelete = onDelete
    }

    var body: some View {
        let status = ListStatus(list: list, now: clock.now)
        let color = list.color.color

        List {
            if !status.isActive {
                Section {
                    Label(
                        "Startet am \(list.anchorDate.formatted(date: .long, time: .omitted))",
                        systemImage: "calendar"
                    )
                    .foregroundStyle(.secondary)
                }
            }

            Section {
                ForEach(status.open) { task in
                    TaskRow(task: task, isDone: false, color: color, isEnabled: status.isActive) {
                        toggle(task, in: status.period)
                    }
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        deleteButton(for: task)
                    }
                }
                .onMove { source, destination in
                    move(status.open, from: source, to: destination)
                }

                AddTaskRow(list: list, period: status.period, color: color, isFocused: $isAddingTask)
                    .onGeometryChange(for: CGRect.self) { $0.frame(in: .global) } action: { addRowFrame = $0 }
            } footer: {
                if status.isComplete {
                    Text("Alles erledigt für diesen Zeitraum.")
                }
            }

            if !status.done.isEmpty {
                Section {
                    if showCompleted {
                        ForEach(status.done) { task in
                            TaskRow(task: task, isDone: true, color: color) {
                                toggle(task, in: status.period)
                            }
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                deleteButton(for: task)
                            }
                        }
                    }
                } header: {
                    Button {
                        withAnimation(Theme.Motion.check) { showCompleted.toggle() }
                    } label: {
                        HStack {
                            Text("Erledigt (\(status.done.count))")
                            Spacer()
                            Image(systemName: "chevron.right")
                                .rotationEffect(.degrees(showCompleted ? 90 : 0))
                        }
                        .contentShape(.rect)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(showCompleted ? "Erledigte ausblenden" : "Erledigte anzeigen")
                }
            }
        }
        // Tippen außerhalb des Eingabefelds beendet die Eingabe (getippter Text wird übernommen).
        .simultaneousGesture(
            SpatialTapGesture(coordinateSpace: .global).onEnded { tap in
                if isAddingTask, !addRowFrame.contains(tap.location) {
                    isAddingTask = false
                }
            }
        )
        .scrollDismissesKeyboard(.immediately)
        .navigationTitle("\(list.emoji) \(list.name)")
        .tint(color)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showSettings = true
                } label: {
                    Label("Listeneinstellungen", systemImage: "gearshape")
                }
            }
        }
        .sheet(isPresented: $showSettings) {
            NavigationStack {
                ListSettingsView(mode: .edit(list), onDelete: onDelete)
            }
        }
        .confirmationDialog(
            "To-do löschen?",
            isPresented: isShowingDeletionDialog,
            titleVisibility: .visible,
            presenting: pendingDeletion
        ) { task in
            Button(onceLabel, role: .destructive) {
                if let period = status.period {
                    withAnimation(Theme.Motion.check) { context.skip(task, in: period, at: clock.now) }
                    save()
                }
            }
            Button("Alle zukünftigen löschen", role: .destructive) {
                withAnimation(Theme.Motion.check) { context.deleteFutureOccurrences(of: task, at: clock.now) }
                save()
            }
            Button("Abbrechen", role: .cancel) {}
        } message: { task in
            Text("„\(task.title)“")
        }
    }

    // MARK: - Aktionen

    private func deleteButton(for task: RoutineTask) -> some View {
        Button(role: .destructive) {
            requestDelete(task)
        } label: {
            Label("Löschen", systemImage: "trash")
        }
    }

    private func toggle(_ task: RoutineTask, in period: Period?) {
        guard let period else { return }
        withAnimation(Theme.Motion.check) {
            if task.isCompleted(in: period) {
                context.uncomplete(task, in: period)
            } else {
                context.complete(task, in: period, at: clock.now)
            }
        }
        save()
    }

    private func requestDelete(_ task: RoutineTask) {
        // Ohne Wiederholung oder einmalig: es gibt keine „zukünftigen“, also direkt löschen.
        if list.recurrence == .none || task.oneOffPeriodKey != nil {
            withAnimation(Theme.Motion.check) { context.deletePermanently(task) }
            save()
        } else {
            pendingDeletion = task
        }
    }

    private func move(_ tasks: [RoutineTask], from source: IndexSet, to destination: Int) {
        var reordered = tasks
        reordered.move(fromOffsets: source, toOffset: destination)
        for (index, task) in reordered.enumerated() {
            task.sortOrder = index
        }
        save()
    }

    private func save() {
        try? context.save()
    }

    private var onceLabel: String {
        list.recurrence == .daily && list.interval == 1 ? "Nur heute löschen" : "Nur diesmal löschen"
    }

    private var isShowingDeletionDialog: Binding<Bool> {
        Binding(
            get: { pendingDeletion != nil },
            set: { if !$0 { pendingDeletion = nil } }
        )
    }
}

/// Eine To-do-Zeile mit rundem Toggle rechts.
struct TaskRow: View {
    let task: RoutineTask
    let isDone: Bool
    let color: Color
    var isEnabled = true
    let onToggle: () -> Void

    var body: some View {
        HStack(spacing: Theme.Spacing.m) {
            VStack(alignment: .leading, spacing: Theme.Spacing.xxs) {
                Text(task.title)
                    .foregroundStyle(isDone ? Color.secondary : Color.primary)
                if task.oneOffPeriodKey != nil {
                    Text("Einmalig")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: 0)
            CheckToggle(isOn: isDone, color: color, action: onToggle)
                .disabled(!isEnabled)
                .opacity(isEnabled ? 1 : 0.4)
        }
        .accessibilityElement(children: .combine)
    }
}

/// „+ Aufgabe hinzufügen“ am Ende der Liste, mit Auswahl „Immer / Einmalig“.
///
/// Verhalten wie in der Erinnerungen-App: Return fügt hinzu und bleibt für das nächste To-do offen.
/// Verliert das Feld den Fokus (Tippen außerhalb, Scrollen), wird getippter Text übernommen
/// und die Eingabe geschlossen. Ein leeres Feld schließt sich einfach.
struct AddTaskRow: View {
    let list: RoutineList
    let period: Period?
    let color: Color
    @FocusState.Binding var isFocused: Bool

    @Environment(\.modelContext) private var context
    @Environment(AppClock.self) private var clock
    @State private var isEditing = false
    @State private var title = ""
    @State private var isOneOff = false

    var body: some View {
        if isEditing {
            VStack(alignment: .leading, spacing: Theme.Spacing.m) {
                TextField("Neue Aufgabe", text: $title)
                    .focused($isFocused)
                    .submitLabel(.next)
                    .onSubmit {
                        add()
                        isFocused = true
                    }

                if showsFrequencyChoice {
                    Picker("Häufigkeit", selection: $isOneOff) {
                        Text("Immer").tag(false)
                        Text("Einmalig").tag(true)
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                }
            }
            .padding(.vertical, Theme.Spacing.xs)
            .onAppear { isFocused = true }
            .onChange(of: isFocused) { _, focused in
                guard !focused else { return }
                // Nach Return holt sich das Feld den Fokus sofort zurück: dann nicht schließen.
                DispatchQueue.main.async {
                    if !isFocused { finish() }
                }
            }
        } else {
            Button {
                isEditing = true
            } label: {
                Label("Aufgabe hinzufügen", systemImage: "plus.circle.fill")
            }
            .foregroundStyle(color)
        }
    }

    /// Bei Listen ohne Wiederholung gibt es keinen nächsten Zeitraum, also keine Auswahl.
    private var showsFrequencyChoice: Bool {
        list.recurrence != .none && period != nil
    }

    private var trimmedTitle: String {
        title.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func add() {
        let text = trimmedTitle
        guard !text.isEmpty else { return }
        let oneOffKey = (isOneOff && showsFrequencyChoice) ? period?.key : nil
        withAnimation(Theme.Motion.check) {
            context.addTask(text, to: list, oneOffPeriodKey: oneOffKey, at: clock.now)
        }
        try? context.save()
        title = ""
    }

    /// Übernimmt getippten Text und schließt die Eingabe.
    private func finish() {
        add()
        isOneOff = false
        withAnimation(Theme.Motion.check) { isEditing = false }
    }
}

#Preview {
    let container = RoutinePersistence.previewContainer()
    let list = PreviewData.list(named: "Morgenroutine", in: container)
    NavigationStack {
        ListDetailView(list: list, onDelete: {})
    }
    .previewEnvironment(container: container)
}
