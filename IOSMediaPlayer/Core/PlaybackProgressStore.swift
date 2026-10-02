import Combine
import Foundation
import OSLog

@MainActor
public final class PlaybackProgressStore: ObservableObject {
    public static let shared = PlaybackProgressStore()

    @Published public private(set) var items: [MediaItem] = []

    private let defaults: UserDefaults
    private let storageKey: String
    private let completionThreshold: Double = 0.95
    private let minimumProgressThreshold: Double = 0.02
    private let logger = Logger(subsystem: "com.calebchu.iosmediaplayer", category: "PlaybackProgressStore")

    /// - Parameters:
    ///   - defaults: Where the library is stored. Tests pass an isolated suite so they never touch real data.
    ///   - storageKey: The key the encoded library is stored under.
    public init(defaults: UserDefaults = .standard, storageKey: String = "ios_media_player_items_v1") {
        self.defaults = defaults
        self.storageKey = storageKey
        loadItems()
    }

    public var continueWatchingItems: [MediaItem] {
        return items
            .filter { item in
                !item.isCompleted && item.progressFraction >= minimumProgressThreshold
            }
            .sorted { $0.lastPlayedDate > $1.lastPlayedDate }
    }

    public var libraryItems: [MediaItem] {
        return items.sorted { $0.lastPlayedDate > $1.lastPlayedDate }
    }

    public func item(withId id: UUID) -> MediaItem? {
        return items.first { $0.id == id }
    }

    public func loadItems() {
        guard let data = defaults.data(forKey: storageKey) else {
            items = []
            return
        }

        do {
            items = try JSONDecoder().decode([MediaItem].self, from: data)
        } catch {
            logger.error("Failed to decode media items: \(error.localizedDescription, privacy: .public)")
        }
    }

    /// Adds `item`, or merges it into the entry with the same ID or URL, and returns the stored item.
    ///
    /// Progress (position, duration, completion) always comes from the stored entry: callers pass
    /// snapshots or freshly created items, and `updateProgress` is the only writer of progress.
    ///
    /// Streams whose URL embeds a user name or password are returned unsaved, so credentials are
    /// never written to preferences.
    @discardableResult
    public func saveItem(_ item: MediaItem) -> MediaItem {
        guard !item.hasEmbeddedCredentials else { return item }

        if let index = items.firstIndex(where: { $0.id == item.id || $0.url == item.url }) {
            var existing = items[index]
            if !item.title.isEmpty {
                existing.title = item.title
            }
            if let artist = item.artist {
                existing.artist = artist
            }
            if let bookmarkData = item.bookmarkData {
                existing.bookmarkData = bookmarkData
            }
            if existing.duration <= 0 && item.duration > 0 {
                existing.duration = item.duration
            }
            existing.isRemote = item.isRemote
            existing.mediaType = item.mediaType
            existing.lastPlayedDate = max(existing.lastPlayedDate, item.lastPlayedDate)

            items[index] = existing
            persist()
            return existing
        }

        items.insert(item, at: 0)
        persist()
        return item
    }

    public func deleteItem(withId id: UUID) {
        items.removeAll { $0.id == id }
        persist()
    }

    public func updateProgress(for id: UUID, position: TimeInterval, duration: TimeInterval) {
        guard let index = items.firstIndex(where: { $0.id == id }), position.isFinite else { return }

        var item = items[index]
        item.lastPosition = max(0, position)
        if duration > 0 && duration.isFinite {
            item.duration = duration
        }
        item.lastPlayedDate = Date()

        if item.duration > 0 && (item.lastPosition / item.duration) >= completionThreshold {
            item.isCompleted = true
        } else if item.lastPosition < (item.duration * 0.9) {
            item.isCompleted = false
        }

        items[index] = item
        persist()
    }

    public func markCompleted(id: UUID) {
        guard let index = items.firstIndex(where: { $0.id == id }) else { return }
        items[index].isCompleted = true
        items[index].lastPosition = items[index].duration
        persist()
    }

    public func updateBookmark(_ bookmarkData: Data, for id: UUID) {
        guard let index = items.firstIndex(where: { $0.id == id }) else { return }
        items[index].bookmarkData = bookmarkData
        persist()
    }

    public func clearAll() {
        items.removeAll()
        defaults.removeObject(forKey: storageKey)
    }

    public func createSecurityScopedBookmark(for url: URL) -> Data? {
        guard url.isFileURL else { return nil }

        let shouldStop = url.startAccessingSecurityScopedResource()
        defer {
            if shouldStop {
                url.stopAccessingSecurityScopedResource()
            }
        }

        do {
            return try url.bookmarkData(
                options: .minimalBookmark,
                includingResourceValuesForKeys: nil,
                relativeTo: nil
            )
        } catch {
            logger.error("Failed to create bookmark: \(error.localizedDescription, privacy: .public)")
            return nil
        }
    }

    private func persist() {
        do {
            let data = try JSONEncoder().encode(items)
            defaults.set(data, forKey: storageKey)
        } catch {
            logger.error("Failed to encode media items: \(error.localizedDescription, privacy: .public)")
        }
    }
}
