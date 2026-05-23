import XCTest
@testable import Rally

/// Locks in the timing-window boundaries that the entire game-feel system
/// depends on. If anyone tightens the windows in `Tunables` or
/// `HitQuality`, these tests are the alarm.
final class HitQualityTests: XCTestCase {

    // MARK: - Default windows (scalar = 1.0)

    func testZeroDeltaIsPerfect() {
        XCTAssertEqual(HitQuality.grade(absDelta: 0), .perfect)
    }

    func testJustInsidePerfectIsPerfect() {
        // The half-width window is symmetric: 33 ms is exactly on the edge.
        XCTAssertEqual(HitQuality.grade(absDelta: 0.0329), .perfect)
    }

    func testJustOutsidePerfectIsGreat() {
        XCTAssertEqual(HitQuality.grade(absDelta: 0.034), .great)
    }

    func testJustInsideGreatIsGreat() {
        XCTAssertEqual(HitQuality.grade(absDelta: 0.0659), .great)
    }

    func testJustOutsideGreatIsGood() {
        XCTAssertEqual(HitQuality.grade(absDelta: 0.067), .good)
    }

    func testJustInsideGoodIsGood() {
        XCTAssertEqual(HitQuality.grade(absDelta: 0.0999), .good)
    }

    func testJustOutsideGoodIsMiss() {
        XCTAssertEqual(HitQuality.grade(absDelta: 0.101), .miss)
    }

    func testHugeDeltaIsMiss() {
        XCTAssertEqual(HitQuality.grade(absDelta: 10), .miss)
    }

    // MARK: - Window scalar (session difficulty)

    func testNarrowerScalarTightensWindows() {
        // 0.9× scalar: perfect window = 33 ms × 0.9 = 29.7 ms.
        // A delta of 32 ms is no longer perfect.
        XCTAssertEqual(
            HitQuality.grade(absDelta: 0.032, windowScalar: 0.9),
            .great
        )
    }

    func testWiderScalarLoosensWindows() {
        // 1.2× scalar: perfect window = 33 ms × 1.2 = 39.6 ms.
        // A delta of 38 ms is now perfect.
        XCTAssertEqual(
            HitQuality.grade(absDelta: 0.038, windowScalar: 1.2),
            .perfect
        )
    }

    func testScalarPreservesGradeOrdering() {
        // Whatever the scalar, perfect ⊆ great ⊆ good. This loop walks
        // each scalar and asserts the grade boundaries stay monotonic.
        for scalar in [0.8, 1.0, 1.2] {
            let perfectEdge = HitQuality.perfect.windowSeconds * scalar
            let greatEdge   = HitQuality.great.windowSeconds   * scalar
            let goodEdge    = HitQuality.good.windowSeconds    * scalar

            XCTAssertLessThan(perfectEdge, greatEdge, "perfect must be tighter than great @ scalar=\(scalar)")
            XCTAssertLessThan(greatEdge,   goodEdge,  "great must be tighter than good @ scalar=\(scalar)")
        }
    }

    func testZeroScalarClampsToTenth() {
        // Hostile input: a scalar of 0 would collapse every window to 0
        // and turn every hit into a miss. `grade` clamps the minimum so
        // perfects are still attainable.
        XCTAssertEqual(HitQuality.grade(absDelta: 0, windowScalar: 0), .perfect)
    }

    // MARK: - frameStopSeconds reconciliation
    //
    // The `HitQuality.frameStopSeconds` accessor MUST read from
    // `Tunables.frameStop*Ms` — that's the single source of truth. If the
    // two ever drift, the per-hit feel won't match the spec.

    func testFrameStopReconciledWithTunables() {
        XCTAssertEqual(
            HitQuality.perfect.frameStopSeconds,
            Tunables.frameStopPerfectMs.seconds,
            accuracy: 1e-9
        )
        XCTAssertEqual(
            HitQuality.great.frameStopSeconds,
            Tunables.frameStopGreatMs.seconds,
            accuracy: 1e-9
        )
        XCTAssertEqual(
            HitQuality.good.frameStopSeconds,
            Tunables.frameStopGoodMs.seconds,
            accuracy: 1e-9
        )
        XCTAssertEqual(
            HitQuality.miss.frameStopSeconds,
            Tunables.frameStopMissMs.seconds,
            accuracy: 1e-9
        )
    }

    // MARK: - Combo tier boundaries

    func testComboTierBoundaries() {
        XCTAssertEqual(Tunables.comboTier(forCombo: 0), 0)
        XCTAssertEqual(Tunables.comboTier(forCombo: Tunables.comboTier1 - 1), 0)
        XCTAssertEqual(Tunables.comboTier(forCombo: Tunables.comboTier1), 1)
        XCTAssertEqual(Tunables.comboTier(forCombo: Tunables.comboTier2 - 1), 1)
        XCTAssertEqual(Tunables.comboTier(forCombo: Tunables.comboTier2), 2)
        XCTAssertEqual(Tunables.comboTier(forCombo: Tunables.comboTier3), 3)
        XCTAssertEqual(Tunables.comboTier(forCombo: Tunables.comboTier4), 4)
        XCTAssertEqual(Tunables.comboTier(forCombo: 1_000), 4)
    }

    func testTierJuiceMultiplierIsMonotonic() {
        let mults = (0...4).map { Tunables.tierJuiceMultiplier(tier: $0) }
        for (a, b) in zip(mults, mults.dropFirst()) {
            XCTAssertGreaterThanOrEqual(b, a, "tier juice must be non-decreasing")
        }
        // Tier 0 is the spec baseline.
        XCTAssertEqual(mults[0], 1.0, accuracy: 1e-9)
    }
}
