import MediaPlayer
import SwiftUI
import UIKit

public struct GestureOverlayView: View {
    @ObservedObject var playbackManager: PlaybackManager
    public let onSingleTap: () -> Void
    public let onHUDUpdate: (HUDType?) -> Void

    @State private var dragDirection: DragDirection = .none
    @State private var initialBrightness: CGFloat = 0.5
    @State private var initialVolume: Float = 0.5
    @State private var initialSeekTime: TimeInterval = 0
    @State private var currentSeekDelta: TimeInterval = 0
    @State private var volumeSlider: UISlider?
    @State private var hudDismissTask: Task<Void, Never>?
    /// Brightness before the first swipe in this player session, restored when the player closes.
    @State private var brightnessToRestore: CGFloat?

    private enum DragDirection {
        case none
        case verticalLeft
        case verticalRight
        case horizontal
    }

    public init(
        playbackManager: PlaybackManager,
        onSingleTap: @escaping () -> Void,
        onHUDUpdate: @escaping (HUDType?) -> Void
    ) {
        self.playbackManager = playbackManager
        self.onSingleTap = onSingleTap
        self.onHUDUpdate = onHUDUpdate
    }

    public var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Hidden volume view to allow system volume control without system HUD
                HiddenVolumeView(sliderBinding: $volumeSlider)
                    .frame(width: 0, height: 0)
                    .opacity(0.001)

                // Single and double tap detector
                Color.clear
                    .contentShape(Rectangle())
                    .onTapGesture(count: 2, coordinateSpace: .local) { location in
                        let interval = NowPlayingManager.skipInterval
                        let startTime = playbackManager.currentTime
                        if location.x < (geometry.size.width / 2.0) {
                            playbackManager.skipBackward(seconds: interval)
                        } else {
                            playbackManager.skipForward(seconds: interval)
                        }
                        // Report the actual jump, which is shorter near either end of the timeline.
                        let target = playbackManager.currentTime
                        onHUDUpdate(.seek(targetTime: target, delta: target - startTime))
                        scheduleHUDDismiss()
                    }
                    .onTapGesture(count: 1) {
                        onSingleTap()
                    }
            }
            .simultaneousGesture(
                DragGesture(minimumDistance: 10)
                    .onChanged { value in
                        handleDragChanged(value: value, size: geometry.size)
                    }
                    .onEnded { value in
                        handleDragEnded(value: value)
                    }
            )
        }
        .onDisappear {
            hudDismissTask?.cancel()
            if let brightness = brightnessToRestore, let screen = currentScreen {
                screen.brightness = brightness
            }
        }
    }

    /// The screen showing the player. Replaces the deprecated `UIScreen.main`.
    private var currentScreen: UIScreen? {
        return UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first { $0.activationState == .foregroundActive }?
            .screen
    }

    private func handleDragChanged(value: DragGesture.Value, size: CGSize) {
        let translation = value.translation
        let startLocation = value.startLocation

        if dragDirection == .none {
            hudDismissTask?.cancel()
            let isHorizontal = abs(translation.width) > abs(translation.height)
            if isHorizontal {
                dragDirection = .horizontal
                initialSeekTime = playbackManager.currentTime
            } else if startLocation.x < (size.width / 2.0) {
                dragDirection = .verticalLeft
                initialBrightness = currentScreen?.brightness ?? 0.5
                if brightnessToRestore == nil {
                    brightnessToRestore = initialBrightness
                }
            } else {
                dragDirection = .verticalRight
                initialVolume = volumeSlider?.value ?? AVAudioSession.sharedInstance().outputVolume
            }
        }

        switch dragDirection {
        case .verticalLeft:
            let delta = -translation.height / (size.height * 0.75)
            let newBrightness = min(max(initialBrightness + delta, 0.0), 1.0)
            currentScreen?.brightness = newBrightness
            onHUDUpdate(.brightness(Float(newBrightness)))

        case .verticalRight:
            let delta = Float(-translation.height / (size.height * 0.75))
            let newVolume = min(max(initialVolume + delta, 0.0), 1.0)
            setSystemVolume(newVolume)
            onHUDUpdate(.volume(newVolume))

        case .horizontal:
            let timeline = playbackManager.timeline
            let factor: Double = timeline.length > 300 ? 120 : 60
            let deltaSeconds = Double(translation.width / size.width) * factor
            let targetTime = timeline.clamp(initialSeekTime + deltaSeconds)
            currentSeekDelta = targetTime - initialSeekTime
            onHUDUpdate(.seek(targetTime: targetTime, delta: currentSeekDelta))

        case .none:
            break
        }
    }

    private func handleDragEnded(value: DragGesture.Value) {
        if dragDirection == .horizontal {
            let targetTime = playbackManager.timeline.clamp(initialSeekTime + currentSeekDelta)
            playbackManager.seek(to: targetTime)
        }

        dragDirection = .none
        scheduleHUDDismiss()
    }

    private func setSystemVolume(_ volume: Float) {
        if let slider = volumeSlider {
            DispatchQueue.main.async {
                slider.setValue(volume, animated: false)
            }
        }
    }

    /// Hides the HUD 1.2s after the latest update. Each call replaces the previous timer, so an
    /// earlier gesture can't hide a newer HUD early.
    private func scheduleHUDDismiss() {
        hudDismissTask?.cancel()
        hudDismissTask = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(1200))
            guard !Task.isCancelled else { return }
            onHUDUpdate(nil)
        }
    }
}

private struct HiddenVolumeView: UIViewRepresentable {
    @Binding var sliderBinding: UISlider?

    func makeUIView(context: Context) -> MPVolumeView {
        let volumeView = MPVolumeView(frame: .zero)
        volumeView.clipsToBounds = true
        for subview in volumeView.subviews {
            if let slider = subview as? UISlider {
                DispatchQueue.main.async {
                    self.sliderBinding = slider
                }
                break
            }
        }
        return volumeView
    }

    func updateUIView(_ uiView: MPVolumeView, context: Context) {}
}
