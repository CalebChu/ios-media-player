import Combine
import Foundation
import OSLog

/// Manages persistent user preferences for all in-player gesture controls.
@MainActor
public final class GestureSettingsStore: ObservableObject {
    public static let shared = GestureSettingsStore()

    public enum Keys {
        public static let swipeDownToExit = "ios_media_player_gesture_swipe_down_to_exit"
        public static let volumeGesture = "ios_media_player_gesture_volume"
        public static let brightnessGesture = "ios_media_player_gesture_brightness"
        public static let seekGesture = "ios_media_player_gesture_seek"
        public static let doubleTapSkip = "ios_media_player_gesture_double_tap_skip"
        public static let singleTapToggle = "ios_media_player_gesture_single_tap_toggle"
    }

    private let defaults: UserDefaults
    private let logger = Logger(subsystem: "com.calebchu.iosmediaplayer", category: "GestureSettingsStore")

    // MARK: - Published Settings

    /// When enabled, swiping down anywhere on the player exits the video.
    /// This is enabled by default.
    @Published public var isSwipeDownToExitEnabled: Bool {
        didSet {
            defaults.set(isSwipeDownToExitEnabled, forKey: Keys.swipeDownToExit)
        }
    }

    /// When enabled, swiping vertically on the right half adjusts audio volume.
    /// Note: Only effective when `isSwipeDownToExitEnabled` is `false`.
    @Published public var isVolumeGestureEnabled: Bool {
        didSet {
            defaults.set(isVolumeGestureEnabled, forKey: Keys.volumeGesture)
        }
    }

    /// When enabled, swiping vertically on the left half adjusts screen brightness.
    /// Note: Only effective when `isSwipeDownToExitEnabled` is `false`.
    @Published public var isBrightnessGestureEnabled: Bool {
        didSet {
            defaults.set(isBrightnessGestureEnabled, forKey: Keys.brightnessGesture)
        }
    }

    /// When enabled, swiping horizontally scrubs / seeks through media.
    @Published public var isSeekGestureEnabled: Bool {
        didSet {
            defaults.set(isSeekGestureEnabled, forKey: Keys.seekGesture)
        }
    }

    /// When enabled, double-tapping left or right skips backward or forward 10 seconds.
    @Published public var isDoubleTapToSkipEnabled: Bool {
        didSet {
            defaults.set(isDoubleTapToSkipEnabled, forKey: Keys.doubleTapSkip)
        }
    }

    /// When enabled, single-tapping toggles visibility of floating controls.
    @Published public var isSingleTapToToggleControlsEnabled: Bool {
        didSet {
            defaults.set(isSingleTapToToggleControlsEnabled, forKey: Keys.singleTapToggle)
        }
    }

    // MARK: - Initialization

    /// - Parameter defaults: Target `UserDefaults` suite. Unit tests supply an isolated suite.
    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults

        // Swipe Down to Exit defaults to true
        if defaults.object(forKey: Keys.swipeDownToExit) != nil {
            self.isSwipeDownToExitEnabled = defaults.bool(forKey: Keys.swipeDownToExit)
        } else {
            self.isSwipeDownToExitEnabled = true
        }

        // Volume gesture defaults to true
        if defaults.object(forKey: Keys.volumeGesture) != nil {
            self.isVolumeGestureEnabled = defaults.bool(forKey: Keys.volumeGesture)
        } else {
            self.isVolumeGestureEnabled = true
        }

        // Brightness gesture defaults to true
        if defaults.object(forKey: Keys.brightnessGesture) != nil {
            self.isBrightnessGestureEnabled = defaults.bool(forKey: Keys.brightnessGesture)
        } else {
            self.isBrightnessGestureEnabled = true
        }

        // Horizontal seek defaults to true
        if defaults.object(forKey: Keys.seekGesture) != nil {
            self.isSeekGestureEnabled = defaults.bool(forKey: Keys.seekGesture)
        } else {
            self.isSeekGestureEnabled = true
        }

        // Double tap to skip defaults to true
        if defaults.object(forKey: Keys.doubleTapSkip) != nil {
            self.isDoubleTapToSkipEnabled = defaults.bool(forKey: Keys.doubleTapSkip)
        } else {
            self.isDoubleTapToSkipEnabled = true
        }

        // Single tap to toggle controls defaults to true
        if defaults.object(forKey: Keys.singleTapToggle) != nil {
            self.isSingleTapToToggleControlsEnabled = defaults.bool(forKey: Keys.singleTapToggle)
        } else {
            self.isSingleTapToToggleControlsEnabled = true
        }
    }

    // MARK: - Computed Properties

    /// Vertical gestures (brightness and volume) are only allowed when swipe down to exit is off.
    public var areVerticalGesturesAllowed: Bool {
        return !isSwipeDownToExitEnabled
    }

    /// Effective volume gesture state: allowed only if swipe down to exit is off AND volume gesture is toggled on.
    public var effectiveVolumeGestureEnabled: Bool {
        return areVerticalGesturesAllowed && isVolumeGestureEnabled
    }

    /// Effective brightness gesture state: allowed only if swipe down to exit is off AND brightness gesture is toggled on.
    public var effectiveBrightnessGestureEnabled: Bool {
        return areVerticalGesturesAllowed && isBrightnessGestureEnabled
    }

    // MARK: - Actions

    /// Resets all gesture settings to their standard factory defaults.
    public func resetToDefaults() {
        isSwipeDownToExitEnabled = true
        isVolumeGestureEnabled = true
        isBrightnessGestureEnabled = true
        isSeekGestureEnabled = true
        isDoubleTapToSkipEnabled = true
        isSingleTapToToggleControlsEnabled = true
        logger.info("Gesture settings reset to defaults.")
    }
}
