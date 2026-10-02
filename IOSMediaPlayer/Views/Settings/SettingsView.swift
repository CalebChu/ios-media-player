import SwiftUI

public struct SettingsView: View {
    @EnvironmentObject private var settings: GestureSettingsStore
    @Environment(\.dismiss) private var dismiss

    public init() {}

    public var body: some View {
        NavigationStack {
            Form {
                gesturesSection
                resetSection
                aboutSection
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }

    // MARK: - Gestures Section

    private var gesturesSection: some View {
        Section {
            // Swipe Down to Exit
            Toggle(isOn: $settings.isSwipeDownToExitEnabled) {
                gestureRow(
                    title: "Swipe Down to Exit",
                    subtitle: "Swipe downwards anywhere on the player to exit playback",
                    systemImage: "arrow.down.to.line",
                    iconColor: .orange
                )
            }

            // Volume Control
            Toggle(isOn: $settings.isVolumeGestureEnabled) {
                gestureRow(
                    title: "Volume Control",
                    subtitle: "Swipe vertically on the right half of the screen",
                    systemImage: "speaker.wave.2.fill",
                    iconColor: .blue,
                    disabledReason: settings.isSwipeDownToExitEnabled
                        ? "Disabled while Swipe Down to Exit is active"
                        : nil
                )
            }
            .disabled(settings.isSwipeDownToExitEnabled)

            // Brightness Control
            Toggle(isOn: $settings.isBrightnessGestureEnabled) {
                gestureRow(
                    title: "Brightness Control",
                    subtitle: "Swipe vertically on the left half of the screen",
                    systemImage: "sun.max.fill",
                    iconColor: .yellow,
                    disabledReason: settings.isSwipeDownToExitEnabled
                        ? "Disabled while Swipe Down to Exit is active"
                        : nil
                )
            }
            .disabled(settings.isSwipeDownToExitEnabled)

            // Horizontal Seek
            Toggle(isOn: $settings.isSeekGestureEnabled) {
                gestureRow(
                    title: "Horizontal Seek",
                    subtitle: "Swipe horizontally to scrub through media",
                    systemImage: "arrow.left.and.right",
                    iconColor: .green
                )
            }

            // Double Tap to Skip
            Toggle(isOn: $settings.isDoubleTapToSkipEnabled) {
                gestureRow(
                    title: "Double Tap to Skip",
                    subtitle: "Double tap the left or right half to skip 10 seconds",
                    systemImage: "goforward.10",
                    iconColor: .purple
                )
            }

            // Single Tap Controls
            Toggle(isOn: $settings.isSingleTapToToggleControlsEnabled) {
                gestureRow(
                    title: "Single Tap Controls",
                    subtitle: "Tap anywhere to show or hide player controls",
                    systemImage: "hand.tap.fill",
                    iconColor: .cyan
                )
            }
        } header: {
            Text("Playback Gestures")
        } footer: {
            Text("Vertical gestures for brightness and volume are only allowed when Swipe Down to Exit is turned off.")
        }
    }

    // MARK: - Row Helper

    private func gestureRow(
        title: String,
        subtitle: String,
        systemImage: String,
        iconColor: Color,
        disabledReason: String? = nil
    ) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: systemImage)
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(iconColor)
                .frame(width: 28, height: 28)
                .padding(.top, 2)

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.body)
                    .foregroundColor(.primary)

                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                if let reason = disabledReason {
                    Text(reason)
                        .font(.caption2.weight(.medium))
                        .foregroundColor(.orange)
                        .padding(.top, 1)
                }
            }
        }
        .padding(.vertical, 4)
    }

    // MARK: - Reset Section

    private var resetSection: some View {
        Section {
            Button(role: .destructive) {
                withAnimation {
                    settings.resetToDefaults()
                }
            } label: {
                HStack {
                    Spacer()
                    Text("Reset Gestures to Defaults")
                        .fontWeight(.medium)
                    Spacer()
                }
            }
        } footer: {
            Text("Restores all gesture settings to their standard configuration (Swipe Down to Exit enabled).")
        }
    }

    // MARK: - About Section

    private var aboutSection: some View {
        Section {
            HStack {
                Text("Version")
                Spacer()
                Text("1.0.0")
                    .foregroundColor(.secondary)
            }
        } header: {
            Text("About")
        }
    }
}
