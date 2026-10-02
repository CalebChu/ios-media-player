import XCTest
@testable import IOSMediaPlayer

final class PlaybackTimelineTests: XCTestCase {
    func testFiniteTimelineClampsAndMaps() {
        let timeline = PlaybackTimeline.finite(duration: 200)

        XCTAssertFalse(timeline.isLive)
        XCTAssertEqual(timeline.length, 200)
        XCTAssertEqual(timeline.clamp(-5), 0)
        XCTAssertEqual(timeline.clamp(250), 200)
        XCTAssertEqual(timeline.fraction(of: 50), 0.25, accuracy: 0.0001)
        XCTAssertEqual(timeline.time(atFraction: 0.5), 100, accuracy: 0.0001)
        XCTAssertEqual(timeline.distanceFromLiveEdge(10), 0)
    }

    func testNonFiniteDurationProducesEmptyTimeline() {
        XCTAssertEqual(PlaybackTimeline.finite(duration: .nan).length, 0)
        XCTAssertEqual(PlaybackTimeline.finite(duration: .infinity).length, 0)
        XCTAssertEqual(PlaybackTimeline.finite(duration: -10).length, 0)
        XCTAssertEqual(PlaybackTimeline.empty.fraction(of: 10), 0)
    }

    func testLiveWindowMapsRelativeToItsStart() {
        // A live window that has moved forward: 1,000s to 1,060s into the stream.
        let timeline = PlaybackTimeline(range: 1000...1060, isLive: true)

        XCTAssertEqual(timeline.length, 60)
        XCTAssertEqual(timeline.fraction(of: 1030), 0.5, accuracy: 0.0001)
        XCTAssertEqual(timeline.time(atFraction: 0), 1000)
        XCTAssertEqual(timeline.time(atFraction: 1), 1060)
        XCTAssertEqual(timeline.clamp(10), 1000)
        XCTAssertEqual(timeline.distanceFromLiveEdge(1045), 15)
        XCTAssertEqual(timeline.distanceFromLiveEdge(1070), 0)
    }

    func testInvalidInputsAreHandled() {
        let timeline = PlaybackTimeline.finite(duration: 100)
        XCTAssertEqual(timeline.clamp(.nan), 0)
        XCTAssertEqual(timeline.fraction(of: .nan), 0)
        XCTAssertEqual(timeline.time(atFraction: .nan), 0)
        XCTAssertEqual(timeline.time(atFraction: 2), 100)
    }
}
