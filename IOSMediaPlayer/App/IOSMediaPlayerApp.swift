import SwiftUI

@main
struct IOSMediaPlayerApp: App {
    // Both are app-lifetime singletons, so they are injected rather than owned with @StateObject.
    private let playbackManager = PlaybackManager.shared
    private let progressStore = PlaybackProgressStore.shared
    @Environment(\.scenePhase) private var scenePhase

    init() {
        AVAudioSessionManager.shared.configureAudioSession()
    }

    var body: some Scene {
        WindowGroup {
            LibraryView()
                .environmentObject(playbackManager)
                .environmentObject(progressStore)
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
