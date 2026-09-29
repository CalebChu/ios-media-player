import XCTest
@testable import IOSMediaPlayer

final class PlaybackSpeedTests: XCTestCase {
    func testSpeedTitles() {
        XCTAssertEqual(PlaybackSpeed.half.title, "0.5x")
        XCTAssertEqual(PlaybackSpeed.threeQuarters.title, "0.75x")
        XCTAssertEqual(PlaybackSpeed.normal.title, "1.0x")
        XCTAssertEqual(PlaybackSpeed.oneAndQuarter.title, "1.25x")
        XCTAssertEqual(PlaybackSpeed.oneAndHalf.title, "1.5x")
        XCTAssertEqual(PlaybackSpeed.oneAndThreeQuarters.title, "1.75x")
        XCTAssertEqual(PlaybackSpeed.double.title, "2.0x")
    }

    func testClosestSpeed() {
        XCTAssertEqual(PlaybackSpeed.closest(to: 1.0), .normal)
        XCTAssertEqual(PlaybackSpeed.closest(to: 0.9), .normal)
        XCTAssertEqual(PlaybackSpeed.closest(to: 0.6), .half)
        XCTAssertEqual(PlaybackSpeed.closest(to: 1.6), .oneAndHalf)
        XCTAssertEqual(PlaybackSpeed.closest(to: 2.5), .double)
    }
}
