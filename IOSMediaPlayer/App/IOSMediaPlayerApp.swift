import SwiftUI

@main
struct IOSMediaPlayerApp: App {
    // App-lifetime singletons, injected rather than owned with @StateObject.
    private let playbackManager = PlaybackManager.shared
    private let progressStore = PlaybackProgressStore.shared
    private let settingsStore = GestureSettingsStore.shared
    @Environment(\.scenePhase) private var scenePhase

    init() {
        AVAudioSessionManager.shared.configureAudioSession()
    }

    var body: some Scene {
        WindowGroup {
            LibraryView()
                .environmentObject(playbackManager)
                .environmentObject(progressStore)
                .environmentObject(settingsStore)
                .preferredColorScheme(.dark)
        }
        .onChange(of: scenePhase) { _, phase in
            switch phase {
            case .background, .inactive:
                playbackManager.persistCurrentProgress()
            default:
                break
            }
        }
    }
}
