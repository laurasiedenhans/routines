#if os(iOS)
import SwiftUI
import SwiftData
import Combine
import UIKit
import RoutineKit

/// Bereiche der Navigationsleiste (iPhone).
enum AppSection: String, CaseIterable, Identifiable {
    case today
    case routines
    case lists

    var id: String { rawValue }

    var title: String {
        switch self {
        case .today: "Heute"
        case .routines: "Routinen"
        case .lists: "Listen"
        }
    }

    /// Platzhalter-Symbole, später austauschbar.
    var systemImage: String {
        switch self {
        case .today: "sun.max"
        case .routines: "arrow.triangle.2.circlepath"
        case .lists: "checklist"
        }
    }

    /// Was das „+“ in diesem Bereich anlegt.
    var newKind: ListKind {
        switch self {
        case .today, .routines: .routine
        case .lists: .list
        }
    }
}

/// iPhone: drei Bereiche mit Navigationsleiste unten. Standard ist „Heute“.
struct PhoneRootView: View {
    @Environment(AppSettings.self) private var settings
    @Query(sort: \RoutineList.sortOrder) private var lists: [RoutineList]
    @State private var section: AppSection = .today
    @State private var creating: ListKind?
    @State private var isKeyboardVisible = false

    var body: some View {
        Group {
            switch section {
            case .today:
                SectionStack { DashboardView() }
            case .routines:
                SectionStack { CollectionView(kind: .routine) }
            case .lists:
                SectionStack { CollectionView(kind: .list) }
            }
        }
        // Inhalte laufen unter der Leiste durch, lassen sich aber bis über die Leiste scrollen.
        .contentMargins(.bottom, Theme.TabBar.contentClearance, for: .scrollContent)
        .overlay(alignment: .bottom) {
            // Beim Tippen ausblenden, sonst schwebt die Leiste über der Tastatur.
            if !isKeyboardVisible {
                BottomBar(section: $section, addLabel: section.newKind.newTitle) {
                    creating = section.newKind
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .sheet(item: $creating) { kind in
            NavigationStack {
                ListSettingsView(mode: .create(kind))
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { _ in
            withAnimation(Theme.Motion.check) { isKeyboardVisible = true }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
            withAnimation(Theme.Motion.check) { isKeyboardVisible = false }
        }
        .task(id: ringCandidates) {
            settings.reconcile(candidates: ringCandidates)
        }
    }

    private var ringCandidates: [RingCandidate] {
        lists.filter(\.isRingEligible).map(\.ringCandidate)
    }
}

/// Navigationsleiste im iOS-26-Stil: links die Bereiche in einem Glass-Container,
/// rechts separat das „+“. Beide orientieren sich am Rand und wachsen zur Mitte.
struct BottomBar: View {
    @Binding var section: AppSection
    let addLabel: String
    let onAdd: () -> Void

    @Namespace private var selectionNamespace

    var body: some View {
        GlassEffectContainer(spacing: Theme.Spacing.l) {
            HStack(alignment: .center) {
                HStack(spacing: 0) {
                    ForEach(AppSection.allCases) { item in
                        tabButton(for: item)
                    }
                }
                .padding(Theme.TabBar.groupPadding)
                .glassEffect(.regular.interactive(), in: Capsule())

                Spacer(minLength: Theme.Spacing.m)

                Button(action: onAdd) {
                    Image(systemName: "plus")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(Color.accentColor)
                        .frame(width: Theme.TabBar.addButtonSize, height: Theme.TabBar.addButtonSize)
                        .contentShape(Circle())
                }
                .buttonStyle(.plain)
                .glassEffect(.regular.interactive(), in: Circle())
                .accessibilityLabel(addLabel)
            }
            .padding(.horizontal, Theme.TabBar.edgePadding)
            .padding(.bottom, Theme.TabBar.bottomPadding)
        }
    }

    private func tabButton(for item: AppSection) -> some View {
        let isSelected = section == item
        return Button {
            withAnimation(Theme.Motion.check) { section = item }
        } label: {
            VStack(spacing: 2) {
                Image(systemName: item.systemImage)
                    .font(.system(size: Theme.TabBar.iconSize, weight: .medium))
                    .frame(height: 24)
                Text(item.title)
                    .font(.caption2.weight(.semibold))
            }
            .foregroundStyle(isSelected ? Color.accentColor : Color.primary)
            .frame(minWidth: Theme.TabBar.itemMinWidth, minHeight: Theme.TabBar.itemHeight)
            .background {
                if isSelected {
                    Capsule()
                        .fill(Color.primary.opacity(Theme.TabBar.selectionOpacity))
                        .matchedGeometryEffect(id: "selection", in: selectionNamespace)
                }
            }
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(item.title)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

#Preview {
    PhoneRootView()
        .previewEnvironment()
}
#endif
