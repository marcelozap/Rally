import CoreLocation
import Foundation

/// One-shot proximity verifier used by the "I'm here" CTA on
/// `CourtDetailView`.
///
/// ## Behavior
///
/// - Requests `.whenInUse` authorization (never `.always`).
/// - Calls `requestLocation()` for a *single* fix, then stops the manager —
///   no background location tracking, no continuous updates.
/// - Compares the fix to the court's `CLLocationCoordinate2D` and considers
///   the player "present" if horizontal accuracy is acceptable AND the
///   distance to the pin is under `proximityRadiusMeters`.
///
/// ## Privacy
///
/// The caller is responsible for showing the human-readable rationale
/// before invoking `verify(...)`. The class itself only consumes the CoreLocation
/// result; it never persists coordinates or accuracy.
final class CourtCheckIn: NSObject, CLLocationManagerDelegate {

    enum Outcome {
        case unlocked
        case tooFar(distanceMeters: Double)
        case lowAccuracy(horizontalAccuracyMeters: Double)
        case denied
        case unavailable
    }

    /// Maximum allowed horizontal accuracy (in meters) for a check-in to
    /// count. iPhone GPS routinely reports <30m; we accept anything up to
    /// 100m so indoor or shaded scenarios aren't impossible.
    var maxHorizontalAccuracyMeters: Double = 100

    /// Distance threshold from the court pin within which we consider the
    /// player physically present. Tuned for iconic-venue grounds where
    /// stadium footprints often span 200-400m.
    var proximityRadiusMeters: Double = 350

    private let manager = CLLocationManager()
    private var target: CLLocationCoordinate2D?
    private var completion: ((Outcome) -> Void)?

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
    }

    /// Kick off a single fix and decide unlock outcome against `pin`.
    /// The completion fires once and only once.
    func verify(against pin: CLLocationCoordinate2D, completion: @escaping (Outcome) -> Void) {
        guard CLLocationManager.locationServicesEnabled() else {
            completion(.unavailable)
            return
        }
        self.target = pin
        self.completion = completion

        switch manager.authorizationStatus {
        case .notDetermined:
            manager.requestWhenInUseAuthorization()
        case .restricted, .denied:
            deliver(.denied)
        case .authorizedAlways, .authorizedWhenInUse:
            manager.requestLocation()
        @unknown default:
            deliver(.unavailable)
        }
    }

    // MARK: - CLLocationManagerDelegate

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        switch manager.authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            manager.requestLocation()
        case .denied, .restricted:
            deliver(.denied)
        default:
            break
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let target = target, let fix = locations.last else { return }
        let acc = fix.horizontalAccuracy
        if acc < 0 || acc > maxHorizontalAccuracyMeters {
            deliver(.lowAccuracy(horizontalAccuracyMeters: acc))
            return
        }
        let pinLoc = CLLocation(latitude: target.latitude, longitude: target.longitude)
        let d = fix.distance(from: pinLoc)
        if d <= proximityRadiusMeters {
            deliver(.unlocked)
        } else {
            deliver(.tooFar(distanceMeters: d))
        }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        deliver(.unavailable)
    }

    // MARK: -

    private func deliver(_ outcome: Outcome) {
        let cb = completion
        completion = nil
        target = nil
        cb?(outcome)
    }
}
