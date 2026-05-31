import MapKit
import SwiftUI

/// Global map of **curated tennis venues only** — satellite-style layers evoke “Earth” browsing;
/// Google Earth itself isn’t embedded (would require their SDK & keys).
struct CourtsMapView: View {
    @State private var position: MapCameraPosition = .region(
        MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 22, longitude: 15),
            span: MKCoordinateSpan(latitudeDelta: 115, longitudeDelta: 115)
        )
    )
    @State private var mapLook: MapLook = .satellite
    @State private var selectedCourt: IconicTennisCourt?
    @State private var filter: AtlasFilter = .all
    @State private var bestFor: BestForTag? = nil
    @State private var selectedRegion: String? = nil
    @State private var searchText = ""

    private enum MapLook: String, CaseIterable, Identifiable {
        case satellite = "Satellite"
        case hybrid = "Hybrid"
        case map = "Map"
        var id: String { rawValue }
    }

    private enum AtlasFilter: String, CaseIterable, Identifiable {
        case all = "All"
        case venues = "Venues"
        case camps = "Camps"
        var id: String { rawValue }
    }

    private var visibleDestinations: [IconicTennisCourt] {
        let base: [IconicTennisCourt]
        switch filter {
        case .all: base = IconicCourtsCatalog.allCourts
        case .venues: base = IconicCourtsCatalog.iconicVenues
        case .camps: base = IconicCourtsCatalog.trainingCamps
        }

        let filteredByFit: [IconicTennisCourt]
        if let bestFor {
            filteredByFit = base.filter { $0.campProfile?.bestForTag == bestFor }
        } else {
            filteredByFit = base
        }

        let filteredByRegion: [IconicTennisCourt]
        if let selectedRegion {
            filteredByRegion = filteredByFit.filter { $0.region == selectedRegion }
        } else {
            filteredByRegion = filteredByFit
        }

        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return filteredByRegion }
        return filteredByRegion.filter { $0.matchesAtlasSearch(query) }
    }

    private var featuredDestinations: [IconicTennisCourt] {
        Array(visibleDestinations.prefix(3))
    }

    private var bestForOptions: [BestForTag] {
        Array(
            Set(IconicCourtsCatalog.trainingCamps.compactMap { $0.campProfile?.bestForTag })
        ).sorted { $0.rawValue < $1.rawValue }
    }

    private var regionOptions: [String] {
        let preferredOrder = [
            "Europe",
            "North America",
            "Latin America",
            "Asia",
            "Middle East",
            "Africa",
            "Oceania"
        ]
        let available = Set(IconicCourtsCatalog.allCourts.map(\.region))
        return preferredOrder.filter { available.contains($0) }
    }

    private var bestForLabel: String {
        bestFor?.rawValue ?? "Any fit"
    }

    private var bestForSummary: String {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        if let selectedRegion, let bestFor, !query.isEmpty {
            return "\(selectedRegion) · \(bestFor.rawValue.lowercased()) · “\(query)”"
        }
        if let selectedRegion, let bestFor {
            return "\(selectedRegion) · \(bestFor.rawValue.lowercased())."
        }
        if let selectedRegion, !query.isEmpty {
            return "\(selectedRegion) · search results for “\(query)”."
        }
        if let bestFor, !query.isEmpty {
            return "Filtered for \(bestFor.rawValue.lowercased()) and “\(query)”."
        }
        if let bestFor {
            return "Filtered for \(bestFor.rawValue.lowercased())."
        }
        if let selectedRegion {
            return "Browsing \(selectedRegion)."
        }
        if !query.isEmpty {
            return "Search results for “\(query)”."
        }
        return "Showing every venue and camp."
    }

    private var filteredCountLabel: String {
        if filter == .camps {
            return "\(visibleDestinations.count) camp destinations"
        } else if filter == .venues {
            return "\(visibleDestinations.count) iconic venues"
        } else {
            return "\(visibleDestinations.count) world tennis spots"
        }
    }

    private var hasActiveFilters: Bool {
        filter != .all || bestFor != nil || selectedRegion != nil || !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var activeFilterHighlights: [(String, Color)] {
        var highlights: [(String, Color)] = []
        if filter != .all {
            highlights.append((filter.rawValue, RallyUIKit.Palette.cyan))
        }
        if let selectedRegion {
            highlights.append((selectedRegion, RallyUIKit.Palette.lime))
        }
        if let bestFor {
            highlights.append((bestFor.rawValue, RallyUIKit.Palette.gold))
        }
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !query.isEmpty {
            highlights.append(("“\(query)”", RallyUIKit.Palette.rose))
        }
        return highlights
    }

    private var availabilityHighlights: [(String, String, Color)] {
        let siteCount = visibleDestinations.filter { $0.venueWebsiteURL != nil }.count
        let bookingCount = visibleDestinations.filter { $0.bookingOrMembershipURL != nil }.count
        let programCount = visibleDestinations.filter { $0.officialProgramURL != nil }.count

        var highlights: [(String, String, Color)] = [
            ("Site", "\(siteCount)", RallyUIKit.Palette.cyan),
            (filter == .venues ? "Booking" : "Ready now", "\(bookingCount)", RallyUIKit.Palette.rose)
        ]

        if programCount > 0 {
            highlights.append(("Program", "\(programCount)", RallyUIKit.Palette.gold))
        }

        return highlights
    }

    private var mapStyle: MapStyle {
        switch mapLook {
        case .satellite: return .imagery
        case .hybrid: return .hybrid
        case .map: return .standard
        }
    }

    var body: some View {
        let destinations = visibleDestinations

        Map(position: $position) {
            ForEach(destinations) { court in
                Annotation(court.name, coordinate: court.coordinate) {
                    Button {
                        selectedCourt = court
                    } label: {
                        courtMarker(court)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .mapStyle(mapStyle)
        .mapControls {
            MapPitchToggle()
            MapCompass()
        }
        .safeAreaInset(edge: .top) {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 10) {
                    RallyUIKit.SectionCard(stroke: RallyUIKit.Palette.cyan.opacity(0.22)) {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack(alignment: .center, spacing: 12) {
                                RallyUIKit.IconBadge(
                                    systemName: "magnifyingglass",
                                    tint: RallyUIKit.Palette.lime,
                                    size: 30
                                )

                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Explore the tennis world")
                                        .font(.system(.subheadline, design: .rounded).weight(.bold))
                                        .foregroundStyle(.white)
                                    Text("Search places, then narrow by destination type and camp fit.")
                                        .font(.caption)
                                        .foregroundStyle(.white.opacity(0.58))
                                }
                            }

                            TextField("Search name, city, country, or region", text: $searchText)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                                .rallyTextFieldStyle()
                        }
                    }
                    .padding(.horizontal, 16)

                    filterStrip(
                        title: "Destination type",
                        icon: "line.3.horizontal.decrease.circle.fill",
                        tint: RallyUIKit.Palette.cyan
                    ) {
                        ScrollView(.horizontal, showsIndicators: false) {
                            LazyHStack(spacing: 10) {
                                ForEach(AtlasFilter.allCases) { mode in
                                    atlasModeChip(mode)
                                }
                            }
                            .padding(.horizontal, 2)
                        }
                        .scrollClipDisabled()
                    }

                    filterStrip(
                        title: "Map layer",
                        icon: "square.2.layers.3d.fill",
                        tint: RallyUIKit.Palette.rose
                    ) {
                        ScrollView(.horizontal, showsIndicators: false) {
                            LazyHStack(spacing: 10) {
                                ForEach(MapLook.allCases) { mode in
                                    mapLookChip(mode)
                                }
                            }
                            .padding(.horizontal, 2)
                        }
                        .scrollClipDisabled()
                    }

                    filterStrip(
                        title: "Region",
                        icon: "globe.central.south.asia.fill",
                        tint: RallyUIKit.Palette.lime
                    ) {
                        ScrollView(.horizontal, showsIndicators: false) {
                            LazyHStack(spacing: 10) {
                                regionChip(nil, label: "World")
                                ForEach(regionOptions, id: \.self) { region in
                                    regionChip(region, label: region)
                                }
                            }
                            .padding(.horizontal, 2)
                        }
                        .scrollClipDisabled()
                    }

                    filterStrip(
                        title: "Best for",
                        icon: "sparkles",
                        tint: RallyUIKit.Palette.gold
                    ) {
                        ScrollView(.horizontal, showsIndicators: false) {
                            LazyHStack(spacing: 10) {
                                bestForChip(nil, label: "Any fit")
                                ForEach(bestForOptions) { option in
                                    bestForChip(option, label: option.rawValue)
                                }
                            }
                            .padding(.horizontal, 2)
                        }
                        .scrollClipDisabled()
                    }

                    RallyUIKit.SectionCard(stroke: RallyUIKit.Palette.mist) {
                        VStack(alignment: .leading, spacing: 10) {
                            VStack(alignment: .leading, spacing: 6) {
                                Text(filteredCountLabel.uppercased())
                                    .font(.system(.caption2, design: .rounded).weight(.bold))
                                    .tracking(1.2)
                                    .foregroundStyle(.white.opacity(0.5))
                                Text(bestForSummary)
                                    .font(.system(.subheadline, design: .rounded).weight(.semibold))
                                    .foregroundStyle(.white)
                                Text("Apple Maps imagery — tap a pin for official venue, camp, sponsor-host, and enrollment links.")
                                    .font(.caption)
                                    .foregroundStyle(.white.opacity(0.42))
                            }

                            if !activeFilterHighlights.isEmpty {
                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 8) {
                                        ForEach(Array(activeFilterHighlights.enumerated()), id: \.offset) { _, item in
                                            atlasFactTag(item.0, tint: item.1)
                                        }
                                    }
                                    .padding(.horizontal, 1)
                                }
                                .scrollClipDisabled()
                            }

                            HStack(spacing: 8) {
                                ForEach(Array(availabilityHighlights.enumerated()), id: \.offset) { _, item in
                                    atlasCountTag(title: item.0, value: item.1, tint: item.2)
                                }
                            }

                            if hasActiveFilters {
                                HStack(spacing: 10) {
                                    Button {
                                        clearFilters()
                                    } label: {
                                        Label("Reset atlas", systemImage: "arrow.counterclockwise")
                                    }
                                    .buttonStyle(SecondaryButtonStyle(tint: RallyUIKit.Palette.cyan))
                                    .frame(maxWidth: .infinity)

                                    if !destinations.isEmpty {
                                        Button {
                                            focus(on: destinations)
                                        } label: {
                                            Label("Focus results", systemImage: "scope")
                                        }
                                        .buttonStyle(GhostButtonStyle())
                                        .frame(maxWidth: .infinity)
                                    }
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 16)

                    if !destinations.isEmpty {
                        filterStrip(
                            title: "Featured now",
                            icon: "sparkles.rectangle.stack.fill",
                            tint: RallyUIKit.Palette.champagne
                        ) {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 12) {
                                    ForEach(featuredDestinations) { court in
                                        featuredDestinationCard(court)
                                    }
                                }
                                .padding(.horizontal, 2)
                            }
                            .scrollClipDisabled()
                        }

                        filterStrip(
                            title: "Visible now",
                            icon: "rectangle.grid.1x2.fill",
                            tint: RallyUIKit.Palette.lime
                        ) {
                            ScrollView {
                                LazyVStack(spacing: 10) {
                                    ForEach(destinations.prefix(6)) { court in
                                        destinationRow(court)
                                    }
                                }
                            }
                            .frame(maxHeight: 260)
                        }
                    } else {
                        RallyUIKit.SectionCard(stroke: RallyUIKit.Palette.rose.opacity(0.18)) {
                            VStack(alignment: .leading, spacing: 10) {
                                HStack(spacing: 8) {
                                    RallyUIKit.IconBadge(systemName: "eye.slash.fill", tint: RallyUIKit.Palette.rose, size: 24)
                                    Text("No visible destinations")
                                        .font(.system(.caption, design: .rounded).weight(.bold))
                                        .tracking(1)
                                        .foregroundStyle(.white.opacity(0.62))
                                }
                                Text("Try widening the region, clearing the search, or switching destination type.")
                                    .font(.system(.subheadline, design: .rounded).weight(.semibold))
                                    .foregroundStyle(.white)
                                VStack(spacing: 10) {
                                    if hasActiveFilters {
                                        ScrollView(.horizontal, showsIndicators: false) {
                                            HStack(spacing: 8) {
                                                ForEach(Array(activeFilterHighlights.enumerated()), id: \.offset) { _, item in
                                                    atlasFactTag(item.0, tint: item.1)
                                                }
                                            }
                                            .padding(.horizontal, 1)
                                        }
                                        .scrollClipDisabled()
                                    }

                                    Button {
                                        clearFilters()
                                        focusWorld()
                                    } label: {
                                        Label("Show the full atlas", systemImage: "globe")
                                    }
                                    .buttonStyle(SecondaryButtonStyle(tint: RallyUIKit.Palette.rose))
                                }
                            }
                        }
                        .padding(.horizontal, 16)
                    }
                }
                .padding(.top, 8)
                .padding(.bottom, 8)
                .scrollClipDisabled()
            }
        }
        .allowsHitTesting(true)
        .navigationTitle("World tennis atlas")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    focusWorld()
                } label: {
                    RallyUIKit.IconBadge(systemName: "globe", tint: RallyUIKit.Palette.cyan, size: 34)
                }
                .accessibilityLabel("Show whole world")
            }
        }
        .navigationDestination(item: $selectedCourt) { court in
            CourtDetailView(court: court)
        }
    }

    private func filterStrip<Content: View>(title: String, icon: String, tint: Color, @ViewBuilder content: () -> Content) -> some View {
        RallyUIKit.SectionCard(stroke: tint.opacity(0.22)) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    RallyUIKit.IconBadge(systemName: icon, tint: tint, size: 24)
                    Text(title)
                        .font(.system(.caption, design: .rounded).weight(.bold))
                        .tracking(1)
                        .foregroundStyle(.white.opacity(0.62))
                }
                content()
            }
        }
        .padding(.horizontal, 16)
    }

    private func atlasChip(
        label: String,
        systemName: String,
        isSelected: Bool,
        tint: Color
    ) -> some View {
        HStack(spacing: 8) {
            Image(systemName: systemName)
                .font(.system(size: 12, weight: .bold))
            Text(label)
                .font(.system(.caption, design: .rounded).weight(.semibold))
                .lineLimit(1)
        }
        .foregroundStyle(isSelected ? Color.black : Color.white.opacity(0.9))
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
        .frame(minHeight: 42)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(isSelected ? AnyShapeStyle(RallyUIKit.accentGradient(tint)) : AnyShapeStyle(Color.white.opacity(0.06)))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(
                    isSelected ? Color.white.opacity(0.28) : Color.white.opacity(0.10),
                    lineWidth: isSelected ? 1.15 : 1
                )
        )
        .shadow(color: isSelected ? tint.opacity(0.22) : .clear, radius: 12, x: 0, y: 6)
        .contentShape(RoundedRectangle(cornerRadius: 16))
    }

    private func atlasModeChip(_ mode: AtlasFilter) -> some View {
        let isSelected = filter == mode
        let icon: String
        switch mode {
        case .all: icon = "globe.americas.fill"
        case .venues: icon = "sportscourt.fill"
        case .camps: icon = "figure.tennis"
        }

        return Button {
            filter = mode
        } label: {
            atlasChip(
                label: mode.rawValue,
                systemName: icon,
                isSelected: isSelected,
                tint: RallyUIKit.Palette.cyan
            )
        }
        .buttonStyle(.plain)
    }

    private func mapLookChip(_ mode: MapLook) -> some View {
        let isSelected = mapLook == mode
        let icon: String
        switch mode {
        case .satellite: icon = "globe.europe.africa.fill"
        case .hybrid: icon = "square.2.layers.3d.top.filled"
        case .map: icon = "map.fill"
        }

        return Button {
            mapLook = mode
        } label: {
            atlasChip(
                label: mode.rawValue,
                systemName: icon,
                isSelected: isSelected,
                tint: RallyUIKit.Palette.rose
            )
        }
        .buttonStyle(.plain)
    }

    private func bestForChip(_ tag: BestForTag?, label: String) -> some View {
        let isSelected = bestFor == tag
        return Button {
            bestFor = tag
            if tag != nil && filter == .venues {
                filter = .camps
            }
        } label: {
            atlasChip(
                label: label,
                systemName: bestForIcon(tag),
                isSelected: isSelected,
                tint: RallyUIKit.Palette.gold
            )
        }
        .buttonStyle(.plain)
    }

    private func regionChip(_ region: String?, label: String) -> some View {
        let isSelected = selectedRegion == region
        return Button {
            selectedRegion = region
            if let region {
                focus(region: region)
            } else {
                focusWorld()
            }
        } label: {
            atlasChip(
                label: label,
                systemName: regionIcon(region),
                isSelected: isSelected,
                tint: RallyUIKit.Palette.lime
            )
        }
        .buttonStyle(.plain)
    }

    private func regionIcon(_ region: String?) -> String {
        switch region {
        case nil: return "globe.americas.fill"
        case "Europe": return "building.columns.fill"
        case "North America": return "map.fill"
        case "Latin America": return "sun.max.fill"
        case "Asia": return "sparkles"
        case "Middle East": return "moon.stars.fill"
        case "Africa": return "leaf.fill"
        case "Oceania": return "water.waves"
        default: return "globe.europe.africa.fill"
        }
    }

    private func bestForIcon(_ tag: BestForTag?) -> String {
        switch tag {
        case .none: return "circle.grid.2x1.fill"
        case .allAround: return "figure.tennis"
        case .juniors: return "figure.2.and.child.holdinghands"
        case .intensive: return "bolt.fill"
        case .travel: return "airplane"
        case .flexible: return "calendar.badge.clock"
        case .surfaces: return "square.grid.3x3.middle.filled"
        }
    }

    private func destinationRow(_ court: IconicTennisCourt) -> some View {
        Button {
            selectedCourt = court
            withAnimation(.easeInOut(duration: 0.35)) {
                position = .region(
                    MKCoordinateRegion(
                        center: court.coordinate,
                        span: MKCoordinateSpan(latitudeDelta: 2.8, longitudeDelta: 2.8)
                    )
                )
            }
        } label: {
            HStack(alignment: .top, spacing: 14) {
                RallyUIKit.IconBadge(
                    systemName: court.kind == .venue ? "sportscourt.fill" : "figure.tennis",
                    tint: court.kind == .venue ? RallyUIKit.Palette.cyan : RallyUIKit.Palette.gold,
                    size: 42
                )

                VStack(alignment: .leading, spacing: 8) {
                    HStack(alignment: .top, spacing: 8) {
                        VStack(alignment: .leading, spacing: 5) {
                            Text(court.name)
                                .font(RallyUIKit.Typography.body(.subheadline, weight: .bold))
                                .foregroundStyle(RallyUIKit.Palette.frost)
                                .lineLimit(1)

                            Text("\(court.subtitle) · \(court.region)")
                                .font(RallyUIKit.Typography.body(.caption, weight: .medium))
                                .foregroundStyle(RallyUIKit.Palette.cloud.opacity(0.58))
                                .lineLimit(1)
                        }

                        Spacer(minLength: 0)

                        Text(court.kind.rawValue.uppercased())
                            .font(.system(.caption2, design: .rounded).weight(.bold))
                            .tracking(0.9)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 5)
                            .background(
                                Capsule().fill((court.kind == .venue ? RallyUIKit.Palette.cyan : RallyUIKit.Palette.gold).opacity(0.16))
                            )
                            .foregroundStyle(court.kind == .venue ? RallyUIKit.Palette.cyan : RallyUIKit.Palette.gold)
                    }

                    if let profile = court.campProfile {
                        HStack(spacing: 8) {
                            atlasFactTag(profile.bestForTag.rawValue, tint: RallyUIKit.Palette.gold)
                            atlasFactTag(profile.audience, tint: RallyUIKit.Palette.cyan)
                            atlasFactTag("Official links", tint: RallyUIKit.Palette.rose)
                        }
                    } else {
                        HStack(spacing: 8) {
                            atlasFactTag(court.vibe, tint: RallyUIKit.Palette.cyan)
                            atlasFactTag("Official links", tint: RallyUIKit.Palette.rose)
                        }
                    }

                    HStack(spacing: 8) {
                        actionStatusTag("Site", available: court.venueWebsiteURL != nil, tint: RallyUIKit.Palette.cyan)
                        actionStatusTag(court.kind == .venue ? "Booking" : "Enrollment", available: court.bookingOrMembershipURL != nil, tint: RallyUIKit.Palette.rose)
                        if court.officialProgramURL != nil {
                            actionStatusTag("Program", available: true, tint: RallyUIKit.Palette.gold)
                        }
                    }
                }
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 18)
                    .fill(Color.white.opacity(0.055))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18)
                    .stroke(Color.white.opacity(0.08), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.16), radius: 10, x: 0, y: 5)
        }
        .buttonStyle(.plain)
    }

    private func featuredDestinationCard(_ court: IconicTennisCourt) -> some View {
        let tint = court.kind == .venue ? RallyUIKit.Palette.cyan : RallyUIKit.Palette.gold

        return Button {
            selectedCourt = court
            focus(on: [court])
        } label: {
            VStack(alignment: .leading, spacing: 12) {
                ZStack(alignment: .topTrailing) {
                    RoundedRectangle(cornerRadius: 22)
                        .fill(
                            LinearGradient(
                                colors: [
                                    RallyUIKit.Palette.obsidian,
                                    tint.opacity(0.22),
                                    Color.white.opacity(0.04)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(height: 158)

                    Circle()
                        .fill(tint.opacity(0.2))
                        .frame(width: 110, height: 110)
                        .blur(radius: 18)
                        .offset(x: 18, y: -18)

                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text(court.kind.rawValue.uppercased())
                                .font(RallyUIKit.Typography.label(.caption2, weight: .bold))
                                .tracking(1.2)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 5)
                                .background(Capsule().fill(tint.opacity(0.14)))
                                .foregroundStyle(tint)
                            Spacer()
                            RallyUIKit.IconBadge(
                                systemName: court.kind == .venue ? "sportscourt.fill" : "figure.tennis",
                                tint: tint,
                                size: 28
                            )
                        }

                        Spacer(minLength: 0)

                        VStack(alignment: .leading, spacing: 6) {
                            Text(court.name)
                                .font(RallyUIKit.Typography.title(.headline, weight: .bold))
                                .foregroundStyle(RallyUIKit.Palette.frost)
                                .lineLimit(2)
                            Text("\(court.subtitle) · \(court.region)")
                                .font(RallyUIKit.Typography.body(.caption, weight: .semibold))
                                .foregroundStyle(RallyUIKit.Palette.cloud.opacity(0.7))
                                .lineLimit(1)
                        }
                    }
                    .padding(16)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text(court.vibe)
                        .font(RallyUIKit.Typography.body(.subheadline, weight: .semibold))
                        .foregroundStyle(RallyUIKit.Palette.frost)
                        .lineLimit(2)

                    HStack(spacing: 8) {
                        if let profile = court.campProfile {
                            atlasFactTag(profile.bestForTag.rawValue, tint: RallyUIKit.Palette.gold)
                            atlasFactTag(profile.audience, tint: RallyUIKit.Palette.cyan)
                        } else {
                            atlasFactTag("Iconic venue", tint: RallyUIKit.Palette.cyan)
                        }
                        atlasFactTag("Official links", tint: RallyUIKit.Palette.rose)
                    }

                    if let sponsorHostName = court.sponsorHostName {
                        HStack(spacing: 6) {
                            Image(systemName: "checkmark.seal.fill")
                                .font(.system(size: 12, weight: .bold))
                            Text("Official host: \(sponsorHostName)")
                                .font(RallyUIKit.Typography.body(.caption2, weight: .semibold))
                                .lineLimit(1)
                        }
                        .foregroundStyle(RallyUIKit.Palette.cloud.opacity(0.76))
                    } else if court.bookingOrMembershipURL != nil {
                        HStack(spacing: 6) {
                            Image(systemName: "checkmark.seal.fill")
                                .font(.system(size: 12, weight: .bold))
                            Text(court.kind == .venue ? "Official booking available" : "Official enrollment available")
                                .font(RallyUIKit.Typography.body(.caption2, weight: .semibold))
                                .lineLimit(1)
                        }
                        .foregroundStyle(RallyUIKit.Palette.cloud.opacity(0.76))
                    }

                    HStack(spacing: 6) {
                        Text(court.kind == .venue ? "Open official destination" : "Open official camp")
                            .font(RallyUIKit.Typography.label(.caption, weight: .bold))
                        Spacer(minLength: 0)
                        Image(systemName: "arrow.right.circle.fill")
                            .font(.system(size: 14, weight: .bold))
                    }
                    .foregroundStyle(tint)
                }
            }
            .padding(14)
            .frame(width: 278, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 24)
                    .fill(Color.white.opacity(0.055))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 24)
                    .stroke(tint.opacity(0.18), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.16), radius: 12, x: 0, y: 6)
        }
        .buttonStyle(.plain)
    }

    private func atlasFactTag(_ text: String, tint: Color) -> some View {
        Text(text)
            .font(RallyUIKit.Typography.body(.caption2, weight: .semibold))
            .foregroundStyle(RallyUIKit.Palette.frost.opacity(0.86))
            .lineLimit(1)
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(
                Capsule().fill(tint.opacity(0.11))
            )
            .overlay(
                Capsule().stroke(tint.opacity(0.18), lineWidth: 1)
            )
    }

    private func atlasCountTag(title: String, value: String, tint: Color) -> some View {
        HStack(spacing: 6) {
            Text(title)
                .font(RallyUIKit.Typography.label(.caption2, weight: .semibold))
            Text(value)
                .font(RallyUIKit.Typography.label(.caption, weight: .bold))
        }
        .foregroundStyle(tint)
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(
            Capsule().fill(tint.opacity(0.12))
        )
        .overlay(
            Capsule().stroke(tint.opacity(0.18), lineWidth: 1)
        )
    }

    private func actionStatusTag(_ label: String, available: Bool, tint: Color) -> some View {
        HStack(spacing: 5) {
            Image(systemName: available ? "checkmark.circle.fill" : "minus.circle")
                .font(.system(size: 10, weight: .bold))
            Text(label)
                .font(RallyUIKit.Typography.label(.caption2, weight: .bold))
        }
        .foregroundStyle(available ? tint : RallyUIKit.Palette.cloud.opacity(0.42))
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(
            Capsule().fill((available ? tint : RallyUIKit.Palette.cloud).opacity(available ? 0.11 : 0.08))
        )
        .overlay(
            Capsule().stroke((available ? tint : RallyUIKit.Palette.cloud).opacity(available ? 0.18 : 0.1), lineWidth: 1)
        )
    }

    private func focusWorld() {
        withAnimation(.easeInOut(duration: 0.45)) {
            position = .region(
                MKCoordinateRegion(
                    center: CLLocationCoordinate2D(latitude: 22, longitude: 15),
                    span: MKCoordinateSpan(latitudeDelta: 115, longitudeDelta: 115)
                )
            )
        }
    }

    private func clearFilters() {
        filter = .all
        bestFor = nil
        selectedRegion = nil
        searchText = ""
    }

    private func focus(region: String) {
        let courts = visibleDestinations.filter { $0.region == region }
        focus(on: courts)
    }

    private func focus(on courts: [IconicTennisCourt]) {
        guard !courts.isEmpty else { return }
        let lats = courts.map(\.latitude)
        let lons = courts.map(\.longitude)
        guard let minLat = lats.min(),
              let maxLat = lats.max(),
              let minLon = lons.min(),
              let maxLon = lons.max() else { return }

        let center = CLLocationCoordinate2D(
            latitude: (minLat + maxLat) / 2,
            longitude: (minLon + maxLon) / 2
        )
        let span = MKCoordinateSpan(
            latitudeDelta: max(6, (maxLat - minLat) * 1.75),
            longitudeDelta: max(6, (maxLon - minLon) * 1.75)
        )

        withAnimation(.easeInOut(duration: 0.42)) {
            position = .region(MKCoordinateRegion(center: center, span: span))
        }
    }

    @ViewBuilder
    private func courtMarker(_ court: IconicTennisCourt) -> some View {
        VStack(spacing: 2) {
            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                court.kind == .venue ? Color.green.opacity(0.95) : RallyUIKit.Palette.gold.opacity(0.95),
                                court.kind == .venue ? Color.green.opacity(0.55) : RallyUIKit.Palette.rose.opacity(0.55)
                            ],
                            center: .center,
                            startRadius: 2,
                            endRadius: 22
                        )
                    )
                    .frame(width: 40, height: 40)
                    .overlay(Circle().stroke(Color.white.opacity(0.35), lineWidth: 1))
                Image(systemName: court.kind == .venue ? "sportscourt.fill" : "figure.tennis")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(.white)
            }
            .shadow(color: .black.opacity(0.35), radius: 4, x: 0, y: 2)

            Text(court.shortLabel)
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(.white)
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(Capsule().fill(Color.black.opacity(0.55)))
        }
    }
}

private extension IconicTennisCourt {
    /// Abbreviated marker label under the pin.
    var shortLabel: String {
        if let first = name.split(separator: "·").first {
            return String(first).trimmingCharacters(in: .whitespaces)
        }
        return name
    }

    func matchesAtlasSearch(_ query: String) -> Bool {
        let needle = query.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
        let haystacks = [
            name,
            subtitle,
            region,
            campProfile?.bestFor ?? "",
            campProfile?.audience ?? ""
        ].map { $0.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current) }

        return haystacks.contains { $0.contains(needle) }
    }
}
