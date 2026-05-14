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

    private enum MapLook: String, CaseIterable, Identifiable {
        case satellite = "Satellite"
        case hybrid = "Hybrid"
        case map = "Map"
        var id: String { rawValue }
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
                ForEach(IconicCourtsCatalog.allCourts) { court in
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

            VStack(spacing: 8) {
                Picker("Layer", selection: $mapLook) {
                    ForEach(MapLook.allCases) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 16)

                Text("Tennis courts only · \(IconicCourtsCatalog.allCourts.count) iconic pins")
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(.white.opacity(0.55))

                Text("Apple Maps imagery — tap a pin. For Google-style satellite, use “Satellite view” in court details.")
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.35))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
            }
            .padding(.top, 8)
        }
        .navigationTitle("Court atlas")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    focusWorld()
                } label: {
                    Image(systemName: "globe")
                        .foregroundStyle(.cyan)
                }
                .accessibilityLabel("Show whole world")
            }
        }
        .navigationDestination(item: $selectedCourt) { court in
            CourtDetailView(court: court)
        }
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
                            colors: [Color.green.opacity(0.95), Color.green.opacity(0.55)],
                            center: .center,
                            startRadius: 2,
                            endRadius: 22
                        )
                    )
                    .frame(width: 40, height: 40)
                    .overlay(Circle().stroke(Color.white.opacity(0.35), lineWidth: 1))
                Image(systemName: "sportscourt.fill")
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
}
