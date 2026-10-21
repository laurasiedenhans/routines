import SwiftUI

/// Zentrale Stilwerte der App. Views verwenden nie hart codierte Werte, sondern immer `Theme`.
/// Hier kann das Design später an einer Stelle angepasst werden.
public enum Theme {

    public enum Spacing {
        public static var xxs: CGFloat { 2 }
        public static var xs: CGFloat { 4 }
        public static var s: CGFloat { 8 }
        public static var m: CGFloat { 12 }
        public static var l: CGFloat { 18 }
        public static var xl: CGFloat { 24 }
    }

    public enum Radius {
        /// Tageskarte (Liquid Glass)
        public static var card: CGFloat { 26 }
        public static var swatch: CGFloat { 10 }
    }

    public enum Ring {
        public static var diameter: CGFloat { 92 }
        public static var lineWidth: CGFloat { 11 }
        /// Linienstärke bei „Ringe ineinander“
        public static var nestedLineWidth: CGFloat { 10 }
        /// Abstand zwischen den Ringen bei „Ringe ineinander“
        public static var nestedSpacing: CGFloat { 2.5 }
        /// Lücke zwischen Segmenten (in Punkt, zusätzlich zu den runden Enden)
        public static var segmentGap: CGFloat { 4 }
        public static var trackOpacity: Double { 0.22 }
        public static var accent: Color { .accentColor }
        public static var emptyTrack: Color { .secondary }
        public static var labelFont: Font { .system(size: 20, weight: .bold, design: .rounded) }
    }

    public enum Bar {
        public static var height: CGFloat { 6 }
        public static var trackOpacity: Double { 0.2 }
    }

    /// Navigationsleiste unten (iPhone)
    public enum TabBar {
        /// Abstand der Glass-Container zum Bildschirmrand
        public static var edgePadding: CGFloat { 20 }
        public static var bottomPadding: CGFloat { 4 }
        public static var itemMinWidth: CGFloat { 68 }
        public static var itemHeight: CGFloat { 52 }
        /// Innenabstand der Gruppe um die Buttons
        public static var groupPadding: CGFloat { 4 }
        /// Durchmesser des „+“-Buttons (= Höhe der Gruppe)
        public static var addButtonSize: CGFloat { 60 }
        public static var iconSize: CGFloat { 19 }
        public static var selectionOpacity: Double { 0.1 }
    }

    public enum Check {
        public static var size: CGFloat { 24 }
        public static var hitArea: CGFloat { 44 }
    }

    public enum Icon {
        /// Emoji-Kreis in Listenzeilen
        public static var size: CGFloat { 36 }
        public static var smallSize: CGFloat { 28 }
        /// Vorschau in den Listen-Einstellungen
        public static var largeSize: CGFloat { 64 }
        public static var swatchSize: CGFloat { 32 }
    }

    public enum Motion {
        public static var check: Animation { .snappy(duration: 0.3) }
        public static var ring: Animation { .smooth(duration: 0.5) }
    }
}
