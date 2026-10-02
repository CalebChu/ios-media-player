import AVFoundation
import XCTest
@testable import IOSMediaPlayer

/// Exercises PlaybackManager's load/play/pause lifecycle against short silent WAV files
/// generated on the fly, so the tests need no bundled media or network access.
@MainActor
final class PlaybackManagerTests: XCTestCase {
    private static let suiteName = "PlaybackManagerTests"

    private var defaults: UserDefaults!
    private var store: PlaybackProgressStore!
    private var manager: PlaybackManager!
    private var temporaryFiles: [URL] = []

    override func setUp() async throws {
        try await super.setUp()
        defaults = UserDefaults(suiteName: Self.suiteName)
        defaults.removePersistentDomain(forName: Self.suiteName)
        store = PlaybackProgressStore(defaults: defaults)
        manager = PlaybackManager(progressStore: store)
    }

    override func tearDown() async throws {
        manager.stop()
        manager = nil
        store = nil
        defaults.removePersistentDomain(forName: Self.suiteName)
        defaults = nil
        for url in temporaryFiles {
            try? FileManager.default.removeItem(at: url)
        }
        temporaryFiles = []
        try await super.tearDown()
    }

    // MARK: - Playback intent

    func testAutoPlayStartsOnceReady() async throws {
        manager.loadMedia(item: try makeLocalItem(), autoPlay: true)
        XCTAssertTrue(manager.isPlaying, "Intent is set immediately, before the item is ready")

        try await waitUntil { self.manager.player.rate > 0 }
        XCTAssertTrue(manager.wantsToPlay)
    }

    func testPauseWhileLoadingIsNotOverriddenByReadiness() async throws {
        manager.loadMedia(item: try makeLocalItem(), autoPlay: true)
        manager.togglePlayPause()
        XCTAssertFalse(manager.isPlaying)

        try await waitUntil { self.manager.playbackState == .paused }
        XCTAssertEqual(manager.player.rate, 0)
        XCTAssertFalse(manager.wantsToPlay)
    }

    func testResumeSeekRestoresSavedPositionWithoutPlaying() async throws {
        manager.loadMedia(item: try makeLocalItem(lastPosition: 1.5), autoPlay: false)

        try await waitUntil { self.manager.playbackState == .paused }
        XCTAssertEqual(manager.currentTime, 1.5, accuracy: 0.1)
        XCTAssertEqual(manager.player.rate, 0)
    }

    func testCallbacksFromPreviousLoadAreIgnored() async throws {
        // The first item would resume at 1.5s and auto-play; replacing it immediately must
        // leave the second item at its own position, paused.
        let first = try makeLocalItem(title: "First", lastPosition: 1.5)
        let second = try makeLocalItem(title: "Second")
        manager.loadMedia(item: first, autoPlay: true)
        manager.loadMedia(item: second, autoPlay: false)

        try await waitUntil { self.manager.playbackState == .paused }
        try await Task.sleep(for: .milliseconds(300))

        XCTAssertEqual(manager.currentMediaItem?.id, second.id)
        XCTAssertEqual(manager.player.rate, 0)
        XCTAssertEqual(manager.currentTime, 0, accuracy: 0.1)
    }

    // MARK: - Interruptions

    func testInterruptionResumesWhenUserWasPlaying() async throws {
        try await loadAndStartPlaying()

        manager.handleInterruptionBegan()
        XCTAssertTrue(manager.isInterrupted)
        XCTAssertFalse(manager.isPlaying)
        XCTAssertTrue(manager.wantsToPlay, "Intent survives the interruption")
        XCTAssertEqual(manager.player.rate, 0)

        manager.handleInterruptionEnded(shouldResume: true)
        XCTAssertFalse(manager.isInterrupted)
        XCTAssertGreaterThan(manager.player.rate, 0)
    }

    func testPauseDuringInterruptionPreventsResume() async throws {
        try await loadAndStartPlaying()

        manager.handleInterruptionBegan()
        manager.pause()
        manager.handleInterruptionEnded(shouldResume: true)

        XCTAssertFalse(manager.wantsToPlay)
        XCTAssertEqual(manager.player.rate, 0)
    }

    func testInterruptionWithoutResumeClearsIntent() async throws {
        try await loadAndStartPlaying()

        manager.handleInterruptionBegan()
        manager.handleInterruptionEnded(shouldResume: false)

        XCTAssertFalse(manager.wantsToPlay)
        XCTAssertFalse(manager.isPlaying)
        XCTAssertEqual(manager.player.rate, 0)
    }

    func testInterruptionDoesNotResumeWhenAlreadyPaused() async throws {
        manager.loadMedia(item: try makeLocalItem(), autoPlay: false)
        try await waitUntil { self.manager.playbackState == .paused }

        manager.handleInterruptionBegan()
        manager.handleInterruptionEnded(shouldResume: true)

        XCTAssertEqual(manager.player.rate, 0)
    }

    // MARK: - Persistence

    func testProgressIsNotSavedWhileLoading() throws {
        let item = store.saveItem(try makeLocalItem(lastPosition: 1.5, duration: 3))
        let savedDate = store.items[0].lastPlayedDate

        manager.loadMedia(item: item, autoPlay: false)
        manager.persistCurrentProgress()

        XCTAssertEqual(store.items[0].lastPosition, 1.5)
        XCTAssertEqual(store.items[0].lastPlayedDate, savedDate)
    }

    func testSeekingToZeroIsPersisted() async throws {
        let item = store.saveItem(try makeLocalItem(lastPosition: 1.5, duration: 3))
        manager.loadMedia(item: item, autoPlay: false)
        try await waitUntil { self.manager.playbackState == .paused }

        let seeked = expectation(description: "seek finished")
        manager.seek(to: 0) { seeked.fulfill() }
        await fulfillment(of: [seeked], timeout: 5)

        XCTAssertEqual(store.items[0].lastPosition, 0)
    }

    func testReplayingCurrentItemIsRecognised() async throws {
        let item = store.saveItem(try makeLocalItem())
        manager.loadMedia(item: item, autoPlay: false)
        try await waitUntil { self.manager.playbackState == .paused }

        XCTAssertTrue(manager.isLoaded(item))
        XCTAssertFalse(manager.isLoaded(try makeLocalItem(title: "Other")))
    }

    func testUnresolvableBookmarkFailsWithMessage() {
        let item = MediaItem(
            title: "Missing",
            url: URL(fileURLWithPath: "/nonexistent/missing.mp4"),
            isRemote: false,
            bookmarkData: Data("not a bookmark".utf8)
        )

        manager.loadMedia(item: item, autoPlay: true)

        XCTAssertTrue(manager.isFailed)
        XCTAssertFalse(manager.wantsToPlay)
        XCTAssertNil(manager.player.currentItem)
        XCTAssertFalse(manager.isLoaded(item))
    }

    func testPlayDoesNothingAfterFailure() {
        let item = MediaItem(
            title: "Missing",
            url: URL(fileURLWithPath: "/nonexistent/missing.mp4"),
            isRemote: false,
            bookmarkData: Data("not a bookmark".utf8)
        )
        manager.loadMedia(item: item, autoPlay: false)

        manager.play()

        XCTAssertTrue(manager.isFailed)
        XCTAssertFalse(manager.wantsToPlay)
    }

    // MARK: - Helpers

    private func loadAndStartPlaying() async throws {
        manager.loadMedia(item: try makeLocalItem(duration: 3), autoPlay: true)
        try await waitUntil { self.manager.player.rate > 0 }
    }

    private func waitUntil(
        timeout: TimeInterval = 5,
        file: StaticString = #filePath,
        line: UInt = #line,
        _ condition: @escaping () -> Bool
    ) async throws {
        let deadline = Date().addingTimeInterval(timeout)
        while !condition() {
            if Date() > deadline {
                XCTFail("Timed out waiting for condition", file: file, line: line)
                return
            }
            try await Task.sleep(for: .milliseconds(50))
        }
    }

    private func makeLocalItem(
        title: String = "Silence",
        lastPosition: TimeInterval = 0,
        duration: TimeInterval = 0
    ) throws -> MediaItem {
        let url = try Self.writeSilentWAV(seconds: 3)
        temporaryFiles.append(url)
        return MediaItem(
            title: title,
            url: url,
            isRemote: false,
            duration: duration,
            lastPosition: lastPosition,
            mediaType: .audio
        )
    }

    /// Writes a mono 16-bit PCM WAV file of silence and returns its URL.
    private static func writeSilentWAV(seconds: Double) throws -> URL {
        let sampleRate: UInt32 = 8_000
        let bytesPerSample: UInt16 = 2
        let sampleCount = UInt32(Double(sampleRate) * seconds)
        let dataSize = sampleCount * UInt32(bytesPerSample)

        var data = Data()
        func append<T: FixedWidthInteger>(_ value: T) {
            withUnsafeBytes(of: value.littleEndian) { data.append(contentsOf: $0) }
        }

        data.append(contentsOf: Array("RIFF".utf8))
        append(UInt32(36) + dataSize)
        data.append(contentsOf: Array("WAVE".utf8))
        data.append(contentsOf: Array("fmt ".utf8))
        append(UInt32(16))                                  // fmt chunk size
        append(UInt16(1))                                   // PCM
        append(UInt16(1))                                   // mono
        append(sampleRate)
        append(sampleRate * UInt32(bytesPerSample))         // byte rate
        append(bytesPerSample)                              // block align
        append(UInt16(16))                                  // bits per sample
        data.append(contentsOf: Array("data".utf8))
        append(dataSize)
        data.append(Data(count: Int(dataSize)))

        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("wav")
        try data.write(to: url)
        return url
    }
}
