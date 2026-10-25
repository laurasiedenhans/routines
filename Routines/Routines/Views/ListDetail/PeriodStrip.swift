import SwiftUI
import RoutineKit

/// Markierung unter einem Zeitraum in der Leiste.
enum PeriodDot {
    case none
    /// Vergangen, alles erledigt
    case complete
    /// Vergangen, etwas offen geblieben
    case incomplete
    /// Zukünftig, einmalige Aufgabe eingeplant
    case planned

    var color: Color {
        switch self {
        case .none: .clear
        case .complete: .green
        case .incomplete: .gray.opacity(0.5)
        case .planned: .orange
        }
    }

    var accessibilityText: String? {
        switch self {
        case .none: nil
        case .complete: "alles erledigt"
        case .incomplete: "unvollständig"
        case .planned: "Aufgabe eingeplant"
        }
    }
}

/// Ein Kästchen der Leiste.
struct PeriodStripItem: Identifiable {
    let index: Int
    let top: String
    let main: String
    let accessibilityLabel: String
    let dot: PeriodDot
    var id: Int { index }
}

/// Zeitraum-Leiste: 7 Tage/Wochen bzw. 5 Monate/Jahre zum Antippen,
/// seitliches Wischen blättert eine ganze Leiste weiter.
struct PeriodStrip: View {
    /// `nil` = Platzhalter vor dem ersten Zeitraum der Liste
    let items: [PeriodStripItem?]
    let selectedIndex: Int
    let currentIndex: Int?
    let color: Color
    let onSelect: (Int) -> Void
    /// -1 = zurück, +1 = vor
    let onPage: (Int) -> Void

    var body: some View {
        HStack(spacing: Theme.Strip.chipSpacing) {
            ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                if let item {
                    chip(item)
                } else {
                    Color.clear
                        .frame(maxWidth: .infinity, minHeight: Theme.Strip.chipHeight)
                        .accessibilityHidden(true)
                }
            }
        }
        .contentShape(.rect)
        // simultan, damit die Liste weiterhin vertikal scrollt
        .simultaneousGesture(
            DragGesture(minimumDistance: 20).onEnded { value in
                guard abs(value.translation.width) > abs(value.translation.height) else { return }
                if value.translation.width < -Theme.Strip.swipeThreshold {
                    onPage(1)
                } else if value.translation.width > Theme.Strip.swipeThreshold {
                    onPage(-1)
                }
            }
        )
        .accessibilityElement(children: .contain)
        .accessibilityAction(named: "Zurückblättern") { onPage(-1) }
        .accessibilityAction(named: "Weiterblättern") { onPage(1) }
    }

    private func chip(_ item: PeriodStripItem) -> some View {
        let isSelected = item.index == selectedIndex
        let isCurrent = item.index == currentIndex
        return Button {
            onSelect(item.index)
        } label: {
            VStack(spacing: 3) {
                Text(item.top)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(isSelected ? Color.white : Color.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Text(item.main)
                    .font(.system(size: 17, weight: isSelected ? .bold : .semibold))
                    .foregroundStyle(isSelected ? Color.white : (isCurrent ? color : Color.primary))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Circle()
                    .fill(isSelected ? Color.clear : item.dot.color)
                    .frame(width: Theme.Strip.dotSize, height: Theme.Strip.dotSize)
            }
            .frame(maxWidth: .infinity, minHeight: Theme.Strip.chipHeight)
            .background {
                RoundedRectangle(cornerRadius: Theme.Strip.chipRadius)
                    .fill(isSelected ? color : (isCurrent ? color.opacity(Theme.Strip.currentOpacity) : Color.clear))
            }
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityLabel([item.accessibilityLabel, item.dot.accessibilityText].compactMap { $0 }.joined(separator: ", "))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
