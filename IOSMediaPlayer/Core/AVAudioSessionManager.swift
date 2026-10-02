import AVFoundation
import Foundation
import OSLog

public final class AVAudioSessionManager {
    public static let shared = AVAudioSessionManager()

    public var onInterruptionBegan: (() -> Void)?
    public var onInterruptionEnded: ((Bool) -> Void)?
    public var onRouteChangeOldDeviceUnavailable: (() -> Void)?

    private var isConfigured = false
    private let logger = Logger(subsystem: "com.calebchu.iosmediaplayer", category: "AudioSession")

    private init() {
        setupObservers()
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    public func configureAudioSession() {
        guard !isConfigured else { return }

        let audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setCategory(.playback, mode: .moviePlayback, options: [])
            isConfigured = true
        } catch {
            logger.error("Failed to configure AVAudioSession: \(error.localizedDescription, privacy: .public)")
        }
    }

    public func activateAudioSession() {
        do {
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            logger.error("Failed to activate AVAudioSession: \(error.localizedDescription, privacy: .public)")
        }
    }

    public func deactivateAudioSession() {
        do {
            try AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        } catch {
            logger.error("Failed to deactivate AVAudioSession: \(error.localizedDescription, privacy: .public)")
        }
    }

    private func setupObservers() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleInterruption),
            name: AVAudioSession.interruptionNotification,
            object: AVAudioSession.sharedInstance()
        )

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleRouteChange),
            name: AVAudioSession.routeChangeNotification,
            object: AVAudioSession.sharedInstance()
        )
    }

    @objc private func handleInterruption(notification: Notification) {
        guard let userInfo = notification.userInfo,
              let typeValue = userInfo[AVAudioSessionInterruptionTypeKey] as? UInt,
              let interruptionType = AVAudioSession.InterruptionType(rawValue: typeValue) else {
            return
        }

        switch interruptionType {
        case .began:
            onInterruptionBegan?()
        case .ended:
            if let optionsValue = userInfo[AVAudioSessionInterruptionOptionKey] as? UInt {
                let options = AVAudioSession.InterruptionOptions(rawValue: optionsValue)
                let shouldResume = options.contains(.shouldResume)
                onInterruptionEnded?(shouldResume)
            } else {
                onInterruptionEnded?(false)
            }
        @unknown default:
            break
        }
    }

    @objc private func handleRouteChange(notification: Notification) {
        guard let userInfo = notification.userInfo,
              let reasonValue = userInfo[AVAudioSessionRouteChangeReasonKey] as? UInt,
              let reason = AVAudioSession.RouteChangeReason(rawValue: reasonValue) else {
            return
        }

        if reason == .oldDeviceUnavailable {
            onRouteChangeOldDeviceUnavailable?()
        }
    }
}
