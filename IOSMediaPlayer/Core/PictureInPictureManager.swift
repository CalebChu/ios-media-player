import AVKit
import Combine
import Foundation
import OSLog

@MainActor
public final class PictureInPictureManager: NSObject, ObservableObject {
    public static let shared = PictureInPictureManager()

    @Published public private(set) var isPiPActive = false
    @Published public private(set) var isPiPPossible = false

    /// Asks the UI to present the full-screen player so PiP can hand playback back to it.
    /// The restore finishes once the player's video view is back in a window.
    public var onRestoreUserInterface: (() -> Void)?

    /// The one view that renders video. Player presentations embed this view instead of creating
    /// their own layer, so the PiP controller is created once and never replaced while active.
    public let playerView = PlayerLayerUIView()

    private var pipController: AVPictureInPictureController?
    private var pipPossibleObservation: NSKeyValueObservation?
    private var pendingRestoreCompletion: ((Bool) -> Void)?
    private let logger = Logger(subsystem: "com.calebchu.iosmediaplayer", category: "PictureInPicture")

    /// If the player never reappears (for example, the presentation is blocked), finish the restore anyway
    /// so AVKit doesn't wait indefinitely.
    private static let restoreTimeout: Duration = .seconds(2)

    public var isPiPSupported: Bool {
        return AVPictureInPictureController.isPictureInPictureSupported()
    }

    private override init() {
        super.init()
    }

    public func attach(player: AVPlayer) {
        if playerView.playerLayer.player !== player {
            playerView.playerLayer.player = player
        }

        guard isPiPSupported, pipController == nil,
              let controller = AVPictureInPictureController(playerLayer: playerView.playerLayer) else { return }

        controller.delegate = self
        controller.canStartPictureInPictureAutomaticallyFromInline = true
        pipController = controller

        pipPossibleObservation = controller.observe(\.isPictureInPicturePossible, options: [.initial, .new]) { [weak self] controller, _ in
            let isPossible = controller.isPictureInPicturePossible
            Task { @MainActor [weak self] in
                self?.isPiPPossible = isPossible
            }
        }
    }

    /// Called by the player's host view whenever it enters a window.
    public func playerViewDidAppear() {
        completePendingRestore(true)
    }

    public func startPiP() {
        guard let controller = pipController, controller.isPictureInPicturePossible else { return }
        controller.startPictureInPicture()
    }

    public func stopPiP() {
        guard let controller = pipController, controller.isPictureInPictureActive else { return }
        controller.stopPictureInPicture()
    }

    public func togglePiP() {
        if isPiPActive {
            stopPiP()
        } else {
            startPiP()
        }
    }

    private func completePendingRestore(_ restored: Bool) {
        guard let completion = pendingRestoreCompletion else { return }
        pendingRestoreCompletion = nil
        completion(restored)
    }
}

extension PictureInPictureManager: @preconcurrency AVPictureInPictureControllerDelegate {
    public func pictureInPictureControllerWillStartPictureInPicture(_ pictureInPictureController: AVPictureInPictureController) {
        isPiPActive = true
    }

    public func pictureInPictureControllerDidStartPictureInPicture(_ pictureInPictureController: AVPictureInPictureController) {
        isPiPActive = true
    }

    public func pictureInPictureControllerDidStopPictureInPicture(_ pictureInPictureController: AVPictureInPictureController) {
        isPiPActive = false
        completePendingRestore(false)
    }

    public func pictureInPictureController(
        _ pictureInPictureController: AVPictureInPictureController,
        failedToStartPictureInPictureWithError error: Error
    ) {
        isPiPActive = false
        logger.error("PiP failed to start: \(error.localizedDescription, privacy: .public)")
    }

    public func pictureInPictureController(
        _ pictureInPictureController: AVPictureInPictureController,
        restoreUserInterfaceForPictureInPictureStopWithCompletionHandler completionHandler: @escaping (Bool) -> Void
    ) {
        // The player is still on screen: nothing to present.
        if playerView.window != nil {
            completionHandler(true)
            return
        }

        guard let presentPlayer = onRestoreUserInterface else {
            completionHandler(false)
            return
        }

        completePendingRestore(false)
        pendingRestoreCompletion = completionHandler
        presentPlayer()

        Task { @MainActor [weak self] in
            try? await Task.sleep(for: PictureInPictureManager.restoreTimeout)
            self?.completePendingRestore(true)
        }
    }
}
