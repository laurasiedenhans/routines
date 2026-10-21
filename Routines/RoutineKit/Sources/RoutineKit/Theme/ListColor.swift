import SwiftUI

/// Farbpalette für Listen, angelehnt an die Erinnerungen-App.
/// Nutzt Apple-Systemfarben, die sich automatisch an Hell/Dunkel anpassen.
public enum ListColor: String, CaseIterable, Identifiable, Codable, Sendable {
    case red, orange, yellow, green, mint, teal, cyan, blue, indigo, purple, pink, brown, gray

    public var id: String { rawValue }

    public var color: Color {
        switch self {
        case .red: .red
        case .orange: .orange
        case .yellow: .yellow
        case .green: .green
        case .mint: .mint
        case .teal: .teal
        case .cyan: .cyan
        case .blue: .blue
        case .indigo: .indigo
        case .purple: .purple
        case .pink: .pink
        case .brown: .brown
        case .gray: .gray
        }
    }

    public var displayName: String {
        switch self {
        case .red: "Rot"
        case .orange: "Orange"
        case .yellow: "Gelb"
        case .green: "Grün"
        case .mint: "Mint"
        case .teal: "Türkis"
        case .cyan: "Cyan"
        case .blue: "Blau"
        case .indigo: "Indigo"
        case .purple: "Lila"
        case .pink: "Pink"
        case .brown: "Braun"
        case .gray: "Grau"
        }
    }
}
