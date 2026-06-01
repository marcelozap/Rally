import SwiftUI
import SwiftData

struct HomeView: View {
    @EnvironmentObject private var auth: AuthSession
    @Query private var avatarConfigs: [AvatarConfig]
    @Query private var progressRecords: [PlayerProgress]

    @Binding var selectedTab: RallyTab
    @Binding var isPlaying: Bool

    @StateObject private var gamePreferences = GamePreferences.shared

    private var avatar: AvatarConfig? { avatarConfigs.first }
    private var progress: PlayerProgress? { progressRecords.first }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: RallyUIKit.Spacing.lg) {
                    if auth.isGuestMode {
                        guestOfflineBanner
                    }
                    avatarCard
                    homeLoadoutSection
                    pregameSection
                }
                .padding(.horizontal, RallyUIKit.Spacing.md)
                .padding(.vertical, RallyUIKit.Spacing.sm)
            }
            .background(RallyUIKit.screenBackground)
            .navigationTitle(greeting)
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Menu {
                        if auth.isGuestMode {
                            Label("Offline on this device", systemImage: "wifi.slash")
                        }
                        if let email = auth.userEmail {
                            Label(email, systemImage: "envelope.fill")
                        }
                        Button(auth.isGuestMode ? "Leave offline mode…" : "Sign out", role: .destructive) {
                            auth.logout()
                        }
                    } label: {
                        Image(systemName: "person.text.rectangle")
                            .foregroundStyle(RallyUIKit.Palette.champagne)
                    }
                    .accessibilityLabel("Account")
                }
                ToolbarItem(placement: .topBarTrailing) {
                    if let avatar = avatar {
                        NavigationLink {
                            AvatarCustomizerView(config: avatar)
                        } label: {
                            Image(systemName: "person.crop.circle")
                                .foregroundStyle(RallyUIKit.Palette.champagne)
                        }
                    }
                }
            }
        }
    }

    private var homeLoadoutSection: some View {
        RallyUIKit.LuxePanel(tint: RallyUIKit.Palette.champagne) {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top, spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        RallyUIKit.EditorialEyebrow(text: "Locker room", tint: RallyUIKit.Palette.champagne)
                        Text("Pick your loadout, then play")
                            .font(RallyUIKit.Typography.title(.headline, weight: .bold))
                            .foregroundStyle(RallyUIKit.Palette.frost)
                        Text("Racket, top, bottom, and shoes should feel like one look before you head into wall rally.")
                            .font(RallyUIKit.Typography.body(.caption, weight: .medium))
                            .foregroundStyle(RallyUIKit.Palette.cloud.opacity(0.76))
                    }

                    Spacer(minLength: 8)

                    Button {
                        selectedTab = .shop
                    } label: {
                        Text("Edit")
                            .font(RallyUIKit.Typography.label(.caption, weight: .bold))
                            .foregroundStyle(RallyUIKit.Palette.champagne)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(
                                Capsule().fill(RallyUIKit.Palette.champagne.opacity(0.12))
                            )
                            .overlay(
                                Capsule().stroke(RallyUIKit.Palette.champagne.opacity(0.22), lineWidth: 1)
                            )
                    }
                    .buttonStyle(.plain)
                }

                HStack(spacing: 10) {
                    homeLoadoutChip(title: "Racket", value: equippedItemName(avatar?.equippedRacketID, fallback: "Ready"), tint: RallyUIKit.Palette.cyan)
                    homeLoadoutChip(title: "Top", value: equippedItemName(avatar?.equippedTopID, fallback: "Top"), tint: RallyUIKit.Palette.champagne)
                }

                HStack(spacing: 10) {
                    homeLoadoutChip(title: "Bottom", value: equippedItemName(avatar?.equippedBottomID, fallback: "Bottom"), tint: RallyUIKit.Palette.gold)
                    homeLoadoutChip(title: "Shoes", value: equippedItemName(avatar?.equippedShoesID, fallback: "Shoes"), tint: RallyUIKit.Palette.rose)
                }
            }
        }
    }

    private func equippedItemName(_ itemID: String?, fallback: String) -> String {
        guard let itemID, let item = ShopCatalog.item(id: itemID) else {
            return fallback
        }
        return item.name
    }

    private func homeLoadoutChip(title: String, value: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title.uppercased())
                .font(RallyUIKit.Typography.body(.caption2, weight: .bold))
                .tracking(1.0)
                .foregroundStyle(tint.opacity(0.9))
            Text(value)
                .font(RallyUIKit.Typography.label(.caption, weight: .semibold))
                .foregroundStyle(RallyUIKit.Palette.frost)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: RallyUIKit.Radius.sm)
                .fill(Color.white.opacity(0.04))
        )
        .overlay(
            RoundedRectangle(cornerRadius: RallyUIKit.Radius.sm)
                .stroke(tint.opacity(0.18), lineWidth: 1)
        )
    }

    private var guestOfflineBanner: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "icloud.slash")
                .font(.title3)
                .foregroundStyle(RallyUIKit.Palette.gold)
            Text("You're playing offline for now. Your progress stays on this device until you sign in and turn sync on.")
                .font(RallyUIKit.Typography.body(.caption, weight: .medium))
                .foregroundStyle(RallyUIKit.Palette.cloud.opacity(0.88))
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(RallyUIKit.Spacing.sm)
        .background(RoundedRectangle(cornerRadius: RallyUIKit.Radius.md).fill(RallyUIKit.Palette.gold.opacity(0.12)))
        .overlay(RoundedRectangle(cornerRadius: RallyUIKit.Radius.md).stroke(RallyUIKit.Palette.gold.opacity(0.28), lineWidth: 1))
    }

    private var greeting: String {
        let raw = avatar?.playerName.trimmingCharacters(in: .whitespaces) ?? ""
        let name = raw.isEmpty ? "Marcy" : raw
        return "Hey, \(name)"
    }

    // MARK: - Avatar card

    private var avatarCard: some View {
        Group {
            if let avatar = avatar {
                RallyUIKit.LuxePanel(tint: RallyUIKit.Palette.cyan) {
                    VStack(alignment: .leading, spacing: 16) {
                        HStack(alignment: .top, spacing: 12) {
                            VStack(alignment: .leading, spacing: 4) {
                                RallyUIKit.EditorialEyebrow(text: "Player", tint: RallyUIKit.Palette.cyan)
                                Text(displayName(for: avatar))
                                    .font(RallyUIKit.Typography.display(34, weight: .bold))
                                    .foregroundStyle(RallyUIKit.Palette.frost)
                                Text("Pregame hub")
                                    .font(RallyUIKit.Typography.body(.caption, weight: .semibold))
                                    .foregroundStyle(RallyUIKit.Palette.cloud.opacity(0.66))
                            }
                            Spacer(minLength: 0)
                            if let progress {
                                levelHeroBadge(progress)
                            }
                        }

                        ZStack(alignment: .bottomLeading) {
                            if usesReferenceAvatarArt(avatar) {
                                referenceAvatarArt
                                    .frame(height: 320)
                            } else {
                                AvatarView(config: avatar, subtlePerspective: true)
                                    .frame(height: 320)
                            }

                            HStack(spacing: 8) {
                                heroStatPill(icon: "circle.hexagongrid.fill", value: "\(progress?.coins ?? 0)", tint: RallyUIKit.Palette.gold)
                                heroStatPill(icon: "star.fill", value: "\(progress?.bestScore ?? 0)", tint: RallyUIKit.Palette.cyan)
                                heroStatPill(icon: "flame.fill", value: "\(progress?.dailyStreak ?? 0)d", tint: RallyUIKit.Palette.rose)
                            }
                            .padding(16)
                        }

                        HStack(alignment: .top, spacing: 12) {
                            VStack(alignment: .leading, spacing: 6) {
                                Text("Current look")
                                    .font(RallyUIKit.Typography.label(.caption, weight: .bold))
                                    .foregroundStyle(RallyUIKit.Palette.cloud.opacity(0.8))
                                Text(equippedSummary(avatar))
                                    .font(RallyUIKit.Typography.body(.subheadline, weight: .semibold))
                                    .foregroundStyle(RallyUIKit.Palette.frost)
                                    .lineLimit(2)
                            }
                            Spacer(minLength: 8)
                            if let progress {
                                VStack(alignment: .trailing, spacing: 6) {
                                    Text("Progress")
                                        .font(RallyUIKit.Typography.label(.caption, weight: .bold))
                                        .foregroundStyle(RallyUIKit.Palette.cloud.opacity(0.8))
                                    Text("\(progress.xpToNextLevel) XP to lv. \(progress.level + 1)")
                                        .font(RallyUIKit.Typography.body(.caption, weight: .medium))
                                        .foregroundStyle(RallyUIKit.Palette.cloud.opacity(0.72))
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    private func equippedSummary(_ avatar: AvatarConfig) -> String {
        let top = ShopCatalog.item(id: avatar.equippedTopID)?.name ?? "—"
        let racket = ShopCatalog.item(id: avatar.equippedRacketID)?.name ?? "—"
        return "\(top) · \(racket)"
    }

    private func displayName(for avatar: AvatarConfig) -> String {
        let raw = avatar.playerName.trimmingCharacters(in: .whitespacesAndNewlines)
        return raw.isEmpty ? "Marcy" : raw
    }

    private func usesReferenceAvatarArt(_ avatar: AvatarConfig) -> Bool {
        displayName(for: avatar).caseInsensitiveCompare("Marcy") == .orderedSame
    }

    private var referenceAvatarArt: some View {
        ZStack {
            LinearGradient(
                colors: [
                    RallyUIKit.Palette.ink,
                    RallyUIKit.Palette.slate,
                    Color.black
                ],
                startPoint: .top,
                endPoint: .bottom
            )

            Image("MarcyAvatarReference")
                .resizable()
                .interpolation(.high)
                .scaledToFit()
                .padding(.horizontal, 18)
                .padding(.top, 10)
                .padding(.bottom, 6)
        }
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }

    private func levelHeroBadge(_ p: PlayerProgress) -> some View {
        ZStack {
            Circle()
                .fill(LinearGradient(
                    colors: [RallyUIKit.Palette.champagne, RallyUIKit.Palette.gold, RallyUIKit.Palette.cyan],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                ))
                .frame(width: 62, height: 62)
            Text("\(p.level)")
                .font(RallyUIKit.Typography.display(24, weight: .bold))
                .foregroundStyle(RallyUIKit.Palette.obsidian)
        }
        .shadow(color: RallyUIKit.Shadow.glow(RallyUIKit.Palette.gold), radius: 14, x: 0, y: 10)
    }

    private func heroStatPill(icon: String, value: String, tint: Color) -> some View {
        HStack(spacing: RallyUIKit.Spacing.xs) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(tint)
            Text(value)
                .font(RallyUIKit.Typography.label(.caption, weight: .bold))
                .foregroundStyle(RallyUIKit.Palette.frost)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            Capsule().fill(Color.black.opacity(0.34))
        )
        .overlay(
            Capsule().stroke(tint.opacity(0.22), lineWidth: 1)
        )
    }

    private var pregameSection: some View {
        RallyUIKit.LuxePanel(tint: RallyUIKit.Palette.cyan) {
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .top, spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        RallyUIKit.EditorialEyebrow(text: "Play", tint: RallyUIKit.Palette.cyan)
                        Text("Step into one live rally")
                            .font(RallyUIKit.Typography.title(.headline, weight: .bold))
                            .foregroundStyle(RallyUIKit.Palette.frost)
                        Text("Pick the court, set handedness, then go straight into the one-ball wall rhythm.")
                            .font(RallyUIKit.Typography.body(.caption, weight: .medium))
                            .foregroundStyle(RallyUIKit.Palette.cloud.opacity(0.76))
                    }
                    Spacer(minLength: 0)
                    RallyUIKit.IconBadge(systemName: "sportscourt.fill", tint: RallyUIKit.Palette.cyan, size: 38)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Venue")
                        .font(RallyUIKit.Typography.label(.caption, weight: .bold))
                        .foregroundStyle(RallyUIKit.Palette.cloud.opacity(0.88))
                    HStack(spacing: 8) {
                        ForEach(CourtVenue.allCases) { venue in
                            pregameChip(
                                title: venue.displayName,
                                isSelected: CourtVenue.current == venue,
                                tint: venue == .wimbledonGrass ? RallyUIKit.Palette.lime : RallyUIKit.Palette.cyan
                            ) {
                                CourtVenue.current = venue
                            }
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Handedness")
                        .font(RallyUIKit.Typography.label(.caption, weight: .bold))
                        .foregroundStyle(RallyUIKit.Palette.cloud.opacity(0.88))
                    HStack(spacing: 8) {
                        ForEach(GamePreferences.DominantHand.allCases) { hand in
                            pregameChip(
                                title: hand == .right ? "Righty" : "Lefty",
                                isSelected: gamePreferences.dominantHand == hand,
                                tint: hand == .right ? RallyUIKit.Palette.gold : RallyUIKit.Palette.rose
                            ) {
                                gamePreferences.dominantHand = hand
                            }
                        }
                    }
                }

                Button(action: startPractice) {
                    HStack(spacing: 12) {
                        RallyUIKit.IconBadge(systemName: "play.fill", tint: RallyUIKit.Palette.obsidian, size: 42)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Play")
                                .font(RallyUIKit.Typography.title(.title3, weight: .bold))
                            Text("Minimal HUD · one ball · rally counter")
                                .font(RallyUIKit.Typography.body(.caption, weight: .medium))
                                .opacity(0.82)
                        }
                        Spacer(minLength: 0)
                        Image(systemName: "arrow.right.circle.fill")
                            .font(.title2)
                    }
                    .foregroundStyle(RallyUIKit.Palette.obsidian)
                    .frame(maxWidth: .infinity, minHeight: 70, alignment: .leading)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 14)
                    .background(
                        RoundedRectangle(cornerRadius: RallyUIKit.Radius.xl, style: .continuous)
                            .fill(RallyUIKit.accentGradient(RallyUIKit.Palette.cyan))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: RallyUIKit.Radius.xl, style: .continuous)
                            .stroke(Color.white.opacity(0.35), lineWidth: 1)
                    )
                    .shadow(color: RallyUIKit.Palette.cyan.opacity(0.32), radius: 18, y: 8)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func pregameChip(title: String, isSelected: Bool, tint: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(RallyUIKit.Typography.label(.caption, weight: .bold))
                .foregroundStyle(isSelected ? RallyUIKit.Palette.obsidian : RallyUIKit.Palette.frost)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .frame(maxWidth: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: RallyUIKit.Radius.sm)
                        .fill(isSelected ? tint : Color.white.opacity(0.05))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: RallyUIKit.Radius.sm)
                        .stroke(tint.opacity(isSelected ? 0.0 : 0.3), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }

    private func startPractice() {
        gamePreferences.matchPace = .calm
        isPlaying = true
    }

}
