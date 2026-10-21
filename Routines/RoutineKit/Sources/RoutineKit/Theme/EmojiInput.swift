import Foundation

/// Hilfen für die Emoji-Eingabe (SwiftUI hat keinen nativen Emoji-Picker).
public enum EmojiInput {

    /// Das letzte Emoji in einem Text, z. B. aus einem Textfeld.
    public static func lastEmoji(in text: String) -> String? {
        text.reversed().first(where: isEmoji).map { String($0) }
    }

    public static func isEmoji(_ character: Character) -> Bool {
        guard let first = character.unicodeScalars.first else { return false }
        let properties = first.properties
        if properties.isEmojiPresentation { return true }
        // z. B. „☀️“ (Symbol + Variation Selector) oder Ziffern-Emoji „1️⃣“
        return properties.isEmoji && character.unicodeScalars.count > 1
    }

    /// Vorschläge für das Emoji-Raster in den Listen-Einstellungen.
    public static let suggestions: [String] = [
        "☀️", "🌙", "⭐️", "✅", "📋", "🗓️",
        "🏃", "🧘", "💪", "🚴", "🏊", "🥗",
        "💊", "💧", "🦷", "🛏️", "📖", "✍️",
        "🧺", "🧹", "🪴", "🐶", "🛒", "🍳",
        "💼", "💻", "💳", "📊", "📦", "🎓",
        "🎵", "🎨", "❤️", "🙏", "🌿", "🧠"
    ]
}
