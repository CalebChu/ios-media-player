import SwiftUI
import UniformTypeIdentifiers

public struct LibraryView: View {
    @EnvironmentObject private var progressStore: PlaybackProgressStore
    @EnvironmentObject private var playbackManager: PlaybackManager

    @State private var isShowingFileImporter = false
    @State private var isShowingStreamSheet = false
    @State private var isPlayerPresented = false
    @State private var pendingStreamPlaybackItem: MediaItem?

    public init() {}

    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    continueWatchingSection
                    quickActionsSection
                    mediaListSection
                }
                .padding(.vertical, 16)
            }
            .background(Color(.systemGroupedBackground).ignoresSafeArea())
            .navigationTitle("Media Player")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        Button(action: { isShowingFileImporter = true }) {
                            Label("Import Files", systemImage: "folder.badge.plus")
                        }
                        Button(action: { isShowingStreamSheet = true }) {
                            Label("Network Stream", systemImage: "antenna.radiowaves.left.and.right")
                        }
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 20))
                    }
                }
            }
            .fileImporter(
                isPresented: $isShowingFileImporter,
                allowedContentTypes: [.movie, .video, .audio, .mpeg4Movie, .quickTimeMovie, .mp3],
                allowsMultipleSelection: true
            ) { result in
                handleFileImport(result: result)
            }
            .sheet(isPresented: $isShowingStreamSheet, onDismiss: {
                if let item = pendingStreamPlaybackItem {
                    pendingStreamPlaybackItem = nil
                    startPlayback(for: item)
                }
            }) {
                StreamInputSheet { mediaItem in
                    pendingStreamPlaybackItem = mediaItem
                }
            }
            .fullScreenCover(isPresented: $isPlayerPresented) {
                VideoPlayerContainerView(playbackManager: playbackManager)
            }
            .onAppear {
                PictureInPictureManager.shared.onRestoreUserInterface = { completionHandler in
                    isPlayerPresented = true
                    completionHandler(true)
                }
            }
        }
    }

    // Continue Watching Section
    @ViewBuilder
    private var continueWatchingSection: some View {
        let continueItems = progressStore.continueWatchingItems
        if !continueItems.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Continue Watching")
                        .font(.title3)
                        .fontWeight(.bold)
                    Spacer()
                }
                .padding(.horizontal, 20)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 16) {
                        ForEach(continueItems) { item in
                            Button(action: { startPlayback(for: item) }) {
                                continueWatchingCard(for: item)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 20)
                }
            }
        }
    }

    private func continueWatchingCard(for item: MediaItem) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color(.secondarySystemGroupedBackground))
                    .frame(width: 220, height: 124)

                Image(systemName: item.mediaType == .audio ? "waveform" : "play.rectangle.fill")
                    .font(.system(size: 38))
                    .foregroundColor(.accentColor.opacity(0.85))

                // Floating glass play badge
                Image(systemName: "play.fill")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.white)
                    .frame(width: 32, height: 32)
                    .liquidGlassPill(specularOpacity: 0.5)

                // Progress Bar at bottom of card
                VStack {
                    Spacer()
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Color.black.opacity(0.3))
                            .frame(height: 5)

                        Capsule()
                            .fill(Color.accentColor)
                            .frame(width: 220 * CGFloat(item.progressFraction), height: 5)
                    }
                    .padding(.horizontal, 8)
                    .padding(.bottom, 6)
                }
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(item.title)
                    .font(.system(size: 14, weight: .semibold))
                    .lineLimit(1)
                    .foregroundColor(.primary)

                HStack {
                    Text(item.formattedLastPosition)
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)

                    Spacer()

                    let percent = Int(item.progressFraction * 100)
                    Text("\(percent)%")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.accentColor)
                }
            }
            .frame(width: 220)
        }
    }

    // Quick Actions
    @ViewBuilder
    private var quickActionsSection: some View {
        if #available(iOS 26, *) {
            HStack(spacing: 14) {
                Button(action: { isShowingFileImporter = true }) {
                    Label("Import Files", systemImage: "folder.fill")
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                }
                .buttonStyle(.glassProminent)

                Button(action: { isShowingStreamSheet = true }) {
                    Label("Stream URL", systemImage: "link")
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                }
                .buttonStyle(.glass)
            }
            .padding(.horizontal, 20)
        } else {
            HStack(spacing: 14) {
                Button(action: { isShowingFileImporter = true }) {
                    HStack {
                        Image(systemName: "folder.fill")
                            .font(.system(size: 18))
                            .foregroundColor(.white)
                        Text("Import Files")
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.accentColor)
                    .cornerRadius(14)
                }

                Button(action: { isShowingStreamSheet = true }) {
                    HStack {
                        Image(systemName: "link")
                            .font(.system(size: 18))
                        Text("Stream URL")
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .foregroundColor(.primary)
                    .background(Color(.secondarySystemGroupedBackground))
                    .cornerRadius(14)
                }
            }
            .padding(.horizontal, 20)
        }
    }

    // Media List Section
    @ViewBuilder
    private var mediaListSection: some View {
        let items = progressStore.libraryItems
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Library")
                    .font(.title3)
                    .fontWeight(.bold)
                Spacer()
                Text("\(items.count) items")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 20)

            if items.isEmpty {
                VStack(spacing: 14) {
                    Image(systemName: "film.stack")
                        .font(.system(size: 48))
                        .foregroundColor(Color(uiColor: .tertiaryLabel))
                    Text("No Media Yet")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    Text("Tap Import Files or Stream URL above to add videos and audio.")
                        .font(.subheadline)
                        .foregroundColor(Color(uiColor: .tertiaryLabel))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
            } else {
                LazyVStack(spacing: 10) {
                    ForEach(items) { item in
                        Button(action: { startPlayback(for: item) }) {
                            mediaListRow(for: item)
                        }
                        .buttonStyle(.plain)
                        .contextMenu {
                            Button(role: .destructive) {
                                progressStore.deleteItem(withId: item.id)
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }
                }
                .padding(.horizontal, 20)
            }
        }
    }

    private func mediaListRow(for item: MediaItem) -> some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color(.tertiarySystemGroupedBackground))
                    .frame(width: 50, height: 50)

                Image(systemName: item.mediaType == .audio ? "music.note" : "video.fill")
                    .font(.system(size: 20))
                    .foregroundColor(.accentColor)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(item.title)
                    .font(.system(size: 15, weight: .semibold))
                    .lineLimit(1)
                    .foregroundColor(.primary)

                HStack(spacing: 8) {
                    if item.duration > 0 {
                        Text(item.formattedDuration)
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }

                    if item.isRemote {
                        Text("Stream")
                            .font(.system(size: 10, weight: .bold))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.accentColor.opacity(0.15))
                            .foregroundColor(.accentColor)
                            .cornerRadius(4)
                    }

                    if item.isCompleted {
                        Text("Completed")
                            .font(.system(size: 10, weight: .bold))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.green.opacity(0.15))
                            .foregroundColor(.green)
                            .cornerRadius(4)
                    }
                }
            }

            Spacer()

            Image(systemName: "play.circle.fill")
                .font(.system(size: 24))
                .foregroundColor(.accentColor.opacity(0.8))
        }
        .padding(12)
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(14)
    }

    private func handleFileImport(result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            for url in urls {
                let bookmark = progressStore.createSecurityScopedBookmark(for: url)
                let isAudio = ["mp3", "m4a", "wav", "aac"].contains(url.pathExtension.lowercased())
                let item = MediaItem(
                    title: url.deletingPathExtension().lastPathComponent,
                    url: url,
                    isRemote: false,
                    bookmarkData: bookmark,
                    mediaType: isAudio ? .audio : .video
                )
                let savedItem = progressStore.saveItem(item)

                if urls.count == 1 {
                    startPlayback(for: savedItem)
                }
            }

        case .failure(let error):
            print("Failed to import files: \(error.localizedDescription)")
        }
    }

    private func startPlayback(for item: MediaItem) {
        // Checkpoint whatever is playing first, so the saved entry reflects its latest position.
        playbackManager.persistCurrentProgress()
        let savedItem = progressStore.saveItem(item)

        if playbackManager.isLoaded(savedItem) {
            // Already in the player: show it again instead of reloading, which would rewind it.
            if !playbackManager.isPlaying {
                playbackManager.play()
            }
        } else {
            playbackManager.loadMedia(item: savedItem)
        }
        isPlayerPresented = true
    }
}
