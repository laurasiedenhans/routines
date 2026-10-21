import SwiftUI
import RoutineKit

/// Tageskarte oben auf dem Startbildschirm: Ring links, Text rechts, Liquid Glass.
struct DayProgressCard: View {
    let summary: DayRingSummary
    let style: RingStyle

    var body: some View {
        HStack(spacing: Theme.Spacing.l) {
            ring
                .frame(width: Theme.Ring.diameter, height: Theme.Ring.diameter)

            VStack(alignment: .leading, spacing: Theme.Spacing.xxs) {
                HStack(alignment: .firstTextBaseline, spacing: Theme.Spacing.s) {
                    Text("Heute")
                        .font(.title3.bold())
                    if style == .nested, summary.state == .ready {
                        Text(summary.fraction, format: .percent.precision(.fractionLength(0)))
                            .font(.title3.bold())
                            .foregroundStyle(.secondary)
                            .contentTransition(.numericText(value: summary.fraction))
                    }
                }
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                if let detail {
                    Text(detail)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, Theme.Spacing.l)
        .padding(.horizontal, Theme.Spacing.l)
        .glassEffect(.regular, in: .rect(cornerRadius: Theme.Radius.card))
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private var ring: some View {
        switch style {
        case .simple:
            SimpleRing(fraction: summary.fraction)
        case .segmented:
            SegmentedRing(items: summary.items)
        case .nested:
            NestedRings(items: summary.items)
        }
    }

    private var subtitle: String {
        switch summary.state {
        case .ready: "\(summary.done) von \(summary.total) To-dos"
        case .noSelection: "Listen in den Einstellungen auswählen"
        case .nothingDue: "Heute keine Routinen fällig"
        }
    }

    private var detail: String? {
        guard summary.state == .ready else { return nil }
        guard let next = summary.nextUp else { return "Alles erledigt" }
        if let minutes = next.startTimeMinutes {
            return "Als Nächstes: \(next.name) · \(RecurrenceFormatting.startTime(minutes: minutes))"
        }
        return "Als Nächstes: \(next.name)"
    }
}

#Preview {
    let items = [
        DayRingItem(id: UUID(), name: "Morgenroutine", emoji: "☀️", color: .orange, done: 3, total: 4, startTimeMinutes: 390),
        DayRingItem(id: UUID(), name: "Abendroutine", emoji: "🌙", color: .indigo, done: 1, total: 3, startTimeMinutes: 1290)
    ]
    VStack(spacing: Theme.Spacing.l) {
        ForEach(RingStyle.allCases, id: \.self) { style in
            DayProgressCard(summary: DayRingSummary(items: items, state: .ready), style: style)
        }
        DayProgressCard(summary: DayRingSummary(items: [], state: .nothingDue), style: .segmented)
    }
    .padding()
}
