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
                    duration: playbackManager.duration,
                    bufferedTime: playbackManager.bufferedTime,
                    onSeek: { time in
                        playbackManager.seek(to: time)
                    }
                )

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
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .liquidGlass(cornerRadius: 28, specularOpacity: 0.4)
    }

    private var transportControls: some View {
        HStack(spacing: 28) {
            // Playback Speed Menu
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
                    .frame(minWidth: 44, minHeight: 34)
            }
            .liquidGlassPill(specularOpacity: 0.35)

            Spacer()

            // Skip Backward
            Button(action: { playbackManager.skipBackward(seconds: 10) }) {
                Image(systemName: "gobackward.10")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(width: 44, height: 44)
            }

            // Play / Pause
            Button(action: { playbackManager.togglePlayPause() }) {
                Image(systemName: playbackManager.isPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(.white)
                    .frame(width: 64, height: 64)
            }
            .liquidGlassPill(specularOpacity: 0.5)

            // Skip Forward
            Button(action: { playbackManager.skipForward(seconds: 10) }) {
                Image(systemName: "goforward.10")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(width: 44, height: 44)
            }

            Spacer()

            // Stop / Reset Button
            Button(action: { playbackManager.seek(to: 0) }) {
                Image(systemName: "backward.end.fill")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(minWidth: 44, minHeight: 34)
            }
            .liquidGlassPill(specularOpacity: 0.35)
        }
    }
}
