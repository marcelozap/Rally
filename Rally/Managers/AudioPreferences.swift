import Combine
import SwiftUI

/// User-facing sound toggle backed by `UserDefaults` and wired to `AudioManager`.
@MainActor
final class AudioPreferences: ObservableObject {
    static let shared = AudioPreferences()

    @Published var isSoundEnabled: Bool {
        didSet {
            guard oldValue != isSoundEnabled else { return }
            UserDefaults.standard.set(isSoundEnabled, forKey: UserDefaultsKeys.soundEnabled)
            UserDefaults.standard.set(true, forKey: UserDefaultsKeys.soundPreferenceExplicitlySet)
            AudioManager.shared.applySoundEnabled(isSoundEnabled)
        }
    }

    private init() {
        isSoundEnabled = RallyDefaults.resolvedSoundEnabled()
        AudioManager.shared.applySoundEnabled(isSoundEnabled)
    }
}

struct SoundToggleButton: View {
    @ObservedObject private var audio = AudioPreferences.shared

    var body: some View {
        Button {
            audio.isSoundEnabled.toggle()
        } label: {
            HStack(spacing: 6) {
                Image(systemName: audio.isSoundEnabled ? "speaker.wave.2.fill" : "speaker.slash.fill")
                    .font(.system(size: 12, weight: .bold))
                Text(audio.isSoundEnabled ? "Sound On" : "Sound Off")
                    .font(.system(size: 11, weight: .black, design: .rounded))
                    .lineLimit(1)
            }
            .foregroundStyle(audio.isSoundEnabled ? Color.cyan : Color.white.opacity(0.62))
            .padding(.horizontal, 10)
            .frame(height: 36)
            .background(
                Capsule(style: .continuous)
                    .fill(Color.white.opacity(audio.isSoundEnabled ? 0.10 : 0.055))
            )
            .overlay(
                Capsule(style: .continuous)
                    .stroke(audio.isSoundEnabled ? Color.cyan.opacity(0.34) : Color.white.opacity(0.12), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(audio.isSoundEnabled ? "Mute sound" : "Unmute sound")
    }
}
