import SwiftUI
import RoutineKit

/// Prozentanzeige in der Mitte eines Rings.
struct PercentLabel: View {
    let fraction: Double

    var body: some View {
        Text(fraction, format: .percent.precision(.fractionLength(0)))
            .font(Theme.Ring.labelFont)
            .monospacedDigit()
            .lineLimit(1)
            .minimumScaleFactor(0.6)
            .contentTransition(.numericText(value: fraction))
    }
}

/// D · ein Ring in einer Farbe. Wird auch für die einzelnen Ringe von „Ringe ineinander“ genutzt.
struct SimpleRing: View {
    var fraction: Double
    /// `nil` = Akzentfarbe der App (aus den Einstellungen)
    var color: Color? = nil
    var lineWidth: CGFloat = Theme.Ring.lineWidth
    var showsLabel = true

    private var style: AnyShapeStyle {
        if let color { AnyShapeStyle(color) } else { AnyShapeStyle(.tint) }
    }

    var body: some View {
        ZStack {
            Circle()
                .stroke(style.opacity(Theme.Ring.trackOpacity), lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: fraction)
                .stroke(style, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
                // Runde Enden würden bei 0 % einen Punkt zeichnen.
                .opacity(fraction > 0 ? 1 : 0)
            if showsLabel {
                PercentLabel(fraction: fraction)
                    .padding(lineWidth)
            }
        }
        .padding(lineWidth / 2)
        .animation(Theme.Motion.ring, value: fraction)
    }
}

/// E · ein Segment pro Liste in ihrer Farbe, Länge nach Anzahl To-dos, runde Enden.
struct SegmentedRing: View {
    let items: [DayRingItem]
    var diameter: CGFloat = Theme.Ring.diameter
    var lineWidth: CGFloat = Theme.Ring.lineWidth
    var gap: CGFloat = Theme.Ring.segmentGap

    private struct Segment: Identifiable {
        let id: UUID
        let color: Color
        let from: Double
        let trackTo: Double
        let fillTo: Double
        let hasProgress: Bool
    }

    private var fraction: Double {
        let total = items.reduce(0) { $0 + $1.total }
        let done = items.reduce(0) { $0 + $1.done }
        return total == 0 ? 0 : Double(done) / Double(total)
    }

    private var segments: [Segment] {
        let total = Double(items.reduce(0) { $0 + $1.total })
        guard total > 0 else { return [] }

        if items.count == 1, let item = items.first {
            return [Segment(id: item.id, color: item.color.color, from: 0, trackTo: 1,
                            fillTo: item.fraction, hasProgress: item.done > 0)]
        }

        // Runde Enden ragen um lineWidth/2 über das Segment hinaus: entsprechend einrücken.
        let circumference = Double.pi * Double(diameter - lineWidth)
        let inset = (Double(gap) + Double(lineWidth)) / circumference / 2
        var cursor = 0.0
        return items.map { item in
            let share = Double(item.total) / total
            let start = cursor + inset
            let end = max(cursor + share - inset, start + 0.001)
            cursor += share
            return Segment(id: item.id, color: item.color.color, from: start, trackTo: end,
                           fillTo: start + (end - start) * item.fraction, hasProgress: item.done > 0)
        }
    }

    var body: some View {
        ZStack {
            if items.isEmpty {
                Circle().stroke(Theme.Ring.emptyTrack.opacity(Theme.Ring.trackOpacity), lineWidth: lineWidth)
            }
            ForEach(segments) { segment in
                Circle()
                    .trim(from: segment.from, to: segment.trackTo)
                    .stroke(segment.color.opacity(Theme.Ring.trackOpacity),
                            style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                Circle()
                    .trim(from: segment.from, to: segment.fillTo)
                    .stroke(segment.color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .opacity(segment.hasProgress ? 1 : 0)
            }
            PercentLabel(fraction: fraction)
                .padding(lineWidth)
        }
        .padding(lineWidth / 2)
        .animation(Theme.Motion.ring, value: items)
    }
}

/// F · Ringe ineinander wie die Bewegungsringe. Max. 3, immer so weit außen wie möglich.
struct NestedRings: View {
    let items: [DayRingItem]
    var lineWidth: CGFloat = Theme.Ring.nestedLineWidth
    var spacing: CGFloat = Theme.Ring.nestedSpacing

    var body: some View {
        ZStack {
            if items.isEmpty {
                SimpleRing(fraction: 0, color: Theme.Ring.emptyTrack, lineWidth: lineWidth, showsLabel: false)
            }
            ForEach(Array(items.prefix(3).enumerated()), id: \.element.id) { index, item in
                SimpleRing(fraction: item.fraction, color: item.color.color, lineWidth: lineWidth, showsLabel: false)
                    .padding(CGFloat(index) * (lineWidth + spacing))
            }
        }
    }
}

#Preview("Ringe") {
    let items = [
        DayRingItem(id: UUID(), name: "Morgen", emoji: "☀️", color: .orange, done: 3, total: 4, startTimeMinutes: 390),
        DayRingItem(id: UUID(), name: "Abend", emoji: "🌙", color: .indigo, done: 1, total: 3, startTimeMinutes: 1290),
        DayRingItem(id: UUID(), name: "Training", emoji: "🏃", color: .red, done: 0, total: 2, startTimeMinutes: nil)
    ]
    HStack(spacing: Theme.Spacing.xl) {
        SimpleRing(fraction: 4.0 / 9.0)
        SegmentedRing(items: items)
        NestedRings(items: items)
    }
    .frame(height: Theme.Ring.diameter)
    .padding()
}
