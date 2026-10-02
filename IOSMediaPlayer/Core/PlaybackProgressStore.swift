import Foundation
import Combine

@MainActor
public final class PlaybackProgressStore: ObservableObject {
    public static let shared = PlaybackProgressStore()

    @Published public private(set) var items: [MediaItem] = []

    private let storageKey = "ios_media_player_items_v1"
    private let completionThreshold: Double = 0.95
    private let minimumProgressThreshold: Double = 0.02

    public init() {
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

    public func loadItems() {
        guard let data = UserDefaults.standard.data(forKey: storageKey) else {
            return
        }

        do {
            let decoded = try JSONDecoder().decode([MediaItem].self, from: data)
            self.items = decoded
        } catch {
            print("Failed to decode media items: \(error.localizedDescription)")
        }
    }

    @discardableResult
    public func saveItem(_ item: MediaItem) -> MediaItem {
        if let index = items.firstIndex(where: { $0.id == item.id || $0.url == item.url }) {
            var existing = items[index]
            let resolvedPosition = item.lastPosition > 0 ? item.lastPosition : existing.lastPosition
            let resolvedDuration = item.duration > 0 ? item.duration : existing.duration
            let resolvedCompleted = item.lastPosition > 0 ? item.isCompleted : (existing.isCompleted || item.isCompleted)

            existing.title = item.title.isEmpty ? existing.title : item.title
            if let artist = item.artist { existing.artist = artist }
            if let bookmarkData = item.bookmarkData { existing.bookmarkData = bookmarkData }
            existing.isRemote = item.isRemote
            existing.mediaType = item.mediaType
            existing.lastPosition = resolvedPosition
            existing.duration = resolvedDuration
            existing.isCompleted = resolvedCompleted
            existing.lastPlayedDate = max(existing.lastPlayedDate, item.lastPlayedDate)

            items[index] = existing
            persist()
            return existing
        } else {
            items.insert(item, at: 0)
            persist()
            return item
        }
    }

    public func deleteItem(withId id: UUID) {
        items.removeAll { $0.id == id }
        persist()
    }

    public func updateProgress(for id: UUID, position: TimeInterval, duration: TimeInterval) {
        guard let index = items.firstIndex(where: { $0.id == id }) else { return }

        var item = items[index]
        item.lastPosition = position
        if duration > 0 {
            item.duration = duration
        }
        item.lastPlayedDate = Date()

        if item.duration > 0 && (position / item.duration) >= completionThreshold {
            item.isCompleted = true
        } else if position < (item.duration * 0.9) {
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

    public func clearAll() {
        items.removeAll()
        UserDefaults.standard.removeObject(forKey: storageKey)
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
            print("Failed to create bookmark for \(url): \(error.localizedDescription)")
            return nil
        }
    }

    private func persist() {
        do {
            let data = try JSONEncoder().encode(items)
            UserDefaults.standard.set(data, forKey: storageKey)
        } catch {
            print("Failed to encode media items: \(error.localizedDescription)")
        }
    }
}
