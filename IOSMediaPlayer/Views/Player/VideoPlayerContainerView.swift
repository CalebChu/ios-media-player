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
            // Background backdrop: stays fixed, dims out as video pulls down
            Color.black
                .opacity(swipeDownOffset > 0 ? max(0.0, 1.0 - Double(swipeDownOffset / 400.0)) : 1.0)
                .ignoresSafeArea()

            // Video rendering layer: moves with swipeDownOffset
            AVPlayerLayerView(
                player: playbackManager.player,
                videoGravity: playbackManager.videoGravity
            )
            .ignoresSafeArea()
            .offset(y: swipeDownOffset)

            // Gesture detection layer: stays STATIONARY at root window coordinates.
            // This prevents the gesture's coordinate space from moving with the offset,
            // completely eliminating the oscillation/flicker feedback loop.
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

            // Floating Center HUD Toast (moves with video)
            if let hud = activeHUD {
                GlassHUDView(type: hud)
                    .offset(y: swipeDownOffset)
                    .zIndex(10)
            }

            // Buffering / Loading Indicator (moves with video)
            if playbackManager.playbackState == .buffering || playbackManager.playbackState == .loading {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    .scaleEffect(1.6)
                    .padding(24)
                    .liquidGlassPill(specularOpacity: 0.4)
                    .offset(y: swipeDownOffset)
                    .zIndex(5)
            }

            // Error Overlay (moves with video)
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
                .offset(y: swipeDownOffset)
                .zIndex(6)
            }

            // Top and Bottom Player Toolbars (on top of gesture layer, moves with video)
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
                .offset(y: swipeDownOffset)
                .zIndex(8)
            }
        }
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
