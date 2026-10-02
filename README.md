# iOS Media Player

> A focused, lightweight media player for iOS built with Swift and SwiftUI. Delivers essential playback features done right—fast local and streaming media, fluid gestures, background audio, and seamless resumption in a clean Liquid Glass interface.

---

## About

iOS Media Player strips away the bloat found in modern media players to focus strictly on what matters: smooth, reliable playback and an effortless user experience. 

Designed to be lightweight and distraction-free, it provides the essential tools you need—responsive gestural controls, Picture-in-Picture, background playback, and automatic progress resumption—while staying out of the way. Built natively with Swift and SwiftUI, it integrates directly with iOS system media controls and embraces Apple's Liquid Glass aesthetic without unnecessary overhead.

---

## Features

- **Essential Playback**: Fast, hardware-accelerated playback for local video/audio (`.mp4`, `.mov`, `.m4v`, `.mp3`, `.m4a`, `.wav`) and live/VOD streams (HLS `.m3u8`, direct URLs) with pitch-corrected speed adjustment (`0.5x`–`2.0x`).
- **PiP & Background Audio**: Native Picture-in-Picture support and background playback with full Lock Screen and Control Center integration (`NowPlaying`).
- **Direct Gesture Controls**: Fluid on-screen gestures for scrubbing, double-tap skip, and swipe-down to dismiss, plus vertical brightness and volume sliders—all individually customizable in Settings.
- **Instant Resumption**: Automatically saves playback progress across app launches and maintains persistent access to imported files.
- **Liquid Glass Interface**: Minimalist, unobtrusive controls utilizing native `.glassEffect()` on iOS 26 with an `.ultraThinMaterial` fallback for iOS 17–18.

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
| **Swipe Down** | Exit video playback (default; disables vertical brightness/volume gestures) |
| **Swipe Up / Down (Left side)** | Adjust screen brightness (available when Swipe Down to Exit is off) |
| **Swipe Up / Down (Right side)** | Adjust audio volume (available when Swipe Down to Exit is off) |
| **Swipe Left / Right** | Scrub / Seek through media |
| **Double Tap (Left half)** | Skip backward 10 seconds |
| **Double Tap (Right half)** | Skip forward 10 seconds |
| **Single Tap** | Show or hide floating player controls |
| **Gear Button (Toolbar)** | Open Gesture Settings page |
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
│   ├── PlaybackProgressStore.swift    # Library persistence & security-scoped bookmarks
│   └── GestureSettingsStore.swift     # Gesture preference persistence & exclusivity logic
├── Models/
│   ├── MediaItem.swift                # Identifiable media resource model
│   ├── PlaybackSpeed.swift            # Playback rate options
│   └── PlaybackTimeline.swift         # Finite vs. live seekable range mapping
├── Views/
│   ├── Library/
│   │   ├── LibraryView.swift          # Main screen with shelves & file importer
│   │   └── StreamInputSheet.swift     # Modal for entering stream URLs
│   ├── Player/
│   │   ├── VideoPlayerContainerView.swift # Full-screen player view
│   │   ├── AVPlayerLayerView.swift    # Hosts the shared hardware-accelerated video layer
│   │   ├── GestureOverlayView.swift   # Gesture recognizers & HUD triggers
│   │   ├── PlayerOverlayView.swift    # Liquid glass floating toolbars
│   │   └── GlassHUDView.swift         # Glass HUD toasts for volume/brightness/seek
│   └── Settings/
│       └── SettingsView.swift         # Settings page for toggling gesture controls
└── Components/
    ├── LiquidGlassModifier.swift      # Native glass on iOS 26, material fallback before
    └── GlassScrubber.swift            # Custom interactive, accessible playback scrubber

IOSMediaPlayerTests/                   # Unit tests for models, store, timeline, settings & playback lifecycle
```

---

## Contributing

Contributions, feature requests, and issue reports are welcome! Please feel free to check the [issues page](https://github.com/CalebChu/ios-media-player/issues).

---

## License

This project is licensed under the MIT License. See [LICENSE](LICENSE).
