# iOS Media Player

> A modern, feature-rich native media player for iOS engineered with Swift and SwiftUI, featuring AVFoundation playback, Picture-in-Picture, background audio, intuitive gesture controls, persistent playback resumption, and an iOS Liquid Glass aesthetic.

---

## Features

### 🎬 Core Playback & Media Engine
- **Versatile Media Support**: Hardware-accelerated playback for local files (`.mp4`, `.mov`, `.m4v`, `.mp3`, `.m4a`, `.wav`) and live/VOD network streams (Apple HLS `.m3u8`, HTTP/HTTPS direct streams) powered by `AVFoundation`.
- **Variable Playback Speeds**: Seamless speed adjustment (`0.5x`, `0.75x`, `1.0x`, `1.25x`, `1.5x`, `1.75x`, `2.0x`) with automatic pitch correction.
- **Picture-in-Picture (PiP)**: Full `AVPictureInPictureController` integration for floating video playback across applications and home screen transitions.
- **Background Audio**: Uninterrupted audio playback when locking the device or switching apps via `AVAudioSession` (`.playback` category).
- **Lock Screen & Control Center**: Full metadata synchronization (`MPNowPlayingInfoCenter`) and remote playback commands (`MPRemoteCommandCenter`) for play/pause, seeking, and skip buttons.

### 👆 Intuitive Gestural Controls
- **Brightness Adjustment**: Swipe vertically on the left half of the screen with a floating liquid glass HUD.
- **Volume Adjustment**: Swipe vertically on the right half of the screen with a responsive glass HUD indicator.
- **Precision Scrubbing**: Swipe horizontally anywhere on the screen to preview time offsets (`+0:30`, `-1:15`) before seeking.
- **Quick Skip**: Double-tap the left or right screen edges to jump backward or forward by 10 seconds.
- **Dynamic Controls Fade**: Single tap toggles the liquid glass overlay controls with an automatic 4-second idle auto-hide.

### 💾 Smart Resumption & Persistence
- **Auto-Save Progress**: Automatically records elapsed playback position and duration upon pause, backgrounding, or app termination.
- **Security-Scoped Bookmarks**: Retains permanent access to files imported from the iOS Files app across restarts.
- **Continue Watching Shelf**: Quickly resume partially watched videos and podcasts with progress indicator rings.

### 🫧 Liquid Glass Aesthetic
- **Frosted Translucency**: Layered SwiftUI `.ultraThinMaterial` surfaces that respond dynamically to video colors and ambient light.
- **Specular Border Highlights**: Subtle chromatic linear gradient strokes mimicking real-world glass reflections.
- **Floating Pill Toolbars**: Ergonomic floating control bars designed for single-handed use on modern OLED displays and Dynamic Island devices.

---

## Requirements

- **iOS**: 17.0+
- **Xcode**: 15.0+
- **Swift**: 5.9+
- **macOS**: Sonoma (14.0) or later for building with Xcode

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

---

## Usage Guide

### Importing Local Media
1. On the main **Library** screen, tap the **Import Files** button.
2. Select any compatible video or audio file from your device, iCloud Drive, or connected file providers.
3. The file will be cataloged in your library and playback will begin immediately.

### Streaming Network Content
1. Tap the **Stream URL** button in the library header.
2. Enter an HLS (`.m3u8`) or direct media stream URL (or select one of the built-in test streams).
3. Tap **Play Stream** to launch the player.

### In-Player Controls & Gestures
| Gesture / Action | Result |
| :--- | :--- |
| **Swipe Up / Down (Left side)** | Adjust screen brightness |
| **Swipe Up / Down (Right side)** | Adjust audio volume |
| **Swipe Left / Right** | Scrub / Seek through media |
| **Double Tap (Left edge)** | Skip backward 10 seconds |
| **Double Tap (Right edge)** | Skip forward 10 seconds |
| **Single Tap** | Show or hide floating player controls |
| **PiP Button (Top Bar)** | Enter Picture-in-Picture floating window |
| **Speed Button (Bottom Bar)** | Select playback speed (`0.5x` – `2.0x`) |

---

## Project Structure

```
IOSMediaPlayer/
├── App/
│   ├── IOSMediaPlayerApp.swift       # App lifecycle & audio session setup
│   └── Info.plist                     # Background modes & file access keys
├── Core/
│   ├── PlaybackManager.swift          # AVPlayer state machine & timing engine
│   ├── AVAudioSessionManager.swift    # Audio interruptions & route handling
│   ├── NowPlayingManager.swift        # Lock screen & Control Center integration
│   ├── PictureInPictureManager.swift  # AVPictureInPictureController coordination
│   └── PlaybackProgressStore.swift    # UserDefaults & security-scoped bookmarks
├── Models/
│   ├── MediaItem.swift                # Identifiable media resource model
│   └── PlaybackSpeed.swift            # Playback rate options
├── Views/
│   ├── Library/
│   │   ├── LibraryView.swift          # Main screen with shelves & file importer
│   │   └── StreamInputSheet.swift     # Modal for entering stream URLs
│   └── Player/
│       ├── VideoPlayerContainerView.swift # Full-screen player view
│       ├── AVPlayerLayerView.swift    # Hardware-accelerated video layer
│       ├── GestureOverlayView.swift   # Gesture recognizers & HUD triggers
│       ├── PlayerOverlayView.swift    # Liquid glass floating toolbars
│       └── GlassHUDView.swift         # Glass HUD toasts for volume/brightness/seek
└── Components/
    ├── LiquidGlassModifier.swift      # Glass material & specular reflection styles
    ├── LiquidGlassCard.swift          # Reusable translucent glass containers
    └── GlassScrubber.swift            # Custom interactive playback scrubber
```

---

## Contributing

Contributions, feature requests, and issue reports are welcome! Please feel free to check the [issues page](https://github.com/CalebChu/ios-media-player/issues).

---

## License

This project is licensed under the MIT License.
