import Foundation
import MediaPlayer

public final class NowPlayingManager {
    public static let shared = NowPlayingManager()

    public var onPlay: (() -> Void)?
    public var onPause: (() -> Void)?
    public var onTogglePlayPause: (() -> Void)?
    public var onSkipForward: ((TimeInterval) -> Void)?
    public var onSkipBackward: ((TimeInterval) -> Void)?
    public var onSeek: ((TimeInterval) -> Void)?
    public var onChangeRate: ((Float) -> Void)?

    private var isConfigured = false

    private init() {}

    public func configureRemoteCommands() {
        guard !isConfigured else { return }

        let commandCenter = MPRemoteCommandCenter.shared()

        commandCenter.playCommand.isEnabled = true
        commandCenter.playCommand.addTarget { [weak self] _ in
            self?.onPlay?()
            return .success
        }

        commandCenter.pauseCommand.isEnabled = true
        commandCenter.pauseCommand.addTarget { [weak self] _ in
            self?.onPause?()
            return .success
        }

        commandCenter.togglePlayPauseCommand.isEnabled = true
        commandCenter.togglePlayPauseCommand.addTarget { [weak self] _ in
            self?.onTogglePlayPause?()
            return .success
        }

        commandCenter.skipForwardCommand.isEnabled = true
        commandCenter.skipForwardCommand.preferredIntervals = [15.0]
        commandCenter.skipForwardCommand.addTarget { [weak self] event in
            guard let skipEvent = event as? MPSkipIntervalCommandEvent else {
                self?.onSkipForward?(15.0)
                return .success
            }
            self?.onSkipForward?(skipEvent.interval)
            return .success
        }

        commandCenter.skipBackwardCommand.isEnabled = true
        commandCenter.skipBackwardCommand.preferredIntervals = [15.0]
        commandCenter.skipBackwardCommand.addTarget { [weak self] event in
            guard let skipEvent = event as? MPSkipIntervalCommandEvent else {
                self?.onSkipBackward?(15.0)
                return .success
            }
            self?.onSkipBackward?(skipEvent.interval)
            return .success
        }

        commandCenter.changePlaybackPositionCommand.isEnabled = true
        commandCenter.changePlaybackPositionCommand.addTarget { [weak self] event in
            guard let positionEvent = event as? MPChangePlaybackPositionCommandEvent else {
                return .commandFailed
            }
            self?.onSeek?(positionEvent.positionTime)
            return .success
        }

        commandCenter.changePlaybackRateCommand.isEnabled = true
        commandCenter.changePlaybackRateCommand.supportedPlaybackRates = [0.5, 0.75, 1.0, 1.25, 1.5, 1.75, 2.0]
        commandCenter.changePlaybackRateCommand.addTarget { [weak self] event in
            guard let rateEvent = event as? MPChangePlaybackRateCommandEvent else {
                return .commandFailed
            }
            self?.onChangeRate?(rateEvent.playbackRate)
            return .success
        }

        isConfigured = true
    }

    public func updateNowPlaying(
        title: String,
        artist: String? = nil,
        duration: TimeInterval,
        elapsed: TimeInterval,
        rate: Float
    ) {
        var info: [String: Any] = [
            MPMediaItemPropertyTitle: title,
            MPNowPlayingInfoPropertyPlaybackRate: Double(rate),
            MPNowPlayingInfoPropertyDefaultPlaybackRate: 1.0,
            MPNowPlayingInfoPropertyElapsedPlaybackTime: elapsed
        ]

        if let artist = artist, !artist.isEmpty {
            info[MPMediaItemPropertyArtist] = artist
        }

        if duration > 0 && !duration.isNaN && !duration.isInfinite {
            info[MPMediaItemPropertyPlaybackDuration] = duration
        }

        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
    }

    public func updatePlaybackState(elapsed: TimeInterval, rate: Float) {
        guard var info = MPNowPlayingInfoCenter.default().nowPlayingInfo else { return }
        info[MPNowPlayingInfoPropertyElapsedPlaybackTime] = elapsed
        info[MPNowPlayingInfoPropertyPlaybackRate] = Double(rate)
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
    }

    public func clearNowPlaying() {
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
    }
}
