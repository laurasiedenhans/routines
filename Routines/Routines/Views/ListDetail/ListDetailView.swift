import SwiftUI
import SwiftData
import RoutineKit

/// Alle To-dos einer Liste. Erledigte wandern in den einklappbaren Bereich „Erledigt“.
///
/// Wiederholende Listen haben oben eine Zeitraum-Leiste: Vergangene Zeiträume lassen sich ansehen
/// und nachträglich abhaken, zukünftige ansehen und mit einmaligen Aufgaben vorplanen.
struct ListDetailView: View {
    @Bindable var list: RoutineList
    var onDelete: () -> Void

    @Environment(\.modelContext) private var context
    @Environment(AppClock.self) private var clock
    /// Nur auf dem iPhone vorhanden: das „+“ der Navigationsleiste
    @Environment(QuickAddCenter.self) private var quickAdd: QuickAddCenter?
    @State private var showSettings = false
    @State private var showCompleted = false
    @State private var pendingDeletion: RoutineTask?
    @State private var confirmReuse = false
    @State private var confirmClearDone = false
    @FocusState private var focus: TaskFocus?
    @State private var editingTaskID: UUID?
    @State private var isAdding = false
    /// Gewählter Zeitraum, `nil` = immer der aktuelle
    @State private var selectedIndex: Int?
    /// Erster Zeitraum der Leiste, `nil` = Standardfenster um den aktuellen Zeitraum
    @State private var stripBase: Int?
    /// Positionen der Eingabefelder, um „Tippen außerhalb“ zu erkennen. Bewusst kein @State-Wert,
    /// damit Scrollen keine Neuberechnung der Ansicht auslöst.
    @State private var frames = FieldFrames()

    init(list: RoutineList, onDelete: @escaping () -> Void) {
        _list = Bindable(list)
        self.onDelete = onDelete
    }

    var body: some View {
        let engine = RecurrenceEngine.current
        let paging = makePaging(engine: engine)
        let status = paging.map { ListStatus(list: list, period: $0.selectedPeriod, now: clock.now, engine: engine) }
            ?? ListStatus(list: list, now: clock.now, engine: engine)
        let color = list.color.color
        let today = engine.startOfDay(clock.now)
        // Abhaken nur im aktuellen und in vergangenen Zeiträumen
        let canCheck = status.period.map { $0.start <= today } ?? false
        let isFuturePreview = status.period != nil && !canCheck
        let isCurrentPeriod = paging.map { $0.selectedIndex == $0.currentIndex } ?? true

        ScrollViewReader { proxy in
        List {
            if let paging {
                Section {
                    periodHeader(paging, engine: engine, color: color)
                }
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
                .listRowInsets(EdgeInsets(top: Theme.Spacing.xs, leading: Theme.Spacing.xs, bottom: Theme.Spacing.xs, trailing: Theme.Spacing.xs))
            }

            if engine.periodIndex(for: list.rule, containing: clock.now) == nil {
                Section {
                    Label(
                        "Startet am \(list.anchorDate.formatted(date: .long, time: .omitted))",
                        systemImage: "calendar"
                    )
                    .foregroundStyle(.secondary)
                }
            } else if isFuturePreview, let period = status.period {
                Section {
                    Label(
                        "Vorschau · Abhaken ab \(PeriodFormatting.dayString(period.start, calendar: engine.calendar, withYear: false)) möglich",
                        systemImage: "eye"
                    )
                    .font(.subheadline)
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
                    taskRow(task, isDone: false, color: color, isEnabled: canCheck, period: status.period)
                }
                .onMove { source, destination in
                    move(status.open, from: source, to: destination)
                }

                AddTaskRow(
                    list: list,
                    period: status.period,
                    isPast: !isCurrentPeriod && canCheck,
                    isFuture: !isCurrentPeriod && !canCheck,
                    color: color,
                    isEditing: $isAdding,
                    focus: $focus
                )
                .id(Self.addRowID)
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
                        taskRow(task, isDone: true, color: color, isEnabled: canCheck, period: status.period)
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
        // Eingabezeile samt „Immer / Einmalig“ über die Tastatur schieben: beim Öffnen und nach jedem Hinzufügen.
        .onChange(of: focus) { _, newValue in
            if newValue == .newTask { scrollToAddRow(proxy) }
        }
        .onChange(of: status.open.count) { _, _ in
            if focus == .newTask { scrollToAddRow(proxy) }
        }
        // „+“ der Navigationsleiste: Eingabezeile öffnen wie „Aufgabe hinzufügen“
        .onChange(of: quickAdd?.requestToken) { _, _ in
            guard quickAdd?.activeListID == list.id else { return }
            if isAdding {
                focus = .newTask
            } else {
                isAdding = true
            }
            withAnimation(Theme.Motion.check) { proxy.scrollTo(Self.addRowID, anchor: .bottom) }
        }
        }
        .navigationTitle("\(list.emoji) \(list.name)")
        .tint(color)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showSettings = true
                } label: {
                    Label("Liste bearbeiten", systemImage: "pencil")
                }
            }
        }
        .sheet(isPresented: $showSettings) {
            NavigationStack {
                ListSettingsView(mode: .edit(list), onDelete: onDelete)
            }
        }
        .onAppear { quickAdd?.activeListID = list.id }
        .onDisappear {
            if quickAdd?.activeListID == list.id { quickAdd?.activeListID = nil }
        }
        // Wiederholung geändert: Zeiträume passen nicht mehr, zurück zum aktuellen
        .onChange(of: ruleSignature) { _, _ in
            selectedIndex = nil
            stripBase = nil
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
            Button(onceLabel(isCurrent: isCurrentPeriod), role: .destructive) {
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

    private static let addRowID = "addTaskRow"

    /// Wartet kurz, bis die Tastatur eingeblendet ist, und scrollt dann die ganze Eingabezeile ins Bild.
    private func scrollToAddRow(_ proxy: ScrollViewProxy) {
        Task {
            try? await Task.sleep(for: .milliseconds(350))
            withAnimation(Theme.Motion.check) {
                proxy.scrollTo(Self.addRowID, anchor: .bottom)
            }
        }
    }

    // MARK: - Blättern

    /// Was die Leiste gerade zeigt.
    private struct Paging {
        let kind: RecurrenceKind
        let count: Int
        /// Index des aktuellen Zeitraums, `nil` solange die Liste noch nicht gestartet ist
        let currentIndex: Int?
        let selectedIndex: Int
        let selectedPeriod: Period
        let base: Int
        let defaultBase: Int

        var isAtDefault: Bool { selectedIndex == (currentIndex ?? 0) && base == defaultBase }
    }

    /// `nil` bei Listen ohne Wiederholung: Die haben nur einen Zeitraum und keine Leiste.
    private func makePaging(engine: RecurrenceEngine) -> Paging? {
        let rule = list.rule
        guard rule.kind != .none else { return nil }
        let count = PeriodFormatting.stripCount(for: rule.kind)
        let currentIndex = engine.periodIndex(for: rule, containing: clock.now)
        let reference = currentIndex ?? 0
        let defaultBase: Int
        if rule.kind == .daily, rule.interval == 1, let start = engine.period(for: rule, index: reference)?.start {
            // Täglich: eine Kalenderwoche Mo–So
            let weekday = engine.calendar.component(.weekday, from: start)
            defaultBase = reference - (weekday + 5) % 7
        } else {
            // Sonst der aktuelle Zeitraum in der Mitte
            defaultBase = reference - count / 2
        }
        let selected = max(0, selectedIndex ?? reference)
        guard let period = engine.period(for: rule, index: selected) else { return nil }
        return Paging(
            kind: rule.kind,
            count: count,
            currentIndex: currentIndex,
            selectedIndex: selected,
            selectedPeriod: period,
            base: stripBase ?? defaultBase,
            defaultBase: defaultBase
        )
    }

    private func periodHeader(_ paging: Paging, engine: RecurrenceEngine, color: Color) -> some View {
        let isCurrent = paging.selectedIndex == paging.currentIndex
        let range = PeriodFormatting.range(kind: paging.kind, period: paging.selectedPeriod, engine: engine)
        return VStack(spacing: Theme.Spacing.s) {
            HStack(alignment: .firstTextBaseline) {
                Text(PeriodFormatting.title(kind: paging.kind, period: paging.selectedPeriod, isCurrent: isCurrent, engine: engine))
                    .font(.title3.weight(.bold))
                    .contentTransition(.numericText())
                Spacer(minLength: Theme.Spacing.s)
                if !paging.isAtDefault {
                    Button(paging.currentIndex == nil ? "Zum Start" : PeriodFormatting.currentTitle(kind: paging.kind)) {
                        withAnimation(Theme.Motion.check) {
                            selectedIndex = nil
                            stripBase = nil
                        }
                    }
                    .buttonStyle(.bordered)
                    .buttonBorderShape(.capsule)
                    .controlSize(.small)
                    .tint(color)
                }
            }
            .padding(.horizontal, Theme.Spacing.m)

            PeriodStrip(
                items: stripItems(paging, engine: engine),
                selectedIndex: paging.selectedIndex,
                currentIndex: paging.currentIndex,
                color: color,
                onSelect: { index in
                    withAnimation(Theme.Motion.check) { selectedIndex = index }
                },
                onPage: { direction in page(direction, paging: paging) }
            )

            if let range {
                Text(range)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
        }
    }

    private func stripItems(_ paging: Paging, engine: RecurrenceEngine) -> [PeriodStripItem?] {
        (paging.base ..< paging.base + paging.count).map { index in
            guard index >= 0, let period = engine.period(for: list.rule, index: index) else { return nil }
            let label = PeriodFormatting.chip(kind: paging.kind, period: period, engine: engine)
            return PeriodStripItem(
                index: index,
                top: label.top,
                main: label.main,
                accessibilityLabel: PeriodFormatting.title(
                    kind: paging.kind, period: period, isCurrent: index == paging.currentIndex, engine: engine
                ),
                dot: dot(for: period, index: index, currentIndex: paging.currentIndex, engine: engine)
            )
        }
    }

    /// Grün = vergangen und alles erledigt, grau = vergangen mit Offenem, orange = zukünftig mit eingeplanter Aufgabe.
    private func dot(for period: Period, index: Int, currentIndex: Int?, engine: RecurrenceEngine) -> PeriodDot {
        let current = currentIndex ?? -1
        if index < current {
            let status = ListStatus(list: list, period: period, now: clock.now, engine: engine)
            guard status.total > 0 else { return .none }
            return status.isComplete ? .complete : .incomplete
        }
        if index > current {
            let planned = (list.tasks ?? []).contains { $0.deletedAt == nil && $0.oneOffPeriodKey == period.key }
            return planned ? .planned : .none
        }
        return .none
    }

    /// Eine ganze Leiste weiterblättern, die Auswahl wandert mit.
    private func page(_ direction: Int, paging: Paging) {
        let newBase = paging.base + direction * paging.count
        // Nicht vor den ersten Zeitraum der Liste
        guard newBase + paging.count > 0 else { return }
        focus = nil
        withAnimation(Theme.Motion.check) {
            stripBase = newBase
            selectedIndex = max(0, paging.selectedIndex + direction * paging.count)
        }
    }

    private var ruleSignature: String {
        "\(list.recurrence.rawValue)-\(list.interval)-\(list.weekday)-\(list.anchorDate.timeIntervalSinceReferenceDate)"
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

    /// Löschen per Wischen. Folgt eine Rückfrage („nur heute / alle zukünftigen“), bekommt der Button
    /// keine destruktive Rolle: Die würde die Zeile sofort ausblenden, bevor überhaupt entschieden ist.
    @ViewBuilder
    private func deleteButton(for task: RoutineTask) -> some View {
        if needsDeleteConfirmation(task) {
            Button {
                pendingDeletion = task
            } label: {
                Label("Löschen", systemImage: "trash")
            }
            .tint(.red)
        } else {
            Button(role: .destructive) {
                withAnimation(Theme.Motion.check) { context.deletePermanently(task) }
                save()
            } label: {
                Label("Löschen", systemImage: "trash")
            }
        }
    }

    /// Ohne Wiederholung oder einmalig: Es gibt keine „zukünftigen“, also direkt löschen.
    private func needsDeleteConfirmation(_ task: RoutineTask) -> Bool {
        list.recurrence != .none && task.oneOffPeriodKey == nil
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

    private func onceLabel(isCurrent: Bool) -> String {
        isCurrent && list.recurrence == .daily && list.interval == 1 ? "Nur heute löschen" : "Nur diesmal löschen"
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
///
/// Im angezeigten Zeitraum: in der Zukunft ist „Einmalig“ vorgewählt, in der Vergangenheit
/// gibt es nur einmalige Aufgaben (eine dauerhafte würde dort ohnehin nicht erscheinen).
struct AddTaskRow: View {
    let list: RoutineList
    let period: Period?
    var isPast = false
    var isFuture = false
    let color: Color
    @Binding var isEditing: Bool
    var focus: FocusState<TaskFocus?>.Binding

    @Environment(\.modelContext) private var context
    @Environment(AppClock.self) private var clock
    @State private var title = ""
    @State private var isOneOff = false

    var body: some View {
        Group {
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
                    } else if isPast {
                        Text("Wird nur in diesem Zeitraum hinzugefügt")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .padding(.bottom, Theme.Spacing.xs)
                    }
                }
                .onAppear {
                    isOneOff = isFuture
                    focus.wrappedValue = .newTask
                }
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
        // Anderer Zeitraum gewählt: Vorauswahl neu setzen
        .onChange(of: period?.key) { _, _ in
            isOneOff = isFuture
        }
    }

    /// Wiederholende Liste mit Zeitraum. Bei Listen ohne Wiederholung gibt es keinen nächsten Zeitraum.
    private var isRepeating: Bool {
        list.recurrence != .none && period != nil
    }

    private var showsFrequencyChoice: Bool {
        isRepeating && !isPast
    }

    private var trimmedTitle: String {
        title.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func add() {
        let text = trimmedTitle
        guard !text.isEmpty else { return }
        let oneOffKey = (isRepeating && (isOneOff || isPast)) ? period?.key : nil
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
        isOneOff = isFuture
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
