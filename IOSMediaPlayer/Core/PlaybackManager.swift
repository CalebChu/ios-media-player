import AVFoundation
import Combine
import Foundation
import UIKit

@MainActor
public final class PlaybackManager: ObservableObject {
    public static let shared = PlaybackManager()

    public enum PlaybackState: Equatable {
        case idle
        case loading
        case playing
        case paused
        case buffering
        case failed(String)
    }

    @Published public private(set) var currentMediaItem: MediaItem?
    @Published public private(set) var playbackState: PlaybackState = .idle
    @Published public private(set) var currentTime: TimeInterval = 0
    @Published public private(set) var duration: TimeInterval = 0
    @Published public private(set) var bufferedTime: TimeInterval = 0
    @Published public private(set) var playbackSpeed: PlaybackSpeed = .normal
    @Published public var videoGravity: AVLayerVideoGravity = .resizeAspect

    public let player = AVPlayer()

    private var timeObserverToken: Any?
    private var itemStatusObservation: NSKeyValueObservation?
    private var timeControlStatusObservation: NSKeyValueObservation?
    private var loadedTimeRangesObservation: NSKeyValueObservation?
    private var activeSecurityScopedURL: URL?
    private var cancellables = Set<AnyCancellable>()

    public init() {
        setupAudioSession()
        setupNowPlayingCommands()
        setupNotificationObservers()
    }

    deinit {
        if let token = timeObserverToken {
            player.removeTimeObserver(token)
        }
        activeSecurityScopedURL?.stopAccessingSecurityScopedResource()
    }

    public var isPlaying: Bool {
        return player.timeControlStatus != .paused
    }

    public var progressFraction: Double {
        guard duration > 0 else { return 0 }
        let fraction = currentTime / duration
        return min(max(fraction, 0.0), 1.0)
    }

    public var bufferedFraction: Double {
        guard duration > 0 else { return 0 }
        let fraction = bufferedTime / duration
        return min(max(fraction, 0.0), 1.0)
    }

    public func loadMedia(item: MediaItem, autoPlay: Bool = true) {
        persistCurrentProgress()
        stopAccessingActiveSecurityScopedResource()

        currentMediaItem = item
        playbackState = .loading
        currentTime = item.lastPosition
        duration = item.duration
        bufferedTime = 0

        let targetURL: URL
        if !item.isRemote, let resolved = item.resolveSecurityScopedURL() {
            targetURL = resolved
            if resolved.startAccessingSecurityScopedResource() {
                activeSecurityScopedURL = resolved
            }
        } else {
            targetURL = item.url
        }

        let asset = AVURLAsset(url: targetURL)
        let playerItem = AVPlayerItem(asset: asset)

        observePlayerItem(playerItem, resumePosition: item.isCompleted ? 0 : item.lastPosition, autoPlay: autoPlay)
        player.replaceCurrentItem(with: playerItem)
        setupPeriodicTimeObserver()

        AVAudioSessionManager.shared.configureAudioSession()
        updateNowPlayingMetadata()
    }

    public func play() {
        guard let currentItem = player.currentItem,
              currentItem.status != .failed,
              player.error == nil else { return }
        if case .failed = playbackState { return }

        AVAudioSessionManager.shared.activateAudioSession()
        player.rate = playbackSpeed.rate
        playbackState = .playing
        updateNowPlayingPlaybackState()
    }

    public func pause() {
        player.pause()
        playbackState = .paused
        persistCurrentProgress()
        updateNowPlayingPlaybackState()
    }

    public func togglePlayPause() {
        if isPlaying {
            pause()
        } else {
            play()
        }
    }

    public func seek(to time: TimeInterval, completion: (() -> Void)? = nil) {
        let clampedTime = max(0, min(time, duration))
        currentTime = clampedTime

        let cmTime = CMTime(seconds: clampedTime, preferredTimescale: 600)
        player.seek(to: cmTime, toleranceBefore: .zero, toleranceAfter: .zero) { [weak self] finished in
            guard finished else { return }
            Task { @MainActor [weak self] in
                self?.persistCurrentProgress()
                self?.updateNowPlayingPlaybackState()
                completion?()
            }
        }
    }

    public func skipForward(seconds: TimeInterval = 10) {
        seek(to: currentTime + seconds)
    }

    public func skipBackward(seconds: TimeInterval = 10) {
        seek(to: currentTime - seconds)
    }

    public func setPlaybackSpeed(_ speed: PlaybackSpeed) {
        playbackSpeed = speed
        player.defaultRate = speed.rate
        if isPlaying {
            player.rate = speed.rate
        }
        updateNowPlayingPlaybackState()
    }

    public func toggleVideoGravity() {
        videoGravity = (videoGravity == .resizeAspect) ? .resizeAspectFill : .resizeAspect
    }

    public func stop() {
        persistCurrentProgress()
        player.pause()
        player.replaceCurrentItem(with: nil)
        removePeriodicTimeObserver()
        stopAccessingActiveSecurityScopedResource()

        currentMediaItem = nil
        playbackState = .idle
        currentTime = 0
        duration = 0
        bufferedTime = 0
        NowPlayingManager.shared.clearNowPlaying()
    }

    public func persistCurrentProgress() {
        guard let item = currentMediaItem, currentTime > 0 else { return }
        PlaybackProgressStore.shared.updateProgress(for: item.id, position: currentTime, duration: duration)
    }

    private func observePlayerItem(_ playerItem: AVPlayerItem, resumePosition: TimeInterval, autoPlay: Bool) {
        itemStatusObservation?.invalidate()
        timeControlStatusObservation?.invalidate()
        loadedTimeRangesObservation?.invalidate()

        itemStatusObservation = playerItem.observe(\.status, options: [.new, .initial]) { [weak self] item, _ in
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                switch item.status {
                case .readyToPlay:
                    let itemDuration = item.duration.seconds
                    if !itemDuration.isNaN && !itemDuration.isInfinite && itemDuration > 0 {
                        self.duration = itemDuration
                    }

                    if resumePosition > 0 && resumePosition < self.duration {
                        self.seek(to: resumePosition) {
                            if autoPlay {
                                self.play()
                            }
                        }
                    } else if autoPlay {
                        self.play()
                    } else {
                        self.playbackState = .paused
                    }
                    self.updateNowPlayingMetadata()

                case .failed:
                    let message = item.error?.localizedDescription ?? "Playback failed"
                    self.playbackState = .failed(message)

                case .unknown:
                    self.playbackState = .loading

                @unknown default:
                    break
                }
            }
        }

        timeControlStatusObservation = player.observe(\.timeControlStatus, options: [.new]) { [weak self] player, _ in
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                switch player.timeControlStatus {
                case .paused:
                    if case .failed = self.playbackState {
                        // Keep failed state
                    } else {
                        self.playbackState = .paused
                    }
                case .waitingToPlayAtSpecifiedRate:
                    self.playbackState = .buffering
                case .playing:
                    self.playbackState = .playing
                @unknown default:
                    break
                }
            }
        }

        loadedTimeRangesObservation = playerItem.observe(\.loadedTimeRanges, options: [.new]) { [weak self] item, _ in
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                if let timeRange = item.loadedTimeRanges.first?.timeRangeValue {
                    let buffered = timeRange.start.seconds + timeRange.duration.seconds
                    self.bufferedTime = max(0, buffered)
                }
            }
        }
    }

    private func setupPeriodicTimeObserver() {
        removePeriodicTimeObserver()

        let interval = CMTime(seconds: 0.25, preferredTimescale: 600)
        timeObserverToken = player.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            Task { @MainActor [weak self] in
                guard let self = self, self.isPlaying else { return }
                self.currentTime = time.seconds
            }
        }
    }

    private func removePeriodicTimeObserver() {
        if let token = timeObserverToken {
            player.removeTimeObserver(token)
            timeObserverToken = nil
        }
    }

    private func setupAudioSession() {
        let audioManager = AVAudioSessionManager.shared
        audioManager.onInterruptionBegan = { [weak self] in
            Task { @MainActor [weak self] in
                self?.pause()
            }
        }

        audioManager.onInterruptionEnded = { [weak self] shouldResume in
            Task { @MainActor [weak self] in
                if shouldResume {
                    self?.play()
                }
            }
        }

        audioManager.onRouteChangeOldDeviceUnavailable = { [weak self] in
            Task { @MainActor [weak self] in
                self?.pause()
            }
        }
    }

    private func setupNowPlayingCommands() {
        let commandManager = NowPlayingManager.shared
        commandManager.configureRemoteCommands()

        commandManager.onPlay = { [weak self] in
            Task { @MainActor [weak self] in self?.play() }
        }
        commandManager.onPause = { [weak self] in
            Task { @MainActor [weak self] in self?.pause() }
        }
        commandManager.onTogglePlayPause = { [weak self] in
            Task { @MainActor [weak self] in self?.togglePlayPause() }
        }
        commandManager.onSkipForward = { [weak self] seconds in
            Task { @MainActor [weak self] in self?.skipForward(seconds: seconds) }
        }
        commandManager.onSkipBackward = { [weak self] seconds in
            Task { @MainActor [weak self] in self?.skipBackward(seconds: seconds) }
        }
        commandManager.onSeek = { [weak self] time in
            Task { @MainActor [weak self] in self?.seek(to: time) }
        }
        commandManager.onChangeRate = { [weak self] rate in
            Task { @MainActor [weak self] in
                let speed = PlaybackSpeed.closest(to: rate)
                self?.setPlaybackSpeed(speed)
            }
        }
    }

    private func setupNotificationObservers() {
        NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            Task { @MainActor [weak self] in
                guard let self = self,
                      let currentItem = self.player.currentItem,
                      (notification.object as? AVPlayerItem) == currentItem else {
                    return
                }

                if let mediaItem = self.currentMediaItem {
                    PlaybackProgressStore.shared.markCompleted(id: mediaItem.id)
                }
                self.playbackState = .paused
                self.seek(to: 0)
            }
        }
    }

    private func updateNowPlayingMetadata() {
        guard let item = currentMediaItem else { return }
        NowPlayingManager.shared.updateNowPlaying(
            title: item.title,
            artist: item.artist,
            duration: duration,
            elapsed: currentTime,
            rate: isPlaying ? playbackSpeed.rate : 0.0
        )
    }

    private func updateNowPlayingPlaybackState() {
        NowPlayingManager.shared.updatePlaybackState(
            elapsed: currentTime,
            rate: isPlaying ? playbackSpeed.rate : 0.0
        )
    }

    private func stopAccessingActiveSecurityScopedResource() {
        if let url = activeSecurityScopedURL {
            url.stopAccessingSecurityScopedResource()
            activeSecurityScopedURL = nil
        }
    }
}
