import SwiftUI
import SwiftData

struct HomeView: View {
    @EnvironmentObject private var auth: AuthSession
    @EnvironmentObject private var avatarAppearanceStore: RallyAvatarAppearanceStore
    @Environment(\.modelContext) private var modelContext
    @Query private var avatarConfigs: [AvatarConfig]

    @Binding var selectedTab: RallyTab
    @Binding var isPlaying: Bool

    @StateObject private var gamePreferences = GamePreferences.shared
    @State private var selectedCourt: CourtVenue = CourtVenue.current
    @State private var selectedLoadoutCategory: ShopItem.Category = .racket

    private var avatar: AvatarConfig? { avatarConfigs.first }
    private let editableLoadoutCategories: [ShopItem.Category] = [.racket, .top, .bottom, .shoes]
    private let featuredCourtVenues: [CourtVenue] = [.wimbledonGrass, .miamiHard, .barcelonaClay]
    private var selectedLoadoutItem: ShopItem? {
        equippedItem(for: selectedLoadoutCategory)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                courtBackdrop(for: selectedCourt)
                    .ignoresSafeArea()

                loadoutScreen
            }
            .safeAreaInset(edge: .bottom) {
                playDock
            }
            .navigationTitle(displayName(for: avatar))
            .navigationBarTitleDisplayMode(.inline)
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
                        Image(systemName: auth.isGuestMode ? "icloud.slash" : "person.text.rectangle")
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
                        .accessibilityLabel("Edit look")
                    }
                }
            }
            .onAppear {
                selectedCourt = featuredCourtVenues.contains(CourtVenue.current) ? CourtVenue.current : .wimbledonGrass
                CourtVenue.current = selectedCourt
                avatarAppearanceStore.sync(from: avatar)
            }
        }
    }

    private var loadoutScreen: some View {
        GeometryReader { proxy in
            let stageHeight = min(402, max(354, proxy.size.height * 0.50))

            VStack(spacing: 9) {
                loadoutTopChrome

                livingPregameStage
                    .frame(height: stageHeight)

                wardrobeRail

                courtRail

                Spacer(minLength: 78)
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .frame(width: proxy.size.width, height: proxy.size.height, alignment: .top)
        }
    }

    private var loadoutTopChrome: some View {
        ZStack {
            VStack(alignment: .center, spacing: 3) {
                Text("LOADOUT")
                    .font(.system(size: 11, weight: .black, design: .rounded))
                    .tracking(2.2)
                    .foregroundStyle(RallyUIKit.Palette.cyan.opacity(0.82))
            }
            .frame(maxWidth: .infinity)

            HStack {
                Spacer()

                Button {
                    selectedTab = .shop
                } label: {
                    Image(systemName: "tshirt.fill")
                        .font(.system(size: 15, weight: .black))
                        .foregroundStyle(RallyUIKit.Palette.obsidian)
                        .frame(width: 36, height: 36)
                        .background(Circle().fill(RallyUIKit.Palette.champagne))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 2)
    }

    private func stageArrow(systemName: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 16, weight: .black))
                .foregroundStyle(.white)
                .frame(width: 46, height: 46)
                .background(
                    Circle()
                        .fill(Color.black.opacity(0.42))
                )
                .overlay(
                    Circle()
                        .stroke(Color.white.opacity(0.18), lineWidth: 1)
                )
                .shadow(color: Color.black.opacity(0.24), radius: 12, y: 6)
        }
        .buttonStyle(LoadoutPlayButtonStyle())
    }

    private func handButton(_ hand: GamePreferences.DominantHand) -> some View {
        Button {
            gamePreferences.dominantHand = hand
        } label: {
            HStack(spacing: 7) {
                Image(systemName: hand == .right ? "hand.raised.fill" : "hand.raised")
                    .font(.system(size: 12, weight: .bold))
                Text(hand.title)
                    .font(RallyUIKit.Typography.label(.caption, weight: .bold))
            }
            .foregroundStyle(gamePreferences.dominantHand == hand ? RallyUIKit.Palette.obsidian : .white.opacity(0.80))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(
                Capsule(style: .continuous)
                    .fill(
                        gamePreferences.dominantHand == hand
                            ? AnyShapeStyle(RallyUIKit.accentGradient(RallyUIKit.Palette.gold))
                            : AnyShapeStyle(Color.white.opacity(0.08))
                    )
            )
            .overlay(
                Capsule(style: .continuous)
                    .stroke(Color.white.opacity(gamePreferences.dominantHand == hand ? 0.24 : 0.08), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private func cycleCourt(_ direction: Int) {
        let courts = featuredCourtVenues
        guard let currentIndex = courts.firstIndex(of: selectedCourt) else {
            setCourt(courts.first ?? .wimbledonGrass)
            return
        }
        let nextIndex = (currentIndex + direction + courts.count) % courts.count
        setCourt(courts[nextIndex])
    }

    private func setCourt(_ venue: CourtVenue) {
        selectedCourt = venue
        CourtVenue.current = venue
    }

    private func cycleLoadout(_ direction: Int) {
        guard let avatar else {
            selectedTab = .shop
            return
        }
        let items = ShopCatalog.allItems.filter { $0.category == selectedLoadoutCategory }
        guard !items.isEmpty else { return }
        let currentID = equippedID(for: selectedLoadoutCategory, avatar: avatar)
        let currentIndex = items.firstIndex { $0.id == currentID } ?? 0
        let nextIndex = (currentIndex + direction + items.count) % items.count
        withAnimation(.spring(response: 0.22, dampingFraction: 0.78)) {
            setEquippedID(items[nextIndex].id, for: selectedLoadoutCategory, avatar: avatar)
            avatarAppearanceStore.sync(from: avatar)
        }
        try? modelContext.save()
    }

    private func equippedItem(for category: ShopItem.Category) -> ShopItem? {
        guard let avatar else { return nil }
        return ShopCatalog.item(id: equippedID(for: category, avatar: avatar))
    }

    private func equippedID(for category: ShopItem.Category, avatar: AvatarConfig) -> String {
        switch category {
        case .racket: return avatar.equippedRacketID
        case .top: return avatar.equippedTopID
        case .bottom: return avatar.equippedBottomID
        case .shoes: return avatar.equippedShoesID
        case .bag, .accessory: return ""
        }
    }

    private func setEquippedID(_ id: String, for category: ShopItem.Category, avatar: AvatarConfig) {
        switch category {
        case .racket: avatar.equippedRacketID = id
        case .top: avatar.equippedTopID = id
        case .bottom: avatar.equippedBottomID = id
        case .shoes: avatar.equippedShoesID = id
        case .bag, .accessory: break
        }
    }

    private func icon(for category: ShopItem.Category) -> String {
        switch category {
        case .racket: return "tennis.racket"
        case .top: return "tshirt.fill"
        case .bottom: return "rectangle.fill"
        case .shoes: return "shoe.fill"
        case .bag: return "duffle.bag.fill"
        case .accessory: return "sparkles"
        }
    }

    private func shortLabel(for category: ShopItem.Category) -> String {
        switch category {
        case .racket: return "Racket"
        case .top: return "Top"
        case .bottom: return "Shorts"
        case .shoes: return "Shoes"
        case .bag: return "Bag"
        case .accessory: return "Gear"
        }
    }

    private func loadoutFill(for category: ShopItem.Category) -> LinearGradient {
        let item = avatar.flatMap { ShopCatalog.item(id: equippedID(for: category, avatar: $0)) }
        let fill = item?.color ?? RallyUIKit.Palette.ink
        let accent = item?.accentColor ?? RallyUIKit.Palette.cyan
        return LinearGradient(
            colors: [fill.opacity(0.96), accent.opacity(0.52), RallyUIKit.Palette.obsidian],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private func categoryAccent(for category: ShopItem.Category) -> Color {
        switch category {
        case .racket: return RallyUIKit.Palette.gold
        case .top: return RallyUIKit.Palette.cyan
        case .bottom: return RallyUIKit.Palette.rose
        case .shoes: return RallyUIKit.Palette.lime
        case .bag: return RallyUIKit.Palette.champagne
        case .accessory: return RallyUIKit.Palette.cloud
        }
    }

    private func courtBackdrop(for venue: CourtVenue) -> some View {
        ZStack {
            stageGradient(for: venue)
            RadialGradient(
                colors: [courtAccent(for: venue).opacity(0.28), .clear],
                center: .top,
                startRadius: 20,
                endRadius: 460
            )
            LinearGradient(
                colors: [.clear, Color.black.opacity(0.62)],
                startPoint: .top,
                endPoint: .bottom
            )
        }
    }

    private func stageGradient(for venue: CourtVenue) -> LinearGradient {
        switch venue {
        case .miamiHard:
            return LinearGradient(colors: [Color(red: 0.08, green: 0.35, blue: 0.58), Color(red: 0.03, green: 0.13, blue: 0.25), Color(red: 0.01, green: 0.02, blue: 0.05)], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .wimbledonGrass:
            return LinearGradient(colors: [Color(red: 0.08, green: 0.34, blue: 0.12), Color(red: 0.03, green: 0.12, blue: 0.05), Color(red: 0.01, green: 0.025, blue: 0.015)], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .redClay:
            return LinearGradient(colors: [Color(red: 0.38, green: 0.16, blue: 0.08), Color(red: 0.10, green: 0.04, blue: 0.035), Color.black], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .barcelonaClay:
            return LinearGradient(colors: [Color(red: 0.58, green: 0.20, blue: 0.08), Color(red: 0.18, green: 0.06, blue: 0.035), Color(red: 0.035, green: 0.015, blue: 0.010)], startPoint: .topLeading, endPoint: .bottomTrailing)
        }
    }

    private func courtSwatch(for venue: CourtVenue) -> LinearGradient {
        LinearGradient(
            colors: [courtAccent(for: venue).opacity(0.95), Color.black.opacity(0.38)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private func courtAccent(for venue: CourtVenue) -> Color {
        switch venue {
        case .miamiHard: return RallyUIKit.Palette.cyan
        case .wimbledonGrass: return RallyUIKit.Palette.lime
        case .redClay: return RallyUIKit.Palette.rose
        case .barcelonaClay: return RallyUIKit.Palette.rose
        }
    }

    private func courtLinesOverlay(for venue: CourtVenue) -> some View {
        GeometryReader { proxy in
            let w = proxy.size.width
            let h = proxy.size.height
            ZStack {
                PerspectiveCourtPlate()
                    .fill(courtAccent(for: venue).opacity(0.12))
                    .frame(width: w * 0.86, height: h * 0.58)
                    .offset(y: h * 0.18)

                VStack(spacing: 22) {
                    Capsule().fill(Color.white.opacity(0.12)).frame(width: w * 0.58, height: 2)
                    Capsule().fill(Color.white.opacity(0.08)).frame(width: w * 0.72, height: 2)
                    Capsule().fill(Color.white.opacity(0.06)).frame(width: w * 0.86, height: 2)
                }
                .offset(y: h * 0.22)

            }
            .allowsHitTesting(false)
        }
    }

    private var livingPregameStage: some View {
        ZStack(alignment: .top) {
            RoundedRectangle(cornerRadius: 32, style: .continuous)
                .fill(stageGradient(for: selectedCourt))
                .overlay(movingStageLight.clipShape(RoundedRectangle(cornerRadius: 32, style: .continuous)))
                .overlay(courtLinesOverlay(for: selectedCourt).clipShape(RoundedRectangle(cornerRadius: 32, style: .continuous)))
                .overlay(
                    RoundedRectangle(cornerRadius: 32, style: .continuous)
                        .stroke(Color.white.opacity(0.12), lineWidth: 1)
                )

            VStack(spacing: 0) {
                stageStatusStrip
                    .padding(.horizontal, 16)
                    .padding(.top, 14)

                ZStack {
                    rhythmAvatar

                    HStack {
                        stageArrow(systemName: "chevron.left") {
                            cycleLoadout(-1)
                        }
                        Spacer()
                        stageArrow(systemName: "chevron.right") {
                            cycleLoadout(1)
                        }
                    }
                    .padding(.horizontal, 10)
                    .offset(y: 16)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 32, style: .continuous))
        .gesture(
            DragGesture(minimumDistance: 24)
                .onEnded { value in
                    if value.translation.width < -28 {
                        cycleCourt(1)
                    } else if value.translation.width > 28 {
                        cycleCourt(-1)
                    }
                }
        )
    }

    private var stageStatusStrip: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(selectedCourt.displayName)
                    .font(RallyUIKit.Typography.title(.headline, weight: .bold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.68)

                Text(selectedLoadoutCategory.displayName.uppercased())
                    .font(.system(size: 10, weight: .black, design: .rounded))
                    .tracking(1.4)
                    .foregroundStyle(courtAccent(for: selectedCourt).opacity(0.78))
            }

            Spacer(minLength: 8)

            HStack(spacing: 6) {
                Image(systemName: gamePreferences.dominantHand == .right ? "hand.raised.fill" : "hand.raised")
                Text(gamePreferences.dominantHand.title)
            }
            .font(RallyUIKit.Typography.label(.caption2, weight: .black))
            .foregroundStyle(RallyUIKit.Palette.obsidian)
            .padding(.horizontal, 11)
            .padding(.vertical, 7)
            .background(Capsule(style: .continuous).fill(RallyUIKit.Palette.champagne.opacity(0.92)))
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color.black.opacity(0.18))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
    }

    private var movingStageLight: some View {
        TimelineView(.animation) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            let sweep = CGFloat(sin(t * 0.62))
            ZStack {
                RadialGradient(
                    colors: [courtAccent(for: selectedCourt).opacity(0.15), .clear],
                    center: UnitPoint(x: 0.48 + sweep * 0.20, y: 0.30),
                    startRadius: 20,
                    endRadius: 240
                )

                Capsule()
                    .fill(Color.white.opacity(0.045))
                    .frame(width: 72, height: 480)
                    .blur(radius: 32)
                    .rotationEffect(.degrees(-12))
                    .offset(x: sweep * 120, y: -36)
            }
            .allowsHitTesting(false)
        }
    }

    private var rhythmAvatar: some View {
        TimelineView(.animation) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            let splitStep = CGFloat(sin(t * 2.05))
            let lookBeat = CGFloat(sin(t * 0.72))
            let swingBeat = CGFloat((sin(t * 3.2) + 1.0) * 0.5)
            let ballBounce = abs(CGFloat(sin(t * 4.4)))
            let handScale: CGFloat = gamePreferences.dominantHand == .left ? -1 : 1

            ZStack {
                Capsule(style: .continuous)
                    .fill(courtAccent(for: selectedCourt).opacity(0.36))
                    .frame(width: 176, height: 4)
                    .blur(radius: 0.5)
                    .offset(y: 132)

                Ellipse()
                    .fill(Color.black.opacity(0.54))
                    .frame(width: 188 + swingBeat * 5, height: 25)
                    .blur(radius: 9)
                    .offset(y: 134)

                HStack(spacing: 20) {
                    Capsule(style: .continuous)
                        .fill(RallyUIKit.Palette.cyan.opacity(0.42))
                        .frame(width: 38, height: 5)
                    Capsule(style: .continuous)
                        .fill(RallyUIKit.Palette.cyan.opacity(0.42))
                        .frame(width: 38, height: 5)
                }
                .offset(x: splitStep * 1.4, y: 121)

                if avatar != nil {
                    RallyAvatarView(
                        appearance: avatarAppearanceStore.appearance,
                        targetHeight: 318,
                        showsRacket: true,
                        breathingPhase: t * 2.05
                    )
                    .scaleEffect(x: handScale, y: 1.0)
                    .rotationEffect(.degrees(lookBeat * 1.2 + splitStep * 0.34))
                    .offset(x: splitStep * 1.2, y: 8)
                    .scaleEffect(1.025)
                    .frame(width: 278, height: 318)
                    .shadow(color: .black.opacity(0.24), radius: 16, y: 10)
                    .transition(.opacity.combined(with: .scale(scale: 0.98)))

                    tennisRhythmCue(
                        handScale: handScale,
                        swingBeat: swingBeat,
                        ballBounce: ballBounce
                    )
                } else {
                    Image(systemName: "figure.tennis")
                        .font(.system(size: 142, weight: .black))
                        .foregroundStyle(.white.opacity(0.74))
                        .rotationEffect(.degrees(lookBeat * 1.2 + splitStep * 0.34))
                        .offset(y: 8)
                        .frame(width: 302, height: 330)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        }
    }

    private func tennisRhythmCue(handScale: CGFloat, swingBeat: CGFloat, ballBounce: CGFloat) -> some View {
        let accent = courtAccent(for: selectedCourt)
        let racketSide = handScale * 96
        let ballY = CGFloat(-18) + ballBounce * 52

        return ZStack {
            ForEach(0..<3) { index in
                let lineIndex = CGFloat(index)
                Capsule(style: .continuous)
                    .fill(accent.opacity(0.36 - lineIndex * 0.08))
                    .frame(width: 58 - lineIndex * 9, height: 3)
                    .blur(radius: 0.4)
                    .rotationEffect(.degrees(handScale > 0 ? -24 : 24))
                    .offset(
                        x: handScale * (74 + swingBeat * 15 - lineIndex * 8),
                        y: -10 + swingBeat * 18 + lineIndex * 12
                    )
            }

            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color.white,
                            RallyUIKit.Palette.lime,
                            RallyUIKit.Palette.lime.opacity(0.55)
                        ],
                        center: .topLeading,
                        startRadius: 1,
                        endRadius: 11
                    )
                )
                .frame(width: 17, height: 17)
                .overlay(Circle().stroke(Color.white.opacity(0.72), lineWidth: 1))
                .shadow(color: RallyUIKit.Palette.lime.opacity(0.55), radius: 10)
                .offset(x: racketSide + swingBeat * handScale * 10, y: ballY)

            Circle()
                .fill(accent.opacity(0.16))
                .frame(width: 42 + swingBeat * 8, height: 42 + swingBeat * 8)
                .blur(radius: 12)
                .offset(x: racketSide + handScale * 4, y: 8)
        }
        .allowsHitTesting(false)
    }

    private var wardrobeRail: some View {
        HStack(spacing: 9) {
            ForEach(editableLoadoutCategories, id: \.self) { category in
                Button {
                    selectedLoadoutCategory = category
                } label: {
                    VStack(spacing: 8) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .fill(loadoutFill(for: category))
                                .frame(width: 70, height: 72)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                                        .stroke(
                                            selectedLoadoutCategory == category
                                                ? RallyUIKit.Palette.cyan.opacity(0.72)
                                                : Color.white.opacity(0.09),
                                            lineWidth: selectedLoadoutCategory == category ? 1.6 : 1
                                        )
                                )
                            Image(systemName: icon(for: category))
                                .font(.system(size: 25, weight: .bold))
                                .foregroundStyle(.white.opacity(0.92))
                        }
                        Text(shortLabel(for: category))
                            .font(RallyUIKit.Typography.label(.caption2, weight: .bold))
                            .foregroundStyle(selectedLoadoutCategory == category ? RallyUIKit.Palette.cyan : RallyUIKit.Palette.cloud.opacity(0.66))
                    }
                }
                .buttonStyle(.plain)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color.black.opacity(0.18))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Color.white.opacity(0.06), lineWidth: 1)
        )
    }

    private var courtRail: some View {
        HStack(spacing: 8) {
            ForEach(featuredCourtVenues) { venue in
                Button {
                    setCourt(venue)
                } label: {
                    HStack(spacing: 7) {
                        Circle()
                            .fill(courtAccent(for: venue))
                            .frame(width: 8, height: 8)
                        Text(venueShortName(venue))
                            .font(RallyUIKit.Typography.label(.caption2, weight: .bold))
                            .foregroundStyle(venue == selectedCourt ? RallyUIKit.Palette.obsidian : RallyUIKit.Palette.cloud.opacity(0.66))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(
                        Capsule(style: .continuous)
                            .fill(venue == selectedCourt ? AnyShapeStyle(RallyUIKit.accentGradient(courtAccent(for: venue))) : AnyShapeStyle(Color.white.opacity(0.07)))
                    )
                    .overlay(
                        Capsule(style: .continuous)
                            .stroke(venue == selectedCourt ? Color.white.opacity(0.24) : Color.white.opacity(0.08), lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var playDock: some View {
        TimelineView(.animation) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            let pulse = CGFloat((sin(t * 3.0) + 1) * 0.5)

            Button(action: startPractice) {
                HStack(spacing: 13) {
                    Image(systemName: "play.fill")
                        .font(.system(size: 21, weight: .black))
                    Text("PLAY")
                        .font(.system(size: 24, weight: .black, design: .rounded))
                        .tracking(2.6)
                    Spacer()
                    Text(venueShortName(selectedCourt).uppercased())
                        .font(.system(size: 10, weight: .black, design: .rounded))
                        .tracking(1.2)
                        .foregroundStyle(.white.opacity(0.68))
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 24)
                .frame(height: 64)
                .background(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    RallyUIKit.Palette.cyan,
                                    RallyUIKit.Palette.teal,
                                    RallyUIKit.Palette.ink
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(Color.white.opacity(0.16), lineWidth: 1)
                )
                .shadow(color: RallyUIKit.Palette.cyan.opacity(0.24 + pulse * 0.10), radius: 18 + pulse * 4, y: 8)
                .padding(.horizontal, RallyUIKit.Spacing.md)
                .padding(.bottom, 7)
                .background(
                    LinearGradient(
                        colors: [Color.black.opacity(0), Color.black.opacity(0.64)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .ignoresSafeArea()
                )
            }
            .buttonStyle(LoadoutPlayButtonStyle())
        }
    }

    private var avatarCard: some View {
        PremiumAvatarStageContainer(tone: .calm, accent: RallyUIKit.Palette.cyan, height: 214) {
            ZStack {
                LinearGradient(
                    colors: [
                        RallyUIKit.Palette.obsidian.opacity(0.98),
                        RallyUIKit.Palette.ink.opacity(0.96),
                        Color.black.opacity(0.94)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )

                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .stroke(Color.white.opacity(0.06), lineWidth: 1)

                Circle()
                    .fill(RallyUIKit.Palette.cyan.opacity(0.18))
                    .frame(width: 240, height: 240)
                    .blur(radius: 42)
                    .offset(x: -74, y: -44)

                Circle()
                    .fill(RallyUIKit.Palette.gold.opacity(0.10))
                    .frame(width: 200, height: 200)
                    .blur(radius: 36)
                    .offset(x: 110, y: -58)

                VStack(spacing: 16) {
                    HStack(alignment: .top, spacing: 18) {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Rally")
                                .font(.system(size: 31, weight: .black, design: .rounded))
                                .foregroundStyle(.white.opacity(0.98))

                            Text("clean contact. live return.")
                                .font(RallyUIKit.Typography.label(.caption, weight: .bold))
                                .foregroundStyle(RallyUIKit.Palette.cloud.opacity(0.72))
                                .textCase(.lowercase)

                            HStack(spacing: 8) {
                                heroPill("Wall Rally", tint: RallyUIKit.Palette.cyan)
                                heroPill("Fast Reset", tint: RallyUIKit.Palette.gold)
                            }
                        }

                        Spacer(minLength: 0)

                        ZStack {
                            Circle()
                                .fill(RallyUIKit.Palette.cyan.opacity(0.14))
                                .frame(width: 82, height: 82)
                            Circle()
                                .stroke(Color.white.opacity(0.18), lineWidth: 1)
                                .frame(width: 78, height: 78)
                            Image(systemName: "tennis.racket")
                                .font(.system(size: 32, weight: .bold))
                                .foregroundStyle(.white.opacity(0.96))
                                .rotationEffect(.degrees(-20))
                        }
                    }

                    Spacer(minLength: 0)

                    ZStack {
                        Capsule()
                            .fill(
                                LinearGradient(
                                    colors: [
                                        RallyUIKit.Palette.cyan.opacity(0.16),
                                        RallyUIKit.Palette.cyan.opacity(0.04)
                                    ],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                            .frame(height: 64)
                            .blur(radius: 10)
                            .offset(y: 10)

                        HStack(spacing: 24) {
                            heroCard(icon: "tennis.racket", tint: RallyUIKit.Palette.cyan)
                            heroCard(icon: "circle.fill", tint: RallyUIKit.Palette.lime)
                            heroCard(icon: "shoe.fill", tint: RallyUIKit.Palette.gold)
                        }
                    }
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 20)
            }
        }
    }

    private func heroPill(_ title: String, tint: Color) -> some View {
        Text(title)
            .font(RallyUIKit.Typography.label(.caption2, weight: .bold))
            .foregroundStyle(.white.opacity(0.94))
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                Capsule(style: .continuous)
                    .fill(tint.opacity(0.18))
            )
            .overlay(
                Capsule(style: .continuous)
                    .stroke(tint.opacity(0.32), lineWidth: 1)
            )
    }

    private func heroCard(icon: String, tint: Color) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.10),
                            Color.white.opacity(0.04)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 72, height: 72)
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
                .frame(width: 72, height: 72)

            Image(systemName: icon)
                .font(.system(size: 28, weight: .bold))
                .foregroundStyle(tint)
        }
    }

    private var homeLoadoutSection: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 14) {
                homeLoadoutPick(item: avatar.flatMap { ShopCatalog.item(id: $0.equippedRacketID) }, icon: "tennis.racket", tint: RallyUIKit.Palette.cyan)
                homeLoadoutPick(item: avatar.flatMap { ShopCatalog.item(id: $0.equippedTopID) }, icon: "tshirt.fill", tint: RallyUIKit.Palette.champagne)
                homeLoadoutPick(item: avatar.flatMap { ShopCatalog.item(id: $0.equippedBottomID) }, icon: "rectangle.fill", tint: RallyUIKit.Palette.gold)
                homeLoadoutPick(item: avatar.flatMap { ShopCatalog.item(id: $0.equippedShoesID) }, icon: "shoe.fill", tint: RallyUIKit.Palette.rose)
            }
        }
        .scrollClipDisabled()
    }

    private func homeLoadoutPick(item: ShopItem?, icon: String, tint: Color) -> some View {
        let fill = item?.color ?? RallyUIKit.Palette.ink
        let accent = item?.accentColor ?? tint
        let isSelected = selectedLoadoutCategory.displayName == labelForIcon(icon)
        let label: String
        switch icon {
        case "tennis.racket": label = "Racket"
        case "tshirt.fill": label = "Top"
        case "rectangle.fill": label = "Bottom"
        case "shoe.fill": label = "Shoes"
        default: label = "Kit"
        }
        return Button { selectedTab = .shop } label: {
            VStack(spacing: item == nil ? 8 : 0) {
                ZStack(alignment: .topTrailing) {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    fill.opacity(item == nil ? 0.34 : 0.74),
                                    accent.opacity(item == nil ? 0.18 : 0.34),
                                    RallyUIKit.Palette.obsidian.opacity(0.96)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 108, height: 118)
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(Color.white.opacity(0.12), lineWidth: 1)
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(isSelected ? accent.opacity(0.92) : Color.clear, lineWidth: 2)
                    Image(systemName: icon)
                        .font(.system(size: 29, weight: .semibold))
                        .symbolRenderingMode(.monochrome)
                        .foregroundStyle(item == nil ? .white.opacity(0.36) : .white.opacity(isSelected ? 0.98 : 0.60))
                        .saturation(isSelected ? 1 : 0.60)

                    if item != nil {
                        VStack {
                            HStack {
                                Spacer()
                                Circle()
                                    .fill(accent)
                                    .frame(width: 8, height: 8)
                            }
                            Spacer()
                        }
                        .padding(8)
                    }
                }

                if item == nil {
                    Text(label)
                        .font(RallyUIKit.Typography.label(.caption2, weight: .bold))
                        .foregroundStyle(RallyUIKit.Palette.cloud.opacity(0.62))
                        .frame(width: 108)
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(item?.name ?? label)
    }

    private func labelForIcon(_ icon: String) -> String {
        switch icon {
        case "tennis.racket": return ShopItem.Category.racket.displayName
        case "tshirt.fill": return ShopItem.Category.top.displayName
        case "rectangle.fill": return ShopItem.Category.bottom.displayName
        case "shoe.fill": return ShopItem.Category.shoes.displayName
        default: return ""
        }
    }

    private var essentialsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Wall Rally")
                .font(RallyUIKit.Typography.title(.headline, weight: .bold))
                .foregroundStyle(RallyUIKit.Palette.frost)

            pregameRow(label: "Court") {
                ForEach(CourtVenue.allCases) { venue in
                    pregameChip(
                        title: venueShortName(venue),
                        isSelected: CourtVenue.current == venue,
                        tint: venue == .wimbledonGrass ? RallyUIKit.Palette.lime : RallyUIKit.Palette.cyan
                    ) { CourtVenue.current = venue }
                }
            }

            pregameRow(label: "Hand") {
                ForEach(GamePreferences.DominantHand.allCases) { hand in
                    pregameChip(
                        title: hand == .right ? "Right" : "Left",
                        isSelected: gamePreferences.dominantHand == hand,
                        tint: hand == .right ? RallyUIKit.Palette.gold : RallyUIKit.Palette.rose
                    ) { gamePreferences.dominantHand = hand }
                }
            }

            Button(action: startPractice) {
                ZStack {
                    HStack(spacing: 10) {
                        Image(systemName: "play.fill")
                            .font(.title3.weight(.bold))
                        Text("Play")
                            .font(RallyUIKit.Typography.title(.title3, weight: .bold))
                    }
                    .frame(maxWidth: .infinity, alignment: .center)

                    HStack {
                        Spacer()
                        Circle()
                            .fill(Color.white.opacity(0.18))
                            .frame(width: 18, height: 18)
                            .overlay(
                                Circle()
                                    .stroke(Color.white.opacity(0.12), lineWidth: 1)
                            )
                    }
                }
                .foregroundStyle(RallyUIKit.Palette.obsidian)
                .frame(maxWidth: .infinity, minHeight: 56)
                .padding(.horizontal, 18)
                .background(
                    RoundedRectangle(cornerRadius: RallyUIKit.Radius.xl, style: .continuous)
                        .fill(RallyUIKit.accentGradient(RallyUIKit.Palette.cyan))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: RallyUIKit.Radius.xl, style: .continuous)
                        .stroke(Color.white.opacity(0.28), lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
        }
    }

    private func displayName(for avatar: AvatarConfig?) -> String {
        let raw = avatar?.playerName.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return raw.isEmpty ? "Player" : raw
    }

    private func venueShortName(_ venue: CourtVenue) -> String {
        switch venue {
        case .miamiHard: return "Australia"
        case .wimbledonGrass: return "Wimbledon"
        case .redClay: return "Clay"
        case .barcelonaClay: return "Barcelona"
        }
    }

    private func pregameRow<Content: View>(label: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label)
                .font(RallyUIKit.Typography.label(.caption, weight: .bold))
                .foregroundStyle(RallyUIKit.Palette.cloud.opacity(0.62))
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    content()
                }
            }
            .scrollClipDisabled()
        }
    }

    private func pregameChip(title: String, isSelected: Bool, tint: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(RallyUIKit.Typography.label(.caption, weight: .bold))
                .foregroundStyle(isSelected ? RallyUIKit.Palette.obsidian : RallyUIKit.Palette.frost.opacity(0.9))
                .frame(minWidth: 86)
                .padding(.horizontal, 14)
                .padding(.vertical, 11)
                .background(
                    Capsule()
                        .fill(isSelected ? AnyShapeStyle(RallyUIKit.accentGradient(tint)) : AnyShapeStyle(Color.white.opacity(0.06)))
                )
                .overlay(
                    Capsule()
                        .stroke(isSelected ? Color.white.opacity(0.22) : Color.white.opacity(0.08), lineWidth: 1)
                )
                .shadow(color: isSelected ? tint.opacity(0.24) : .clear, radius: 10, x: 0, y: 5)
        }
        .buttonStyle(.plain)
    }

    private func startPractice() {
        gamePreferences.matchPace = .calm
        isPlaying = true
    }
}

private struct LoadoutPlayButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.spring(response: 0.18, dampingFraction: 0.72), value: configuration.isPressed)
    }
}

private struct PerspectiveCourtPlate: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX + rect.width * 0.18, y: rect.minY + rect.height * 0.14))
        path.addLine(to: CGPoint(x: rect.maxX - rect.width * 0.18, y: rect.minY + rect.height * 0.14))
        path.addLine(to: CGPoint(x: rect.maxX - rect.width * 0.04, y: rect.maxY - rect.height * 0.08))
        path.addLine(to: CGPoint(x: rect.minX + rect.width * 0.04, y: rect.maxY - rect.height * 0.08))
        path.closeSubpath()
        return path
    }
}
