import SwiftUI

public struct StreamInputSheet: View {
    @Environment(\.dismiss) private var dismiss
    public let onPlay: (MediaItem) -> Void

    @State private var streamTitle = ""
    @State private var streamURLString = ""
    @State private var errorMessage: String?

    private struct SampleStream: Identifiable, Hashable {
        let id = UUID()
        let title: String
        let description: String
        let url: String
    }

    private let sampleStreams: [SampleStream] = [
        SampleStream(
            title: "Big Buck Bunny (HLS)",
            description: "Apple standard HLS test stream with multi-bitrate video",
            url: "https://test-streams.mux.dev/x36xhzz/x36xhzz.m3u8"
        ),
        SampleStream(
            title: "Elephants Dream (Direct MP4)",
            description: "High definition 1080p open-source media stream",
            url: "https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ElephantsDream.mp4"
        ),
        SampleStream(
            title: "For Bigger Blazes (Direct MP4)",
            description: "Chromecast sample video stream with stereo audio",
            url: "https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ForBiggerBlazes.mp4"
        )
    ]

    public init(onPlay: @escaping (MediaItem) -> Void) {
        self.onPlay = onPlay
    }

    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    customURLSection
                    presetsSection
                }
                .padding(20)
            }
            .background(Color(.systemGroupedBackground).ignoresSafeArea())
            .navigationTitle("Network Stream")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }

    private var customURLSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Enter Stream Details")
                .font(.headline)
                .foregroundColor(.primary)

            VStack(spacing: 10) {
                TextField("Stream Title (Optional)", text: $streamTitle)
                    .textFieldStyle(.plain)
                    .padding(12)
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(12)

                TextField("https://example.com/playlist.m3u8", text: $streamURLString)
                    .textFieldStyle(.plain)
                    .keyboardType(.URL)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .padding(12)
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(12)
            }

            if let error = errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundColor(.red)
            }

            Button(action: validateAndPlayCustomStream) {
                HStack {
                    Spacer()
                    Image(systemName: "play.fill")
                    Text("Play Stream")
                        .fontWeight(.semibold)
                    Spacer()
                }
                .padding(.vertical, 14)
                .foregroundColor(.white)
                .background(Color.accentColor)
                .cornerRadius(14)
            }
        }
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(18)
    }

    private var presetsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Sample Streams")
                .font(.headline)
                .foregroundColor(.primary)

            ForEach(sampleStreams, id: \.id) { sample in
                Button(action: {
                    playSampleStream(sample)
                }) {
                    HStack(spacing: 14) {
                        Image(systemName: "play.circle.fill")
                            .font(.system(size: 28))
                            .foregroundColor(.accentColor)

                        VStack(alignment: .leading, spacing: 4) {
                            Text(sample.title)
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundColor(.primary)

                            Text(sample.description)
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                                .lineLimit(2)
                        }

                        Spacer()

                        Image(systemName: "chevron.right")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(Color(uiColor: .tertiaryLabel))
                    }
                    .padding(14)
                    .background(Color(.secondarySystemGroupedBackground))
                    .cornerRadius(14)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func validateAndPlayCustomStream() {
        guard let url = URL(string: streamURLString.trimmingCharacters(in: .whitespacesAndNewlines)),
              url.scheme == "http" || url.scheme == "https" else {
            errorMessage = "Please enter a valid HTTP or HTTPS stream URL."
            return
        }

        let title = streamTitle.isEmpty ? url.lastPathComponent : streamTitle
        let item = MediaItem(
            title: title.isEmpty ? "Network Stream" : title,
            url: url,
            isRemote: true,
            mediaType: .video
        )
        onPlay(item)
        dismiss()
    }

    private func playSampleStream(_ sample: SampleStream) {
        guard let url = URL(string: sample.url) else { return }
        let item = MediaItem(
            title: sample.title,
            artist: "Sample Stream",
            url: url,
            isRemote: true,
            mediaType: .video
        )
        onPlay(item)
        dismiss()
    }
}
