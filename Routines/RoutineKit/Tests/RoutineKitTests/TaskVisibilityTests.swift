import Foundation
import Testing
@testable import RoutineKit

@Suite("Sichtbarkeit von To-dos")
struct TaskVisibilityTests {
    let today = Period(start: date(2026, 10, 21, 0), end: date(2026, 10, 22, 0), key: key(2026, 10, 21))
    let lastWeek = Period(start: date(2026, 10, 14, 0), end: date(2026, 10, 15, 0), key: key(2026, 10, 14))

    @Test func regularTaskIsVisible() {
        #expect(TaskVisibility.isVisible(deletedAt: nil, oneOffPeriodKey: nil, isSkipped: false, in: today))
    }

    @Test func skippedTaskIsHidden() {
        #expect(!TaskVisibility.isVisible(deletedAt: nil, oneOffPeriodKey: nil, isSkipped: true, in: today))
    }

    @Test func oneOffTaskOnlyInItsPeriod() {
        #expect(TaskVisibility.isVisible(deletedAt: nil, oneOffPeriodKey: today.key, isSkipped: false, in: today))
        #expect(!TaskVisibility.isVisible(deletedAt: nil, oneOffPeriodKey: lastWeek.key, isSkipped: false, in: today))
    }

    @Test func deletedTaskHiddenFromDeletionOnButKeptInHistory() {
        let deletedAt = date(2026, 10, 21, 9)
        #expect(!TaskVisibility.isVisible(deletedAt: deletedAt, oneOffPeriodKey: nil, isSkipped: false, in: today))
        #expect(TaskVisibility.isVisible(deletedAt: deletedAt, oneOffPeriodKey: nil, isSkipped: false, in: lastWeek))
    }

    @Test func deletedTaskInListWithoutRepetitionIsHidden() {
        let open = Period(start: date(2026, 10, 1, 0), end: nil, key: key(2026, 10, 1))
        #expect(!TaskVisibility.isVisible(deletedAt: date(2026, 10, 5), oneOffPeriodKey: nil, isSkipped: false, in: open))
    }
}

@Suite("Emoji-Eingabe")
struct EmojiInputTests {
    @Test func picksLastEmoji() {
        #expect(EmojiInput.lastEmoji(in: "abc☀️") == "☀️")
        #expect(EmojiInput.lastEmoji(in: "🌙x🏃") == "🏃")
    }

    @Test func ignoresPlainText() {
        #expect(EmojiInput.lastEmoji(in: "123 abc") == nil)
    }

    @Test func supportsComposedEmoji() {
        #expect(EmojiInput.lastEmoji(in: "🇪🇸") == "🇪🇸")
        #expect(EmojiInput.lastEmoji(in: "👍🏽") == "👍🏽")
    }
}
