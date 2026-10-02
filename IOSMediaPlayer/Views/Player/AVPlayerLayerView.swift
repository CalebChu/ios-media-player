import AVFoundation
import SwiftUI
import UIKit

/// Shows the app's shared video view. Every presentation embeds the same `PlayerLayerUIView`,
/// so Picture in Picture keeps one controller and can restore into whichever player is on screen.
public struct AVPlayerLayerView: UIViewRepresentable {
    public let player: AVPlayer
    public let videoGravity: AVLayerVideoGravity

    public init(player: AVPlayer, videoGravity: AVLayerVideoGravity = .resizeAspect) {
        self.player = player
        self.videoGravity = videoGravity
    }

    public func makeUIView(context: Context) -> PlayerHostView {
        let host = PlayerHostView()
        host.backgroundColor = .black
        return host
    }

    public func updateUIView(_ host: PlayerHostView, context: Context) {
        let pipManager = PictureInPictureManager.shared
        pipManager.attach(player: player)
        host.embedPlayerView()

        let playerLayer = pipManager.playerView.playerLayer
        if playerLayer.videoGravity != videoGravity {
            playerLayer.videoGravity = videoGravity
        }
    }
}

/// Hosts the shared `PlayerLayerUIView` and reports when it is back on screen.
public final class PlayerHostView: UIView {
    func embedPlayerView() {
        let playerView = PictureInPictureManager.shared.playerView
        guard playerView.superview !== self else { return }
        playerView.removeFromSuperview()
        playerView.frame = bounds
        playerView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        addSubview(playerView)
    }

    public override func didMoveToWindow() {
        super.didMoveToWindow()
        guard window != nil else { return }
        embedPlayerView()
        PictureInPictureManager.shared.playerViewDidAppear()
    }
}

/// A view backed by an `AVPlayerLayer`, so the layer always matches the view's bounds.
public final class PlayerLayerUIView: UIView {
    public override static var layerClass: AnyClass {
        return AVPlayerLayer.self
    }

    public var playerLayer: AVPlayerLayer {
        return layer as! AVPlayerLayer
    }

    public override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .black
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        backgroundColor = .black
    }
}
