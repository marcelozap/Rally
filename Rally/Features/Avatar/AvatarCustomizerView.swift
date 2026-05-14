import SwiftUI
import SwiftData

/// First-launch customizer. Captures the player's name and the four
/// non-equipment avatar fields (skin tone, hair style, hair color, body
/// type). Sets `AvatarConfig.hasCompletedSetup = true` on save.
struct AvatarCustomizerView: View {
    @Bindable var config: AvatarConfig
    @Environment(\.modelContext) private var modelContext

    /// When this is the first-launch flow, `onComplete` dismisses the gate.
    /// In "edit avatar" mode, it pops the navigation stack.
    var onComplete: (() -> Void)? = nil

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
                AvatarView(config: config)
                    .frame(height: 320)
                    .padding(.horizontal)

                VStack(alignment: .leading, spacing: 18) {
                    namingSection
                    skinSection
                    hairStyleSection
                    hairColorSection
                    bodySection
                }
                .padding(.horizontal, 20)

                Button {
                    config.hasCompletedSetup = true
                    try? modelContext.save()
                    onComplete?()
                } label: {
                    Text(onComplete == nil ? "Save changes" : "Step onto the court")
                        .font(.system(.headline, design: .rounded))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            RoundedRectangle(cornerRadius: 14)
                                .fill(Color.cyan)
                        )
                        .foregroundStyle(.black)
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 40)
            }
        }
        .navigationTitle("Your avatar")
        .navigationBarTitleDisplayMode(.inline)
        .background(Color.black.ignoresSafeArea())
    }

    // MARK: Sections

    private var namingSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Name")
                .font(.system(.caption, design: .rounded).weight(.semibold))
                .foregroundStyle(.white.opacity(0.5))
                .textCase(.uppercase)
            TextField("Player", text: $config.playerName)
                .textFieldStyle(.plain)
                .padding(.vertical, 10)
                .padding(.horizontal, 12)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.white.opacity(0.15), lineWidth: 1)
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

    private func sectionTitle(_ text: String) -> some View {
        Text(text)
            .font(.system(.caption, design: .rounded).weight(.semibold))
            .foregroundStyle(.white.opacity(0.5))
            .textCase(.uppercase)
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
