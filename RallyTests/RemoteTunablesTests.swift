import XCTest
@testable import Rally

final class RemoteTunablesTests: XCTestCase {

    func testManifestDecodesPartialJSON() throws {
        let json = #"{ "bpmBreaker": 175 }"#.data(using: .utf8)!
        let manifest = try JSONDecoder().decode(RemoteTunablesManifest.self, from: json)
        XCTAssertEqual(manifest.bpmBreaker, 175)
        XCTAssertNil(manifest.bpmWarmUp)
        XCTAssertNil(manifest.recoverySeconds)
    }

    func testManifestDecodesEmptyObject() throws {
        let json = "{}".data(using: .utf8)!
        let manifest = try JSONDecoder().decode(RemoteTunablesManifest.self, from: json)
        XCTAssertEqual(manifest, .empty)
    }

    @MainActor
    func testFallsBackToBundledTunablesWhenManifestEmpty() {
        let r = RemoteTunables()
        // Default manifest is .empty — every lookup should return the
        // bundled `Tunables` value.
        XCTAssertEqual(r.bpm(for: .warmUp),   Tunables.MatchFlow.bpmWarmUp)
        XCTAssertEqual(r.bpm(for: .exchange), Tunables.MatchFlow.bpmExchange)
        XCTAssertEqual(r.bpm(for: .pressure), Tunables.MatchFlow.bpmPressure)
        XCTAssertEqual(r.bpm(for: .breaker),  Tunables.MatchFlow.bpmBreaker)
        XCTAssertEqual(r.recoverySeconds(),   Tunables.MatchFlow.recoverySeconds)
    }

    func testMatchFlowUsesInjectedBPMResolver() {
        let c = MatchFlowCoordinator(sessionDurationSeconds: 180) { phase in
            switch phase {
            case .breaker: return 999
            default:       return 100
            }
        }
        XCTAssertEqual(c.profile(for: .breaker).bpm, 999)
        XCTAssertEqual(c.profile(for: .warmUp).bpm, 100)
    }
}
