import SwiftUI

/// Shop-centric avatar presenter: SceneKit figure + horizontal emote picker.
/// Keeps try-on previews (`preview`) in sync with the parent sheet/detail row.
struct AvatarShopStageView: View {
    let config: AvatarConfig
    var preview: (slot: ShopItem.Category, item: ShopItem)?
    @Binding var emote: AvatarShopEmote

    var body: some View {
        VStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 22)
                    .fill(
                        RadialGradient(
                            colors: [Color(red: 0.06, green: 0.08, blue: 0.14), .black],
                            center: .center,
                            startRadius: 20,
                            endRadius: 220
                        )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 22)
                            .stroke(Color.cyan.opacity(0.28), lineWidth: 1)
                    )

                AvatarScene3DView(
                    spec: AvatarVisualSpec.from(config: config, preview: preview),
                    emote: emote
                )
                .frame(height: 300)
                .padding(.top, 6)
            }
            .frame(height: 308)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(AvatarShopEmote.allCases) { e in
                        emoteChip(e)
                    }
                }
                .padding(.horizontal, 4)
            }
        }
    }

    private func emoteChip(_ e: AvatarShopEmote) -> some View {
        let selected = emote == e
        return Button {
            emote = e
        } label: {
            HStack(spacing: 6) {
                Image(systemName: e.symbolName)
                Text(e.label)
                    .font(.system(.caption, design: .rounded).weight(.semibold))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                Capsule()
                    .fill(selected ? Color.cyan.opacity(0.35) : Color.white.opacity(0.06))
            )
            .overlay(
                Capsule()
                    .stroke(selected ? Color.cyan : Color.white.opacity(0.18), lineWidth: 1)
            )
            .foregroundStyle(selected ? Color.black : Color.white.opacity(0.85))
        }
        .buttonStyle(.plain)
    }
}
