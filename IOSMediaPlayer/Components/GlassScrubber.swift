import SwiftUI

public struct GlassScrubber: View {
    public let currentTime: TimeInterval
    public let timeline: PlaybackTimeline
    public let bufferedTime: TimeInterval
    public let onSeek: (TimeInterval) -> Void
    /// Called with `true` when a drag begins and `false` when it ends, so callers can keep controls visible.
    public let onEditingChanged: (Bool) -> Void

    @State private var isDragging = false
    @State private var dragPosition: Double = 0.0

    /// How far one VoiceOver swipe up or down moves the playhead.
    private let accessibilityStep: TimeInterval = 10

    public init(
        currentTime: TimeInterval,
        timeline: PlaybackTimeline,
        bufferedTime: TimeInterval,
        onSeek: @escaping (TimeInterval) -> Void,
        onEditingChanged: @escaping (Bool) -> Void = { _ in }
    ) {
        self.currentTime = currentTime
        self.timeline = timeline
        self.bufferedTime = bufferedTime
        self.onSeek = onSeek
        self.onEditingChanged = onEditingChanged
    }

    private var currentFraction: Double {
        guard timeline.length > 0 else { return 0.0 }
        if isDragging {
            return dragPosition
        }
        return timeline.fraction(of: currentTime)
    }

    private var bufferedFraction: Double {
        return timeline.fraction(of: bufferedTime)
    }

    private var accessibilityPositionDescription: String {
        if timeline.isLive {
            let behind = timeline.distanceFromLiveEdge(currentTime)
            return behind > 5 ? "\(MediaItem.formatTime(behind)) behind live" : "Live"
        }
        return "\(MediaItem.formatTime(currentTime)) of \(MediaItem.formatTime(timeline.range.upperBound))"
    }

    public var body: some View {
        GeometryReader { geometry in
            let totalWidth = geometry.size.width
            let activeWidth = totalWidth * currentFraction
            let bufferedWidth = totalWidth * bufferedFraction

            ZStack(alignment: .leading) {
                // Background Track
                Capsule()
                    .fill(Color.white.opacity(0.18))
                    .frame(height: isDragging ? 8 : 5)

                // Buffered Track
                Capsule()
                    .fill(Color.white.opacity(0.35))
                    .frame(width: max(0, bufferedWidth), height: isDragging ? 8 : 5)

                // Elapsed Track
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [.white, Color.white.opacity(0.85)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: max(0, activeWidth), height: isDragging ? 8 : 5)

                // Glass Scrubber Thumb
                Circle()
                    .fill(.ultraThinMaterial)
                    .overlay {
                        Circle()
                            .strokeBorder(Color.white.opacity(0.8), lineWidth: 1.5)
                    }
                    .shadow(color: Color.black.opacity(0.3), radius: 4, x: 0, y: 2)
                    .frame(width: isDragging ? 22 : 14, height: isDragging ? 22 : 14)
                    .offset(x: max(0, min(activeWidth - (isDragging ? 11 : 7), totalWidth - (isDragging ? 22 : 14))))
            }
            .frame(maxHeight: .infinity)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        if !isDragging {
                            isDragging = true
                            onEditingChanged(true)
                        }
                        let clampedX = min(max(0, value.location.x), totalWidth)
                        dragPosition = totalWidth > 0 ? (clampedX / totalWidth) : 0
                    }
                    .onEnded { value in
                        let clampedX = min(max(0, value.location.x), totalWidth)
                        let finalFraction = totalWidth > 0 ? (clampedX / totalWidth) : 0
                        isDragging = false
                        onSeek(timeline.time(atFraction: finalFraction))
                        onEditingChanged(false)
                    }
            )
            .animation(.interactiveSpring(response: 0.25, dampingFraction: 0.8), value: isDragging)
        }
        .frame(height: 44)
        .sensoryFeedback(.impact(weight: .light), trigger: isDragging)
        .accessibilityElement()
        .accessibilityLabel("Playback position")
        .accessibilityValue(accessibilityPositionDescription)
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment:
                onSeek(timeline.clamp(currentTime + accessibilityStep))
            case .decrement:
                onSeek(timeline.clamp(currentTime - accessibilityStep))
            @unknown default:
                break
            }
        }
    }
}
