import XCTest
@testable import GitViewer

@MainActor
final class DateRelativeFormatTests: XCTestCase {

    private func dateSecondsAgo(_ seconds: TimeInterval) -> Date {
        Date().addingTimeInterval(-seconds)
    }

    func testJustNow() {
        XCTAssertEqual(dateSecondsAgo(30).relativeDisplay, "just now")
    }

    func testJustNowBoundary() {
        XCTAssertEqual(dateSecondsAgo(59).relativeDisplay, "just now")
    }

    func testMinutesAgo() {
        XCTAssertEqual(dateSecondsAgo(5 * 60).relativeDisplay, "5 min ago")
    }

    func testOneMinuteAgo() {
        XCTAssertEqual(dateSecondsAgo(90).relativeDisplay, "1 min ago")
    }

    func testHoursAgo() {
        XCTAssertEqual(dateSecondsAgo(3 * 3600).relativeDisplay, "3 hr ago")
    }

    func testOneHourAgo() {
        XCTAssertEqual(dateSecondsAgo(3601).relativeDisplay, "1 hr ago")
    }

    func testYesterday() {
        XCTAssertEqual(dateSecondsAgo(86400 + 1).relativeDisplay, "yesterday")
    }

    func testTwoDaysAgo() {
        XCTAssertEqual(dateSecondsAgo(2 * 86400 + 1).relativeDisplay, "2 days ago")
    }

    func testDaysAgo() {
        XCTAssertEqual(dateSecondsAgo(3 * 86400 + 1).relativeDisplay, "3 days ago")
    }

    func testExactlySevenDayBoundaryShowsDateString() {
        // 604800s = exactly 7 days → falls into the "older than a week" branch
        let display = dateSecondsAgo(604800 + 1).relativeDisplay
        XCTAssertFalse(display.hasSuffix("ago"))
        XCTAssertFalse(display.isEmpty)
    }

    func testOlderThanWeekShowsDateString() {
        // 8 days ago → should show formatted date, not relative
        let display = dateSecondsAgo(8 * 86400).relativeDisplay
        // Should NOT match relative patterns
        XCTAssertFalse(display.hasSuffix("ago"))
        XCTAssertFalse(display == "just now")
        XCTAssertFalse(display == "yesterday")
        // Should be a non-empty date string (e.g., "Mar 24")
        XCTAssertFalse(display.isEmpty)
    }

    func testFutureDateFallsBackToAbsolute() {
        // Clocks can be skewed; a future date should show absolute rather than "just now"
        let future = Date().addingTimeInterval(3600)
        XCTAssertEqual(future.relativeDisplay, future.absoluteDisplay)
    }
}

final class StringSHATests: XCTestCase {

    func testShortSHAReturnsFirst7Chars() {
        let sha = "a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2"
        XCTAssertEqual(sha.shortSHA, "a1b2c3d")
    }

    func testShortSHAOnShortString() {
        XCTAssertEqual("abc".shortSHA, "abc")
    }

    func testShortSHAOnEmptyString() {
        XCTAssertEqual("".shortSHA, "")
    }

    func testShortSHAExactly7Chars() {
        XCTAssertEqual("1234567".shortSHA, "1234567")
    }
}
