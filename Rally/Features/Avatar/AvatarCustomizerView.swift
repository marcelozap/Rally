import SwiftUI
import SwiftData

/// Two-mode avatar editor.
///
/// - **First-launch mode** (`isFirstLaunch == true`): the gating screen the
///   app boots into on a fresh install. Adds a hero "Build your avatar"
///   intro, auto-focuses the name field, and the bottom CTA reads
///   "Step onto the court". `ContentView`'s `@Query` observation reads
///   `hasCompletedSetup = true` and transitions to the main tabs — no
///   manual dismiss needed.
///
/// - **Edit mode** (`isFirstLaunch == false`): pushed from Home via the
///   avatar icon. Same form, no hero, CTA reads "Save changes" and pops
///   the navigation stack on save.
struct AvatarCustomizerView: View {
    @Bindable var config: AvatarConfig

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var auth: AuthSession
    @FocusState private var nameFieldFocused: Bool

    var isFirstLaunch: Bool = false

    private static let hairColorPalette: [(name: String, hex: String)] = [
        ("Black",    "#1A1410"),
        ("Brown",    "#5C3A20"),
        ("Chestnut", "#8B5A2B"),
        ("Blonde",   "#E0C088"),
        ("Auburn",   "#A93226"),
        ("Silver",   "#C0C0C0"),
        ("Magenta",  "#D63384"),
        ("Cyan",     "#00BCD4")
    ]

    var body: some View {
        ScrollView {
            VStack(spacing: RallyUIKit.Spacing.xl) {
                if isFirstLaunch {
                    welcomeHero
                }

                RallyUIKit.SectionCard(stroke: RallyUIKit.Palette.cyan.opacity(0.24)) {
                    ZStack(alignment: .bottom) {
                        heroBackdrop

                        AvatarRealityKitView(
                            spec: AvatarVisualSpec.from(config: config, preview: nil),
                            emote: .shopLook
                        )
                        .frame(height: isFirstLaunch ? 300 : 336)
                        .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))

                        customizationReadout
                            .padding(.horizontal, 14)
                            .padding(.bottom, 14)
                    }
                }
                .padding(.horizontal, 20)

                VStack(alignment: .leading, spacing: 18) {
                    namingSection
                    skinSection
                    hairStyleSection
                    hairColorSection
                    bodySection
                }
                .padding(.horizontal, 20)

                ctaButton
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
                    .padding(.bottom, 40)
            }
        }
        .navigationTitle(isFirstLaunch ? "" : "Your avatar")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(isFirstLaunch ? .hidden : .visible, for: .navigationBar)
        .background(RallyUIKit.screenBackground.ignoresSafeArea())
        .onAppear {
            if isFirstLaunch {
                // Tiny delay so the keyboard avoidance settles after layout.
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                    nameFieldFocused = true
                }
            }
        }
    }

    // MARK: - First-launch hero

    private var welcomeHero: some View {
        RallyUIKit.LuxePanel(tint: RallyUIKit.Palette.cyan) {
            VStack(spacing: 10) {
                RallyUIKit.EditorialEyebrow(text: "Welcome to Rally", tint: RallyUIKit.Palette.cyan)

                Text("Build your avatar")
                    .font(RallyUIKit.Typography.display(34, weight: .bold))
                    .foregroundStyle(RallyUIKit.Palette.frost)
                    .multilineTextAlignment(.center)

                Text("This is the player you’ll see on Home, in the shop try-on, and across your match history. You can change all of it later from the avatar icon on Home.")
                    .font(RallyUIKit.Typography.body(.subheadline, weight: .medium))
                    .foregroundStyle(RallyUIKit.Palette.cloud.opacity(0.74))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 6)
            }
            .frame(maxWidth: .infinity)
        }
        .padding(.top, 24)
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

    private var customizationReadout: some View {
        HStack(spacing: 8) {
            StatPill(label: config.bodyType.displayName, tint: RallyUIKit.Palette.cyan)
            StatPill(label: config.hairStyle.displayName, tint: RallyUIKit.Palette.rose)
            StatPill(label: config.skinTone.displayName, tint: RallyUIKit.Palette.champagne)
        }
    }

    // MARK: - Sections

    private var namingSection: some View {
        sectionCard(title: "Name") {
            TextField("Your name", text: $config.playerName)
                .focused($nameFieldFocused)
                .submitLabel(.done)
                .rallyTextFieldStyle()
        }
    }

    private var skinSection: some View {
        sectionCard(title: "Skin tone") {
            HStack(spacing: 12) {
                ForEach(AvatarSkinTone.allCases) { tone in
                    Circle()
                        .fill(Color(hex: tone.hex) ?? .gray)
                        .frame(width: 36, height: 36)
                        .overlay(
                            Circle()
                                .stroke(config.skinTone == tone ? Color.cyan : .clear, lineWidth: 2)
                        )
                        .onTapGesture { config.skinTone = tone }
                }
            }
        }
    }

    private var hairStyleSection: some View {
        sectionCard(title: "Hair style") {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(AvatarHairStyle.allCases) { style in
                        Chip(
                            label: style.displayName,
                            selected: config.hairStyle == style
                        ) {
                            config.hairStyle = style
                        }
                    }
                }
            }
        }
    }

    private var hairColorSection: some View {
        sectionCard(title: "Hair color") {
            HStack(spacing: 12) {
                ForEach(Self.hairColorPalette, id: \.hex) { entry in
                    Circle()
                        .fill(Color(hex: entry.hex) ?? .gray)
                        .frame(width: 30, height: 30)
                        .overlay(
                            Circle()
                                .stroke(config.hairColorHex == entry.hex ? Color.cyan : .clear, lineWidth: 2)
                        )
                        .onTapGesture { config.hairColorHex = entry.hex }
                }
            }
        }
    }

    private var bodySection: some View {
        sectionCard(title: "Build") {
            HStack(spacing: 10) {
                ForEach(AvatarBodyType.allCases) { type in
                    Chip(
                        label: type.displayName,
                        selected: config.bodyType == type
                    ) {
                        config.bodyType = type
                    }
                }
            }
        }
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
        .disabled(!canSave)
    }

    private var canSave: Bool {
        // Require at least a non-empty name on first launch so the player
        // doesn't end up greeted as "Player" forever.
        if isFirstLaunch {
            return !config.playerName.trimmingCharacters(in: .whitespaces).isEmpty
        }
        return true
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
        if config.playerName.isEmpty { config.playerName = "Marcy" }
        config.hasCompletedSetup = true
        try? modelContext.save()
        if auth.isAuthenticated {
            Task {
                await RallySyncCoordinator.pushIfAuthenticated(modelContext: modelContext)
            }
        }
        if !isFirstLaunch {
            dismiss()
        }
        // First-launch: ContentView re-renders into mainTabs via @Query.
    }
}

// MARK: - Chip

private struct StatPill: View {
    let label: String
    let tint: Color

    var body: some View {
        Text(label)
            .font(RallyUIKit.Typography.label(.caption, weight: .semibold))
            .foregroundStyle(.white.opacity(0.94))
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
            .background(
                Capsule()
                    .fill(Color.black.opacity(0.36))
            )
            .overlay(
                Capsule()
                    .stroke(tint.opacity(0.45), lineWidth: 1)
            )
    }
}

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
