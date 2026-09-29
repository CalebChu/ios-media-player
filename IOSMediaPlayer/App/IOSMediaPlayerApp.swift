import SwiftUI

@main
struct IOSMediaPlayerApp: App {
    @StateObject private var playbackManager = PlaybackManager.shared
    @StateObject private var progressStore = PlaybackProgressStore.shared
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
        .onChange(of: scenePhase) { phase in
            switch phase {
            case .background, .inactive:
                playbackManager.persistCurrentProgress()
            default:
                break
            }
        }
    }
}
