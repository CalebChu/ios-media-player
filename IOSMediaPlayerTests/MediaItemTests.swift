import XCTest
@testable import IOSMediaPlayer

final class MediaItemTests: XCTestCase {
    func testMediaItemProgressFraction() {
        let item = MediaItem(
            title: "Test Video",
            url: URL(string: "https://example.com/video.mp4")!,
            isRemote: true,
            duration: 100,
            lastPosition: 25
        )

        XCTAssertEqual(item.progressFraction, 0.25, accuracy: 0.001)
    }

    func testProgressFractionClamping() {
        let overItem = MediaItem(
            title: "Over Video",
            url: URL(string: "https://example.com/video.mp4")!,
            isRemote: true,
            duration: 100,
            lastPosition: 150
        )
        XCTAssertEqual(overItem.progressFraction, 1.0)

        let negativeItem = MediaItem(
            title: "Negative Video",
            url: URL(string: "https://example.com/video.mp4")!,
            isRemote: true,
            duration: 100,
            lastPosition: -10
        )
        XCTAssertEqual(negativeItem.progressFraction, 0.0)
    }

    func testFormatTime() {
        XCTAssertEqual(MediaItem.formatTime(45), "00:45")
        XCTAssertEqual(MediaItem.formatTime(65), "01:05")
        XCTAssertEqual(MediaItem.formatTime(3665), "1:01:05")
        XCTAssertEqual(MediaItem.formatTime(0), "00:00")
        XCTAssertEqual(MediaItem.formatTime(-5), "00:00")
    }

    func testFormattedRemainingTime() {
        let item = MediaItem(
            title: "Test",
            url: URL(string: "https://example.com/test.mp4")!,
            isRemote: true,
            duration: 120,
            lastPosition: 20
        )
        XCTAssertEqual(item.formattedRemainingTime, "-01:40")
    }
}
