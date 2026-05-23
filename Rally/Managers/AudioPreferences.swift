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
            AudioManager.shared.applySoundEnabled(isSoundEnabled)
        }
    }

    private init() {
        if UserDefaults.standard.object(forKey: UserDefaultsKeys.soundEnabled) == nil {
            isSoundEnabled = false
        } else {
            isSoundEnabled = UserDefaults.standard.bool(forKey: UserDefaultsKeys.soundEnabled)
        }
        AudioManager.shared.applySoundEnabled(isSoundEnabled)
    }
}

struct SoundToggleButton: View {
    @ObservedObject private var audio = AudioPreferences.shared

    var body: some View {
        Button {
            audio.isSoundEnabled.toggle()
        } label: {
            Image(systemName: audio.isSoundEnabled ? "speaker.wave.2.fill" : "speaker.slash.fill")
                .font(.body.weight(.semibold))
                .foregroundStyle(audio.isSoundEnabled ? Color.cyan : Color.white.opacity(0.45))
                .frame(width: 36, height: 36)
                .background(
                    Circle()
                        .fill(Color.white.opacity(0.06))
                )
                .overlay(
                    Circle()
                        .stroke(Color.white.opacity(0.12), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(audio.isSoundEnabled ? "Mute sound" : "Unmute sound")
    }
}
