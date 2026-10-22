import Foundation
import Testing
@testable import RoutineKit

@Suite("Aufräumen abgeschlossener Listen")
struct CompletedListCleanupTests {

    @Test func neverDeletes() {
        #expect(CompletedListCleanup.deletionDate(completedAt: date(2026, 10, 1), retention: .never, calendar: .berlin) == nil)
    }

    @Test func deletionDateAddsDays() {
        let completedAt = date(2026, 10, 20, 18, 30)
        #expect(CompletedListCleanup.deletionDate(completedAt: completedAt, retention: .oneDay, calendar: .berlin) == date(2026, 10, 21, 18, 30))
        #expect(CompletedListCleanup.deletionDate(completedAt: completedAt, retention: .oneWeek, calendar: .berlin) == date(2026, 10, 27, 18, 30))
        #expect(CompletedListCleanup.deletionDate(completedAt: completedAt, retention: .oneMonth, calendar: .berlin) == date(2026, 11, 19, 18, 30))
    }

    @Test func retentionDays() {
        #expect(ListRetention.never.days == nil)
        #expect(ListRetention.threeDays.days == 3)
        #expect(ListRetention.twoWeeks.days == 14)
    }
}
