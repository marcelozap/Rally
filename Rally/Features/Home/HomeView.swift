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
                    HStack(spacing: 8) {
                        Button {
                            showsJournal = true
                        } label: {
                            topChromeIcon(systemName: "calendar")
                        }
                        .buttonStyle(LoadoutPlayButtonStyle())
                        .accessibilityLabel("Open journal")

                        NavigationLink {
                            CoachView()
                        } label: {
                            Text("Coach")
                                .font(RallyUIKit.Typography.body(.subheadline, weight: .bold))
                                .foregroundStyle(RallyUIKit.Palette.champagne)
                                .padding(.horizontal, 12)
                                .frame(height: HomeCraft.headerTapTarget)
                                .background(Capsule().fill(Color.white.opacity(0.075)))
                                .overlay(Capsule().stroke(Color.white.opacity(0.12), lineWidth: 1))
                        }
                        .buttonStyle(LoadoutPlayButtonStyle())
                        .accessibilityLabel("Open Rally Coach")
                        .accessibilityIdentifier("home.rallyCoach")
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    if let avatar = avatar {
                        NavigationLink {
                            AvatarCustomizerView(config: avatar)
                        } label: {
                            topChromeIcon(systemName: "person.crop.circle")
                        }
                        .buttonStyle(LoadoutPlayButtonStyle())
                        .accessibilityLabel("Choose player")
                    }
                }
            }
            .onAppear {
                selectedCourt = featuredCourtVenues.contains(CourtVenue.current) ? CourtVenue.current : .wimbledonGrass
                CourtVenue.current = selectedCourt
                avatarAppearanceStore.commitPersisted(from: avatar)
            }
        }
    }

    private var loadoutScreen: some View {
        GeometryReader { proxy in
            let stageHeight = min(HomeCraft.stageMaxHeight, max(HomeCraft.stageMinHeight, proxy.size.height * HomeCraft.stageHeightShare))

            ScrollView(showsIndicators: false) {
                VStack(spacing: HomeCraft.verticalRhythm) {
                    loadoutTopChrome
                    livingPregameStage
                        .frame(height: stageHeight)
                    wardrobeRail
                    courtRail
                }
                .padding(.horizontal, HomeCraft.horizontalPadding)
                .padding(.top, 12)
                .padding(.bottom, 20)
                .frame(maxWidth: 640)
                .frame(maxWidth: .infinity)
            }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                playDock
                    .padding(.horizontal, HomeCraft.horizontalPadding)
                    .padding(.top, 12)
                    .padding(.bottom, 10)
                    .frame(maxWidth: 640)
                    .frame(maxWidth: .infinity)
                    .background(RallyUIKit.Palette.obsidian.opacity(0.96))
            }
        }
    }

    private var loadoutTopChrome: some View {
        HStack(alignment: .bottom, spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                Text("THE CLUBHOUSE")
                    .font(.system(size: 10, weight: .semibold))
                    .tracking(2.3)
                    .foregroundStyle(RallyUIKit.Palette.lime)
                Text("Ready to rally.")
                    .font(.system(size: 30, weight: .semibold))
                    .tracking(-0.8)
                    .foregroundStyle(RallyUIKit.Palette.frost)
            }
            Spacer(minLength: 0)
            Text("YOUR\nLOADOUT")
                .font(.system(size: 9, weight: .medium))
                .tracking(1.4)
                .lineSpacing(3)
                .multilineTextAlignment(.trailing)
                .foregroundStyle(RallyUIKit.Palette.cloud)
                .padding(.bottom, 3)
        }
        .accessibilityElement(children: .combine)
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
            avatarAppearanceStore.commitPersisted(from: avatar)
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
            RallyUIKit.screenBackground
            LinearGradient(
                colors: [courtAccent(for: venue).opacity(0.055), .clear],
                startPoint: .top,
                endPoint: .center
            )
        }
    }

    private func stageGradient(for venue: CourtVenue) -> LinearGradient {
        LinearGradient(
            colors: [
                RallyUIKit.Palette.slate,
                courtAccent(for: venue).opacity(0.13),
                RallyUIKit.Palette.ink
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
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
        case .miamiHard: return Color(red: 0.38, green: 0.58, blue: 0.64)
        case .wimbledonGrass: return Color(red: 0.49, green: 0.64, blue: 0.41)
        case .redClay: return Color(red: 0.76, green: 0.43, blue: 0.30)
        case .barcelonaClay: return Color(red: 0.76, green: 0.43, blue: 0.30)
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

                rhythmAvatar
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: HomeCraft.largeRadius, style: .continuous))

    }

    private var stageStatusStrip: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(selectedCourt.displayName)
                    .font(RallyUIKit.Typography.title(.headline, weight: .bold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.68)

                Text(avatar?.athletePreset.displayName.uppercased() ?? "YOUR PLAYER")
                    .font(.system(size: 10, weight: .black, design: .rounded))
                    .tracking(1.4)
                    .foregroundStyle(courtAccent(for: selectedCourt).opacity(0.78))
            }

            Spacer(minLength: 8)

            SoundToggleButton(showsLabel: false)
                .buttonStyle(LoadoutPlayButtonStyle())
                .accessibilityHint("Toggles Rally sound effects and music")

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
        ZStack {
            RadialGradient(
                colors: [RallyUIKit.Palette.champagne.opacity(0.12), .clear],
                center: UnitPoint(x: 0.30, y: 0.12),
                startRadius: 10,
                endRadius: 320
            )
            Rectangle()
                .fill(RallyUIKit.Palette.champagne.opacity(0.035))
                .frame(width: 90, height: 540)
                .rotationEffect(.degrees(28))
                .offset(x: 85)
        }
        .allowsHitTesting(false)
    }

    private var rhythmAvatar: some View {
        GeometryReader { proxy in
            let height = max(180, min(340, proxy.size.height - 12))
            ZStack(alignment: .bottom) {
                Ellipse()
                    .fill(Color.black.opacity(0.36))
                    .frame(width: 110, height: 12)
                    .blur(radius: 6)
                    .offset(y: -height * 0.04)

                if avatar != nil {
                    RallyAvatarView(
                        appearance: avatarAppearanceStore.appearance,
                        targetHeight: height,
                        showsRacket: true,
                        leftHanded: gamePreferences.dominantHand == .left
                    )
                    .frame(width: min(290, proxy.size.width), height: height)
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height, alignment: .center)
        }
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
                        .font(.system(size: 16, weight: .semibold))
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
                .frame(width: 44, height: 44)
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
                            .stroke(isSelected ? RallyUIKit.Palette.lime.opacity(0.75) : Color.clear, lineWidth: 1)
                    )
                    .shadow(color: .clear, radius: 0)

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
                .frame(width: 42, height: 34)
        case .shoes:
            LoadoutTennisShoeGlyph(primary: primary, accent: secondary)
                .frame(width: 48, height: 32)
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
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Choose your court")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(RallyUIKit.Palette.frost)
                Spacer()
                Text("03 SURFACES")
                    .font(.system(size: 9, weight: .medium))
                    .tracking(1.2)
                    .foregroundStyle(RallyUIKit.Palette.cloud)
            }
            HStack(spacing: 10) {
                ForEach(featuredCourtVenues) { venue in
                    Button {
                        withAnimation(.easeInOut(duration: 0.22)) { setCourt(venue) }
                    } label: {
                        VStack(alignment: .leading, spacing: 9) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 9)
                                    .fill(courtAccent(for: venue).opacity(0.65))
                                Rectangle()
                                    .stroke(RallyUIKit.Palette.frost.opacity(0.6), lineWidth: 0.8)
                                    .padding(8)
                                HStack(spacing: 0) {
                                    Rectangle().fill(RallyUIKit.Palette.frost.opacity(0.5)).frame(width: 0.8)
                                }
                                .padding(.vertical, 8)
                                Rectangle()
                                    .fill(RallyUIKit.Palette.frost.opacity(0.7))
                                    .frame(height: 1)
                                    .padding(.horizontal, 8)
                            }
                            .frame(height: 48)
                            HStack(spacing: 3) {
                                Text(venueShortName(venue))
                                    .font(.system(size: 11, weight: .semibold))
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.85)
                                Spacer(minLength: 0)
                                if venue == selectedCourt {
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 9, weight: .bold))
                                        .foregroundStyle(RallyUIKit.Palette.lime)
                                }
                            }
                            .foregroundStyle(RallyUIKit.Palette.frost)
                        }
                        .padding(9)
                        .background(RallyUIKit.Palette.ink, in: RoundedRectangle(cornerRadius: 15))
                        .overlay(RoundedRectangle(cornerRadius: 15)
                            .stroke(venue == selectedCourt ? RallyUIKit.Palette.lime.opacity(0.6) : Color.white.opacity(0.09), lineWidth: 1))
                    }
                    .buttonStyle(LoadoutPlayButtonStyle())
                    .accessibilityLabel(venue.displayName)
                    .accessibilityAddTraits(venue == selectedCourt ? [.isSelected] : [])
                }
            }
        }
        .padding(.top, 6)
    }

    private var playDock: some View {
        Button(action: startPractice) {
            HStack(spacing: 12) {
                Image(systemName: "play.fill")
                    .font(.system(size: 17, weight: .semibold))
                Text("Play Rally")
                    .font(.system(size: 19, weight: .bold))
                    .tracking(-0.3)
                Spacer()
                Image(systemName: "arrow.right")
                    .font(.system(size: 17, weight: .semibold))
            }
            .foregroundStyle(RallyUIKit.Palette.obsidian)
            .padding(.horizontal, 22)
            .frame(maxWidth: .infinity, minHeight: 58)
            .background(RallyUIKit.Palette.lime, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .buttonStyle(LoadoutPlayButtonStyle())
        .accessibilityIdentifier("home.playRally")
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

            // Keep this icon graphic and athletic. Earlier versions rounded
            // into a square block, which read more like a generic tile than
            // tennis shorts at phone size.
            var body = Path()
            body.move(to: CGPoint(x: w * 0.15, y: h * 0.17))
            body.addLine(to: CGPoint(x: w * 0.85, y: h * 0.17))
            body.addLine(to: CGPoint(x: w * 0.80, y: h * 0.78))
            body.addQuadCurve(to: CGPoint(x: w * 0.57, y: h * 0.82), control: CGPoint(x: w * 0.68, y: h * 0.88))
            body.addLine(to: CGPoint(x: w * 0.50, y: h * 0.51))
            body.addLine(to: CGPoint(x: w * 0.43, y: h * 0.82))
            body.addQuadCurve(to: CGPoint(x: w * 0.20, y: h * 0.78), control: CGPoint(x: w * 0.32, y: h * 0.88))
            body.closeSubpath()
            context.fill(body, with: .color(primary))

            var innerShadow = Path()
            innerShadow.move(to: CGPoint(x: w * 0.50, y: h * 0.22))
            innerShadow.addLine(to: CGPoint(x: w * 0.50, y: h * 0.52))
            innerShadow.move(to: CGPoint(x: w * 0.50, y: h * 0.50))
            innerShadow.addLine(to: CGPoint(x: w * 0.43, y: h * 0.80))
            innerShadow.move(to: CGPoint(x: w * 0.50, y: h * 0.50))
            innerShadow.addLine(to: CGPoint(x: w * 0.57, y: h * 0.80))
            context.stroke(innerShadow, with: .color(Color.black.opacity(0.24)), lineWidth: max(1.05, w * 0.026))

            var waistband = Path()
            waistband.addRoundedRect(
                in: CGRect(x: w * 0.17, y: h * 0.18, width: w * 0.66, height: max(3.2, h * 0.13)),
                cornerSize: CGSize(width: w * 0.045, height: w * 0.045)
            )
            context.fill(waistband, with: .color(accent.opacity(0.92)))

            var hems = Path()
            hems.move(to: CGPoint(x: w * 0.20, y: h * 0.77))
            hems.addQuadCurve(to: CGPoint(x: w * 0.43, y: h * 0.80), control: CGPoint(x: w * 0.31, y: h * 0.84))
            hems.move(to: CGPoint(x: w * 0.57, y: h * 0.80))
            hems.addQuadCurve(to: CGPoint(x: w * 0.80, y: h * 0.77), control: CGPoint(x: w * 0.69, y: h * 0.84))
            context.stroke(hems, with: .color(accent.opacity(0.82)), lineWidth: max(1.25, w * 0.032))

            let shineRect = CGRect(x: w * 0.25, y: h * 0.32, width: w * 0.10, height: h * 0.35)
            var shine = Path()
            shine.addRoundedRect(in: shineRect, cornerSize: CGSize(width: w * 0.05, height: w * 0.05))
            context.fill(shine, with: .color(Color.white.opacity(0.13)))
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
            shadow.addEllipse(in: CGRect(x: w * 0.14, y: h * 0.76, width: w * 0.72, height: h * 0.14))
            context.fill(shadow, with: .color(Color.black.opacity(0.18)))

            // One side-profile sneaker reads cleaner than a tiny pair at tile
            // size; the long toe and heel collar keep it tennis-specific.
            var upper = Path()
            upper.move(to: CGPoint(x: w * 0.16, y: h * 0.62))
            upper.addQuadCurve(to: CGPoint(x: w * 0.30, y: h * 0.43), control: CGPoint(x: w * 0.20, y: h * 0.47))
            upper.addQuadCurve(to: CGPoint(x: w * 0.52, y: h * 0.39), control: CGPoint(x: w * 0.42, y: h * 0.31))
            upper.addQuadCurve(to: CGPoint(x: w * 0.78, y: h * 0.57), control: CGPoint(x: w * 0.72, y: h * 0.38))
            upper.addQuadCurve(to: CGPoint(x: w * 0.84, y: h * 0.66), control: CGPoint(x: w * 0.86, y: h * 0.61))
            upper.addQuadCurve(to: CGPoint(x: w * 0.21, y: h * 0.70), control: CGPoint(x: w * 0.54, y: h * 0.80))
            upper.addQuadCurve(to: CGPoint(x: w * 0.16, y: h * 0.62), control: CGPoint(x: w * 0.10, y: h * 0.69))
            upper.closeSubpath()
            context.fill(upper, with: .color(primary))

            var sole = Path()
            sole.move(to: CGPoint(x: w * 0.15, y: h * 0.72))
            sole.addQuadCurve(to: CGPoint(x: w * 0.84, y: h * 0.69), control: CGPoint(x: w * 0.50, y: h * 0.82))
            context.stroke(sole, with: .color(accent.opacity(0.96)), lineWidth: max(2.0, h * 0.096))

            var toeCap = Path()
            toeCap.move(to: CGPoint(x: w * 0.66, y: h * 0.51))
            toeCap.addQuadCurve(to: CGPoint(x: w * 0.82, y: h * 0.64), control: CGPoint(x: w * 0.83, y: h * 0.55))
            context.stroke(toeCap, with: .color(Color.white.opacity(0.52)), lineWidth: max(1.0, w * 0.022))

            var laceDeck = Path()
            laceDeck.move(to: CGPoint(x: w * 0.35, y: h * 0.47))
            laceDeck.addQuadCurve(to: CGPoint(x: w * 0.57, y: h * 0.47), control: CGPoint(x: w * 0.45, y: h * 0.37))
            laceDeck.addQuadCurve(to: CGPoint(x: w * 0.63, y: h * 0.59), control: CGPoint(x: w * 0.64, y: h * 0.53))
            laceDeck.addQuadCurve(to: CGPoint(x: w * 0.38, y: h * 0.61), control: CGPoint(x: w * 0.49, y: h * 0.67))
            laceDeck.closeSubpath()
            context.fill(laceDeck, with: .color(accent.opacity(0.28)))

            var laces = Path()
            laces.move(to: CGPoint(x: w * 0.38, y: h * 0.50))
            laces.addLine(to: CGPoint(x: w * 0.55, y: h * 0.57))
            laces.move(to: CGPoint(x: w * 0.47, y: h * 0.47))
            laces.addLine(to: CGPoint(x: w * 0.64, y: h * 0.56))
            context.stroke(laces, with: .color(accent.opacity(0.92)), lineWidth: max(0.9, w * 0.020))
        }
    }
}

private enum HomeCraft {
    static let horizontalPadding: CGFloat = 16
    static let verticalRhythm: CGFloat = 18
    static let headerTapTarget: CGFloat = 44
    static let largeRadius: CGFloat = 24
    static let smallRadius: CGFloat = 18
    static let loadoutTileHeight: CGFloat = 52
    static let stageHeightShare: CGFloat = 0.52
    static let stageMinHeight: CGFloat = 300
    static let stageMaxHeight: CGFloat = 390
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
