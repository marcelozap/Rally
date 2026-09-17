import SwiftUI
import SwiftData

/// Selects a generic model with simple skin and hair color choices.
/// Model geometry, hairstyle and equipped clothing remain independent of color.
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

                VStack(spacing: 0) {
                    HStack {
                        RallyUIKit.EditorialEyebrow(text: "Player studio", tint: RallyUIKit.Palette.champagne)
                        Spacer()
                        Image(systemName: "rotate.3d")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(RallyUIKit.Palette.cloud.opacity(0.65))
                            .accessibilityHidden(true)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 18)
                    RallyAvatarView(
                        appearance: avatarAppearanceStore.appearance(for: config),
                        targetHeight: 304,
                        showsRacket: true,
                        breathingPhase: Date().timeIntervalSinceReferenceDate * 1.8,
                        leftHanded: gamePreferences.dominantHand == .left
                    )
                    .frame(height: 304)

                    playerReadout
                        .padding(.horizontal, 18)
                        .padding(.bottom, 18)
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
        .navigationTitle(isFirstLaunch ? "" : "Your player")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(isFirstLaunch ? .hidden : .visible, for: .navigationBar)
        .background(RallyUIKit.screenBackground.ignoresSafeArea())
        .onAppear {
            avatarAppearanceStore.sync(from: config)
        }
        .onChange(of: config.athletePresetRaw) { _, _ in avatarAppearanceStore.sync(from: config) }
        .onChange(of: config.skinToneOverrideRaw) { _, _ in avatarAppearanceStore.sync(from: config) }
        .onChange(of: config.hairColorOverrideHex) { _, _ in avatarAppearanceStore.sync(from: config) }
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
                            Color(red: 0.13, green: 0.24, blue: 0.20),
                            RallyUIKit.Palette.slate,
                            RallyUIKit.Palette.ink
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            RadialGradient(colors: [RallyUIKit.Palette.champagne.opacity(0.13), .clear],
                           center: .init(x: 0.5, y: 0.32), startRadius: 8, endRadius: 220)

            GeometryReader { geometry in
                Ellipse()
                    .fill(RallyUIKit.Palette.champagne.opacity(0.035))
                    .overlay(Ellipse().stroke(RallyUIKit.Palette.champagne.opacity(0.10), lineWidth: 1))
                    .frame(width: geometry.size.width * 0.74, height: 38)
                    .position(x: geometry.size.width / 2, y: geometry.size.height - 94)
            }

            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .stroke(RallyUIKit.Palette.champagne.opacity(0.14), lineWidth: 1)
        }
    }

    private var playerReadout: some View {
        VStack(spacing: 6) {
            Text("\(config.athletePreset.athleteModel == .male ? "Men" : "Women") · \(config.athletePreset.displayName)")
                .font(RallyUIKit.Typography.label(.headline, weight: .bold))
                .foregroundStyle(RallyUIKit.Palette.frost)
            Text("Drag to rotate · Pinch to zoom")
                .font(RallyUIKit.Typography.label(.caption, weight: .medium))
                .foregroundStyle(RallyUIKit.Palette.cloud.opacity(0.66))
        }
        .multilineTextAlignment(.center)
    }

    // MARK: - Model and color selection

    private var athleteSection: some View {
        sectionCard(title: "Models") {
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
                            .accessibilityLabel("\(model == .male ? "Men" : "Women") \(preset.displayName.lowercased())")
                            .accessibilityIdentifier("athletePreset.\(preset.rawValue)")
                            .accessibilityAddTraits(config.athletePreset == preset ? .isSelected : [])
                        }
                    }
                }
            }

            Divider().overlay(RallyUIKit.Palette.line)

            HStack(spacing: 8) {
                colorRowLabel("Skin")
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 2) {
                        ForEach(AvatarSkinTone.allCases) { tone in
                            colorSwatch(hex: tone.hex, label: "Skin, \(tone.displayName)",
                                        selected: config.skinToneOverride == tone) {
                                config.skinToneOverride = tone
                                avatarAppearanceStore.sync(from: config)
                            }
                            .accessibilityIdentifier("skinColor.\(tone.rawValue)")
                        }
                    }
                }
            }

            HStack(spacing: 8) {
                colorRowLabel("Hair")
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 2) {
                        ForEach(AvatarHairColor.allCases) { color in
                            colorSwatch(hex: color.hex, label: "Hair, \(color.displayName)",
                                        selected: config.hairColorOverrideHex == color.hex) {
                                config.hairColorOverrideHex = color.hex
                                avatarAppearanceStore.sync(from: config)
                            }
                            .accessibilityIdentifier("hairColor.\(color.rawValue)")
                        }
                    }
                }
            }
        }
    }

    private func colorRowLabel(_ text: String) -> some View {
        Text(text)
            .font(RallyUIKit.Typography.label(.caption, weight: .semibold))
            .foregroundStyle(RallyUIKit.Palette.cloud.opacity(0.72))
            .frame(width: 34, alignment: .leading)
    }

    private func colorSwatch(hex: String, label: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Circle()
                .fill(Color(hex: hex) ?? .gray)
                .frame(width: 28, height: 28)
                .overlay(Circle().stroke(Color.white.opacity(0.3), lineWidth: 1))
                .overlay(Circle().stroke(selected ? RallyUIKit.Palette.cyan : .clear, lineWidth: 2).padding(-3))
                .frame(width: 40, height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    // MARK: - CTA

    private var ctaButton: some View {
        Button(action: save) {
            HStack(spacing: 8) {
                Text(isFirstLaunch ? "Step onto the court" : "Save changes")
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
            HStack(spacing: 5) {
                Image(systemName: "checkmark")
                    .font(.system(size: 10, weight: .bold))
                    .opacity(selected ? 1 : 0)
                Text(label)
                    .font(RallyUIKit.Typography.label(.subheadline, weight: .semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.9)
            }
                .padding(.vertical, 9)
                .padding(.horizontal, 8)
                .frame(maxWidth: .infinity, minHeight: 44)
                .background(
                    RoundedRectangle(cornerRadius: 13, style: .continuous)
                        .fill(selected ? RallyUIKit.Palette.cyan : Color.white.opacity(0.045))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 13, style: .continuous)
                        .stroke(selected ? RallyUIKit.Palette.cyan.opacity(0.8) : Color.white.opacity(0.12), lineWidth: 1)
                )
                .foregroundStyle(selected ? RallyUIKit.Palette.ink : RallyUIKit.Palette.frost)
        }
        .buttonStyle(.plain)
    }
}
