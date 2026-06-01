import SwiftUI
import SwiftData

struct HomeView: View {
    @EnvironmentObject private var auth: AuthSession
    @Query private var avatarConfigs: [AvatarConfig]
    @Query private var progressRecords: [PlayerProgress]
    @Query(sort: \TrainingSession.date, order: .reverse) private var trainings: [TrainingSession]
    @Query(sort: \MatchEntry.date, order: .reverse) private var matches: [MatchEntry]
    @Query(sort: \JournalEntry.date, order: .reverse) private var journal: [JournalEntry]

    @Binding var selectedTab: RallyTab
    @Binding var logbookSection: LogbookSection
    @Binding var isPlaying: Bool

    @StateObject private var gamePreferences = GamePreferences.shared
    @State private var showingTrainingEditor = false
    @State private var showingMatchEditor = false
    @State private var showingJournalEditor = false

    private var avatar: AvatarConfig? { avatarConfigs.first }
    private var progress: PlayerProgress? { progressRecords.first }
    private var featuredHomeShopItem: ShopItem? {
        ShopCatalog.item(id: "newbalance.tournament.tank.white")
    }
    private var featuredHomeDestination: IconicTennisCourt? {
        IconicCourtsCatalog.allCourts.first { $0.id == "wimbledon.cc" }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: RallyUIKit.Spacing.lg) {
                    if auth.isGuestMode {
                        guestOfflineBanner
                    }
                    avatarCard
                    playerBadge
                    homeLoadoutSection
                    pregameSection
                    quickActions
                    recentLogbook
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
            .sheet(isPresented: $showingTrainingEditor) {
                NavigationStack { TrainingEditorView(session: nil) }
            }
            .sheet(isPresented: $showingMatchEditor) {
                NavigationStack { MatchEditorView(match: nil) }
            }
            .sheet(isPresented: $showingJournalEditor) {
                NavigationStack { JournalEditorView(entry: nil) }
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

    @ViewBuilder
    private var featuredNowSection: some View {
        if featuredHomeShopItem != nil || featuredHomeDestination != nil {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Now in Rally")
                        .font(RallyUIKit.Typography.label(.headline, weight: .semibold))
                        .foregroundStyle(RallyUIKit.Palette.frost)
                    Spacer()
                }

                HStack(spacing: 12) {
                    if let item = featuredHomeShopItem {
                        Button {
                            selectedTab = .shop
                        } label: {
                            homeFeatureCard(
                                eyebrow: "Style edit",
                                title: item.name,
                                subtitle: "New Balance whites and official buy paths in the shop.",
                                tint: item.accentColor ?? RallyUIKit.Palette.champagne,
                                icon: item.category.iconSystemName
                            )
                        }
                        .buttonStyle(.plain)
                    }

                    if let court = featuredHomeDestination {
                        NavigationLink {
                            CourtsMapView()
                        } label: {
                            homeFeatureCard(
                                eyebrow: court.kind == .venue ? "Travel next" : "Camp next",
                                title: court.name,
                                subtitle: "Open the world atlas for official venue, camp, and booking links.",
                                tint: court.kind == .venue ? RallyUIKit.Palette.cyan : RallyUIKit.Palette.gold,
                                icon: court.kind == .venue ? "globe.europe.africa.fill" : "figure.tennis"
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
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
                ZStack(alignment: .bottomLeading) {
                    RallyUIKit.SectionCard(stroke: RallyUIKit.Palette.cyan.opacity(0.28)) {
                        AvatarView(config: avatar, subtlePerspective: true)
                            .frame(height: 320)
                    }
                    VStack(alignment: .leading, spacing: RallyUIKit.Spacing.xxs) {
                        Text(displayName(for: avatar))
                            .font(RallyUIKit.Typography.title(.title, weight: .bold))
                            .tracking(0.4)
                            .foregroundStyle(RallyUIKit.Palette.frost)
                        Text(equippedSummary(avatar))
                            .font(RallyUIKit.Typography.body(.caption, weight: .medium))
                            .foregroundStyle(RallyUIKit.Palette.cloud.opacity(0.68))
                    }
                    .padding(RallyUIKit.Spacing.lg)
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

    // MARK: - Player badge (level / coins / best)

    @ViewBuilder
    private var playerBadge: some View {
        if let p = progress {
            RallyUIKit.SectionCard(stroke: RallyUIKit.Palette.cyan.opacity(0.26)) {
                VStack(spacing: RallyUIKit.Spacing.sm) {
                    HStack(spacing: RallyUIKit.Spacing.md) {
                        levelBadge(p)
                        VStack(alignment: .leading, spacing: RallyUIKit.Spacing.xxs) {
                            Text("Level \(p.level)")
                                .font(RallyUIKit.Typography.title(.title3, weight: .bold))
                                .foregroundStyle(RallyUIKit.Palette.frost)
                            Text("\(p.xpToNextLevel) XP to lv. \(p.level + 1)")
                                .font(RallyUIKit.Typography.body(.caption, weight: .medium))
                                .foregroundStyle(RallyUIKit.Palette.cloud.opacity(0.68))
                            levelBar(progress: p.levelProgress)
                                .frame(height: 5)
                        }
                        Spacer()
                    }
                    HStack(spacing: RallyUIKit.Spacing.xs + 2) {
                        badgeChip(icon: "circle.hexagongrid.fill", value: "\(p.coins)", label: "coins", tint: RallyUIKit.Palette.gold)
                        badgeChip(icon: "star.fill", value: "\(p.bestScore)", label: "best", tint: RallyUIKit.Palette.cyan)
                        badgeChip(icon: "flame.fill", value: "\(p.dailyStreak)d", label: "streak", tint: RallyUIKit.Palette.rose)
                    }
                }
            }
        }
    }

    private func levelBadge(_ p: PlayerProgress) -> some View {
        ZStack {
            Circle()
                .fill(LinearGradient(
                    colors: [RallyUIKit.Palette.champagne, RallyUIKit.Palette.gold, RallyUIKit.Palette.cyan],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                ))
                .frame(width: 56, height: 56)
            Text("\(p.level)")
                .font(RallyUIKit.Typography.title(.title2, weight: .bold))
                .foregroundStyle(RallyUIKit.Palette.obsidian)
        }
        .shadow(color: RallyUIKit.Shadow.glow(RallyUIKit.Palette.gold), radius: 14, x: 0, y: 10)
    }

    private func levelBar(progress: Double) -> some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.white.opacity(0.08))
                Capsule()
                    .fill(LinearGradient(
                        colors: [RallyUIKit.Palette.cyan, RallyUIKit.Palette.rose],
                        startPoint: .leading, endPoint: .trailing
                    ))
                    .frame(width: geo.size.width * CGFloat(max(0.02, progress)))
            }
        }
    }

    private func badgeChip(icon: String, value: String, label: String, tint: Color) -> some View {
        HStack(spacing: RallyUIKit.Spacing.xs) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(tint)
            VStack(alignment: .leading, spacing: 0) {
                Text(value)
                    .font(RallyUIKit.Typography.label(.subheadline, weight: .bold))
                    .foregroundStyle(RallyUIKit.Palette.frost)
                Text(label)
                    .font(RallyUIKit.Typography.body(.caption2, weight: .medium))
                    .foregroundStyle(RallyUIKit.Palette.cloud.opacity(0.62))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 10)
        .padding(.vertical, RallyUIKit.Spacing.xs)
        .background(
            RoundedRectangle(cornerRadius: RallyUIKit.Radius.sm)
                .fill(Color.white.opacity(0.03))
        )
    }

    // MARK: - Quick actions

    private var quickActions: some View {
        VStack(spacing: RallyUIKit.Spacing.xs + 2) {
            HStack {
                Text("Play and log")
                    .font(RallyUIKit.Typography.label(.headline, weight: .semibold))
                    .foregroundStyle(RallyUIKit.Palette.frost)
                Spacer()
            }
            actionButton(icon: "tennis.racket", label: "Practice", tint: RallyUIKit.Palette.cyan, big: true) {
                startPractice()
            }
            HStack(spacing: RallyUIKit.Spacing.xs + 2) {
                actionButton(icon: "figure.tennis", label: "Training log", tint: RallyUIKit.Palette.lime) {
                    logbookSection = .training
                    selectedTab = .journal
                }
                actionButton(icon: "trophy", label: "Match log", tint: RallyUIKit.Palette.gold) {
                    logbookSection = .matches
                    selectedTab = .journal
                }
                actionButton(icon: "book.closed", label: "Journal", tint: RallyUIKit.Palette.rose) {
                    logbookSection = .journal
                    selectedTab = .journal
                }
            }
        }
    }

    private var pregameSection: some View {
        RallyUIKit.LuxePanel(tint: RallyUIKit.Palette.cyan) {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top, spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        RallyUIKit.EditorialEyebrow(text: "Court setup", tint: RallyUIKit.Palette.cyan)
                        Text("Pick the court before you play")
                            .font(RallyUIKit.Typography.title(.headline, weight: .bold))
                            .foregroundStyle(RallyUIKit.Palette.frost)
                        Text("Keep the live game clean. Choose the venue and handedness here, then step straight into wall rally.")
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

    // MARK: - Court atlas (world map)

    private var courtAtlasSection: some View {
        NavigationLink {
            CourtsMapView()
        } label: {
            RallyUIKit.LuxePanel(tint: RallyUIKit.Palette.lime) {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(alignment: .top, spacing: 12) {
                        VStack(alignment: .leading, spacing: 4) {
                            RallyUIKit.EditorialEyebrow(text: "World tennis atlas", tint: RallyUIKit.Palette.lime)
                            Text(featuredHomeDestination?.name ?? "Iconic venues and global camps")
                                .font(RallyUIKit.Typography.title(.headline, weight: .bold))
                                .foregroundStyle(RallyUIKit.Palette.frost)
                            Text("Browse the tennis world through official venue, academy, booking, and enrollment links.")
                                .font(RallyUIKit.Typography.body(.caption, weight: .medium))
                                .foregroundStyle(RallyUIKit.Palette.cloud.opacity(0.76))
                        }

                        Spacer(minLength: 8)

                        RallyUIKit.IconBadge(
                            systemName: "globe.europe.africa.fill",
                            tint: RallyUIKit.Palette.lime,
                            size: 38
                        )
                    }

                    HStack(spacing: 8) {
                        atlasHomeChip("Venues", tint: RallyUIKit.Palette.cyan)
                        atlasHomeChip("Camps", tint: RallyUIKit.Palette.gold)
                        atlasHomeChip("Official links", tint: RallyUIKit.Palette.rose)
                    }

                    if let featuredHomeDestination {
                        HStack(spacing: 8) {
                            atlasHomeChip(featuredHomeDestination.region, tint: RallyUIKit.Palette.cloud)
                            atlasHomeChip(featuredHomeDestination.kind.rawValue, tint: featuredHomeDestination.kind == .venue ? RallyUIKit.Palette.cyan : RallyUIKit.Palette.gold)
                        }
                    }

                    HStack(spacing: 8) {
                        Text("Open atlas")
                            .font(RallyUIKit.Typography.label(.subheadline, weight: .bold))
                        Spacer()
                        Image(systemName: "arrow.right.circle.fill")
                            .font(.system(size: 16, weight: .bold))
                    }
                    .foregroundStyle(RallyUIKit.Palette.lime)
                }
            }
        }
        .buttonStyle(.plain)
    }

    private func actionButton(
        icon: String,
        label: String,
        tint: Color,
        big: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            actionButtonLabel(icon: icon, label: label, tint: tint, big: big)
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func actionButtonLabel(
        icon: String,
        label: String,
        tint: Color,
        big: Bool = false
    ) -> some View {
        Group {
            if big {
                HStack(spacing: 10) {
                    Image(systemName: icon)
                        .font(.title2)
                    Text(label)
                        .font(RallyUIKit.Typography.label(.headline, weight: .bold))
                        .tracking(0.3)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, RallyUIKit.Spacing.lg)
            } else {
                VStack(spacing: 6) {
                    Image(systemName: icon)
                        .font(.title3)
                    Text(label)
                        .font(RallyUIKit.Typography.label(.caption, weight: .semibold))
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
            }
        }
        .background(
            RoundedRectangle(cornerRadius: RallyUIKit.Radius.md)
                .fill(
                    LinearGradient(
                        colors: [Color.white.opacity(0.08), tint.opacity(0.18)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: RallyUIKit.Radius.md)
                .stroke(tint.opacity(0.78), lineWidth: 1)
        )
        .foregroundStyle(tint)
    }

    private func homeFeatureCard(
        eyebrow: String,
        title: String,
        subtitle: String,
        tint: Color,
        icon: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 8) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(eyebrow.uppercased())
                        .font(RallyUIKit.Typography.label(.caption2, weight: .bold))
                        .tracking(1.2)
                        .foregroundStyle(tint.opacity(0.95))
                    Text(title)
                        .font(RallyUIKit.Typography.body(.subheadline, weight: .bold))
                        .foregroundStyle(RallyUIKit.Palette.frost)
                        .lineLimit(2)
                }
                Spacer(minLength: 0)
                RallyUIKit.IconBadge(systemName: icon, tint: tint, size: 30)
            }

            Text(subtitle)
                .font(RallyUIKit.Typography.body(.caption, weight: .medium))
                .foregroundStyle(RallyUIKit.Palette.cloud.opacity(0.8))
                .lineLimit(3)

            HStack(spacing: 6) {
                Text("Open")
                    .font(RallyUIKit.Typography.label(.caption, weight: .bold))
                Spacer(minLength: 0)
                Image(systemName: "arrow.right.circle.fill")
                    .font(.system(size: 14, weight: .bold))
            }
            .foregroundStyle(tint)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: RallyUIKit.Radius.md)
                .fill(
                    LinearGradient(
                        colors: [Color.white.opacity(0.06), tint.opacity(0.12)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: RallyUIKit.Radius.md)
                .stroke(tint.opacity(0.2), lineWidth: 1)
        )
    }

    // MARK: - Journal preview

    @ViewBuilder
    private var recentLogbook: some View {
        if !homeLogbookMoments.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                sectionHeaderAction(title: "From your journal", actionTitle: "See all") {
                    selectedTab = .journal
                }
                VStack(spacing: 10) {
                    ForEach(homeLogbookMoments) { moment in
                        Button {
                            logbookSection = moment.section
                            selectedTab = .journal
                        } label: {
                            homeLogbookMomentRow(moment)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private var homeLogbookMoments: [HomeLogbookMoment] {
        let trainingMoments = trainings.prefix(1).map(HomeLogbookMoment.init(training:))
        let matchMoments = matches.prefix(1).map(HomeLogbookMoment.init(match:))
        let journalMoments = journal.prefix(1).map(HomeLogbookMoment.init(journal:))

        return (trainingMoments + matchMoments + journalMoments)
            .sorted { $0.date > $1.date }
    }

    private func homeLogbookMomentRow(_ moment: HomeLogbookMoment) -> some View {
        HStack(alignment: .top, spacing: 12) {
            RallyUIKit.IconBadge(
                systemName: moment.iconName,
                tint: moment.tint,
                size: 30
            )

            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .top, spacing: 8) {
                    Text(moment.badge)
                        .font(RallyUIKit.Typography.body(.caption2, weight: .semibold))
                        .padding(.horizontal, 9)
                        .padding(.vertical, 5)
                        .background(
                            Capsule().fill(moment.tint.opacity(0.12))
                        )
                        .overlay(
                            Capsule().stroke(moment.tint.opacity(0.2), lineWidth: 1)
                        )
                        .foregroundStyle(moment.tint.opacity(0.92))

                    Spacer(minLength: 0)

                    Text(moment.date, format: .dateTime.month().day().year())
                        .font(RallyUIKit.Typography.body(.caption2, weight: .semibold))
                        .foregroundStyle(RallyUIKit.Palette.cloud.opacity(0.46))
                }

                Text(moment.title)
                    .font(RallyUIKit.Typography.body(.body, weight: .semibold))
                    .foregroundStyle(RallyUIKit.Palette.frost)
                    .lineLimit(1)

                Text(moment.subtitle)
                    .font(RallyUIKit.Typography.body(.subheadline, weight: .medium))
                    .foregroundStyle(RallyUIKit.Palette.cloud.opacity(0.82))
                    .lineLimit(2)

                if let image = moment.image {
                    ZStack(alignment: .bottomLeading) {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                            .frame(height: 110)
                            .frame(maxWidth: .infinity)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                            .overlay(
                                LinearGradient(
                                    colors: [Color.clear, Color.black.opacity(0.38)],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                                .clipShape(RoundedRectangle(cornerRadius: 14))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 14)
                                    .stroke(Color.white.opacity(0.08), lineWidth: 1)
                            )

                        HStack(spacing: 6) {
                            Image(systemName: "photo.fill")
                                .font(.caption2.weight(.bold))
                            Text("Saved memory")
                                .font(RallyUIKit.Typography.label(.caption2, weight: .bold))
                        }
                        .foregroundStyle(.white.opacity(0.92))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 7)
                        .background(
                            Capsule().fill(Color.black.opacity(0.34))
                        )
                        .padding(10)
                    }
                }
            }

            Image(systemName: "chevron.right")
                .font(RallyUIKit.Typography.label(.caption, weight: .bold))
                .foregroundStyle(RallyUIKit.Palette.cloud.opacity(0.4))
                .padding(.top, 6)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: RallyUIKit.Radius.md)
                .fill(Color.white.opacity(0.04))
        )
        .overlay(
            RoundedRectangle(cornerRadius: RallyUIKit.Radius.md)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
    }

    private func journalFocusTint(_ focus: JournalFocus) -> Color {
        switch focus {
        case .general: return RallyUIKit.Palette.lime
        case .practice: return RallyUIKit.Palette.cyan
        case .match: return RallyUIKit.Palette.gold
        case .rallyGame: return RallyUIKit.Palette.rose
        }
    }

    private func homeJournalPreviewImage(_ entry: JournalEntry) -> UIImage? {
        guard let data = entry.photoData else { return nil }
        return UIImage(data: data)
    }

    private func atlasHomeChip(_ label: String, tint: Color) -> some View {
        Text(label)
            .font(RallyUIKit.Typography.body(.caption2, weight: .semibold))
            .foregroundStyle(tint == RallyUIKit.Palette.cloud ? RallyUIKit.Palette.cloud.opacity(0.86) : tint)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                Capsule().fill((tint == RallyUIKit.Palette.cloud ? RallyUIKit.Palette.cloud : tint).opacity(0.12))
            )
            .overlay(
                Capsule().stroke((tint == RallyUIKit.Palette.cloud ? RallyUIKit.Palette.cloud : tint).opacity(0.18), lineWidth: 1)
            )
    }

    private func sectionHeaderAction(title: String, actionTitle: String, action: @escaping () -> Void) -> some View {
        HStack {
            Text(title)
                .font(RallyUIKit.Typography.label(.headline, weight: .semibold))
                .foregroundStyle(RallyUIKit.Palette.frost)
            Spacer()
            Button(action: action) {
                Text(actionTitle)
                    .font(RallyUIKit.Typography.label(.caption, weight: .semibold))
                    .foregroundStyle(RallyUIKit.Palette.cyan)
            }
            .buttonStyle(.plain)
        }
    }
}

private struct HomeLogbookMoment: Identifiable {
    let id: String
    let section: LogbookSection
    let badge: String
    let title: String
    let subtitle: String
    let date: Date
    let tint: Color
    let iconName: String
    let image: UIImage?

    init(training: TrainingSession) {
        id = "training-\(training.id.uuidString)"
        section = .training
        badge = "Practice"
        title = training.drillType.isEmpty ? "Training session" : training.drillType
        subtitle = "\(training.durationMinutes) minutes · Intensity \(training.intensity)"
        date = training.date
        tint = RallyUIKit.Palette.cyan
        iconName = "figure.tennis"
        image = nil
    }

    init(match: MatchEntry) {
        id = "match-\(match.id.uuidString)"
        section = .matches
        badge = match.resultWon ? "Match win" : "Match day"
        title = match.opponentName.isEmpty ? "Competitive session" : "vs \(match.opponentName)"
        subtitle = match.scoreDisplay.isEmpty ? match.surface.displayName : "\(match.scoreDisplay) · \(match.surface.displayName)"
        date = match.date
        tint = RallyUIKit.Palette.gold
        iconName = match.resultWon ? "sparkles" : "trophy.fill"
        image = match.photoData.flatMap(UIImage.init(data:))
    }

    init(journal: JournalEntry) {
        id = "journal-\(journal.id.uuidString)"
        section = .journal
        badge = journal.focus.displayName
        title = journal.title.isEmpty ? "Journal entry" : journal.title
        subtitle = journal.body.isEmpty ? "A saved note from your tennis life." : journal.body
        date = journal.date
        tint = {
            switch journal.focus {
            case .general: return RallyUIKit.Palette.lime
            case .practice: return RallyUIKit.Palette.cyan
            case .match: return RallyUIKit.Palette.gold
            case .rallyGame: return RallyUIKit.Palette.rose
            }
        }()
        iconName = journal.focus.symbolName
        image = journal.photoData.flatMap(UIImage.init(data:))
    }
}

private struct HomeSectionCardModifier: ViewModifier {
    let stroke: Color

    func body(content: Content) -> some View {
        content
            .padding(RallyUIKit.Spacing.md)
            .background(
                RoundedRectangle(cornerRadius: RallyUIKit.Radius.md)
                    .fill(Color.white.opacity(0.04))
            )
            .overlay(
                RoundedRectangle(cornerRadius: RallyUIKit.Radius.md)
                    .stroke(stroke, lineWidth: 1)
            )
    }
}
