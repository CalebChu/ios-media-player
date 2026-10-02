import Foundation

/// The span of media the user can move through.
///
/// Finite media spans `0...duration`. A live stream spans its seekable window, which moves
/// forward as the stream continues, so positions in it are not progress through a fixed length.
public struct PlaybackTimeline: Equatable {
    public var range: ClosedRange<TimeInterval>
    public var isLive: Bool

    public static let empty = PlaybackTimeline(range: 0...0, isLive: false)

    public init(range: ClosedRange<TimeInterval>, isLive: Bool) {
        self.range = range
        self.isLive = isLive
    }

    public static func finite(duration: TimeInterval) -> PlaybackTimeline {
        let end = duration.isFinite ? max(0, duration) : 0
        return PlaybackTimeline(range: 0...end, isLive: false)
    }

    public var length: TimeInterval {
        return range.upperBound - range.lowerBound
    }

    public func clamp(_ time: TimeInterval) -> TimeInterval {
        guard time.isFinite else { return range.lowerBound }
        return min(max(time, range.lowerBound), range.upperBound)
    }

    /// Where `time` falls in the timeline, from 0 to 1.
    public func fraction(of time: TimeInterval) -> Double {
        guard length > 0, time.isFinite else { return 0 }
        return min(max((time - range.lowerBound) / length, 0), 1)
    }

    public func time(atFraction fraction: Double) -> TimeInterval {
        let clampedFraction = fraction.isFinite ? min(max(fraction, 0), 1) : 0
        return range.lowerBound + clampedFraction * length
    }

    /// How far `time` is behind the live edge. Zero for finite media.
    public func distanceFromLiveEdge(_ time: TimeInterval) -> TimeInterval {
        guard isLive else { return 0 }
        return max(0, range.upperBound - time)
    }
}
