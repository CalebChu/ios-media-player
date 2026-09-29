import AVFoundation
import SwiftUI
import UIKit

public struct AVPlayerLayerView: UIViewRepresentable {
    public let player: AVPlayer
    public let videoGravity: AVLayerVideoGravity

    public init(player: AVPlayer, videoGravity: AVLayerVideoGravity = .resizeAspect) {
        self.player = player
        self.videoGravity = videoGravity
    }

    public func makeUIView(context: Context) -> PlayerContainerUIView {
        let view = PlayerContainerUIView()
        view.playerLayer.player = player
        view.playerLayer.videoGravity = videoGravity
        view.backgroundColor = .black

        PictureInPictureManager.shared.setup(with: view.playerLayer)
        return view
    }

    public func updateUIView(_ uiView: PlayerContainerUIView, context: Context) {
        if uiView.playerLayer.player != player {
            uiView.playerLayer.player = player
            PictureInPictureManager.shared.setup(with: uiView.playerLayer)
        }
        if uiView.playerLayer.videoGravity != videoGravity {
            uiView.playerLayer.videoGravity = videoGravity
        }
    }

    public final class PlayerContainerUIView: UIView {
        public override static var layerClass: AnyClass {
            return AVPlayerLayer.self
        }

        public var playerLayer: AVPlayerLayer {
            return layer as! AVPlayerLayer
        }

        public override func layoutSubviews() {
            super.layoutSubviews()
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            playerLayer.frame = bounds
            CATransaction.commit()
        }
    }
}
