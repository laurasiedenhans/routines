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
    @State private var confirmReuse = false
    @State private var confirmClearDone = false
    @FocusState private var focus: TaskFocus?
    @State private var editingTaskID: UUID?
    /// Positionen der Eingabefelder, um „Tippen außerhalb“ zu erkennen. Bewusst kein @State-Wert,
    /// damit Scrollen keine Neuberechnung der Ansicht auslöst.
    @State private var frames = FieldFrames()

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

            // Einmalige Liste komplett erledigt: leeren und erneut nutzen (z. B. Packliste)
            if isOneOff, status.isComplete {
                Section {
                    Button {
                        confirmReuse = true
                    } label: {
                        Label("Wiederverwenden", systemImage: "arrow.counterclockwise")
                    }
                    .buttonStyle(.borderless)
                    .confirmationDialog("Liste wiederverwenden?", isPresented: $confirmReuse, titleVisibility: .visible) {
                        Button("Alle To-dos entfernen", role: .destructive) {
                            withAnimation(Theme.Motion.check) { context.deleteAllTasks(of: list) }
                            save()
                        }
                        Button("Abbrechen", role: .cancel) {}
                    } message: {
                        Text("Alle To-dos werden gelöscht, die Liste ist danach leer und wieder bei den aktuellen Listen.")
                    }
                } footer: {
                    Text("Alles erledigt. Name, Symbol und Farbe bleiben beim Wiederverwenden erhalten.")
                }
            }

            Section {
                ForEach(status.open) { task in
                    taskRow(task, isDone: false, color: color, isEnabled: status.isActive, period: status.period)
                }
                .onMove { source, destination in
                    move(status.open, from: source, to: destination)
                }

                AddTaskRow(list: list, period: status.period, color: color, focus: $focus)
                    .onGeometryChange(for: CGRect.self) { $0.frame(in: .global) } action: { frames.rects[.newTask] = $0 }
            } footer: {
                if status.isComplete, !isOneOff {
                    Text("Alles erledigt für diesen Zeitraum.")
                }
            }

            if !status.done.isEmpty {
                // „Alle löschen“ nur bei einmaligen Listen: bei Routinen kommen erledigte To-dos wieder.
                CollapsibleSection(
                    title: "Erledigt",
                    count: status.done.count,
                    isExpanded: $showCompleted,
                    actionTitle: isOneOff ? "Alle löschen" : nil,
                    action: { confirmClearDone = true }
                ) {
                    ForEach(status.done) { task in
                        taskRow(task, isDone: true, color: color, isEnabled: true, period: status.period)
                    }
                }
            }
        }
        // Tippen außerhalb des aktiven Eingabefelds beendet die Eingabe (Text wird übernommen).
        // Nur aktiv, solange ein Feld offen ist: sonst fängt die Geste die Zeilen-Buttons ab.
        .simultaneousGesture(
            SpatialTapGesture(coordinateSpace: .global).onEnded { tap in
                guard let current = focus else { return }
                if let rect = frames.rects[current], rect.contains(tap.location) { return }
                focus = nil
            },
            including: focus != nil ? .all : .subviews
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
        .confirmationDialog("Erledigte To-dos löschen?", isPresented: $confirmClearDone, titleVisibility: .visible) {
            Button(status.done.count == 1 ? "1 To-do löschen" : "\(status.done.count) To-dos löschen", role: .destructive) {
                if let period = status.period {
                    withAnimation(Theme.Motion.check) { context.deleteCompletedTasks(of: list, in: period) }
                    save()
                }
            }
            Button("Abbrechen", role: .cancel) {}
        } message: {
            Text("Die erledigten To-dos werden endgültig aus der Liste entfernt.")
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

    // MARK: - Zeilen

    private func taskRow(_ task: RoutineTask, isDone: Bool, color: Color, isEnabled: Bool, period: Period?) -> some View {
        TaskRow(
            task: task,
            isDone: isDone,
            color: color,
            isEnabled: isEnabled,
            isEditing: editingTaskID == task.id,
            focus: $focus,
            onToggle: { toggle(task, in: period) },
            onStartEditing: { editingTaskID = task.id },
            onEndEditing: {
                if editingTaskID == task.id { editingTaskID = nil }
                save()
            }
        )
        .onGeometryChange(for: CGRect.self) { $0.frame(in: .global) } action: { frames.rects[.task(task.id)] = $0 }
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            deleteButton(for: task)
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

    /// Liste ohne Wiederholung
    private var isOneOff: Bool {
        list.recurrence == .none
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

/// Welches Eingabefeld in der Liste gerade aktiv ist.
enum TaskFocus: Hashable {
    case newTask
    case task(UUID)
}

/// Bildschirmpositionen der Eingabefelder (Referenztyp, Änderungen lösen kein Neuzeichnen aus).
final class FieldFrames {
    var rects: [TaskFocus: CGRect] = [:]
}

/// Eine To-do-Zeile mit rundem Toggle rechts. Tippen auf den Titel macht ihn bearbeitbar.
struct TaskRow: View {
    let task: RoutineTask
    let isDone: Bool
    let color: Color
    var isEnabled = true
    let isEditing: Bool
    var focus: FocusState<TaskFocus?>.Binding
    let onToggle: () -> Void
    let onStartEditing: () -> Void
    let onEndEditing: () -> Void

    @State private var draft = ""

    var body: some View {
        HStack(spacing: Theme.Spacing.m) {
            VStack(alignment: .leading, spacing: Theme.Spacing.xxs) {
                if isEditing {
                    TextField("To-do", text: $draft)
                        .focused(focus, equals: .task(task.id))
                        .submitLabel(.done)
                        .onSubmit { focus.wrappedValue = nil }
                        .onAppear {
                            draft = task.title
                            focus.wrappedValue = .task(task.id)
                        }
                } else {
                    Text(task.title)
                        .foregroundStyle(isDone ? Color.secondary : Color.primary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(.rect)
                        .onTapGesture(perform: onStartEditing)
                        .accessibilityAddTraits(.isButton)
                        .accessibilityHint("Zum Bearbeiten tippen")
                }
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
        .onChange(of: focus.wrappedValue) { old, new in
            guard isEditing, old == .task(task.id), new != .task(task.id) else { return }
            commit()
        }
    }

    /// Übernimmt den neuen Titel. Leerer Titel: alter Text bleibt.
    private func commit() {
        let trimmed = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty, trimmed != task.title {
            task.title = trimmed
        }
        onEndEditing()
    }
}

/// „+ Aufgabe hinzufügen“ am Ende der Liste.
///
/// Verhalten wie in der Erinnerungen-App: Die Eingabezeile sieht aus wie ein To-do. Return fügt das
/// To-do genau an dieser Stelle ein (ohne Schiebeanimation) und öffnet darunter die nächste leere Zeile.
/// Verliert das Feld den Fokus (Tippen außerhalb, Scrollen), wird getippter Text übernommen
/// und die Eingabe geschlossen. Ein leeres Feld schließt sich einfach.
struct AddTaskRow: View {
    let list: RoutineList
    let period: Period?
    let color: Color
    var focus: FocusState<TaskFocus?>.Binding

    @Environment(\.modelContext) private var context
    @Environment(AppClock.self) private var clock
    @State private var isEditing = false
    @State private var title = ""
    @State private var isOneOff = false

    var body: some View {
        if isEditing {
            VStack(alignment: .leading, spacing: Theme.Spacing.s) {
                // Eingabezeile im Stil eines To-dos: Beim Hinzufügen wird sie nahtlos zum To-do.
                HStack(spacing: Theme.Spacing.m) {
                    TextField("Neue Aufgabe", text: $title)
                        .focused(focus, equals: .newTask)
                        .submitLabel(.next)
                        .onSubmit {
                            add()
                            focus.wrappedValue = .newTask
                        }

                    // Platzhalter im Stil des Toggles, damit die Zeile genauso hoch ist wie ein To-do
                    Image(systemName: "circle")
                        .font(.system(size: Theme.Check.size))
                        .foregroundStyle(.tertiary)
                        .frame(width: Theme.Check.hitArea, height: Theme.Check.hitArea)
                        .accessibilityHidden(true)
                }

                if showsFrequencyChoice {
                    Picker("Häufigkeit", selection: $isOneOff) {
                        Text("Immer").tag(false)
                        Text("Einmalig").tag(true)
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                    .padding(.bottom, Theme.Spacing.xs)
                }
            }
            .onAppear { focus.wrappedValue = .newTask }
            .onChange(of: focus.wrappedValue) { _, newValue in
                guard newValue != .newTask else { return }
                // Nach Return holt sich das Feld den Fokus sofort zurück: dann nicht schließen.
                DispatchQueue.main.async {
                    if focus.wrappedValue != .newTask { finish() }
                }
            }
        } else {
            Button {
                isEditing = true
            } label: {
                Label("Aufgabe hinzufügen", systemImage: "plus.circle.fill")
            }
            .buttonStyle(.borderless)
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
        // Ohne Animation: Das To-do erscheint genau dort, wo getippt wurde, die Eingabe rutscht eine Zeile tiefer.
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            context.addTask(text, to: list, oneOffPeriodKey: oneOffKey, at: clock.now)
            title = ""
        }
        try? context.save()
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
