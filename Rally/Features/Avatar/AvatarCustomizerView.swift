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
            VStack(spacing: 24) {
                if isFirstLaunch {
                    welcomeHero
                }

                AvatarView(config: config)
                    .frame(height: isFirstLaunch ? 280 : 320)
                    .padding(.horizontal)

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
        .background(Color.black.ignoresSafeArea())
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
        VStack(spacing: 8) {
            Text("WELCOME TO RALLY")
                .font(.system(.caption, design: .rounded).weight(.bold))
                .kerning(4)
                .foregroundStyle(.cyan)

            Text("Build your avatar")
                .font(.system(.largeTitle, design: .rounded).weight(.heavy))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)

            Text("This is the player you'll see everywhere in Rally — on Home, in the shop try-on, and over your match history. Change any of it later from the avatar icon on Home.")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.55))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 16)
                .padding(.top, 2)
        }
        .padding(.top, 24)
        .padding(.horizontal, 16)
    }

    // MARK: - Sections

    private var namingSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionTitle("Name")
            TextField("Your name", text: $config.playerName)
                .focused($nameFieldFocused)
                .textFieldStyle(.plain)
                .submitLabel(.done)
                .padding(.vertical, 10)
                .padding(.horizontal, 12)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(nameFieldFocused ? Color.cyan : Color.white.opacity(0.15), lineWidth: 1)
                )
                .foregroundStyle(.white)
        }
    }

    private var skinSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionTitle("Skin tone")
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
        VStack(alignment: .leading, spacing: 10) {
            sectionTitle("Hair style")
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
        VStack(alignment: .leading, spacing: 10) {
            sectionTitle("Hair color")
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
        VStack(alignment: .leading, spacing: 10) {
            sectionTitle("Build")
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
            .font(.system(.headline, design: .rounded).weight(.bold))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 18)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(canSave ? Color.cyan : Color.cyan.opacity(0.35))
            )
            .foregroundStyle(.black)
        }
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
            .font(.system(.caption, design: .rounded).weight(.semibold))
            .foregroundStyle(.white.opacity(0.5))
            .textCase(.uppercase)
    }

    private func save() {
        config.playerName = config.playerName.trimmingCharacters(in: .whitespaces)
        if config.playerName.isEmpty { config.playerName = "Player" }
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

struct Chip: View {
    let label: String
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.system(.subheadline, design: .rounded).weight(.medium))
                .padding(.vertical, 8)
                .padding(.horizontal, 14)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(selected ? Color.cyan : Color.white.opacity(0.08))
                )
                .foregroundStyle(selected ? .black : .white)
        }
        .buttonStyle(.plain)
    }
}
