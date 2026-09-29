import SwiftUI

public struct GlassScrubber: View {
    public let currentTime: TimeInterval
    public let duration: TimeInterval
    public let bufferedTime: TimeInterval
    public let onSeek: (TimeInterval) -> Void

    @State private var isDragging = false
    @State private var dragPosition: Double = 0.0
    private let impactFeedback = UIImpactFeedbackGenerator(style: .light)

    public init(
        currentTime: TimeInterval,
        duration: TimeInterval,
        bufferedTime: TimeInterval,
        onSeek: @escaping (TimeInterval) -> Void
    ) {
        self.currentTime = currentTime
        self.duration = duration
        self.bufferedTime = bufferedTime
        self.onSeek = onSeek
    }

    private var currentFraction: Double {
        guard duration > 0 else { return 0.0 }
        if isDragging {
            return dragPosition
        }
        let fraction = currentTime / duration
        return min(max(fraction, 0.0), 1.0)
    }

    private var bufferedFraction: Double {
        guard duration > 0 else { return 0.0 }
        let fraction = bufferedTime / duration
        return min(max(fraction, 0.0), 1.0)
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
                            impactFeedback.impactOccurred()
                        }
                        let clampedX = min(max(0, value.location.x), totalWidth)
                        let newFraction = totalWidth > 0 ? (clampedX / totalWidth) : 0
                        dragPosition = newFraction
                    }
                    .onEnded { value in
                        let clampedX = min(max(0, value.location.x), totalWidth)
                        let finalFraction = totalWidth > 0 ? (clampedX / totalWidth) : 0
                        let targetTime = finalFraction * duration
                        isDragging = false
                        onSeek(targetTime)
                        impactFeedback.impactOccurred()
                    }
            )
            .animation(.interactiveSpring(response: 0.25, dampingFraction: 0.8), value: isDragging)
        }
        .frame(height: 28)
    }
}
