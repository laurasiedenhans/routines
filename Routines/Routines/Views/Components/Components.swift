import SwiftUI
import RoutineKit

/// Emoji in einem Kreis in der Listenfarbe.
struct ListIcon: View {
    let emoji: String
    let color: Color
    var size: CGFloat = Theme.Icon.size

    var body: some View {
        Text(emoji)
            .font(.system(size: size * 0.5))
            .frame(width: size, height: size)
            .background(color, in: Circle())
            .accessibilityHidden(true)
    }
}

/// Fortschrittsbalken einer Liste.
struct ListProgressBar: View {
    let fraction: Double
    let color: Color

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(color.opacity(Theme.Bar.trackOpacity))
                Capsule()
                    .fill(color)
                    .frame(width: proxy.size.width * fraction)
                    .opacity(fraction > 0 ? 1 : 0)
            }
        }
        .frame(height: Theme.Bar.height)
        .animation(Theme.Motion.ring, value: fraction)
        .accessibilityElement()
        .accessibilityLabel("Fortschritt")
        .accessibilityValue(Text(fraction, format: .percent.precision(.fractionLength(0))))
    }
}

/// Runder Toggle rechts in einer To-do-Zeile. Ausgefüllt = erledigt.
struct CheckToggle: View {
    let isOn: Bool
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: isOn ? "checkmark.circle.fill" : "circle")
                .font(.system(size: Theme.Check.size))
                .foregroundStyle(isOn ? color : Color.secondary)
                .contentTransition(.symbolEffect(.replace))
                .frame(width: Theme.Check.hitArea, height: Theme.Check.hitArea)
                .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .sensoryFeedback(.success, trigger: isOn) { _, newValue in newValue }
        .accessibilityLabel(isOn ? "Als offen markieren" : "Als erledigt markieren")
    }
}

#Preview {
    VStack(spacing: Theme.Spacing.l) {
        ListIcon(emoji: "☀️", color: .orange)
        ListProgressBar(fraction: 0.6, color: .orange)
        HStack {
            CheckToggle(isOn: false, color: .orange) {}
            CheckToggle(isOn: true, color: .orange) {}
        }
    }
    .padding()
}
