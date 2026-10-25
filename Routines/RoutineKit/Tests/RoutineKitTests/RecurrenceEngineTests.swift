import Foundation
import Testing
@testable import RoutineKit

@Suite("Wiederholungslogik")
struct RecurrenceEngineTests {

    // MARK: Täglich / alle n Tage

    @Test func dailyPeriodIsTheCurrentDay() throws {
        let period = try #require(engine.period(for: rule(.daily, from: date(2026, 10, 1)), containing: date(2026, 10, 21, 10)))
        #expect(period.key == key(2026, 10, 21))
        #expect(period.start == date(2026, 10, 21, 0))
        #expect(period.end == date(2026, 10, 22, 0))
    }

    @Test func listIsInactiveBeforeAnchor() {
        #expect(engine.period(for: rule(.daily, from: date(2026, 10, 25)), containing: date(2026, 10, 21)) == nil)
    }

    @Test func everyThreeDays() throws {
        let r = rule(.daily, every: 3, from: date(2026, 10, 1))
        let period = try #require(engine.period(for: r, containing: date(2026, 10, 5)))
        #expect(period.key == key(2026, 10, 4))
        #expect(period.end == date(2026, 10, 7, 0))
    }

    @Test func everyTwoDaysIsDueOnlyOnFirstDay() {
        let r = rule(.daily, every: 2, from: date(2026, 10, 19))
        #expect(engine.isDue(r, on: date(2026, 10, 21, 8)))
        #expect(!engine.isDue(r, on: date(2026, 10, 22, 8)))
    }

    @Test func daylightSavingTimeDoesNotShiftDays() throws {
        // Umstellung auf Sommerzeit am 29.03.2026
        let daily = rule(.daily, from: date(2026, 3, 1))
        #expect(try #require(engine.period(for: daily, containing: date(2026, 3, 30, 1))).key == key(2026, 3, 30))

        let everyTwo = rule(.daily, every: 2, from: date(2026, 3, 27))
        let period = try #require(engine.period(for: everyTwo, containing: date(2026, 3, 29, 23, 30)))
        #expect(period.key == key(2026, 3, 29))
        #expect(period.end == date(2026, 3, 31, 0))
    }

    // MARK: Wöchentlich

    @Test func weeklyResetsOnChosenWeekday() throws {
        // 21.10.2026 ist ein Mittwoch, zurückgesetzt wird donnerstags (5)
        let r = rule(.weekly, weekday: 5, from: date(2026, 10, 21))
        let period = try #require(engine.period(for: r, containing: date(2026, 10, 21)))
        #expect(period.key == key(2026, 10, 15))
        #expect(period.end == date(2026, 10, 22, 0))
    }

    @Test func everyTwoWeeks() throws {
        let r = rule(.weekly, every: 2, weekday: 5, from: date(2026, 10, 22))
        let first = try #require(engine.period(for: r, containing: date(2026, 11, 4)))
        #expect(first.key == key(2026, 10, 22))
        #expect(first.end == date(2026, 11, 5, 0))

        let second = try #require(engine.period(for: r, containing: date(2026, 11, 5)))
        #expect(second.key == key(2026, 11, 5))
    }

    // MARK: Monatlich

    @Test func monthlyKeepsAnchorAfterShortMonth() throws {
        let r = rule(.monthly, from: date(2026, 1, 30))

        let january = try #require(engine.period(for: r, containing: date(2026, 2, 15)))
        #expect(january.key == key(2026, 1, 30))
        #expect(january.end == date(2026, 2, 28, 0))

        let february = try #require(engine.period(for: r, containing: date(2026, 2, 28)))
        #expect(february.key == key(2026, 2, 28))
        #expect(february.end == date(2026, 3, 30, 0))

        #expect(try #require(engine.period(for: r, containing: date(2026, 3, 29))).key == key(2026, 2, 28))
        #expect(try #require(engine.period(for: r, containing: date(2026, 3, 30))).key == key(2026, 3, 30))
    }

    @Test func monthlyInLeapYear() throws {
        let r = rule(.monthly, from: date(2028, 1, 31))
        let period = try #require(engine.period(for: r, containing: date(2028, 2, 10)))
        #expect(period.key == key(2028, 1, 31))
        #expect(period.end == date(2028, 2, 29, 0))
    }

    @Test func monthly31stInThirtyDayMonth() throws {
        let r = rule(.monthly, from: date(2026, 1, 31))
        let april = try #require(engine.period(for: r, containing: date(2026, 4, 30)))
        #expect(april.key == key(2026, 4, 30))
        #expect(april.end == date(2026, 5, 31, 0))
    }

    @Test func everyThreeMonths() throws {
        let r = rule(.monthly, every: 3, from: date(2026, 1, 30))
        let period = try #require(engine.period(for: r, containing: date(2026, 5, 1)))
        #expect(period.key == key(2026, 4, 30))
        #expect(period.end == date(2026, 7, 30, 0))
    }

    // MARK: Jährlich

    @Test func yearlyFromLeapDay() throws {
        let r = rule(.yearly, from: date(2024, 2, 29))
        let period = try #require(engine.period(for: r, containing: date(2025, 3, 1)))
        #expect(period.key == key(2025, 2, 28))
        #expect(period.end == date(2026, 2, 28, 0))

        #expect(try #require(engine.period(for: r, containing: date(2028, 2, 29))).key == key(2028, 2, 29))
    }

    @Test func everyTwoYears() throws {
        let r = rule(.yearly, every: 2, from: date(2024, 5, 10))
        let period = try #require(engine.period(for: r, containing: date(2025, 6, 1)))
        #expect(period.key == key(2024, 5, 10))
        #expect(period.end == date(2026, 5, 10, 0))
    }

    // MARK: Ohne Wiederholung

    @Test func noneHasSinglePeriodWithoutEnd() throws {
        let r = rule(.none, from: date(2026, 10, 1))
        let period = try #require(engine.period(for: r, containing: date(2027, 1, 1)))
        #expect(period.key == key(2026, 10, 1))
        #expect(period.end == nil)
        #expect(engine.nextPeriodStart(after: date(2027, 1, 1), for: r) == nil)
    }

    // MARK: Blättern und Benennung

    @Test func periodIndexAndPeriodByIndex() throws {
        let r = rule(.daily, every: 2, from: date(2026, 10, 1))
        let k = try #require(engine.periodIndex(for: r, containing: date(2026, 10, 23)))
        #expect(k == 11)
        #expect(try #require(engine.period(for: r, index: k)).key == key(2026, 10, 23))
        #expect(try #require(engine.period(for: r, index: k + 1)).key == key(2026, 10, 25))
        #expect(try #require(engine.period(for: r, index: 0)).key == key(2026, 10, 1))
        #expect(engine.period(for: r, index: -1) == nil)
        #expect(engine.periodIndex(for: r, containing: date(2026, 9, 30)) == nil)
    }

    @Test func monthlyPeriodIsNamedAfterItsMajorityMonth() throws {
        let r = rule(.monthly, from: date(2026, 1, 30))
        let period = try #require(engine.period(for: r, containing: date(2026, 10, 23)))
        #expect(period.key == key(2026, 9, 30))
        let middle = engine.representativeDate(of: period)
        #expect(Calendar.berlin.component(.month, from: middle) == 10)
        #expect(engine.lastDay(of: period) == date(2026, 10, 29, 0))
    }

    @Test func weeklyPeriodIsNamedAfterItsMajorityWeek() throws {
        // Donnerstag bis Mittwoch: 4 von 7 Tagen liegen in der KW, in der die Woche beginnt
        let r = rule(.weekly, weekday: 5, from: date(2026, 10, 1))
        let period = try #require(engine.period(for: r, containing: date(2026, 10, 23)))
        #expect(period.key == key(2026, 10, 22))
        var iso = Calendar(identifier: .iso8601)
        iso.timeZone = Calendar.berlin.timeZone
        #expect(iso.component(.weekOfYear, from: engine.representativeDate(of: period)) == 43)
    }

    @Test func noneHasOnlyIndexZero() {
        let r = rule(.none, from: date(2026, 10, 1))
        #expect(engine.period(for: r, index: 0)?.end == nil)
        #expect(engine.period(for: r, index: 1) == nil)
    }

    // MARK: Sonstiges

    @Test func nextPeriodStartForFutureList() {
        let r = rule(.daily, from: date(2026, 10, 25))
        #expect(engine.nextPeriodStart(after: date(2026, 10, 21), for: r) == date(2026, 10, 25, 0))
    }

    @Test func keyFormat() {
        #expect(engine.key(for: date(2026, 3, 5)) == "2026-03-05")
    }
}
