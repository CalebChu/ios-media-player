import AVFoundation
import SwiftUI

public struct PlayerOverlayView: View {
    @ObservedObject var playbackManager: PlaybackManager
    @ObservedObject var pipManager: PictureInPictureManager
    @EnvironmentObject private var settingsStore: GestureSettingsStore
    public let onDismiss: () -> Void
    /// Called with `true` while the user is scrubbing or has the speed menu open, and `false` when
    /// they finish, so the container can keep the controls visible meanwhile.
    public let onInteractionChanged: (Bool) -> Void
    /// Called after any tap on a control, so the container can restart its auto-hide timer.
    public let onInteraction: () -> Void

    @State private var isShowingSettings = false

    /// Apple's minimum comfortable touch target.
    private let minimumHitSize: CGFloat = 44

    public init(
        playbackManager: PlaybackManager,
        pipManager: PictureInPictureManager = .shared,
        onDismiss: @escaping () -> Void,
        onInteractionChanged: @escaping (Bool) -> Void = { _ in },
        onInteraction: @escaping () -> Void = {}
    ) {
        self.playbackManager = playbackManager
        self.pipManager = pipManager
        self.onDismiss = onDismiss
        self.onInteractionChanged = onInteractionChanged
        self.onInteraction = onInteraction
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
        .sheet(isPresented: $isShowingSettings, onDismiss: {
            onInteractionChanged(false)
        }) {
            SettingsView()
                .environmentObject(settingsStore)
        }
    }

    // MARK: - Top bar

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
                    .frame(width: minimumHitSize, height: minimumHitSize)
            }
            .liquidGlassPill(specularOpacity: 0.4, isInteractive: true)
            .accessibilityLabel("Close player")

            VStack(alignment: .leading, spacing: 2) {
                Text(playbackManager.currentMediaItem?.title ?? "Playing Media")
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(.white)
                    .lineLimit(1)

                if let artist = playbackManager.currentMediaItem?.artist, !artist.isEmpty {
                    Text(artist)
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.75))
                        .lineLimit(1)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .liquidGlass(cornerRadius: 18, specularOpacity: 0.3)
            .accessibilityElement(children: .combine)

            Button(action: {
                playbackManager.toggleVideoGravity()
                onInteraction()
            }) {
                Image(systemName: playbackManager.videoGravity == .resizeAspect ? "arrow.up.left.and.arrow.down.right" : "arrow.down.right.and.arrow.up.left")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(width: minimumHitSize, height: minimumHitSize)
            }
            .liquidGlassPill(specularOpacity: 0.4, isInteractive: true)
            .accessibilityLabel(playbackManager.videoGravity == .resizeAspect ? "Zoom to fill" : "Fit to screen")

            if pipManager.isPiPSupported {
                let canTogglePiP = pipManager.isPiPPossible || pipManager.isPiPActive
                Button(action: {
                    pipManager.togglePiP()
                    onInteraction()
                }) {
                    Image(systemName: pipManager.isPiPActive ? "pip.exit" : "pip.enter")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(width: minimumHitSize, height: minimumHitSize)
                }
                .liquidGlassPill(specularOpacity: 0.4, isInteractive: true)
                .disabled(!canTogglePiP)
                .opacity(canTogglePiP ? 1 : 0.4)
                .accessibilityLabel(pipManager.isPiPActive ? "Stop Picture in Picture" : "Start Picture in Picture")
            }

            Button(action: {
                isShowingSettings = true
                onInteraction()
                onInteractionChanged(true)
            }) {
                Image(systemName: "gearshape")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(width: minimumHitSize, height: minimumHitSize)
            }
            .liquidGlassPill(specularOpacity: 0.4, isInteractive: true)
            .accessibilityLabel("Settings")
        }
    }

    // MARK: - Bottom bar

    private var bottomBar: some View {
        VStack(spacing: 10) {
            VStack(spacing: 0) {
                GlassScrubber(
                    currentTime: playbackManager.currentTime,
                    timeline: playbackManager.timeline,
                    bufferedTime: playbackManager.bufferedTime,
                    onSeek: { time in
                        playbackManager.seek(to: time)
                    },
                    onEditingChanged: onInteractionChanged
                )

                timeLabels
                    .padding(.horizontal, 4)
            }

            // The bar itself is glass, so its controls use nested pills rather than a second glass layer.
            transportControls
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
                    .font(.caption.weight(.medium))
                    .fontDesign(.rounded)
                    .foregroundColor(.white.opacity(0.85))

                Spacer()

                Button(action: {
                    playbackManager.seekToLiveEdge()
                    onInteraction()
                }) {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(behindLive > 5 ? Color.white.opacity(0.5) : Color.red)
                            .frame(width: 6, height: 6)
                        Text("LIVE")
                            .font(.caption.weight(.bold))
                            .fontDesign(.rounded)
                    }
                    .foregroundColor(.white)
                    .frame(minHeight: minimumHitSize)
                    .contentShape(Rectangle())
                }
                .disabled(behindLive <= 5)
                .accessibilityLabel(behindLive > 5 ? "Jump to live" : "Live")
            }
        } else {
            HStack {
                Text(MediaItem.formatTime(playbackManager.currentTime))
                    .font(.caption.weight(.medium))
                    .fontDesign(.rounded)
                    .foregroundColor(.white.opacity(0.85))

                Spacer()

                let remaining = max(0, playbackManager.duration - playbackManager.currentTime)
                Text("-" + MediaItem.formatTime(remaining))
                    .font(.caption.weight(.medium))
                    .fontDesign(.rounded)
                    .foregroundColor(.white.opacity(0.85))
            }
            .accessibilityHidden(true)
        }
    }

    @ViewBuilder
    private var transportControls: some View {
        ViewThatFits(in: .horizontal) {
            // 1. Standard layout (generous spacing for normal portrait & landscape)
            transportControlsRow(spacing: 18, playSize: 62, playIconSize: 26, skipIconSize: 20)

            // 2. Adaptive compact row (for narrow screens like iPhone SE / mini)
            transportControlsRow(spacing: 6, playSize: 52, playIconSize: 22, skipIconSize: 18)

            // 3. Compact two-tier arrangement (for extreme narrow widths or large Dynamic Type)
            compactTwoTierControls
        }
    }

    private func transportControlsRow(
        spacing: CGFloat,
        playSize: CGFloat,
        playIconSize: CGFloat,
        skipIconSize: CGFloat
    ) -> some View {
        HStack(spacing: 0) {
            speedMenuButton

            Spacer(minLength: 8)

            HStack(spacing: spacing) {
                skipBackwardButton(iconSize: skipIconSize)
                playPauseButton(size: playSize, iconSize: playIconSize)
                skipForwardButton(iconSize: skipIconSize)
            }

            Spacer(minLength: 8)

            resetButton
        }
    }

    private var compactTwoTierControls: some View {
        VStack(spacing: 8) {
            HStack(spacing: 16) {
                skipBackwardButton(iconSize: 20)
                playPauseButton(size: 56, iconSize: 24)
                skipForwardButton(iconSize: 20)
            }

            HStack {
                speedMenuButton
                Spacer()
                resetButton
            }
        }
    }

    // MARK: - Controls
    //
    // Visible pills can be smaller than 44pt, but each control's tappable frame is at least 44×44.

    private var speedMenuButton: some View {
        Menu {
            ForEach(PlaybackSpeed.allCases) { speed in
                Button(action: {
                    playbackManager.setPlaybackSpeed(speed)
                    onInteractionChanged(false)
                }) {
                    if playbackManager.playbackSpeed == speed {
                        Label(speed.title, systemImage: "checkmark")
                    } else {
                        Text(speed.title)
                    }
                }
            }
        } label: {
            Text(playbackManager.playbackSpeed.title)
                .font(.footnote.weight(.bold))
                .fontDesign(.rounded)
                .foregroundColor(.white)
                .padding(.horizontal, 8)
                .frame(minWidth: 42, minHeight: 32)
                .liquidGlassPill(specularOpacity: 0.35, isNested: true)
                .frame(minWidth: minimumHitSize, minHeight: minimumHitSize)
                .contentShape(Rectangle())
        }
        // Keep the controls visible while the menu is open; picking a speed or tapping the video resumes auto-hide.
        .simultaneousGesture(TapGesture().onEnded { onInteractionChanged(true) })
        .accessibilityLabel("Playback speed")
        .accessibilityValue(playbackManager.playbackSpeed.title)
    }

    private func skipBackwardButton(iconSize: CGFloat) -> some View {
        Button(action: {
            playbackManager.skipBackward(seconds: NowPlayingManager.skipInterval)
            onInteraction()
        }) {
            Image(systemName: "gobackward.10")
                .font(.system(size: iconSize, weight: .semibold))
                .foregroundColor(.white)
                .frame(width: minimumHitSize, height: minimumHitSize)
                .contentShape(Rectangle())
        }
        .accessibilityLabel("Skip backward 10 seconds")
    }

    private func playPauseButton(size: CGFloat, iconSize: CGFloat) -> some View {
        Button(action: {
            playbackManager.togglePlayPause()
            onInteraction()
        }) {
            Image(systemName: playbackManager.isPlaying ? "pause.fill" : "play.fill")
                .font(.system(size: iconSize, weight: .bold))
                .foregroundColor(.white)
                .frame(width: size, height: size)
                .liquidGlassPill(specularOpacity: 0.5, isNested: true)
        }
        .accessibilityLabel(playbackManager.isPlaying ? "Pause" : "Play")
    }

    private func skipForwardButton(iconSize: CGFloat) -> some View {
        Button(action: {
            playbackManager.skipForward(seconds: NowPlayingManager.skipInterval)
            onInteraction()
        }) {
            Image(systemName: "goforward.10")
                .font(.system(size: iconSize, weight: .semibold))
                .foregroundColor(.white)
                .frame(width: minimumHitSize, height: minimumHitSize)
                .contentShape(Rectangle())
        }
        .accessibilityLabel("Skip forward 10 seconds")
    }

    private var resetButton: some View {
        Button(action: {
            playbackManager.seek(to: playbackManager.timeline.range.lowerBound)
            onInteraction()
        }) {
            Image(systemName: "backward.end.fill")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.white)
                .frame(minWidth: 42, minHeight: 32)
                .liquidGlassPill(specularOpacity: 0.35, isNested: true)
                .frame(minWidth: minimumHitSize, minHeight: minimumHitSize)
                .contentShape(Rectangle())
        }
        .accessibilityLabel("Restart from beginning")
    }
}
