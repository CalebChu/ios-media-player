import SwiftUI

public enum HUDType: Equatable {
    case volume(Float)
    case brightness(Float)
    case seek(targetTime: TimeInterval, delta: TimeInterval)
}

public struct GlassHUDView: View {
    public let type: HUDType

    public init(type: HUDType) {
        self.type = type
    }

    public var body: some View {
        HStack(spacing: 14) {
            iconView
            contentView
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .liquidGlassPill(specularOpacity: 0.5)
        .transition(.asymmetric(
            insertion: .scale(scale: 0.9).combined(with: .opacity),
            removal: .scale(scale: 0.95).combined(with: .opacity)
        ))
    }

    @ViewBuilder
    private var iconView: some View {
        switch type {
        case .volume(let level):
            Image(systemName: volumeIconName(for: level))
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(.white)
                .frame(width: 24)

        case .brightness:
            Image(systemName: "sun.max.fill")
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(.white)
                .frame(width: 24)

        case .seek(_, let delta):
            Image(systemName: delta >= 0 ? "goforward" : "gobackward")
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(.white)
                .frame(width: 24)
        }
    }

    @ViewBuilder
    private var contentView: some View {
        switch type {
        case .volume(let level):
            levelBar(value: level)

        case .brightness(let level):
            levelBar(value: level)

        case .seek(let targetTime, let delta):
            VStack(alignment: .leading, spacing: 2) {
                Text(MediaItem.formatTime(targetTime))
                    .font(.headline.weight(.bold))
                    .fontDesign(.rounded)
                    .foregroundColor(.white)

                let sign = delta >= 0 ? "+" : "-"
                Text("\(sign)\(MediaItem.formatTime(abs(delta)))")
                    .font(.footnote.weight(.medium))
                    .fontDesign(.rounded)
                    .foregroundColor(.white.opacity(0.8))
            }
        }
    }

    private func levelBar(value: Float) -> some View {
        let clamped = min(max(value, 0.0), 1.0)
        return ZStack(alignment: .leading) {
            Capsule()
                .fill(Color.white.opacity(0.25))
                .frame(width: 120, height: 7)

            Capsule()
                .fill(Color.white)
                .frame(width: 120 * CGFloat(clamped), height: 7)
        }
    }

    private func volumeIconName(for level: Float) -> String {
        if level <= 0.01 {
            return "speaker.slash.fill"
        } else if level < 0.33 {
            return "speaker.wave.1.fill"
        } else if level < 0.66 {
            return "speaker.wave.2.fill"
        } else {
            return "speaker.wave.3.fill"
        }
    }
}
