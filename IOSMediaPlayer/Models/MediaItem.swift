import Foundation

public struct MediaItem: Identifiable, Codable, Equatable, Hashable {
    public let id: UUID
    public var title: String
    public var artist: String?
    public var url: URL
    public var isRemote: Bool
    public var bookmarkData: Data?
    public var duration: TimeInterval
    public var lastPosition: TimeInterval
    public var lastPlayedDate: Date
    public var isCompleted: Bool
    public var mediaType: MediaType

    public enum MediaType: String, Codable {
        case video
        case audio
    }

    public init(
        id: UUID = UUID(),
        title: String,
        artist: String? = nil,
        url: URL,
        isRemote: Bool,
        bookmarkData: Data? = nil,
        duration: TimeInterval = 0,
        lastPosition: TimeInterval = 0,
        lastPlayedDate: Date = Date(),
        isCompleted: Bool = false,
        mediaType: MediaType = .video
    ) {
        self.id = id
        self.title = title
        self.artist = artist
        self.url = url
        self.isRemote = isRemote
        self.bookmarkData = bookmarkData
        self.duration = duration
        self.lastPosition = lastPosition
        self.lastPlayedDate = lastPlayedDate
        self.isCompleted = isCompleted
        self.mediaType = mediaType
    }

    public var progressFraction: Double {
        guard duration > 0 else { return 0 }
        let fraction = lastPosition / duration
        return min(max(fraction, 0.0), 1.0)
    }

    public var formattedDuration: String {
        return Self.formatTime(duration)
    }

    public var formattedLastPosition: String {
        return Self.formatTime(lastPosition)
    }

    public var formattedRemainingTime: String {
        let remaining = max(0, duration - lastPosition)
        return "-" + Self.formatTime(remaining)
    }

    public static func formatTime(_ time: TimeInterval) -> String {
        guard !time.isNaN && !time.isInfinite && time >= 0 else {
            return "00:00"
        }
        let totalSeconds = Int(time)
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let seconds = totalSeconds % 60

        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%02d:%02d", minutes, seconds)
        }
    }

    public func resolveSecurityScopedURL() -> URL? {
        guard let data = bookmarkData else {
            return url
        }

        var isStale = false
        do {
            let resolved = try URL(
                resolvingBookmarkData: data,
                options: [.withoutUI],
                relativeTo: nil,
                bookmarkDataIsStale: &isStale
            )
            return resolved
        } catch {
            return url
        }
    }
}
