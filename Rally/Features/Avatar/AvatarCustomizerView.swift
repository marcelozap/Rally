import SwiftUI
import SwiftData

/// Selects one of the six fixed tennis players and preserves the equipped outfit.
/// First launch completes setup; subsequent visits save the player selection.
struct AvatarCustomizerView: View {
    @Bindable var config: AvatarConfig

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var auth: AuthSession
    @EnvironmentObject private var avatarAppearanceStore: RallyAvatarAppearanceStore
    @StateObject private var gamePreferences = GamePreferences.shared

    var isFirstLaunch: Bool = false

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                if isFirstLaunch {
                    welcomeHero
                }

                VStack(spacing: 6) {
                    RallyAvatarView(
                        appearance: avatarAppearanceStore.appearance(for: config),
                        targetHeight: 288,
                        showsRacket: true,
                        breathingPhase: Date().timeIntervalSinceReferenceDate * 1.8,
                        leftHanded: gamePreferences.dominantHand == .left
                    )
                    .frame(height: 288)

                    playerReadout
                        .padding(.bottom, 14)
                }
                .frame(maxWidth: .infinity)
                .background(heroBackdrop)
                .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
                .padding(.horizontal, 20)

                athleteSection
                    .padding(.horizontal, 20)
                    .padding(.bottom, 12)

            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            ctaButton
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(RallyUIKit.screenBackground)
        }
        .navigationTitle(isFirstLaunch ? "" : "Choose your player")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(isFirstLaunch ? .hidden : .visible, for: .navigationBar)
        .background(RallyUIKit.screenBackground.ignoresSafeArea())
        .onAppear {
            avatarAppearanceStore.sync(from: config)
        }
        .onChange(of: config.athletePresetRaw) { _, _ in avatarAppearanceStore.sync(from: config) }
    }

    // MARK: - First-launch hero

    private var welcomeHero: some View {
        VStack(spacing: 6) {
            RallyUIKit.EditorialEyebrow(text: "Welcome to Rally", tint: RallyUIKit.Palette.cyan)
            Text("Choose your player")
                .font(RallyUIKit.Typography.display(28, weight: .bold))
                .foregroundStyle(RallyUIKit.Palette.frost)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 12)
        .padding(.horizontal, 20)
    }

    private var heroBackdrop: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            RallyUIKit.Palette.slate,
                            RallyUIKit.Palette.ink,
                            Color.black
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            Circle()
                .fill(RallyUIKit.Palette.cyan.opacity(0.24))
                .frame(width: 220, height: 220)
                .blur(radius: 48)
                .offset(x: -90, y: -70)

            Circle()
                .fill(RallyUIKit.Palette.champagne.opacity(0.18))
                .frame(width: 200, height: 200)
                .blur(radius: 42)
                .offset(x: 96, y: -48)

            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .stroke(Color.white.opacity(0.09), lineWidth: 1)
        }
    }

    private var playerReadout: some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Text(config.athletePreset.displayName)
                .font(RallyUIKit.Typography.label(.headline, weight: .bold))
                .foregroundStyle(RallyUIKit.Palette.frost)
            Text("Tennis athlete")
                .font(RallyUIKit.Typography.label(.caption, weight: .medium))
                .foregroundStyle(RallyUIKit.Palette.cloud.opacity(0.66))
        }
    }

    // MARK: - Player roster

    private var athleteSection: some View {
        sectionCard(title: "Players") {
            ForEach(RallyAthleteModel.allCases) { model in
                VStack(alignment: .leading, spacing: 8) {
                    Text(model == .male ? "Men" : "Women")
                        .font(RallyUIKit.Typography.label(.caption, weight: .semibold))
                        .foregroundStyle(RallyUIKit.Palette.cloud.opacity(0.65))
                    HStack(spacing: 10) {
                        ForEach(RallyAthletePreset.allCases.filter { $0.athleteModel == model }) { preset in
                            Chip(
                                label: preset.displayName,
                                selected: config.athletePreset == preset
                            ) {
                                config.athletePreset = preset
                                avatarAppearanceStore.sync(from: config)
                            }
                            .accessibilityLabel("\(preset.displayName), \(preset.heritageDescription), \(model.displayName)")
                            .accessibilityIdentifier("athletePreset.\(preset.rawValue)")
                            .accessibilityAddTraits(config.athletePreset == preset ? .isSelected : [])
                        }
                    }
                }
            }
        }
    }

    // MARK: - CTA

    private var ctaButton: some View {
        Button(action: save) {
            HStack(spacing: 8) {
                Text(isFirstLaunch ? "Step onto the court" : "Select player")
                if isFirstLaunch {
                    Image(systemName: "arrow.right")
                }
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(PrimaryButtonStyle(tint: RallyUIKit.Palette.cyan))
    }

    private func sectionTitle(_ text: String) -> some View {
        Text(text)
            .font(RallyUIKit.Typography.label(.caption, weight: .semibold))
            .foregroundStyle(RallyUIKit.Palette.cloud.opacity(0.5))
            .textCase(.uppercase)
    }

    private func sectionCard<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        RallyUIKit.SectionCard(stroke: RallyUIKit.Palette.line) {
            VStack(alignment: .leading, spacing: 10) {
                sectionTitle(title)
                content()
            }
        }
    }

    private func save() {
        config.playerName = config.playerName.trimmingCharacters(in: .whitespaces)
        if config.playerName.isEmpty { config.playerName = "Player" }
        config.hasCompletedSetup = true
        try? modelContext.save()
        avatarAppearanceStore.commitPersisted(from: config)
        if auth.isAuthenticated {
            RallySyncTriggers.pushAvatarAfterLocalSave(modelContext: modelContext)
        }
        if !isFirstLaunch {
            dismiss()
        }
        // First-launch: ContentView re-renders into mainTabs via @Query.
    }
}

// MARK: - Chip

struct Chip: View {
    let label: String
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.system(.subheadline, design: .rounded).weight(.semibold))
                .tracking(0.2)
                .padding(.vertical, 9)
                .padding(.horizontal, 14)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(selected ? AnyShapeStyle(RallyUIKit.accentGradient(RallyUIKit.Palette.cyan)) : AnyShapeStyle(Color.white.opacity(0.08)))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(selected ? Color.white.opacity(0.18) : Color.white.opacity(0.08), lineWidth: 1)
                )
                .foregroundStyle(selected ? .black : .white.opacity(0.88))
        }
        .buttonStyle(.plain)
    }
}
