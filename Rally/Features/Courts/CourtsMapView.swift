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

        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return filteredByFit }
        return filteredByFit.filter { $0.matchesAtlasSearch(query) }
    }

    private var bestForOptions: [BestForTag] {
        Array(
            Set(IconicCourtsCatalog.trainingCamps.compactMap { $0.campProfile?.bestForTag })
        ).sorted { $0.rawValue < $1.rawValue }
    }

    private var bestForLabel: String {
        bestFor?.rawValue ?? "Any fit"
    }

    private var bestForSummary: String {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        if let bestFor, !query.isEmpty {
            return "Filtered for \(bestFor.rawValue.lowercased()) and “\(query)”."
        }
        if let bestFor {
            return "Filtered for \(bestFor.rawValue.lowercased())."
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

    private var mapStyle: MapStyle {
        switch mapLook {
        case .satellite: return .imagery
        case .hybrid: return .hybrid
        case .map: return .standard
        }
    }

    var body: some View {
        ZStack(alignment: .top) {
            Map(position: $position) {
                ForEach(visibleDestinations) { court in
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
                    HStack(spacing: 8) {
                        ForEach(AtlasFilter.allCases) { mode in
                            atlasModeChip(mode)
                        }
                    }
                }

                filterStrip(
                    title: "Map layer",
                    icon: "square.2.layers.3d.fill",
                    tint: RallyUIKit.Palette.rose
                ) {
                    HStack(spacing: 8) {
                        ForEach(MapLook.allCases) { mode in
                            mapLookChip(mode)
                        }
                    }
                }

                filterStrip(
                    title: "Best for",
                    icon: "sparkles",
                    tint: RallyUIKit.Palette.gold
                ) {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            bestForChip(nil, label: "Any fit")
                            ForEach(bestForOptions) { option in
                                bestForChip(option, label: option.rawValue)
                            }
                        }
                    }
                }

                RallyUIKit.SectionCard(stroke: RallyUIKit.Palette.mist) {
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
                }
                .padding(.horizontal, 16)

                if !visibleDestinations.isEmpty {
                    filterStrip(
                        title: "Visible now",
                        icon: "rectangle.grid.1x2.fill",
                        tint: RallyUIKit.Palette.lime
                    ) {
                        ScrollView {
                            LazyVStack(spacing: 10) {
                                ForEach(visibleDestinations.prefix(6)) { court in
                                    destinationRow(court)
                                }
                            }
                        }
                        .frame(maxHeight: 260)
                    }
                }
            }
            .padding(.top, 8)
        }
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
            HStack(spacing: 7) {
                Image(systemName: icon)
                    .font(.caption.weight(.bold))
                Text(mode.rawValue)
                    .font(.system(.caption, design: .rounded).weight(.semibold))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(isSelected ? AnyShapeStyle(RallyUIKit.accentGradient(RallyUIKit.Palette.cyan)) : AnyShapeStyle(Color.white.opacity(0.06)))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(isSelected ? Color.white.opacity(0.18) : Color.white.opacity(0.12), lineWidth: 1)
            )
            .foregroundStyle(isSelected ? Color.black : Color.white.opacity(0.88))
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
            HStack(spacing: 7) {
                Image(systemName: icon)
                    .font(.caption.weight(.bold))
                Text(mode.rawValue)
                    .font(.system(.caption, design: .rounded).weight(.semibold))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(isSelected ? AnyShapeStyle(RallyUIKit.accentGradient(RallyUIKit.Palette.rose)) : AnyShapeStyle(Color.white.opacity(0.06)))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(isSelected ? Color.white.opacity(0.18) : Color.white.opacity(0.12), lineWidth: 1)
            )
            .foregroundStyle(isSelected ? Color.black : Color.white.opacity(0.88))
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
            HStack(spacing: 7) {
                Image(systemName: bestForIcon(tag))
                    .font(.caption.weight(.bold))
                Text(label)
                    .font(.system(.caption, design: .rounded).weight(.semibold))
            }
                .padding(.horizontal, 12)
                .padding(.vertical, 9)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(isSelected ? AnyShapeStyle(RallyUIKit.accentGradient(RallyUIKit.Palette.gold)) : AnyShapeStyle(Color.white.opacity(0.08)))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(isSelected ? Color.white.opacity(0.18) : Color.white.opacity(0.12), lineWidth: 1)
                )
                .foregroundStyle(isSelected ? Color.black : Color.white.opacity(0.88))
        }
        .buttonStyle(.plain)
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
            HStack(spacing: 12) {
                RallyUIKit.IconBadge(
                    systemName: court.kind == .venue ? "sportscourt.fill" : "figure.tennis",
                    tint: court.kind == .venue ? RallyUIKit.Palette.cyan : RallyUIKit.Palette.gold,
                    size: 40
                )

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text(court.name)
                            .font(.system(.subheadline, design: .rounded).weight(.bold))
                            .foregroundStyle(.white)
                            .lineLimit(1)

                        Text(court.kind.rawValue.uppercased())
                            .font(.system(.caption2, design: .rounded).weight(.bold))
                            .tracking(0.8)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 4)
                            .background(
                                Capsule().fill((court.kind == .venue ? RallyUIKit.Palette.cyan : RallyUIKit.Palette.gold).opacity(0.16))
                            )
                            .foregroundStyle(court.kind == .venue ? RallyUIKit.Palette.cyan : RallyUIKit.Palette.gold)
                    }

                    Text("\(court.subtitle) · \(court.region)")
                        .font(.system(.caption, design: .rounded).weight(.medium))
                        .foregroundStyle(.white.opacity(0.56))
                        .lineLimit(1)

                    if let bestFor = court.campProfile?.bestFor {
                        Text(bestFor)
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.72))
                            .lineLimit(1)
                    } else {
                        Text(court.vibe)
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.72))
                            .lineLimit(1)
                    }
                }

                Spacer(minLength: 0)

                Image(systemName: "arrow.up.left.and.arrow.down.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.white.opacity(0.32))
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.white.opacity(0.05))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.white.opacity(0.08), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
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
