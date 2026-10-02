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

    /// Whether the user wants media to play. Only explicit play/pause, failures and reaching the end
    /// change it, so it survives loading, buffering stalls and audio interruptions.
    @Published public private(set) var wantsToPlay = false
    /// True while the system has paused playback for an audio interruption (e.g. a phone call).
    @Published public private(set) var isInterrupted = false

    public let player = AVPlayer()

    nonisolated(unsafe) private var timeObserverToken: Any?
    nonisolated(unsafe) private var endOfItemObserver: NSObjectProtocol?
    nonisolated(unsafe) private var activeSecurityScopedURL: URL?
    private var itemObservations: [NSKeyValueObservation] = []
    private var timeControlStatusObservation: NSKeyValueObservation?

    /// Incremented on every load so callbacks that belong to a previous item can be recognised and dropped.
    private var loadGeneration = 0
    /// True from `loadMedia` until the item is ready and any resume seek has finished.
    private var isPreparingItem = false
    private var pendingSeekCount = 0
    private var hasPlayedToEnd = false

    init() {
        player.audiovisualBackgroundPlaybackPolicy = .continuesIfPossible
        setupAudioSession()
        setupNowPlayingCommands()
        setupNotificationObservers()
        observeTimeControlStatus()
    }

    deinit {
        if let token = timeObserverToken {
            player.removeTimeObserver(token)
        }
        if let observer = endOfItemObserver {
            NotificationCenter.default.removeObserver(observer)
        }
        activeSecurityScopedURL?.stopAccessingSecurityScopedResource()
    }

    /// What the transport controls should show: the user's intent, unless an interruption has paused playback.
    public var isPlaying: Bool {
        return wantsToPlay && !isInterrupted
    }

    public var isFailed: Bool {
        if case .failed = playbackState { return true }
        return false
    }

    public func loadMedia(item: MediaItem, autoPlay: Bool = true) {
        persistCurrentProgress()
        stopAccessingActiveSecurityScopedResource()

        loadGeneration += 1
        isPreparingItem = true
        pendingSeekCount = 0
        hasPlayedToEnd = false
        wantsToPlay = autoPlay
        isInterrupted = false

        let resumePosition = item.isCompleted ? 0 : item.lastPosition
        currentMediaItem = item
        playbackState = .loading
        currentTime = resumePosition
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

        let playerItem = AVPlayerItem(asset: AVURLAsset(url: targetURL))
        observePlayerItem(playerItem, generation: loadGeneration, resumePosition: resumePosition)
        player.replaceCurrentItem(with: playerItem)
        setupPeriodicTimeObserver()

        AVAudioSessionManager.shared.configureAudioSession()
        updateNowPlayingMetadata()
    }

    public func play() {
        guard let currentItem = player.currentItem,
              currentItem.status != .failed,
              !isFailed else { return }

        wantsToPlay = true
        isInterrupted = false

        // The readiness handler starts playback once the item (and any resume seek) is ready.
        guard !isPreparingItem else { return }

        if hasPlayedToEnd {
            hasPlayedToEnd = false
            seek(to: 0) { [weak self] in
                self?.startPlayerIfWanted()
            }
            return
        }
        startPlayer()
    }

    public func pause() {
        wantsToPlay = false
        player.pause()
        if !isPreparingItem && !isFailed && currentMediaItem != nil {
            playbackState = .paused
        }
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
        // AVPlayerItem raises an exception for seeks with a completion handler before it is ready.
        guard let item = player.currentItem, item.status == .readyToPlay else { return }

        let target = clampedSeekTime(time)
        currentTime = target
        hasPlayedToEnd = false
        pendingSeekCount += 1

        let generation = loadGeneration
        let cmTime = CMTime(seconds: target, preferredTimescale: 600)
        player.seek(to: cmTime, toleranceBefore: .zero, toleranceAfter: .zero) { [weak self] finished in
            Task { @MainActor [weak self] in
                guard let self, self.isCurrent(item, generation: generation) else { return }
                self.pendingSeekCount = max(0, self.pendingSeekCount - 1)
                if finished {
                    self.persistCurrentProgress()
                    self.updateNowPlayingPlaybackState()
                }
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
        if player.rate != 0 {
            player.rate = speed.rate
        }
        updateNowPlayingPlaybackState()
    }

    public func toggleVideoGravity() {
        videoGravity = (videoGravity == .resizeAspect) ? .resizeAspectFill : .resizeAspect
    }

    public func stop() {
        persistCurrentProgress()
        loadGeneration += 1
        invalidateItemObservations()
        player.pause()
        player.replaceCurrentItem(with: nil)
        removePeriodicTimeObserver()
        stopAccessingActiveSecurityScopedResource()

        isPreparingItem = false
        pendingSeekCount = 0
        hasPlayedToEnd = false
        wantsToPlay = false
        isInterrupted = false
        currentMediaItem = nil
        playbackState = .idle
        currentTime = 0
        duration = 0
        bufferedTime = 0
        NowPlayingManager.shared.clearNowPlaying()
        AVAudioSessionManager.shared.deactivateAudioSession()
    }

    public func persistCurrentProgress() {
        guard let item = currentMediaItem, currentTime > 0 else { return }
        PlaybackProgressStore.shared.updateProgress(for: item.id, position: currentTime, duration: duration)
    }

    // MARK: - Player item lifecycle

    private func isCurrent(_ item: AVPlayerItem, generation: Int) -> Bool {
        return generation == loadGeneration && player.currentItem === item
    }

    private func observePlayerItem(_ playerItem: AVPlayerItem, generation: Int, resumePosition: TimeInterval) {
        invalidateItemObservations()

        itemObservations = [
            playerItem.observe(\.status, options: [.new, .initial]) { [weak self] item, _ in
                Task { @MainActor [weak self] in
                    guard let self, self.isCurrent(item, generation: generation) else { return }
                    self.handleStatusChange(of: item, resumePosition: resumePosition)
                }
            },
            playerItem.observe(\.loadedTimeRanges, options: [.new]) { [weak self] item, _ in
                Task { @MainActor [weak self] in
                    guard let self, self.isCurrent(item, generation: generation) else { return }
                    self.updateBufferedTime(from: item)
                }
            }
        ]
    }

    private func invalidateItemObservations() {
        itemObservations.forEach { $0.invalidate() }
        itemObservations = []
    }

    private func handleStatusChange(of item: AVPlayerItem, resumePosition: TimeInterval) {
        switch item.status {
        case .readyToPlay:
            guard isPreparingItem else { return }
            let itemDuration = item.duration.seconds
            if itemDuration.isFinite && itemDuration > 0 {
                duration = itemDuration
            }

            if resumePosition > 0 && resumePosition < duration {
                // The completion runs even if the seek is superseded, so preparation always finishes.
                seek(to: resumePosition) { [weak self] in
                    self?.finishPreparingItem()
                }
            } else {
                finishPreparingItem()
            }

        case .failed:
            isPreparingItem = false
            wantsToPlay = false
            playbackState = .failed(item.error?.localizedDescription ?? "Playback failed")
            updateNowPlayingPlaybackState()

        case .unknown:
            playbackState = .loading

        @unknown default:
            break
        }
    }

    private func finishPreparingItem() {
        guard isPreparingItem else { return }
        isPreparingItem = false
        updateNowPlayingMetadata()
        if !startPlayerIfWanted() {
            playbackState = .paused
        }
    }

    /// Starts the player when the user still wants playback. Reads intent at call time, so a pause
    /// made while loading or seeking is respected.
    @discardableResult
    private func startPlayerIfWanted() -> Bool {
        guard isPlaying, !isPreparingItem else { return false }
        startPlayer()
        return true
    }

    private func startPlayer() {
        AVAudioSessionManager.shared.activateAudioSession()
        player.rate = playbackSpeed.rate
        updateNowPlayingPlaybackState()
    }

    private func clampedSeekTime(_ time: TimeInterval) -> TimeInterval {
        guard time.isFinite else { return currentTime }
        if duration > 0 {
            return min(max(time, 0), duration)
        }
        return max(0, time)
    }

    private func updateBufferedTime(from item: AVPlayerItem) {
        // Use the loaded range that contains the playhead; earlier ranges can be left over from previous seeks.
        let playhead = item.currentTime()
        let ranges = item.loadedTimeRanges.map(\.timeRangeValue)
        guard let range = ranges.first(where: { $0.containsTime(playhead) }) ?? ranges.last else { return }
        let end = range.end.seconds
        if end.isFinite {
            bufferedTime = max(0, end)
        }
    }

    private func observeTimeControlStatus() {
        timeControlStatusObservation = player.observe(\.timeControlStatus, options: [.new]) { [weak self] _, _ in
            Task { @MainActor [weak self] in
                self?.handleTimeControlStatusChange()
            }
        }
    }

    private func handleTimeControlStatusChange() {
        guard player.currentItem != nil, !isFailed else { return }
        switch player.timeControlStatus {
        case .paused:
            if !isPreparingItem {
                playbackState = .paused
            }
        case .waitingToPlayAtSpecifiedRate:
            if !isPreparingItem {
                playbackState = .buffering
            }
        case .playing:
            playbackState = .playing
        @unknown default:
            break
        }
        // Keep the lock screen's extrapolated elapsed time correct across stalls and resumes.
        updateNowPlayingPlaybackState()
    }

    private func setupPeriodicTimeObserver() {
        removePeriodicTimeObserver()

        let interval = CMTime(seconds: 0.25, preferredTimescale: 600)
        timeObserverToken = player.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            guard let self else { return }
            MainActor.assumeIsolated {
                self.handlePeriodicTimeUpdate(time)
            }
        }
    }

    private func handlePeriodicTimeUpdate(_ time: CMTime) {
        // While preparing or seeking, `currentTime` already holds the target; don't let stale ticks move it back.
        guard !isPreparingItem, pendingSeekCount == 0 else { return }
        let seconds = time.seconds
        if seconds.isFinite && seconds != currentTime {
            currentTime = seconds
        }
    }

    private func removePeriodicTimeObserver() {
        if let token = timeObserverToken {
            player.removeTimeObserver(token)
            timeObserverToken = nil
        }
    }

    // MARK: - System integration

    private func setupAudioSession() {
        let audioManager = AVAudioSessionManager.shared
        audioManager.onInterruptionBegan = { [weak self] in
            Task { @MainActor [weak self] in
                self?.handleInterruptionBegan()
            }
        }

        audioManager.onInterruptionEnded = { [weak self] shouldResume in
            Task { @MainActor [weak self] in
                self?.handleInterruptionEnded(shouldResume: shouldResume)
            }
        }

        audioManager.onRouteChangeOldDeviceUnavailable = { [weak self] in
            Task { @MainActor [weak self] in
                self?.pause()
            }
        }
    }

    private func handleInterruptionBegan() {
        guard currentMediaItem != nil else { return }
        // Keep `wantsToPlay` untouched: it records whether the user was playing before the
        // interruption. AVPlayer has usually paused itself by now, so its state can't tell us.
        isInterrupted = true
        player.pause()
        persistCurrentProgress()
        updateNowPlayingPlaybackState()
    }

    private func handleInterruptionEnded(shouldResume: Bool) {
        guard isInterrupted else { return }
        isInterrupted = false
        if shouldResume {
            startPlayerIfWanted()
        } else {
            wantsToPlay = false
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
                self?.setPlaybackSpeed(PlaybackSpeed.closest(to: rate))
            }
        }
    }

    private func setupNotificationObservers() {
        endOfItemObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let self else { return }
            let endedItem = notification.object as? AVPlayerItem
            MainActor.assumeIsolated {
                self.handlePlayedToEnd(endedItem)
            }
        }
    }

    private func handlePlayedToEnd(_ endedItem: AVPlayerItem?) {
        guard let endedItem, endedItem === player.currentItem else { return }

        // Stay at the end so the item keeps its completed position; `play()` restarts from the beginning.
        hasPlayedToEnd = true
        wantsToPlay = false
        playbackState = .paused
        if duration > 0 {
            currentTime = duration
        }
        if let mediaItem = currentMediaItem {
            PlaybackProgressStore.shared.markCompleted(id: mediaItem.id)
        }
        updateNowPlayingPlaybackState()
    }

    private func updateNowPlayingMetadata() {
        guard let item = currentMediaItem else { return }
        NowPlayingManager.shared.updateNowPlaying(
            title: item.title,
            artist: item.artist,
            duration: duration,
            elapsed: nowPlayingElapsedTime,
            rate: nowPlayingRate
        )
    }

    private func updateNowPlayingPlaybackState() {
        guard currentMediaItem != nil else { return }
        NowPlayingManager.shared.updatePlaybackState(
            elapsed: nowPlayingElapsedTime,
            rate: nowPlayingRate
        )
    }

    /// The rate the system should extrapolate from: zero unless the player is actually advancing.
    private var nowPlayingRate: Float {
        return player.timeControlStatus == .playing ? player.rate : 0
    }

    private var nowPlayingElapsedTime: TimeInterval {
        let seconds = player.currentTime().seconds
        return seconds.isFinite ? seconds : currentTime
    }

    private func stopAccessingActiveSecurityScopedResource() {
        if let url = activeSecurityScopedURL {
            url.stopAccessingSecurityScopedResource()
            activeSecurityScopedURL = nil
        }
    }
}
