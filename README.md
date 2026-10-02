# iOS Media Player

> A modern, feature-rich native media player for iOS engineered with Swift and SwiftUI, featuring AVFoundation playback, Picture-in-Picture, background audio, intuitive gesture controls, persistent playback resumption, and an iOS Liquid Glass aesthetic.

---

## Features

### 🎬 Core Playback & Media Engine
- **Versatile Media Support**: Hardware-accelerated playback for local files (`.mp4`, `.mov`, `.m4v`, `.mp3`, `.m4a`, `.wav`) and live/VOD network streams (HLS `.m3u8`, HTTP/HTTPS direct streams) powered by `AVFoundation`. Live streams show their position relative to the live edge, with a **LIVE** button to jump back to it.
- **Variable Playback Speeds**: Seamless speed adjustment (`0.5x`, `0.75x`, `1.0x`, `1.25x`, `1.5x`, `1.75x`, `2.0x`) with automatic pitch correction.
- **Picture-in-Picture (PiP)**: Full `AVPictureInPictureController` integration for floating video playback across applications and home screen transitions.
- **Background Audio**: Uninterrupted audio playback when locking the device or switching apps via `AVAudioSession` (`.playback` category).
- **Lock Screen & Control Center**: Metadata synchronization (`MPNowPlayingInfoCenter`) and remote playback commands (`MPRemoteCommandCenter`) for play/pause, seeking, speed, and 10-second skip buttons.
- **Interruption Handling**: Calls and other audio interruptions pause playback and resume it afterwards only if you were playing and didn't pause in the meantime.

### 👆 Intuitive Gestural Controls
- **Brightness Adjustment**: Swipe vertically on the left half of the screen with a floating liquid glass HUD.
- **Volume Adjustment**: Swipe vertically on the right half of the screen with a responsive glass HUD indicator.
- **Precision Scrubbing**: Swipe horizontally anywhere on the screen to preview time offsets (`+0:30`, `-1:15`) before seeking.
- **Quick Skip**: Double-tap the left or right half of the screen to jump backward or forward by 10 seconds.
- **Dynamic Controls Fade**: Single tap toggles the liquid glass overlay controls. They hide after 4 seconds of inactivity, but stay up while you scrub or use the speed menu.

### 💾 Smart Resumption & Persistence
- **Auto-Save Progress**: Records the playback position when you pause, seek, close the player, or the app moves to the background, and checkpoints every 15 seconds during playback. A force-quit loses at most the last few seconds. Live streams have no saved position.
- **Security-Scoped Bookmarks**: Keeps access to files imported from the Files app across restarts. Bookmarks are refreshed when a file moves, and if a file is deleted or its provider becomes unavailable, the player says so and asks you to import it again.
- **Continue Watching Shelf**: Quickly resume partially watched videos and podcasts, with a progress bar on each card.

### 🫧 Liquid Glass Aesthetic
- **Native Glass on iOS 26**: Toolbars and controls use SwiftUI's `.glassEffect()`, which refracts and adapts to the video behind it. Only interactive controls use interactive glass, and controls on the bottom bar use a tinted fill rather than stacking glass on glass.
- **Material Fallback on iOS 17–18**: `.ultraThinMaterial` surfaces with subtle gradient border highlights approximate the look on earlier systems.
- **Floating Pill Toolbars**: The top bar's glass controls are grouped in a `GlassEffectContainer` so they blend together.

---

## Requirements

- **Runs on**: iOS / iPadOS 17.0 or later (native Liquid Glass on iOS 26; material fallback on 17–18)
- **Builds with**: Xcode 26 or later, which provides the iOS 26 SDK the glass APIs need. Runtime `#available` checks keep older iOS versions working, but they don't let older Xcode versions compile the code.
- **macOS**: a version that runs Xcode 26 (macOS Sequoia 15.6 or later)
- **Swift**: the Swift 6.2 toolchain bundled with Xcode 26; the project builds in Swift 5 language mode

---

## Setup & Installation

### 1. Clone the Repository
```bash
git clone https://github.com/CalebChu/ios-media-player.git
cd ios-media-player
```

### 2. Open in Xcode
Open the Xcode project directly:
```bash
open IOSMediaPlayer.xcodeproj
```

### 3. Configure Signing & Capabilities
1. In Xcode, select the **IOSMediaPlayer** project in the Project Navigator.
2. Select the **IOSMediaPlayer** target and navigate to the **Signing & Capabilities** tab.
3. Select your development **Team**.
4. Confirm the following capabilities are enabled:
   - **Background Modes**: Check *Audio, AirPlay, and Picture in Picture*.

### 4. Build and Run
- Choose an iOS 17+ Simulator or connected physical iPhone/iPad.
- Press `Cmd + R` or click the **Play** button to build and run the app.

### 5. Run the Tests
- Press `Cmd + U` in Xcode, or run:
  ```bash
  xcodebuild test -project IOSMediaPlayer.xcodeproj -scheme IOSMediaPlayer \
    -destination 'platform=iOS Simulator,name=iPhone 17'
  ```
- Tests use their own `UserDefaults` suite and generate their own media, so they never touch your library.
- CI runs the tests and builds an unsigned IPA on every push and pull request to `main`.

---

## Usage Guide

### Importing Local Media
1. On the main **Library** screen, tap the **Import Files** button, or use **Open in…** from the Files app.
2. Select any compatible video or audio file from your device, iCloud Drive, or connected file providers.
3. The file will be cataloged in your library. Importing a single file starts playback immediately; importing one you already have keeps its saved progress.

### Streaming Network Content
1. Tap the **Stream URL** button in the library header.
2. Enter an HLS (`.m3u8`) or direct media stream URL (or select one of the built-in test streams).
3. Tap **Play Stream** to launch the player.

**Security notes**
- Plain `http://` media is allowed on purpose (`NSAllowsArbitraryLoadsForMedia`), since this is a general-purpose URL player. The sheet warns before you play an unencrypted stream; prefer HTTPS whenever the server supports it. The exception only covers media loads; everything else still requires HTTPS.
- URLs that embed a user name or password (`https://user:pass@host/…`) play, but are never saved to the library. Tokens in query strings can't be told apart from ordinary parameters, so avoid saving signed URLs you consider secret.

### In-Player Controls & Gestures
| Gesture / Action | Result |
| :--- | :--- |
| **Swipe Up / Down (Left side)** | Adjust screen brightness |
| **Swipe Up / Down (Right side)** | Adjust audio volume |
| **Swipe Left / Right** | Scrub / Seek through media |
| **Double Tap (Left half)** | Skip backward 10 seconds |
| **Double Tap (Right half)** | Skip forward 10 seconds |
| **Single Tap** | Show or hide floating player controls |
| **PiP Button (Top Bar)** | Enter Picture-in-Picture floating window |
| **Speed Button (Bottom Bar)** | Select playback speed (`0.5x` – `2.0x`) |
| **LIVE Button (Live streams)** | Jump back to the live edge |
| **VoiceOver: swipe up/down on the scrubber** | Move 10 seconds forward/back |

---

## Project Structure

```
IOSMediaPlayer/
├── Info.plist                         # Background modes, document types & ATS media exception
├── App/
│   └── IOSMediaPlayerApp.swift        # App lifecycle & dependency injection
├── Core/
│   ├── PlaybackManager.swift          # AVPlayer state machine & timing engine
│   ├── AVAudioSessionManager.swift    # Audio interruptions & route handling
│   ├── NowPlayingManager.swift        # Lock screen & Control Center integration
│   ├── PictureInPictureManager.swift  # PiP controller, shared video view & restore flow
│   └── PlaybackProgressStore.swift    # Library persistence & security-scoped bookmarks
├── Models/
│   ├── MediaItem.swift                # Identifiable media resource model
│   ├── PlaybackSpeed.swift            # Playback rate options
│   └── PlaybackTimeline.swift         # Finite vs. live seekable range mapping
├── Views/
│   ├── Library/
│   │   ├── LibraryView.swift          # Main screen with shelves & file importer
│   │   └── StreamInputSheet.swift     # Modal for entering stream URLs
│   └── Player/
│       ├── VideoPlayerContainerView.swift # Full-screen player view
│       ├── AVPlayerLayerView.swift    # Hosts the shared hardware-accelerated video layer
│       ├── GestureOverlayView.swift   # Gesture recognizers & HUD triggers
│       ├── PlayerOverlayView.swift    # Liquid glass floating toolbars
│       └── GlassHUDView.swift         # Glass HUD toasts for volume/brightness/seek
└── Components/
    ├── LiquidGlassModifier.swift      # Native glass on iOS 26, material fallback before
    └── GlassScrubber.swift            # Custom interactive, accessible playback scrubber

IOSMediaPlayerTests/                   # Unit tests for models, store, timeline & playback lifecycle
```

---

## Contributing

Contributions, feature requests, and issue reports are welcome! Please feel free to check the [issues page](https://github.com/CalebChu/ios-media-player/issues).

---

## License

This project is licensed under the MIT License. See [LICENSE](LICENSE).
