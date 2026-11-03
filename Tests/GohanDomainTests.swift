import XCTest
@testable import AruiteGohan

final class GohanDomainTests: XCTestCase {
    func testKcalAt60kgMatchesDesignCoefficient() {
        XCTAssertEqual(CalorieCalculator.kcal(steps: 7150, weightKg: 60), 286)
        XCTAssertEqual(CalorieCalculator.kcal(steps: 12500, weightKg: 60), 500)
        XCTAssertEqual(CalorieCalculator.kcal(steps: 0, weightKg: 60), 0)
    }

    func testKcalScalesWithWeightAndRounds() {
        XCTAssertEqual(CalorieCalculator.kcal(steps: 10000, weightKg: 75), 500)
        // 13 × 60 × 0.04 ÷ 60 = 0.52 → 1
        XCTAssertEqual(CalorieCalculator.kcal(steps: 13, weightKg: 60), 1)
        XCTAssertEqual(CalorieCalculator.kcal(steps: 12, weightKg: 60), 0)
    }

    func testTierBoundaries() {
        let cases: [(Int, String)] = [
            (0, "tea"), (49, "tea"), (50, "mikan"), (89, "mikan"), (90, "banana"),
            (169, "banana"), (170, "onigiri"), (259, "onigiri"), (260, "burger"),
            (339, "burger"), (340, "cake"), (499, "cake"), (500, "ramen"), (900, "ramen")
        ]
        for (kcal, id) in cases {
            XCTAssertEqual(GohanTier.tier(forKcal: kcal).id, id, "\(kcal)kcal")
        }
    }

    func testAllTierImagesAreNamedLikeAssets() {
        XCTAssertEqual(GohanTier.all.map(\.imageName), ["tea", "mikan", "banana", "onigiri", "burger", "cake", "ramen"])
    }

    func testGaugeAndCap() {
        XCTAssertEqual(GohanDisplay(steps: 0, kcal: 49).filledSegments, 0)
        XCTAssertEqual(GohanDisplay(steps: 0, kcal: 50).filledSegments, 1)
        XCTAssertEqual(GohanDisplay(steps: 0, kcal: 286).filledSegments, 5)
        XCTAssertEqual(GohanDisplay(steps: 0, kcal: 499).filledSegments, 9)
        XCTAssertEqual(GohanDisplay(steps: 0, kcal: 500).filledSegments, 10)
        XCTAssertEqual(GohanDisplay(steps: 0, kcal: 620).filledSegments, 10)
        XCTAssertEqual(GohanDisplay(steps: 0, kcal: 499).kcalText, "499")
        XCTAssertEqual(GohanDisplay(steps: 0, kcal: 500).kcalText, "500+")
    }

    func testNextText() {
        XCTAssertEqual(GohanDisplay(steps: 7150, kcal: 286).nextText, "あと54kcalでショートケーキ")
        XCTAssertEqual(GohanDisplay(steps: 12500, kcal: 500).nextText, "MAX!上限 500kcal 到達")
    }

    func testStepsTextUsesGrouping() {
        XCTAssertEqual(GohanDisplay(steps: 7150, kcal: 286).stepsText, "7,150")
    }

    func testPixelScaleIsIntegerAndFitsWidgetSizes() {
        // 小: 高さ - 余白24
        XCTAssertEqual(PixelScale.small(contentHeight: 170 - 24), 6)
        XCTAssertEqual(PixelScale.small(contentHeight: 158 - 24), 5)
        XCTAssertEqual(PixelScale.small(contentHeight: 148 - 24), 5)
        // 中: タイル = 高さ - 余白28
        XCTAssertEqual(PixelScale.medium(tileHeight: 170 - 28), 7)
        XCTAssertEqual(PixelScale.medium(tileHeight: 158 - 28), 6)
        XCTAssertEqual(PixelScale.medium(tileHeight: 148 - 28), 6)
    }
}

final class SnapshotPolicyTests: XCTestCase {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Tokyo")!
        return calendar
    }

    private func date(_ day: Int, _ hour: Int) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: 11, day: day, hour: hour))!
    }

    private func cached(day: Int, steps: Int, lastReadAt: Date?) -> DaySnapshot {
        DaySnapshot(dayStart: calendar.startOfDay(for: date(day, 0)), steps: steps, weightKg: 60, lastReadAt: lastReadAt)
    }

    func testReadValueIsUsed() {
        let now = date(3, 12)
        let result = SnapshotPolicy.resolve(cached: nil, readSteps: 1000, weightKg: 60, now: now, calendar: calendar)
        XCTAssertEqual(result.steps, 1000)
        XCTAssertEqual(result.lastReadAt, now)
    }

    func testReadFailureKeepsSameDayValue() {
        let previousRead = date(3, 10)
        let result = SnapshotPolicy.resolve(
            cached: cached(day: 3, steps: 5000, lastReadAt: previousRead),
            readSteps: nil, weightKg: 60, now: date(3, 12), calendar: calendar
        )
        XCTAssertEqual(result.steps, 5000)
        XCTAssertEqual(result.lastReadAt, previousRead)
    }

    func testZeroReadDoesNotLowerSameDayValue() {
        let result = SnapshotPolicy.resolve(
            cached: cached(day: 3, steps: 5000, lastReadAt: date(3, 10)),
            readSteps: 0, weightKg: 60, now: date(3, 12), calendar: calendar
        )
        XCTAssertEqual(result.steps, 5000)
    }

    func testNewDayStartsFromZeroEvenIfReadFails() {
        let result = SnapshotPolicy.resolve(
            cached: cached(day: 3, steps: 5000, lastReadAt: date(3, 22)),
            readSteps: nil, weightKg: 60, now: date(4, 1), calendar: calendar
        )
        XCTAssertEqual(result.steps, 0)
        XCTAssertNil(result.lastReadAt)
        XCTAssertEqual(result.dayStart, calendar.startOfDay(for: date(4, 1)))
    }

    func testNewDayUsesRead() {
        let result = SnapshotPolicy.resolve(
            cached: cached(day: 3, steps: 5000, lastReadAt: date(3, 22)),
            readSteps: 300, weightKg: 60, now: date(4, 8), calendar: calendar
        )
        XCTAssertEqual(result.steps, 300)
    }

    func testWeightChangeRecalculatesToday() {
        let result = SnapshotPolicy.resolve(
            cached: cached(day: 3, steps: 6000, lastReadAt: date(3, 10)),
            readSteps: 6000, weightKg: 75, now: date(3, 12), calendar: calendar
        )
        XCTAssertEqual(result.kcal, 300)
    }

    func testNextDayEntryIsZero() {
        let next = SnapshotPolicy.startOfNextDay(from: cached(day: 3, steps: 5000, lastReadAt: nil), calendar: calendar)
        XCTAssertEqual(next?.steps, 0)
        XCTAssertEqual(next?.dayStart, calendar.startOfDay(for: date(4, 0)))
    }
}

final class DiagnosticSummaryTests: XCTestCase {
    func testEventsAtSameSecondHaveDistinctIDsAfterRoundTrip() throws {
        let at = Date(timeIntervalSince1970: 1_000_000)
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try [
            DiagnosticEvent(at: at, source: .app, action: "foreground", steps: 1, error: nil),
            DiagnosticEvent(at: at, source: .widget, action: "timeline", steps: 1, error: nil)
        ].map { try decoder.decode(DiagnosticEvent.self, from: encoder.encode($0)) }
        XCTAssertNotEqual(decoded[0].id, decoded[1].id)
    }

    func testCountsBySourceWithinWindow() {
        let now = Date(timeIntervalSince1970: 1_000_000)
        let events: [DiagnosticEvent] = [
            .init(at: now, source: .widget, action: "timeline", steps: 10, error: nil),
            .init(at: now.addingTimeInterval(-10), source: .widget, action: "timeline", steps: nil, error: "com.apple.healthkit/6"),
            .init(at: now.addingTimeInterval(-90_000), source: .widget, action: "timeline", steps: 1, error: nil),
            .init(at: now, source: .background, action: "observer", steps: 20, error: nil)
        ]
        let rows = DiagnosticSummary.make(events: events, since: now.addingTimeInterval(-86_400))
        let widget = rows.first { $0.source == .widget }
        XCTAssertEqual(widget?.total, 2)
        XCTAssertEqual(widget?.failed, 1)
        XCTAssertEqual(widget?.lastAt, now)
        XCTAssertEqual(rows.first { $0.source == .background }?.total, 1)
        XCTAssertEqual(rows.first { $0.source == .app }?.total, 0)
    }
}
