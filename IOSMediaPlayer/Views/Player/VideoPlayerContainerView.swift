import SwiftUI

public struct VideoPlayerContainerView: View {
    @ObservedObject var playbackManager: PlaybackManager
    @EnvironmentObject private var settingsStore: GestureSettingsStore
    @Environment(\.dismiss) private var dismiss

    @State private var areControlsVisible = true
    @State private var activeHUD: HUDType?
    @State private var autoHideTimerTask: Task<Void, Never>?
    /// True while the user is scrubbing or has a control menu open; auto-hide waits until it clears.
    @State private var isInteractingWithControls = false
    /// Vertical offset driven by the swipe-down-to-exit gesture.
    @State private var swipeDownOffset: CGFloat = 0

    public init(playbackManager: PlaybackManager) {
        self.playbackManager = playbackManager
    }

    public var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            // Video rendering layer
            AVPlayerLayerView(
                player: playbackManager.player,
                videoGravity: playbackManager.videoGravity
            )
            .ignoresSafeArea()

            // Gesture detection layer
            GestureOverlayView(
                playbackManager: playbackManager,
                settings: settingsStore,
                onSingleTap: {
                    toggleControls()
                },
                onHUDUpdate: { hud in
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                        activeHUD = hud
                    }
                    resetAutoHideTimer()
                },
                onSwipeDownChanged: { distance in
                    swipeDownOffset = distance
                    autoHideTimerTask?.cancel()
                },
                onSwipeDownEnded: { shouldDismiss in
                    if shouldDismiss {
                        playbackManager.persistCurrentProgress()
                        dismiss()
                    } else {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            swipeDownOffset = 0
                        }
                        resetAutoHideTimer()
                    }
                }
            )
            .ignoresSafeArea()

            // Floating Center HUD Toast
            if let hud = activeHUD {
                GlassHUDView(type: hud)
                    .zIndex(10)
            }

            // Buffering / Loading Indicator
            if playbackManager.playbackState == .buffering || playbackManager.playbackState == .loading {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    .scaleEffect(1.6)
                    .padding(24)
                    .liquidGlassPill(specularOpacity: 0.4)
                    .zIndex(5)
            }

            // Error Overlay
            if case .failed(let message) = playbackManager.playbackState {
                VStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 32))
                        .foregroundColor(.yellow)

                    Text("Playback Error")
                        .font(.headline)
                        .foregroundColor(.white)

                    Text(message)
                        .font(.footnote)
                        .foregroundColor(.white.opacity(0.8))
                        .multilineTextAlignment(.center)

                    Button("Dismiss") {
                        playbackManager.stop()
                        dismiss()
                    }
                    .padding(.horizontal, 16)
                    .frame(minHeight: 44)
                    .liquidGlassPill(specularOpacity: 0.4, isInteractive: true)
                }
                .padding(24)
                .liquidGlass(cornerRadius: 24, specularOpacity: 0.4)
                .zIndex(6)
            }

            // Top and Bottom Player Toolbars
            if areControlsVisible {
                PlayerOverlayView(
                    playbackManager: playbackManager,
                    onDismiss: {
                        playbackManager.persistCurrentProgress()
                        dismiss()
                    },
                    onInteractionChanged: { isInteracting in
                        isInteractingWithControls = isInteracting
                        if isInteracting {
                            autoHideTimerTask?.cancel()
                        } else {
                            resetAutoHideTimer()
                        }
                    },
                    onInteraction: {
                        resetAutoHideTimer()
                    }
                )
                .zIndex(8)
            }
        }
        .offset(y: swipeDownOffset)
        .opacity(swipeDownOffset > 0 ? max(0.4, 1.0 - Double(swipeDownOffset / 500.0)) : 1.0)
        .statusBarHidden(!areControlsVisible)
        .onAppear {
            scheduleAutoHideTimer()
        }
        .onDisappear {
            autoHideTimerTask?.cancel()
            playbackManager.persistCurrentProgress()
        }
        .onChange(of: playbackManager.playbackState) { _, newState in
            if newState == .playing {
                scheduleAutoHideTimer()
            }
        }
    }

    private func toggleControls() {
        // A tap on the video also dismisses any open menu, so stop treating the controls as in use.
        isInteractingWithControls = false
        withAnimation(.easeInOut(duration: 0.25)) {
            areControlsVisible.toggle()
        }
        if areControlsVisible {
            scheduleAutoHideTimer()
        } else {
            autoHideTimerTask?.cancel()
        }
    }

    private func resetAutoHideTimer() {
        if areControlsVisible {
            scheduleAutoHideTimer()
        }
    }

    private func scheduleAutoHideTimer() {
        autoHideTimerTask?.cancel()
        autoHideTimerTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(4))
            guard !Task.isCancelled,
                  !isInteractingWithControls,
                  playbackManager.isPlaying else { return }
            withAnimation(.easeInOut(duration: 0.25)) {
                areControlsVisible = false
            }
        }
    }
}
