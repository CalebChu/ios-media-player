import XCTest
@testable import IOSMediaPlayer

@MainActor
final class PlaybackProgressStoreTests: XCTestCase {
    private static let suiteName = "PlaybackProgressStoreTests"

    var defaults: UserDefaults!
    var store: PlaybackProgressStore!

    override func setUp() {
        super.setUp()
        // An isolated suite, so tests never read or clear the real library.
        defaults = UserDefaults(suiteName: Self.suiteName)
        defaults.removePersistentDomain(forName: Self.suiteName)
        store = PlaybackProgressStore(defaults: defaults)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: Self.suiteName)
        store = nil
        defaults = nil
        super.tearDown()
    }

    private func makeItem(
        title: String = "Test Movie",
        url: String = "https://example.com/movie.mp4",
        duration: TimeInterval = 120
    ) -> MediaItem {
        return MediaItem(title: title, url: URL(string: url)!, isRemote: true, duration: duration)
    }

    func testSaveAndRetrieveItem() {
        store.saveItem(makeItem())
        XCTAssertEqual(store.items.count, 1)
        XCTAssertEqual(store.items.first?.title, "Test Movie")
    }

    func testUsesInjectedDefaultsOnly() {
        store.saveItem(makeItem())
        XCTAssertNotNil(defaults.data(forKey: "ios_media_player_items_v1"))

        let otherSuite = "PlaybackProgressStoreTests.other"
        let otherDefaults = UserDefaults(suiteName: otherSuite)!
        otherDefaults.removePersistentDomain(forName: otherSuite)
        XCTAssertTrue(PlaybackProgressStore(defaults: otherDefaults).items.isEmpty)
        otherDefaults.removePersistentDomain(forName: otherSuite)
    }

    func testProgressSurvivesReload() {
        let item = makeItem(duration: 1000)
        store.saveItem(item)
        store.updateProgress(for: item.id, position: 300, duration: 1000)

        let reloaded = PlaybackProgressStore(defaults: defaults)
        XCTAssertEqual(reloaded.items.count, 1)
        XCTAssertEqual(reloaded.items.first?.id, item.id)
        XCTAssertEqual(reloaded.items.first?.lastPosition, 300)
        XCTAssertEqual(reloaded.items.first?.duration, 1000)
    }

    func testUpdateProgressAndContinueWatching() {
        let item = makeItem(title: "Series Episode 1", url: "https://example.com/ep1.mp4", duration: 1000)
        store.saveItem(item)

        store.updateProgress(for: item.id, position: 200, duration: 1000)

        let continueItems = store.continueWatchingItems
        XCTAssertEqual(continueItems.count, 1)
        XCTAssertEqual(continueItems.first?.lastPosition, 200)
        XCTAssertFalse(continueItems.first?.isCompleted ?? true)
    }

    func testCompletionThreshold() {
        let item = makeItem(title: "Short Film", url: "https://example.com/short.mp4", duration: 100)
        store.saveItem(item)

        // 96% is over the 95% completion threshold.
        store.updateProgress(for: item.id, position: 96, duration: 100)

        XCTAssertTrue(store.items.first?.isCompleted ?? false)
        XCTAssertTrue(store.continueWatchingItems.isEmpty)
    }

    func testZeroPositionIsSavedAndClearsCompletion() {
        let item = makeItem(duration: 100)
        store.saveItem(item)
        store.updateProgress(for: item.id, position: 98, duration: 100)
        XCTAssertTrue(store.items.first?.isCompleted ?? false)

        store.updateProgress(for: item.id, position: 0, duration: 100)

        XCTAssertEqual(store.items.first?.lastPosition, 0)
        XCTAssertFalse(store.items.first?.isCompleted ?? true)
    }

    func testDeleteItem() {
        let item = makeItem(title: "Temporary Video", url: "https://example.com/temp.mp4")
        store.saveItem(item)
        XCTAssertEqual(store.items.count, 1)

        store.deleteItem(withId: item.id)
        XCTAssertEqual(store.items.count, 0)
    }

    func testReaddingExistingItemPreservesProgressAndReturnsMergedItem() {
        let initialItem = makeItem(title: "Movie", duration: 1000)
        store.saveItem(initialItem)
        store.updateProgress(for: initialItem.id, position: 450, duration: 1000)

        // A new instance, as when re-importing a file or tapping a sample stream again.
        let readdedItem = MediaItem(
            title: "Movie Updated Title",
            url: URL(string: "https://example.com/movie.mp4")!,
            isRemote: true,
            duration: 0,
            lastPosition: 0
        )

        let mergedItem = store.saveItem(readdedItem)

        XCTAssertEqual(store.items.count, 1)
        XCTAssertEqual(mergedItem.id, initialItem.id)
        XCTAssertEqual(mergedItem.title, "Movie Updated Title")
        XCTAssertEqual(mergedItem.lastPosition, 450)
        XCTAssertEqual(mergedItem.duration, 1000)
        XCTAssertEqual(store.items.first?.lastPosition, 450)
    }

    func testStaleSnapshotDoesNotOverwriteNewerProgress() {
        let item = makeItem(duration: 1000)
        store.saveItem(item)
        store.updateProgress(for: item.id, position: 100, duration: 1000)
        let staleSnapshot = store.items[0]

        store.updateProgress(for: item.id, position: 600, duration: 1000)
        let saved = store.saveItem(staleSnapshot)

        XCTAssertEqual(saved.lastPosition, 600)
        XCTAssertEqual(store.items.first?.lastPosition, 600)
    }

    func testStreamsWithEmbeddedCredentialsAreNotPersisted() {
        let item = makeItem(url: "https://user:secret@example.com/live.m3u8")
        XCTAssertTrue(item.hasEmbeddedCredentials)

        let returned = store.saveItem(item)

        XCTAssertEqual(returned.id, item.id)
        XCTAssertTrue(store.items.isEmpty)
        XCTAssertNil(defaults.data(forKey: "ios_media_player_items_v1"))
    }

    func testMarkCompletedAndBookmarkUpdatesPersist() {
        let item = makeItem(duration: 100)
        store.saveItem(item)
        store.markCompleted(id: item.id)
        store.updateBookmark(Data([1, 2, 3]), for: item.id)

        let reloaded = PlaybackProgressStore(defaults: defaults)
        XCTAssertEqual(reloaded.items.first?.isCompleted, true)
        XCTAssertEqual(reloaded.items.first?.lastPosition, 100)
        XCTAssertEqual(reloaded.items.first?.bookmarkData, Data([1, 2, 3]))
    }
}
