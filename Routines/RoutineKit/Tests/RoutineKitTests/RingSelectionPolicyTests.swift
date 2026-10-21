import Foundation
import Testing
@testable import RoutineKit

@Suite("Ringauswahl")
struct RingSelectionPolicyTests {
    let a = UUID(), b = UUID(), c = UUID(), d = UUID()

    @Test func initialFillPrefersDailyLists() {
        let candidates = [
            RingCandidate(id: a, interval: 1, sortOrder: 0),
            RingCandidate(id: b, interval: 2, sortOrder: 1),
            RingCandidate(id: c, interval: 1, sortOrder: 2),
            RingCandidate(id: d, interval: 1, sortOrder: 3)
        ]
        let result = RingSelectionPolicy.reconcile(selected: [], seen: [], candidates: candidates, maxLists: 3)
        #expect(result.selected == [a, c, d])
    }

    @Test func everyNDaysFillsRemainingSpace() {
        let candidates = [
            RingCandidate(id: a, interval: 1, sortOrder: 0),
            RingCandidate(id: b, interval: 2, sortOrder: 1)
        ]
        let result = RingSelectionPolicy.reconcile(selected: [], seen: [], candidates: candidates, maxLists: 3)
        #expect(result.selected == [a, b])
    }

    @Test func newDailyListDoesNotEvictSelected() {
        let candidates = [
            RingCandidate(id: a, interval: 1, sortOrder: 0),
            RingCandidate(id: b, interval: 2, sortOrder: 1),
            RingCandidate(id: c, interval: 1, sortOrder: 2)
        ]
        let result = RingSelectionPolicy.reconcile(selected: [a, b], seen: [a, b], candidates: candidates, maxLists: 2)
        #expect(result.selected == [a, b])
        #expect(result.seen.contains(c))
    }

    @Test func manuallyDeselectedListIsNotReAdded() {
        let candidates = [
            RingCandidate(id: a, interval: 1, sortOrder: 0),
            RingCandidate(id: b, interval: 1, sortOrder: 1)
        ]
        let result = RingSelectionPolicy.reconcile(selected: [a], seen: [a, b], candidates: candidates, maxLists: 3)
        #expect(result.selected == [a])
    }

    @Test func ineligibleListsAreRemoved() {
        let candidates = [RingCandidate(id: a, interval: 1, sortOrder: 0)]
        let result = RingSelectionPolicy.reconcile(selected: [a, b], seen: [a, b], candidates: candidates, maxLists: 3)
        #expect(result.selected == [a])
        #expect(!result.seen.contains(b))
    }

    @Test func unlimitedStyleTakesAll() {
        let candidates = [a, b, c, d].enumerated().map { RingCandidate(id: $1, interval: 1, sortOrder: $0) }
        let result = RingSelectionPolicy.reconcile(selected: [], seen: [], candidates: candidates, maxLists: nil)
        #expect(result.selected.count == 4)
    }

    @Test func limits() {
        #expect(RingStyle.simple.maxLists == nil)
        #expect(RingStyle.segmented.maxLists == 5)
        #expect(RingStyle.nested.maxLists == 3)
        #expect(RingSelectionPolicy.canSelectMore(selectedCount: 3, maxLists: 3) == false)
        #expect(RingSelectionPolicy.canSelectMore(selectedCount: 10, maxLists: nil))
    }
}
