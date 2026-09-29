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
                Color.clear
                    .contentShape(Rectangle())

                // Hidden volume view to allow system volume control without system HUD
                HiddenVolumeView(sliderBinding: $volumeSlider)
                    .frame(width: 0, height: 0)
                    .opacity(0.001)

                // Double tap left / right detectors
                HStack(spacing: 0) {
                    Color.clear
                        .contentShape(Rectangle())
                        .onTapGesture(count: 2) {
                            playbackManager.skipBackward(seconds: 10)
                            onHUDUpdate(.seek(targetTime: max(0, playbackManager.currentTime - 10), delta: -10))
                            scheduleHUDDismiss()
                        }
                    Color.clear
                        .contentShape(Rectangle())
                        .onTapGesture(count: 2) {
                            playbackManager.skipForward(seconds: 10)
                            let target = min(playbackManager.duration, playbackManager.currentTime + 10)
                            onHUDUpdate(.seek(targetTime: target, delta: 10))
                            scheduleHUDDismiss()
                        }
                }

                // Single tap detector
                Color.clear
                    .contentShape(Rectangle())
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
    }

    private func handleDragChanged(value: DragGesture.Value, size: CGSize) {
        let translation = value.translation
        let startLocation = value.startLocation

        if dragDirection == .none {
            let isHorizontal = abs(translation.width) > abs(translation.height)
            if isHorizontal {
                dragDirection = .horizontal
                initialSeekTime = playbackManager.currentTime
            } else if startLocation.x < (size.width / 2.0) {
                dragDirection = .verticalLeft
                initialBrightness = UIScreen.main.brightness
            } else {
                dragDirection = .verticalRight
                initialVolume = volumeSlider?.value ?? AVAudioSession.sharedInstance().outputVolume
            }
        }

        switch dragDirection {
        case .verticalLeft:
            let delta = -translation.height / (size.height * 0.75)
            let newBrightness = min(max(initialBrightness + delta, 0.0), 1.0)
            UIScreen.main.brightness = newBrightness
            onHUDUpdate(.brightness(Float(newBrightness)))

        case .verticalRight:
            let delta = Float(-translation.height / (size.height * 0.75))
            let newVolume = min(max(initialVolume + delta, 0.0), 1.0)
            setSystemVolume(newVolume)
            onHUDUpdate(.volume(newVolume))

        case .horizontal:
            let factor: Double = playbackManager.duration > 300 ? 120 : 60
            let deltaSeconds = Double(translation.width / size.width) * factor
            let targetTime = min(max(0, initialSeekTime + deltaSeconds), playbackManager.duration)
            currentSeekDelta = targetTime - initialSeekTime
            onHUDUpdate(.seek(targetTime: targetTime, delta: currentSeekDelta))

        case .none:
            break
        }
    }

    private func handleDragEnded(value: DragGesture.Value) {
        if dragDirection == .horizontal {
            let targetTime = min(max(0, initialSeekTime + currentSeekDelta), playbackManager.duration)
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

    private func scheduleHUDDismiss() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
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
