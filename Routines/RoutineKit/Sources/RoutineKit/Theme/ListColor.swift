import SwiftUI
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

/// Eine Listenfarbe. Gespeichert wird nur `rawValue` (in `RoutineList.colorRaw`).
/// Alle verfügbaren Farben stehen in `ColorPalette.groups`.
public struct ListColor: Identifiable, Hashable, Sendable {
    /// Stabiler Schlüssel, wird in der Datenbank gespeichert. Nie ändern, sonst verlieren Listen ihre Farbe.
    public let rawValue: String
    /// Name für VoiceOver
    public let displayName: String
    /// Passt sich bei Bedarf an Hell/Dunkel an.
    public let color: Color

    public var id: String { rawValue }

    /// Farbe aus der Palette, `nil` wenn unbekannt.
    public init?(rawValue: String) {
        guard let match = ColorPalette.lookup[rawValue] else { return nil }
        self = match
    }

    init(_ rawValue: String, _ displayName: String, _ color: Color) {
        self.rawValue = rawValue
        self.displayName = displayName
        self.color = color
    }

    /// Farbe aus Hex-Werten, optional mit eigener Variante für den Dark Mode.
    init(_ rawValue: String, _ displayName: String, hex: UInt32, darkHex: UInt32? = nil) {
        self.init(rawValue, displayName, Color.dynamic(light: hex, dark: darkHex ?? hex))
    }

    public static func == (lhs: ListColor, rhs: ListColor) -> Bool { lhs.rawValue == rhs.rawValue }
    public func hash(into hasher: inout Hasher) { hasher.combine(rawValue) }

    /// Alle Farben aller Gruppen.
    public static var allCases: [ListColor] { ColorPalette.groups.flatMap(\.colors) }

    // Apple-Systemfarben (haben eigene Dark-Mode-Varianten von Apple)
    public static let red = ListColor("red", "Rot", .red)
    public static let orange = ListColor("orange", "Orange", .orange)
    public static let yellow = ListColor("yellow", "Gelb", .yellow)
    public static let green = ListColor("green", "Grün", .green)
    public static let mint = ListColor("mint", "Mint", .mint)
    public static let teal = ListColor("teal", "Türkis", .teal)
    public static let cyan = ListColor("cyan", "Cyan", .cyan)
    public static let blue = ListColor("blue", "Blau", .blue)
    public static let indigo = ListColor("indigo", "Indigo", .indigo)
    public static let purple = ListColor("purple", "Lila", .purple)
    public static let pink = ListColor("pink", "Pink", .pink)
    public static let brown = ListColor("brown", "Braun", .brown)
    public static let gray = ListColor("gray", "Grau", .gray)
}

/// Eine Farbgruppe, in der Auswahl als eigene Reihe(n) mit Trennstrich dazwischen.
public struct ColorGroup: Identifiable, Sendable {
    public let id: String
    public let name: String
    public let colors: [ListColor]
}

/// Alle Farbpaletten. Hier werden Gruppen und Farben gepflegt (experimentell, wird noch feinjustiert).
/// `darkHex` nur für Farben, die im Dark Mode sonst kaum sichtbar wären:
/// gleicher Farbton und gleiche Buntheit, nur heller (berechnet in OKLCH).
public enum ColorPalette {
    public static let groups: [ColorGroup] = [
        ColorGroup(id: "apple", name: "Apple", colors: [
            .red, .orange, .yellow, .green, .mint, .teal, .cyan,
            .blue, .indigo, .purple, .pink, .brown, .gray
        ]),
        ColorGroup(id: "chocolate", name: "Schokolade", colors: [
            ListColor("arsenic", "Arsenic", hex: 0x354242),
            ListColor("morningBlue", "Morning Blue", hex: 0x8B9B93),
            ListColor("americanSilver", "American Silver", hex: 0xCFCFCD),
            ListColor("liverChestnut", "Liver Chestnut", hex: 0x55453A),
            ListColor("bistre", "Bistre", hex: 0x362419, darkHex: 0x8B7568)
        ]),
        ColorGroup(id: "denim", name: "Denim", colors: [
            ListColor("silverChalice", "Silver Chalice", hex: 0xB5ACA3),
            ListColor("paleCornflowerBlue", "Pale Cornflower Blue", hex: 0xB0D2EC),
            ListColor("pewterBlue", "Pewter Blue", hex: 0x849DBB),
            ListColor("silverLakeBlue", "Silver Lake Blue", hex: 0x648EC0),
            ListColor("royalBrown", "Royal Brown", hex: 0x533A33)
        ]),
        ColorGroup(id: "forest", name: "Waldgrün", colors: [
            ListColor("corkWedge", "Cork Wedge", hex: 0xC0A889),
            ListColor("cheekyChestnut", "Cheeky Chestnut", hex: 0x7A4E39),
            ListColor("greenBeret", "Green Beret", hex: 0x536D5F),
            ListColor("roycroftBottleGreen", "Roycroft Bottle Green", hex: 0x363F37),
            ListColor("quartzite", "Quartzite", hex: 0x1F2B27, darkHex: 0x707E79)
        ]),
        ColorGroup(id: "autumnLeaves", name: "Herbstlaub", colors: [
            ListColor("spaceCadet", "Space Cadet", hex: 0x25344F),
            ListColor("slateGray", "Slate Gray", hex: 0x617891),
            ListColor("tan", "Tan", hex: 0xD5B893),
            ListColor("coffee", "Coffee", hex: 0x6F4D38),
            ListColor("caputMortuum", "Caput Mortuum", hex: 0x632024)
        ]),
        ColorGroup(id: "bordeaux", name: "Bordeaux", colors: [
            ListColor("camelCoat", "Camel Coat", hex: 0xC6B39A),
            ListColor("boho", "Boho", hex: 0x7B694E),
            ListColor("rubine", "Rubine", hex: 0x6D3A3C),
            ListColor("tamarind", "Tamarind", hex: 0x361319),
            ListColor("italianRoast", "Italian Roast", hex: 0x280B0F, darkHex: 0x866063)
        ])
    ]

    static let lookup: [String: ListColor] = Dictionary(
        groups.flatMap(\.colors).map { ($0.rawValue, $0) },
        uniquingKeysWith: { first, _ in first }
    )
}

extension Color {
    /// Farbe mit getrennten Werten für Hell und Dunkel (0xRRGGBB).
    static func dynamic(light: UInt32, dark: UInt32) -> Color {
        #if canImport(UIKit)
        return Color(uiColor: UIColor { traits in
            UIColor(rgb: traits.userInterfaceStyle == .dark ? dark : light)
        })
        #elseif canImport(AppKit)
        return Color(nsColor: NSColor(name: nil) { appearance in
            let isDark = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            return NSColor(rgb: isDark ? dark : light)
        })
        #else
        return Color(rgb: light)
        #endif
    }

    init(rgb: UInt32) {
        self.init(
            red: Double((rgb >> 16) & 0xFF) / 255,
            green: Double((rgb >> 8) & 0xFF) / 255,
            blue: Double(rgb & 0xFF) / 255
        )
    }
}

#if canImport(UIKit)
extension UIColor {
    convenience init(rgb: UInt32) {
        self.init(
            red: CGFloat((rgb >> 16) & 0xFF) / 255,
            green: CGFloat((rgb >> 8) & 0xFF) / 255,
            blue: CGFloat(rgb & 0xFF) / 255,
            alpha: 1
        )
    }
}
#elseif canImport(AppKit)
extension NSColor {
    convenience init(rgb: UInt32) {
        self.init(
            srgbRed: CGFloat((rgb >> 16) & 0xFF) / 255,
            green: CGFloat((rgb >> 8) & 0xFF) / 255,
            blue: CGFloat(rgb & 0xFF) / 255,
            alpha: 1
        )
    }
}
#endif
