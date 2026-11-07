import SwiftUI
import SwiftData
import RoutineKit

// MARK: - Gruppieren

/// Einträge einer Kategorie im aktuellen Bereich.
struct CategoryGroup: Identifiable {
    let category: ListCategory
    let lists: [RoutineList]
    var id: UUID { category.id }
}

enum CategoryGrouping {
    /// Teilt die Listen in „ohne Kategorie“ und Gruppen je Kategorie (in deren Reihenfolge).
    ///
    /// Eine Kategorie erscheint, wenn sie hier Einträge hat. Ganz leere Kategorien (frisch angelegt)
    /// erscheinen immer, damit man sie nach dem Anlegen auch sieht.
    /// Jede Liste landet genau einmal: in ihrer Kategorie oder (ohne bzw. mit unbekannter Kategorie) bei „ohne Kategorie“.
    static func make(_ lists: [RoutineList], categories: [ListCategory]) -> (uncategorized: [RoutineList], groups: [CategoryGroup]) {
        let known = Set(categories.map(\.id))
        var uncategorized: [RoutineList] = []
        var members: [UUID: [RoutineList]] = [:]
        var placed = Set<UUID>()
        for list in lists where placed.insert(list.id).inserted {
            if let id = list.category?.id, known.contains(id) {
                members[id, default: []].append(list)
            } else {
                uncategorized.append(list)
            }
        }
        let groups = categories.compactMap { category -> CategoryGroup? in
            let mine = members[category.id] ?? []
            let isEmpty = (category.lists ?? []).isEmpty
            guard !mine.isEmpty || isEmpty else { return nil }
            return CategoryGroup(category: category, lists: mine)
        }
        return (uncategorized, groups)
    }
}

// MARK: - Abschnitt

/// Einklappbare Kategorie wie „Erledigt“, mit Emoji und Namen.
/// - Name antippen: bearbeiten (Return oder Tippen daneben übernimmt, leer behält den alten Namen)
/// - Emoji antippen: Emoji auswählen
/// - Nach links wischen: Löschen (Listen bleiben erhalten)
/// - Gedrückt halten: Menü mit Emoji, Umbenennen, Kategorien ordnen, Löschen
/// Hinter dem Namen steht die Anzahl wie bei „Erledigt (3)“, eingeklappt zusätzlich der Fortschritt, z. B. „45 %“.
struct CategorySection<Content: View>: View {
    let category: ListCategory
    let count: Int
    let percent: Int?
    @Binding var isExpanded: Bool
    var onEditEmoji: () -> Void
    var onReorder: () -> Void
    var onDelete: () -> Void
    @ViewBuilder var content: () -> Content

    @Environment(\.modelContext) private var context
    @State private var isEditingName = false
    @State private var draftName = ""
    @State private var swipeOffset: CGFloat = 0
    @FocusState private var nameFocused: Bool

    var body: some View {
        Section {
            if isExpanded {
                content()
            }
        } header: {
            header
        }
    }

    private var header: some View {
        ZStack(alignment: .trailing) {
            // Liegt hinter der Überschrift und wird beim Wischen nach links sichtbar.
            Button(role: .destructive) {
                withAnimation(Theme.Motion.check) { swipeOffset = 0 }
                onDelete()
            } label: {
                Text("Löschen")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                    .frame(width: Theme.Category.deleteWidth - Theme.Spacing.s, height: 30)
                    .background(Color.red, in: Capsule())
            }
            .buttonStyle(.plain)
            .opacity(min(1, -swipeOffset / Theme.Category.deleteWidth))
            .accessibilityHidden(swipeOffset == 0)

            HStack(spacing: Theme.Spacing.s) {
                emojiButton
                nameView
                Spacer(minLength: Theme.Spacing.s)
                toggleButton
            }
            .offset(x: swipeOffset)
            .contentShape(.rect)
            .simultaneousGesture(swipeGesture)
        }
        .contextMenu {
            Button { onEditEmoji() } label: {
                Label(category.emoji.isEmpty ? "Emoji hinzufügen" : "Emoji ändern", systemImage: "face.smiling")
            }
            Button { startEditing() } label: {
                Label("Umbenennen", systemImage: "pencil")
            }
            Button { onReorder() } label: {
                Label("Kategorien ordnen", systemImage: "arrow.up.arrow.down")
            }
            Button(role: .destructive) { onDelete() } label: {
                Label("Kategorie löschen", systemImage: "trash")
            }
        }
        .accessibilityAction(named: "Kategorie löschen") { onDelete() }
    }

    private var emojiButton: some View {
        Button(action: onEditEmoji) {
            if category.emoji.isEmpty {
                Image(systemName: "face.smiling")
                    .foregroundStyle(.tertiary)
            } else {
                Text(category.emoji)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(category.emoji.isEmpty ? "Emoji hinzufügen" : "Emoji ändern")
    }

    @ViewBuilder
    private var nameView: some View {
        if isEditingName {
            TextField("Name der Kategorie", text: $draftName)
                .focused($nameFocused)
                .submitLabel(.done)
                .onSubmit { commitName() }
                .onChange(of: nameFocused) { _, focused in
                    if !focused { commitName() }
                }
        } else {
            Text("\(category.name.isEmpty ? "Ohne Namen" : category.name) (\(count))")
                .lineLimit(1)
                .contentShape(.rect)
                .onTapGesture { startEditing() }
                .accessibilityAddTraits(.isButton)
                .accessibilityHint("Zum Umbenennen tippen")
        }
    }

    private var toggleButton: some View {
        Button {
            withAnimation(Theme.Motion.check) { isExpanded.toggle() }
        } label: {
            HStack(spacing: Theme.Spacing.s) {
                if !isExpanded, let percent {
                    Text("\(percent) %")
                        .monospacedDigit()
                        .transition(.opacity)
                }
                Image(systemName: "chevron.right")
                    .rotationEffect(.degrees(isExpanded ? 90 : 0))
            }
            .frame(minHeight: Theme.Check.hitArea)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityText)
        .accessibilityHint(isExpanded ? "Einklappen" : "Ausklappen")
    }

    private var accessibilityText: String {
        var parts = [category.displayName, "\(count)"]
        if let percent { parts.append("\(percent) Prozent erledigt") }
        return parts.joined(separator: ", ")
    }

    private var swipeGesture: some Gesture {
        DragGesture(minimumDistance: 15)
            .onChanged { value in
                guard abs(value.translation.width) > abs(value.translation.height) else { return }
                let start: CGFloat = swipeOffset <= -Theme.Category.deleteWidth ? -Theme.Category.deleteWidth : 0
                swipeOffset = min(0, max(-Theme.Category.deleteWidth * 1.2, start + value.translation.width))
            }
            .onEnded { value in
                withAnimation(Theme.Motion.check) {
                    let isOpen = value.translation.width < -Theme.Category.swipeThreshold
                        || (swipeOffset < -Theme.Category.deleteWidth / 2 && value.translation.width <= 0)
                    swipeOffset = isOpen ? -Theme.Category.deleteWidth : 0
                }
            }
    }

    private func startEditing() {
        draftName = category.name
        isEditingName = true
        Task {
            try? await Task.sleep(for: .milliseconds(50))
            nameFocused = true
        }
    }

    private func commitName() {
        guard isEditingName else { return }
        let trimmed = draftName.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty, trimmed != category.name {
            category.name = trimmed
            try? context.save()
        }
        isEditingName = false
    }
}

// MARK: - Dialoge rund um Kategorien

/// Offene Dialoge einer Übersicht (Emoji wählen, Löschen bestätigen, Kategorien ordnen).
struct CategoryUIState {
    var emojiFor: ListCategory?
    var deleting: ListCategory?
    var showOrder = false
}

private struct CategoryDialogsModifier: ViewModifier {
    @Binding var state: CategoryUIState

    @Environment(\.modelContext) private var context
    @Environment(AppSettings.self) private var settings

    func body(content: Content) -> some View {
        content
            .sheet(item: $state.emojiFor) { category in
                NavigationStack {
                    CategoryEmojiView(category: category)
                }
            }
            .sheet(isPresented: $state.showOrder) {
                NavigationStack {
                    CategoryOrderView()
                }
            }
            .confirmationDialog(
                "Kategorie löschen?",
                isPresented: Binding(
                    get: { state.deleting != nil },
                    set: { if !$0 { state.deleting = nil } }
                ),
                titleVisibility: .visible,
                presenting: state.deleting
            ) { category in
                Button("„\(category.name)“ löschen", role: .destructive) {
                    settings.setCollapsed(false, for: category.id)
                    withAnimation(Theme.Motion.check) { context.deleteCategory(category) }
                    try? context.save()
                }
                Button("Abbrechen", role: .cancel) {}
            } message: { _ in
                Text("Die Routinen und Listen darin bleiben erhalten und sind danach ohne Kategorie.")
            }
    }
}

private struct NewCategoryAlertModifier: ViewModifier {
    @Binding var isPresented: Bool
    var onCreate: ((ListCategory) -> Void)?

    @Environment(\.modelContext) private var context
    @State private var name = ""

    func body(content: Content) -> some View {
        content
            .alert("Neue Kategorie", isPresented: $isPresented) {
                TextField("Name, z. B. Workout", text: $name)
                Button("Abbrechen", role: .cancel) { name = "" }
                Button("Anlegen") { create() }
            } message: {
                Text("Ein Emoji kannst du danach über die Überschrift hinzufügen.")
            }
    }

    private func create() {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        name = ""
        guard !trimmed.isEmpty else { return }
        let category = context.addCategory(trimmed)
        try? context.save()
        onCreate?(category)
    }
}

extension View {
    func categoryDialogs(_ state: Binding<CategoryUIState>) -> some View {
        modifier(CategoryDialogsModifier(state: state))
    }

    /// Fragt nach dem Namen und legt eine neue Kategorie am Ende an.
    func newCategoryAlert(isPresented: Binding<Bool>, onCreate: ((ListCategory) -> Void)? = nil) -> some View {
        modifier(NewCategoryAlertModifier(isPresented: isPresented, onCreate: onCreate))
    }
}

extension AppSettings {
    /// Aufgeklappt-Zustand einer Kategorie als Binding (wird gespeichert).
    func expandedBinding(for category: ListCategory) -> Binding<Bool> {
        Binding(
            get: { !self.isCollapsed(category.id) },
            set: { self.setCollapsed(!$0, for: category.id) }
        )
    }
}

// MARK: - Emoji wählen

struct CategoryEmojiView: View {
    @Bindable var category: ListCategory

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @State private var customEmoji = ""

    var body: some View {
        Form {
            Section {
                TextField("Eigenes Emoji eingeben", text: $customEmoji)
                    .onChange(of: customEmoji) { _, newValue in
                        if let emoji = EmojiInput.lastEmoji(in: newValue) {
                            category.emoji = emoji
                            customEmoji = ""
                        }
                    }
                EmojiGrid(selection: $category.emoji)
            }
            if !category.emoji.isEmpty {
                Section {
                    Button("Kein Emoji", role: .destructive) {
                        category.emoji = ""
                    }
                }
            }
        }
        .formStyle(.grouped)
        .navigationTitle(category.name)
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Fertig") {
                    try? context.save()
                    dismiss()
                }
            }
        }
    }
}

// MARK: - Kategorien ordnen

/// Alle Kategorien zum Umsortieren per Ziehen (und Löschen per Wischen).
struct CategoryOrderView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Environment(AppSettings.self) private var settings
    @Query(sort: \ListCategory.sortOrder) private var categories: [ListCategory]

    var body: some View {
        List {
            Section {
                ForEach(categories) { category in
                    Text(category.displayName)
                }
                .onMove(perform: move)
                .onDelete(perform: delete)
            } footer: {
                Text("Beim Löschen bleiben die Routinen und Listen erhalten und sind danach ohne Kategorie.")
            }
        }
        .overlay {
            if categories.isEmpty {
                ContentUnavailableView("Noch keine Kategorien", systemImage: "folder")
            }
        }
        .navigationTitle("Kategorien ordnen")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        .environment(\.editMode, .constant(.active))
        #endif
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Fertig") { dismiss() }
            }
        }
    }

    private func move(from source: IndexSet, to destination: Int) {
        var reordered = categories
        reordered.move(fromOffsets: source, toOffset: destination)
        for (index, category) in reordered.enumerated() {
            category.sortOrder = index
        }
        try? context.save()
    }

    private func delete(at offsets: IndexSet) {
        for index in offsets {
            let category = categories[index]
            settings.setCollapsed(false, for: category.id)
            context.deleteCategory(category)
        }
        try? context.save()
    }
}
