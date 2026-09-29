import XCTest
@testable import IOSMediaPlayer

@MainActor
final class PlaybackProgressStoreTests: XCTestCase {
    var store: PlaybackProgressStore!

    override func setUp() {
        super.setUp()
        store = PlaybackProgressStore()
        store.clearAll()
    }

    override func tearDown() {
        store.clearAll()
        super.tearDown()
    }

    func testSaveAndRetrieveItem() {
        let item = MediaItem(
            title: "Test Movie",
            url: URL(string: "https://example.com/movie.mp4")!,
            isRemote: true,
            duration: 120
        )

        store.saveItem(item)
        XCTAssertEqual(store.items.count, 1)
        XCTAssertEqual(store.items.first?.title, "Test Movie")
    }

    func testUpdateProgressAndContinueWatching() {
        let item = MediaItem(
            title: "Series Episode 1",
            url: URL(string: "https://example.com/ep1.mp4")!,
            isRemote: true,
            duration: 1000
        )
        store.saveItem(item)

        // Update progress to 20%
        store.updateProgress(for: item.id, position: 200, duration: 1000)

        let continueItems = store.continueWatchingItems
        XCTAssertEqual(continueItems.count, 1)
        XCTAssertEqual(continueItems.first?.lastPosition, 200)
        XCTAssertFalse(continueItems.first?.isCompleted ?? true)
    }

    func testCompletionThreshold() {
        let item = MediaItem(
            title: "Short Film",
            url: URL(string: "https://example.com/short.mp4")!,
            isRemote: true,
            duration: 100
        )
        store.saveItem(item)

        // Update progress to 96% (over 95% completion threshold)
        store.updateProgress(for: item.id, position: 96, duration: 100)

        XCTAssertTrue(store.items.first?.isCompleted ?? false)
        XCTAssertTrue(store.continueWatchingItems.isEmpty)
    }

    func testDeleteItem() {
        let item = MediaItem(
            title: "Temporary Video",
            url: URL(string: "https://example.com/temp.mp4")!,
            isRemote: true
        )
        store.saveItem(item)
        XCTAssertEqual(store.items.count, 1)

        store.deleteItem(withId: item.id)
        XCTAssertEqual(store.items.count, 0)
    }
}
