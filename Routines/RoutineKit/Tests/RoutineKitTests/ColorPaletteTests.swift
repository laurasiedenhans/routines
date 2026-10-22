import Foundation
import Testing
@testable import RoutineKit

@Suite("Farbpalette")
struct ColorPaletteTests {

    @Test func rawValuesAreUnique() {
        let keys = ListColor.allCases.map(\.rawValue)
        #expect(Set(keys).count == keys.count)
    }

    @Test func existingAppleColorsStillResolve() {
        // Bereits gespeicherte Listen dürfen ihre Farbe nicht verlieren.
        for key in ["red", "orange", "yellow", "green", "mint", "teal", "cyan",
                    "blue", "indigo", "purple", "pink", "brown", "gray"] {
            #expect(ListColor(rawValue: key)?.rawValue == key)
        }
    }

    @Test func unknownColorReturnsNil() {
        #expect(ListColor(rawValue: "doesNotExist") == nil)
    }

    @Test func groups() {
        #expect(ColorPalette.groups.first?.id == "apple")
        #expect(ColorPalette.groups.count == 6)
        #expect(ListColor.allCases.count == 38)
    }
}
