import AVKit
import Foundation
import Combine

@MainActor
public final class PictureInPictureManager: NSObject, ObservableObject {
    public static let shared = PictureInPictureManager()

    @Published public private(set) var isPiPActive = false
    @Published public private(set) var isPiPPossible = false

    public var onRestoreUserInterface: ((@escaping (Bool) -> Void) -> Void)?

    private var pipController: AVPictureInPictureController?
    private var pipPossibleObservation: NSKeyValueObservation?

    public var isPiPSupported: Bool {
        return AVPictureInPictureController.isPictureInPictureSupported()
    }

    public override init() {
        super.init()
    }

    deinit {
        pipPossibleObservation?.invalidate()
    }

    public func setup(with playerLayer: AVPlayerLayer) {
        guard isPiPSupported else { return }

        pipPossibleObservation?.invalidate()
        pipPossibleObservation = nil

        if let existing = pipController, existing.isPictureInPictureActive {
            existing.stopPictureInPicture()
        }

        pipController = AVPictureInPictureController(playerLayer: playerLayer)
        pipController?.delegate = self
        pipController?.canStartPictureInPictureAutomaticallyFromInline = true

        pipPossibleObservation = pipController?.observe(\.isPictureInPicturePossible, options: [.initial, .new]) { [weak self] controller, _ in
            Task { @MainActor [weak self] in
                self?.isPiPPossible = controller.isPictureInPicturePossible
            }
        }
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
}

@preconcurrency extension PictureInPictureManager: AVPictureInPictureControllerDelegate {
    public func pictureInPictureControllerWillStartPictureInPicture(_ pictureInPictureController: AVPictureInPictureController) {
        isPiPActive = true
    }

    public func pictureInPictureControllerDidStartPictureInPicture(_ pictureInPictureController: AVPictureInPictureController) {
        isPiPActive = true
    }

    public func pictureInPictureControllerWillStopPictureInPicture(_ pictureInPictureController: AVPictureInPictureController) {
        // Will stop
    }

    public func pictureInPictureControllerDidStopPictureInPicture(_ pictureInPictureController: AVPictureInPictureController) {
        isPiPActive = false
    }

    public func pictureInPictureController(
        _ pictureInPictureController: AVPictureInPictureController,
        failedToStartPictureInPictureWithError error: Error
    ) {
        isPiPActive = false
        print("PiP failed to start: \(error.localizedDescription)")
    }

    public func pictureInPictureController(
        _ pictureInPictureController: AVPictureInPictureController,
        restoreUserInterfaceForPictureInPictureStopWithCompletionHandler completionHandler: @escaping (Bool) -> Void
    ) {
        if let restoreHandler = onRestoreUserInterface {
            restoreHandler(completionHandler)
        } else {
            completionHandler(true)
        }
    }
}
