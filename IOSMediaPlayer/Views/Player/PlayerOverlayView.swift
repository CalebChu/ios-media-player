import AVFoundation
import SwiftUI

public struct PlayerOverlayView: View {
    @ObservedObject var playbackManager: PlaybackManager
    @ObservedObject var pipManager = PictureInPictureManager.shared
    public let onDismiss: () -> Void

    public init(playbackManager: PlaybackManager, onDismiss: @escaping () -> Void) {
        self.playbackManager = playbackManager
        self.onDismiss = onDismiss
    }

    public var body: some View {
        VStack(spacing: 0) {
            topBar
            Spacer()
            bottomBar
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .transition(.opacity.animation(.easeInOut(duration: 0.25)))
    }

    // Top Floating Toolbar
    @ViewBuilder
    private var topBar: some View {
        if #available(iOS 26, *) {
            GlassEffectContainer {
                topBarContent
            }
        } else {
            topBarContent
        }
    }

    private var topBarContent: some View {
        HStack(spacing: 12) {
            Button(action: onDismiss) {
                Image(systemName: "chevron.down")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.white)
                    .frame(width: 38, height: 38)
            }
            .liquidGlassPill(specularOpacity: 0.4)

            VStack(alignment: .leading, spacing: 2) {
                Text(playbackManager.currentMediaItem?.title ?? "Playing Media")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.white)
                    .lineLimit(1)

                if let artist = playbackManager.currentMediaItem?.artist, !artist.isEmpty {
                    Text(artist)
                        .font(.system(size: 12, weight: .regular))
                        .foregroundColor(.white.opacity(0.75))
                        .lineLimit(1)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .liquidGlass(cornerRadius: 18, specularOpacity: 0.3)

            // Video Gravity Toggle
            Button(action: { playbackManager.toggleVideoGravity() }) {
                Image(systemName: playbackManager.videoGravity == .resizeAspect ? "arrow.up.left.and.arrow.down.right" : "arrow.down.right.and.arrow.up.left")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(width: 38, height: 38)
            }
            .liquidGlassPill(specularOpacity: 0.4)

            // Picture-in-Picture Button
            if pipManager.isPiPSupported {
                Button(action: { pipManager.togglePiP() }) {
                    Image(systemName: pipManager.isPiPActive ? "pip.exit" : "pip.enter")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(width: 38, height: 38)
                }
                .liquidGlassPill(specularOpacity: 0.4)
            }
        }
    }

    // Bottom Floating Control Bar
    private var bottomBar: some View {
        VStack(spacing: 10) {
            // Scrubber & Times
            VStack(spacing: 4) {
                GlassScrubber(
                    currentTime: playbackManager.currentTime,
                    timeline: playbackManager.timeline,
                    bufferedTime: playbackManager.bufferedTime,
                    onSeek: { time in
                        playbackManager.seek(to: time)
                    }
                )

                timeLabels
                    .padding(.horizontal, 4)
            }

            // Transport Controls
            if #available(iOS 26, *) {
                GlassEffectContainer {
                    transportControls
                }
            } else {
                transportControls
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .liquidGlass(cornerRadius: 28, specularOpacity: 0.4)
    }

    @ViewBuilder
    private var timeLabels: some View {
        if playbackManager.isLive {
            let behindLive = playbackManager.timeline.distanceFromLiveEdge(playbackManager.currentTime)
            HStack {
                Text(behindLive > 5 ? "-" + MediaItem.formatTime(behindLive) : "")
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundColor(.white.opacity(0.85))

                Spacer()

                Button(action: { playbackManager.seekToLiveEdge() }) {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(behindLive > 5 ? Color.white.opacity(0.5) : Color.red)
                            .frame(width: 6, height: 6)
                        Text("LIVE")
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                    }
                    .foregroundColor(.white)
                }
                .disabled(behindLive <= 5)
                .accessibilityLabel(behindLive > 5 ? "Jump to live" : "Live")
            }
        } else {
            HStack {
                Text(MediaItem.formatTime(playbackManager.currentTime))
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundColor(.white.opacity(0.85))

                Spacer()

                let remaining = max(0, playbackManager.duration - playbackManager.currentTime)
                Text("-" + MediaItem.formatTime(remaining))
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundColor(.white.opacity(0.85))
            }
        }
    }

    @ViewBuilder
    private var transportControls: some View {
        ViewThatFits(in: .horizontal) {
            // 1. Standard layout (generous spacing for normal portrait & landscape)
            transportControlsRow(spacing: 18, playSize: 62, playIconSize: 26, skipSize: 42, skipIconSize: 20)

            // 2. Adaptive compact row (for narrow screens like iPhone SE / mini)
            transportControlsRow(spacing: 10, playSize: 52, playIconSize: 22, skipSize: 36, skipIconSize: 18)

            // 3. Compact two-tier arrangement (for extreme narrow widths or large Dynamic Type)
            compactTwoTierControls
        }
    }

    @ViewBuilder
    private func transportControlsRow(
        spacing: CGFloat,
        playSize: CGFloat,
        playIconSize: CGFloat,
        skipSize: CGFloat,
        skipIconSize: CGFloat
    ) -> some View {
        HStack(spacing: 0) {
            speedMenuButton

            Spacer(minLength: 8)

            HStack(spacing: spacing) {
                skipBackwardButton(size: skipSize, iconSize: skipIconSize)
                playPauseButton(size: playSize, iconSize: playIconSize)
                skipForwardButton(size: skipSize, iconSize: skipIconSize)
            }

            Spacer(minLength: 8)

            resetButton
        }
    }

    @ViewBuilder
    private var compactTwoTierControls: some View {
        VStack(spacing: 8) {
            HStack(spacing: 16) {
                skipBackwardButton(size: 40, iconSize: 20)
                playPauseButton(size: 56, iconSize: 24)
                skipForwardButton(size: 40, iconSize: 20)
            }

            HStack {
                speedMenuButton
                Spacer()
                resetButton
            }
        }
    }

    private var speedMenuButton: some View {
        Menu {
            ForEach(PlaybackSpeed.allCases) { speed in
                Button(action: { playbackManager.setPlaybackSpeed(speed) }) {
                    HStack {
                        Text(speed.title)
                        if playbackManager.playbackSpeed == speed {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        } label: {
            Text(playbackManager.playbackSpeed.title)
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundColor(.white)
                .frame(minWidth: 42, minHeight: 32)
        }
        .liquidGlassPill(specularOpacity: 0.35)
    }

    private func skipBackwardButton(size: CGFloat, iconSize: CGFloat) -> some View {
        Button(action: { playbackManager.skipBackward(seconds: 10) }) {
            Image(systemName: "gobackward.10")
                .font(.system(size: iconSize, weight: .semibold))
                .foregroundColor(.white)
                .frame(width: size, height: size)
        }
        .accessibilityLabel("Skip backward 10 seconds")
    }

    private func playPauseButton(size: CGFloat, iconSize: CGFloat) -> some View {
        Button(action: { playbackManager.togglePlayPause() }) {
            Image(systemName: playbackManager.isPlaying ? "pause.fill" : "play.fill")
                .font(.system(size: iconSize, weight: .bold))
                .foregroundColor(.white)
                .frame(width: size, height: size)
        }
        .liquidGlassPill(specularOpacity: 0.5)
        .accessibilityLabel(playbackManager.isPlaying ? "Pause" : "Play")
    }

    private func skipForwardButton(size: CGFloat, iconSize: CGFloat) -> some View {
        Button(action: { playbackManager.skipForward(seconds: 10) }) {
            Image(systemName: "goforward.10")
                .font(.system(size: iconSize, weight: .semibold))
                .foregroundColor(.white)
                .frame(width: size, height: size)
        }
        .accessibilityLabel("Skip forward 10 seconds")
    }

    private var resetButton: some View {
        Button(action: { playbackManager.seek(to: 0) }) {
            Image(systemName: "backward.end.fill")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.white)
                .frame(minWidth: 42, minHeight: 32)
        }
        .liquidGlassPill(specularOpacity: 0.35)
        .accessibilityLabel("Restart from beginning")
    }
}
