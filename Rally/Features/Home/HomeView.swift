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
    @State private var showsJournal = false

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
            .sheet(isPresented: $showsJournal) {
                JournalView()
            }
            .navigationTitle(displayName(for: avatar))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        showsJournal = true
                    } label: {
                        topChromeIcon(systemName: "calendar")
                    }
                    .buttonStyle(LoadoutPlayButtonStyle())
                    .accessibilityLabel("Open journal")
                }
                ToolbarItem(placement: .topBarTrailing) {
                    if let avatar = avatar {
                        NavigationLink {
                            AvatarCustomizerView(config: avatar)
                        } label: {
                            topChromeIcon(systemName: "person.crop.circle")
                        }
                        .buttonStyle(LoadoutPlayButtonStyle())
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
            let stageHeight = min(HomeCraft.stageMaxHeight, max(HomeCraft.stageMinHeight, proxy.size.height * HomeCraft.stageHeightShare))

            VStack(spacing: HomeCraft.verticalRhythm) {
                loadoutTopChrome

                livingPregameStage
                    .frame(height: stageHeight)

                wardrobeRail

                courtRail

                playDock

                Spacer(minLength: 0)
            }
            .padding(.horizontal, HomeCraft.horizontalPadding)
            .padding(.top, 8)
            .padding(.bottom, 72)
            .frame(width: proxy.size.width, height: proxy.size.height, alignment: .top)
        }
    }

    private var loadoutTopChrome: some View {
        Text("LOADOUT")
            .font(.system(size: 11, weight: .black, design: .rounded))
            .tracking(2.2)
            .foregroundStyle(RallyUIKit.Palette.cyan.opacity(0.82))
            .frame(maxWidth: .infinity)
        .padding(.horizontal, 2)
    }

    private func topChromeIcon(systemName: String, isFilled: Bool = false) -> some View {
        Image(systemName: systemName)
            .font(.system(size: 16, weight: .bold))
            .foregroundStyle(isFilled ? RallyUIKit.Palette.obsidian : RallyUIKit.Palette.champagne)
            .frame(width: HomeCraft.headerTapTarget, height: HomeCraft.headerTapTarget)
            .background(
                Circle()
                    .fill(isFilled ? RallyUIKit.Palette.champagne : Color.white.opacity(0.075))
            )
            .overlay(
                Circle()
                    .stroke(Color.white.opacity(isFilled ? 0.22 : 0.12), lineWidth: 1)
            )
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
        RallySyncTriggers.pushAvatarAfterLocalSave(modelContext: modelContext)
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
            RoundedRectangle(cornerRadius: HomeCraft.largeRadius, style: .continuous)
                .fill(stageGradient(for: selectedCourt))
                .overlay(movingStageLight.clipShape(RoundedRectangle(cornerRadius: HomeCraft.largeRadius, style: .continuous)))
                .overlay(courtLinesOverlay(for: selectedCourt).clipShape(RoundedRectangle(cornerRadius: HomeCraft.largeRadius, style: .continuous)))
                .overlay(
                    RoundedRectangle(cornerRadius: HomeCraft.largeRadius, style: .continuous)
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
        .clipShape(RoundedRectangle(cornerRadius: HomeCraft.largeRadius, style: .continuous))
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

            Button {
                withAnimation(.spring(response: 0.20, dampingFraction: 0.80)) {
                    gamePreferences.dominantHand = gamePreferences.dominantHand == .right ? .left : .right
                }
            } label: {
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
            .buttonStyle(LoadoutPlayButtonStyle())
            .accessibilityLabel("Switch dominant hand")
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
        VStack(spacing: 11) {
            HStack(alignment: .center, spacing: 10) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(shortLabel(for: selectedLoadoutCategory).uppercased())
                        .font(.system(size: 10, weight: .black, design: .rounded))
                        .tracking(1.7)
                        .foregroundStyle(categoryAccent(for: selectedLoadoutCategory))

                    Text(selectedLoadoutItem?.name ?? "Choose \(shortLabel(for: selectedLoadoutCategory))")
                        .font(.system(size: 15, weight: .black, design: .rounded))
                        .foregroundStyle(RallyUIKit.Palette.frost)
                        .lineLimit(1)

                    Text(selectedLoadoutItem?.brand.uppercased() ?? "RALLY")
                        .font(.system(size: 9, weight: .black, design: .rounded))
                        .tracking(1.1)
                        .foregroundStyle(RallyUIKit.Palette.cloud.opacity(0.48))
                        .lineLimit(1)
                }
                Spacer(minLength: 0)

                HStack(spacing: 7) {
                    itemCycleButton(systemName: "chevron.left") {
                        cycleLoadout(-1)
                    }
                    itemCycleButton(systemName: "chevron.right") {
                        cycleLoadout(1)
                    }
                }
                .accessibilityElement(children: .contain)
            }

            HStack(spacing: 8) {
                ForEach(editableLoadoutCategories, id: \.self) { category in
                    let item = equippedItem(for: category)
                    Button {
                        withAnimation(.spring(response: 0.22, dampingFraction: 0.82)) {
                            selectedLoadoutCategory = category
                        }
                    } label: {
                        loadoutSlotTile(
                            category: category,
                            item: item,
                            isSelected: selectedLoadoutCategory == category
                        )
                    }
                    .buttonStyle(LoadoutPlayButtonStyle())
                    .accessibilityLabel("\(shortLabel(for: category)) \(item?.name ?? "empty")")
                }
            }
            .frame(maxWidth: .infinity)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: HomeCraft.largeRadius, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.black.opacity(0.38),
                            RallyUIKit.Palette.ink.opacity(0.72)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: HomeCraft.largeRadius, style: .continuous)
                .stroke(Color.white.opacity(0.10), lineWidth: 1)
        )
    }

    private func itemCycleButton(systemName: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 12, weight: .black))
                .foregroundStyle(RallyUIKit.Palette.frost)
                .frame(width: 34, height: 34)
                .background(
                    Circle()
                        .fill(Color.white.opacity(0.10))
                )
                .overlay(
                    Circle()
                        .stroke(Color.white.opacity(0.18), lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.20), radius: 7, y: 3)
        }
        .buttonStyle(LoadoutPlayButtonStyle())
    }

    private func loadoutSlotTile(category: ShopItem.Category, item: ShopItem?, isSelected: Bool) -> some View {
        let accent = item?.accentColor ?? categoryAccent(for: category)

        return VStack(spacing: 7) {
            ZStack(alignment: .topTrailing) {
                RoundedRectangle(cornerRadius: HomeCraft.smallRadius, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                RallyUIKit.Palette.slate.opacity(isSelected ? 0.98 : 0.76),
                                RallyUIKit.Palette.ink.opacity(0.96),
                                RallyUIKit.Palette.obsidian.opacity(0.98)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: HomeCraft.smallRadius, style: .continuous)
                            .stroke(Color.white.opacity(isSelected ? 0.24 : 0.12), lineWidth: 1)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: HomeCraft.smallRadius, style: .continuous)
                            .stroke(isSelected ? accent.opacity(0.95) : Color.clear, lineWidth: 2)
                    )
                    .shadow(color: isSelected ? accent.opacity(0.24) : .clear, radius: 13, y: 6)

                loadoutGlyph(for: category, isSelected: isSelected, accent: accent)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                Circle()
                    .fill(accent)
                    .frame(width: 6, height: 6)
                    .padding(8)
                    .opacity(item == nil ? 0 : 1)
            }
            .frame(maxWidth: .infinity)
            .frame(height: HomeCraft.loadoutTileHeight)

            Text(shortLabel(for: category))
                .font(.system(size: 10, weight: .black, design: .rounded))
                .foregroundStyle(isSelected ? .white : RallyUIKit.Palette.cloud.opacity(0.58))
                .lineLimit(1)
        }
    }

    @ViewBuilder
    private func loadoutGlyph(for category: ShopItem.Category, isSelected: Bool, accent: Color) -> some View {
        let primary = isSelected ? Color.white : RallyUIKit.Palette.cloud.opacity(0.66)
        let secondary = isSelected ? accent.opacity(0.88) : RallyUIKit.Palette.cloud.opacity(0.24)

        switch category {
        case .bottom:
            LoadoutShortsGlyph(primary: primary, accent: secondary)
                .frame(width: 37, height: 32)
        case .shoes:
            LoadoutTennisShoeGlyph(primary: primary, accent: secondary)
                .frame(width: 46, height: 30)
        case .top:
            Image(systemName: "tshirt.fill")
                .font(.system(size: 24, weight: .semibold))
                .symbolRenderingMode(.monochrome)
                .foregroundStyle(primary)
                .saturation(isSelected ? 1 : 0.60)
        case .racket:
            Image(systemName: "tennis.racket")
                .font(.system(size: 24, weight: .semibold))
                .symbolRenderingMode(.monochrome)
                .foregroundStyle(primary)
                .saturation(isSelected ? 1 : 0.60)
        case .bag:
            Image(systemName: "duffle.bag.fill")
                .font(.system(size: 24, weight: .semibold))
                .symbolRenderingMode(.monochrome)
                .foregroundStyle(primary)
                .saturation(isSelected ? 1 : 0.60)
        case .accessory:
            Image(systemName: "sparkles")
                .font(.system(size: 24, weight: .semibold))
                .symbolRenderingMode(.monochrome)
                .foregroundStyle(primary)
                .saturation(isSelected ? 1 : 0.60)
        }
    }

    private var courtRail: some View {
        HStack(spacing: 9) {
            ForEach(featuredCourtVenues) { venue in
                Button {
                    withAnimation(.spring(response: 0.24, dampingFraction: 0.82)) {
                        setCourt(venue)
                    }
                } label: {
                    HStack(spacing: 7) {
                        Circle()
                            .fill(courtAccent(for: venue))
                            .frame(width: 7, height: 7)
                        Text(venueShortName(venue))
                            .font(.system(size: 11, weight: .black, design: .rounded))
                            .tracking(0.2)
                            .foregroundStyle(venue == selectedCourt ? RallyUIKit.Palette.frost : RallyUIKit.Palette.cloud.opacity(0.62))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(
                        Capsule(style: .continuous)
                            .fill(
                                venue == selectedCourt
                                    ? AnyShapeStyle(
                                        LinearGradient(
                                            colors: [
                                                courtAccent(for: venue).opacity(0.84),
                                                courtAccent(for: venue).opacity(0.48)
                                            ],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                    : AnyShapeStyle(RallyUIKit.Palette.obsidian.opacity(0.72))
                            )
                    )
                    .overlay(
                        Capsule(style: .continuous)
                            .stroke(venue == selectedCourt ? Color.white.opacity(0.26) : Color.white.opacity(0.12), lineWidth: 1)
                    )
                    .shadow(color: venue == selectedCourt ? courtAccent(for: venue).opacity(0.18) : .clear, radius: 10, y: 5)
                }
                .buttonStyle(LoadoutPlayButtonStyle())
            }
        }
        .padding(.top, 2)
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
                .frame(maxWidth: .infinity)
                .frame(height: 60)
                .background(
                    RoundedRectangle(cornerRadius: HomeCraft.largeRadius, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    courtAccent(for: selectedCourt).opacity(0.98),
                                    RallyUIKit.Palette.cyan.opacity(0.82),
                                    RallyUIKit.Palette.ink
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: HomeCraft.largeRadius, style: .continuous)
                        .stroke(Color.white.opacity(0.22), lineWidth: 1)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: HomeCraft.largeRadius, style: .continuous)
                        .stroke(courtAccent(for: selectedCourt).opacity(0.24), lineWidth: 3)
                        .blur(radius: 8)
                        .opacity(0.45 + pulse * 0.20)
                )
                .shadow(color: courtAccent(for: selectedCourt).opacity(0.24 + pulse * 0.10), radius: 18 + pulse * 4, y: 8)
            }
            .buttonStyle(LoadoutPlayButtonStyle())
        }
        .padding(.top, 8)
    }

    private func displayName(for avatar: AvatarConfig?) -> String {
        let raw = avatar?.playerName.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return raw.isEmpty ? "Player" : raw
    }

    private func venueShortName(_ venue: CourtVenue) -> String {
        switch venue {
        case .miamiHard: return "Miami"
        case .wimbledonGrass: return "Wimbledon"
        case .redClay: return "Clay"
        case .barcelonaClay: return "Barcelona"
        }
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
            .brightness(configuration.isPressed ? -0.08 : 0)
            .animation(.spring(response: 0.18, dampingFraction: 0.72), value: configuration.isPressed)
    }
}

private struct LoadoutShortsGlyph: View {
    let primary: Color
    let accent: Color

    var body: some View {
        Canvas { context, size in
            let w = size.width
            let h = size.height

            var leftLeg = Path()
            leftLeg.move(to: CGPoint(x: w * 0.16, y: h * 0.22))
            leftLeg.addQuadCurve(to: CGPoint(x: w * 0.48, y: h * 0.18), control: CGPoint(x: w * 0.30, y: h * 0.11))
            leftLeg.addLine(to: CGPoint(x: w * 0.47, y: h * 0.48))
            leftLeg.addQuadCurve(to: CGPoint(x: w * 0.36, y: h * 0.82), control: CGPoint(x: w * 0.40, y: h * 0.66))
            leftLeg.addQuadCurve(to: CGPoint(x: w * 0.12, y: h * 0.72), control: CGPoint(x: w * 0.22, y: h * 0.88))
            leftLeg.addLine(to: CGPoint(x: w * 0.16, y: h * 0.22))
            leftLeg.closeSubpath()
            context.fill(leftLeg, with: .color(primary))

            var rightLeg = Path()
            rightLeg.move(to: CGPoint(x: w * 0.52, y: h * 0.18))
            rightLeg.addQuadCurve(to: CGPoint(x: w * 0.84, y: h * 0.22), control: CGPoint(x: w * 0.70, y: h * 0.11))
            rightLeg.addLine(to: CGPoint(x: w * 0.88, y: h * 0.72))
            rightLeg.addQuadCurve(to: CGPoint(x: w * 0.64, y: h * 0.82), control: CGPoint(x: w * 0.78, y: h * 0.88))
            rightLeg.addQuadCurve(to: CGPoint(x: w * 0.53, y: h * 0.48), control: CGPoint(x: w * 0.60, y: h * 0.66))
            rightLeg.addLine(to: CGPoint(x: w * 0.52, y: h * 0.18))
            rightLeg.closeSubpath()
            context.fill(rightLeg, with: .color(primary))

            var shorts = Path()
            shorts.move(to: CGPoint(x: w * 0.16, y: h * 0.22))
            shorts.addQuadCurve(to: CGPoint(x: w * 0.84, y: h * 0.22), control: CGPoint(x: w * 0.50, y: h * 0.08))
            shorts.addLine(to: CGPoint(x: w * 0.88, y: h * 0.42))
            shorts.addQuadCurve(to: CGPoint(x: w * 0.54, y: h * 0.43), control: CGPoint(x: w * 0.68, y: h * 0.50))
            shorts.addQuadCurve(to: CGPoint(x: w * 0.46, y: h * 0.43), control: CGPoint(x: w * 0.50, y: h * 0.38))
            shorts.addQuadCurve(to: CGPoint(x: w * 0.12, y: h * 0.42), control: CGPoint(x: w * 0.32, y: h * 0.50))
            shorts.closeSubpath()
            context.fill(shorts, with: .color(primary.opacity(0.96)))

            var waistband = Path()
            waistband.move(to: CGPoint(x: w * 0.19, y: h * 0.26))
            waistband.addQuadCurve(to: CGPoint(x: w * 0.81, y: h * 0.26), control: CGPoint(x: w * 0.50, y: h * 0.18))
            context.stroke(waistband, with: .color(accent.opacity(0.86)), lineWidth: max(1.7, w * 0.052))

            var centerSeam = Path()
            centerSeam.move(to: CGPoint(x: w * 0.50, y: h * 0.28))
            centerSeam.addQuadCurve(to: CGPoint(x: w * 0.50, y: h * 0.72), control: CGPoint(x: w * 0.54, y: h * 0.50))
            context.stroke(centerSeam, with: .color(Color.black.opacity(0.26)), lineWidth: max(1.0, w * 0.030))

            var hems = Path()
            hems.move(to: CGPoint(x: w * 0.15, y: h * 0.70))
            hems.addQuadCurve(to: CGPoint(x: w * 0.37, y: h * 0.78), control: CGPoint(x: w * 0.25, y: h * 0.84))
            hems.move(to: CGPoint(x: w * 0.63, y: h * 0.78))
            hems.addQuadCurve(to: CGPoint(x: w * 0.85, y: h * 0.70), control: CGPoint(x: w * 0.75, y: h * 0.84))
            context.stroke(hems, with: .color(accent.opacity(0.72)), lineWidth: max(1.2, w * 0.036))

            var sideHighlight = Path()
            sideHighlight.move(to: CGPoint(x: w * 0.27, y: h * 0.30))
            sideHighlight.addQuadCurve(to: CGPoint(x: w * 0.23, y: h * 0.63), control: CGPoint(x: w * 0.24, y: h * 0.48))
            sideHighlight.move(to: CGPoint(x: w * 0.73, y: h * 0.30))
            sideHighlight.addQuadCurve(to: CGPoint(x: w * 0.77, y: h * 0.63), control: CGPoint(x: w * 0.76, y: h * 0.48))
            context.stroke(sideHighlight, with: .color(.white.opacity(0.24)), lineWidth: max(1, w * 0.024))
        }
    }
}

private struct LoadoutTennisShoeGlyph: View {
    let primary: Color
    let accent: Color

    var body: some View {
        Canvas { context, size in
            let w = size.width
            let h = size.height

            var shadow = Path()
            shadow.addEllipse(in: CGRect(x: w * 0.06, y: h * 0.75, width: w * 0.86, height: h * 0.16))
            context.fill(shadow, with: .color(Color.black.opacity(0.18)))

            var upper = Path()
            upper.move(to: CGPoint(x: w * 0.10, y: h * 0.61))
            upper.addQuadCurve(to: CGPoint(x: w * 0.30, y: h * 0.42), control: CGPoint(x: w * 0.18, y: h * 0.43))
            upper.addQuadCurve(to: CGPoint(x: w * 0.56, y: h * 0.36), control: CGPoint(x: w * 0.42, y: h * 0.28))
            upper.addQuadCurve(to: CGPoint(x: w * 0.82, y: h * 0.46), control: CGPoint(x: w * 0.70, y: h * 0.33))
            upper.addQuadCurve(to: CGPoint(x: w * 0.95, y: h * 0.62), control: CGPoint(x: w * 0.94, y: h * 0.48))
            upper.addQuadCurve(to: CGPoint(x: w * 0.91, y: h * 0.70), control: CGPoint(x: w * 0.97, y: h * 0.69))
            upper.addQuadCurve(to: CGPoint(x: w * 0.14, y: h * 0.70), control: CGPoint(x: w * 0.50, y: h * 0.76))
            upper.addQuadCurve(to: CGPoint(x: w * 0.10, y: h * 0.61), control: CGPoint(x: w * 0.04, y: h * 0.67))
            upper.closeSubpath()
            context.fill(upper, with: .color(primary))

            var sole = Path()
            sole.move(to: CGPoint(x: w * 0.08, y: h * 0.70))
            sole.addQuadCurve(to: CGPoint(x: w * 0.93, y: h * 0.69), control: CGPoint(x: w * 0.48, y: h * 0.82))
            context.stroke(sole, with: .color(accent.opacity(0.96)), lineWidth: max(2.4, h * 0.120))

            var outsole = Path()
            outsole.move(to: CGPoint(x: w * 0.11, y: h * 0.81))
            outsole.addQuadCurve(to: CGPoint(x: w * 0.88, y: h * 0.78), control: CGPoint(x: w * 0.48, y: h * 0.88))
            context.stroke(outsole, with: .color(Color.white.opacity(0.42)), lineWidth: max(1, h * 0.032))

            var heelCup = Path()
            heelCup.move(to: CGPoint(x: w * 0.18, y: h * 0.62))
            heelCup.addQuadCurve(to: CGPoint(x: w * 0.31, y: h * 0.44), control: CGPoint(x: w * 0.18, y: h * 0.49))
            heelCup.addLine(to: CGPoint(x: w * 0.38, y: h * 0.68))
            context.stroke(heelCup, with: .color(accent.opacity(0.74)), lineWidth: max(1.2, w * 0.034))

            var tongue = Path()
            tongue.move(to: CGPoint(x: w * 0.41, y: h * 0.42))
            tongue.addQuadCurve(to: CGPoint(x: w * 0.56, y: h * 0.38), control: CGPoint(x: w * 0.49, y: h * 0.33))
            tongue.addQuadCurve(to: CGPoint(x: w * 0.63, y: h * 0.63), control: CGPoint(x: w * 0.64, y: h * 0.50))
            tongue.addQuadCurve(to: CGPoint(x: w * 0.42, y: h * 0.62), control: CGPoint(x: w * 0.51, y: h * 0.70))
            tongue.closeSubpath()
            context.fill(tongue, with: .color(accent.opacity(0.30)))

            var laces = Path()
            laces.move(to: CGPoint(x: w * 0.43, y: h * 0.47))
            laces.addLine(to: CGPoint(x: w * 0.56, y: h * 0.55))
            laces.move(to: CGPoint(x: w * 0.50, y: h * 0.43))
            laces.addLine(to: CGPoint(x: w * 0.65, y: h * 0.54))
            laces.move(to: CGPoint(x: w * 0.58, y: h * 0.45))
            laces.addLine(to: CGPoint(x: w * 0.73, y: h * 0.56))
            context.stroke(laces, with: .color(accent), lineWidth: max(1.1, w * 0.028))

            var speedStripe = Path()
            speedStripe.move(to: CGPoint(x: w * 0.30, y: h * 0.62))
            speedStripe.addQuadCurve(to: CGPoint(x: w * 0.78, y: h * 0.55), control: CGPoint(x: w * 0.54, y: h * 0.42))
            context.stroke(speedStripe, with: .color(accent.opacity(0.82)), lineWidth: max(1.5, w * 0.042))

            var toe = Path()
            toe.move(to: CGPoint(x: w * 0.78, y: h * 0.47))
            toe.addQuadCurve(to: CGPoint(x: w * 0.91, y: h * 0.63), control: CGPoint(x: w * 0.95, y: h * 0.51))
            context.stroke(toe, with: .color(Color.white.opacity(0.55)), lineWidth: max(1, w * 0.026))
        }
    }
}

private enum HomeCraft {
    static let horizontalPadding: CGFloat = 16
    static let verticalRhythm: CGFloat = 9
    static let headerTapTarget: CGFloat = 44
    static let largeRadius: CGFloat = 30
    static let smallRadius: CGFloat = 18
    static let loadoutTileHeight: CGFloat = 52
    static let stageHeightShare: CGFloat = 0.36
    static let stageMinHeight: CGFloat = 268
    static let stageMaxHeight: CGFloat = 304
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
