import SwiftUI
import SpriteKit

/// Root SwiftUI router. Menus are SwiftUI; gameplay is SpriteKit hosted via
/// `SpriteView`. Keep this view thin — anything stateful lives in
/// `AppState` or the relevant manager.
struct ContentView: View {
    @State private var screen: Screen = .menu

    enum Screen: Hashable {
        case menu
        case play
        case cosmetics
        case settings
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            switch screen {
            case .menu:
                MenuView(
                    onPlay: { screen = .play },
                    onCosmetics: { screen = .cosmetics },
                    onSettings: { screen = .settings }
                )
            case .play:
                GameContainerView(onExit: { screen = .menu })
            case .cosmetics:
                CosmeticsPlaceholderView(onBack: { screen = .menu })
            case .settings:
                SettingsPlaceholderView(onBack: { screen = .menu })
            }
        }
        .animation(.easeInOut(duration: 0.2), value: screen)
    }
}

// MARK: - Menu

private struct MenuView: View {
    let onPlay: () -> Void
    let onCosmetics: () -> Void
    let onSettings: () -> Void

    var body: some View {
        VStack(spacing: 40) {
            Spacer()

            Text("RALLY")
                .font(.system(size: 72, weight: .heavy, design: .rounded))
                .kerning(8)
                .foregroundStyle(
                    LinearGradient(
                        colors: [.cyan, .pink],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .shadow(color: .cyan.opacity(0.6), radius: 24)

            Text("swipe to the beat")
                .font(.system(.callout, design: .rounded))
                .foregroundStyle(.white.opacity(0.5))
                .textCase(.lowercase)

            Spacer()

            VStack(spacing: 16) {
                NeonButton(title: "PLAY", tint: .cyan, action: onPlay)
                NeonButton(title: "COSMETICS", tint: .pink, action: onCosmetics)
                NeonButton(title: "SETTINGS", tint: .white, action: onSettings)
            }
            .padding(.horizontal, 40)

            Spacer().frame(height: 60)
        }
    }
}

private struct NeonButton: View {
    let title: String
    let tint: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(.title3, design: .rounded).weight(.bold))
                .kerning(3)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 18)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(tint, lineWidth: 1.5)
                )
                .foregroundStyle(tint)
                .shadow(color: tint.opacity(0.5), radius: 12)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Gameplay container

private struct GameContainerView: View {
    let onExit: () -> Void

    private let scene: GameScene = {
        let s = GameScene(size: UIScreen.main.bounds.size)
        s.scaleMode = .resizeFill
        return s
    }()

    var body: some View {
        ZStack(alignment: .topLeading) {
            SpriteView(scene: scene, options: [.ignoresSiblingOrder])
                .ignoresSafeArea()

            Button(action: onExit) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 28))
                    .foregroundStyle(.white.opacity(0.7))
                    .padding()
            }
        }
    }
}

// MARK: - Placeholders (real screens come in their own commits)

private struct CosmeticsPlaceholderView: View {
    let onBack: () -> Void
    var body: some View {
        PlaceholderView(title: "Cosmetics", onBack: onBack)
    }
}

private struct SettingsPlaceholderView: View {
    let onBack: () -> Void
    var body: some View {
        PlaceholderView(title: "Settings", onBack: onBack)
    }
}

private struct PlaceholderView: View {
    let title: String
    let onBack: () -> Void
    var body: some View {
        VStack(spacing: 24) {
            HStack {
                Button(action: onBack) {
                    Image(systemName: "chevron.left")
                        .font(.title2.weight(.bold))
                        .foregroundStyle(.white)
                }
                Spacer()
            }
            .padding()

            Text(title)
                .font(.system(.largeTitle, design: .rounded).weight(.bold))
                .foregroundStyle(.white)

            Text("Coming soon")
                .foregroundStyle(.white.opacity(0.4))

            Spacer()
        }
    }
}

#Preview {
    ContentView()
}
