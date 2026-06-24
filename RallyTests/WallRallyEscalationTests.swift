import XCTest
@testable import Rally

/// Locks in the wall-rally speed ramp and its mirrored timing taper —
/// `Tunables.wallSpeedTier`, `wallSpeedScalar`, and `wallTimingScalar`.
/// These are pure, so they run without spinning up a SpriteKit scene.
///
/// Verified 2026-06-16 with:
/// `xcodebuild -project Rally.xcodeproj -scheme Rally -configuration Debug
/// -destination 'platform=iOS Simulator,name=iPhone 16 Pro'
/// CODE_SIGNING_ALLOWED=NO -only-testing:RallyTests/WallRallyEscalationTests test`
final class WallRallyEscalationTests: XCTestCase {

    // MARK: - wallSpeedTier boundaries

    func testWallSpeedTierBoundaries() {
        XCTAssertEqual(Tunables.wallSpeedTier(forCombo: 0), 0)
        XCTAssertEqual(Tunables.wallSpeedTier(forCombo: Tunables.wallSpeedComboTier1 - 1), 0)
        XCTAssertEqual(Tunables.wallSpeedTier(forCombo: Tunables.wallSpeedComboTier1), 1)
        XCTAssertEqual(Tunables.wallSpeedTier(forCombo: Tunables.wallSpeedComboTier2 - 1), 1)
        XCTAssertEqual(Tunables.wallSpeedTier(forCombo: Tunables.wallSpeedComboTier2), 2)
        XCTAssertEqual(Tunables.wallSpeedTier(forCombo: Tunables.wallSpeedComboTier3 - 1), 2)
        XCTAssertEqual(Tunables.wallSpeedTier(forCombo: Tunables.wallSpeedComboTier3), 3)
        XCTAssertEqual(Tunables.wallSpeedTier(forCombo: Tunables.wallSpeedComboTier4 - 1), 3)
        XCTAssertEqual(Tunables.wallSpeedTier(forCombo: Tunables.wallSpeedComboTier4), 4)
        XCTAssertEqual(Tunables.wallSpeedTier(forCombo: Tunables.wallSpeedComboTier5 - 1), 4)
        XCTAssertEqual(Tunables.wallSpeedTier(forCombo: Tunables.wallSpeedComboTier5), 5)
        XCTAssertEqual(Tunables.wallSpeedTier(forCombo: 1_000), 5)
    }

    func testWallSpeedScalarMatchesTierAndIsMonotonicallyFaster() {
        // Each tier maps to its documented scalar exactly.
        XCTAssertEqual(Tunables.wallSpeedScalar(forCombo: 0), Tunables.wallSpeedScalarTier0, accuracy: 1e-9)
        XCTAssertEqual(Tunables.wallSpeedScalar(forCombo: Tunables.wallSpeedComboTier1), Tunables.wallSpeedScalarTier1, accuracy: 1e-9)
        XCTAssertEqual(Tunables.wallSpeedScalar(forCombo: Tunables.wallSpeedComboTier2), Tunables.wallSpeedScalarTier2, accuracy: 1e-9)
        XCTAssertEqual(Tunables.wallSpeedScalar(forCombo: Tunables.wallSpeedComboTier3), Tunables.wallSpeedScalarTier3, accuracy: 1e-9)
        XCTAssertEqual(Tunables.wallSpeedScalar(forCombo: Tunables.wallSpeedComboTier4), Tunables.wallSpeedScalarTier4, accuracy: 1e-9)
        XCTAssertEqual(Tunables.wallSpeedScalar(forCombo: Tunables.wallSpeedComboTier5), Tunables.wallSpeedScalarTier5, accuracy: 1e-9)

        // Scalar must strictly shrink tier-over-tier — the ball only ever gets faster
        // (smaller scalar = shorter travel time) as combo climbs. A regression that
        // flattens or reverses the ramp would silently kill the "terrifying by 55" feel.
        let scalars = (0...5).map { tier -> Double in
            switch tier {
            case 0:  return Tunables.wallSpeedScalarTier0
            case 1:  return Tunables.wallSpeedScalarTier1
            case 2:  return Tunables.wallSpeedScalarTier2
            case 3:  return Tunables.wallSpeedScalarTier3
            case 4:  return Tunables.wallSpeedScalarTier4
            default: return Tunables.wallSpeedScalarTier5
            }
        }
        for (a, b) in zip(scalars, scalars.dropFirst()) {
            XCTAssertLessThan(b, a, "wall speed scalar must strictly decrease as tier rises")
        }
    }

    // MARK: - wallTimingScalar (mirrors the speed ramp)

    func testWallTimingScalarMatchesTierAtZeroOpeningBoost() {
        XCTAssertEqual(
            Tunables.wallTimingScalar(forCombo: 0, openingBoost: 0),
            Tunables.wallTimingScalarTier0,
            accuracy: 1e-9
        )
        XCTAssertEqual(
            Tunables.wallTimingScalar(forCombo: Tunables.wallSpeedComboTier1, openingBoost: 0),
            Tunables.wallTimingScalarTier1,
            accuracy: 1e-9
        )
        XCTAssertEqual(
            Tunables.wallTimingScalar(forCombo: Tunables.wallSpeedComboTier2, openingBoost: 0),
            Tunables.wallTimingScalarTier2,
            accuracy: 1e-9
        )
        XCTAssertEqual(
            Tunables.wallTimingScalar(forCombo: Tunables.wallSpeedComboTier3, openingBoost: 0),
            Tunables.wallTimingScalarTier3,
            accuracy: 1e-9
        )
        XCTAssertEqual(
            Tunables.wallTimingScalar(forCombo: Tunables.wallSpeedComboTier4, openingBoost: 0),
            Tunables.wallTimingScalarTier4,
            accuracy: 1e-9
        )
        XCTAssertEqual(
            Tunables.wallTimingScalar(forCombo: Tunables.wallSpeedComboTier5, openingBoost: 0),
            Tunables.wallTimingScalarTier5,
            accuracy: 1e-9
        )
    }

    func testWallTimingScalarStrictlyTapersAcrossTiersAtZeroBoost() {
        // Mirrors the speed ramp: as the ball gets faster (lower speed scalar),
        // the hit window must taper too — so the late game is genuinely harder
        // rather than coasting on an unchanged window.
        let combos = [0, Tunables.wallSpeedComboTier1, Tunables.wallSpeedComboTier2,
                       Tunables.wallSpeedComboTier3, Tunables.wallSpeedComboTier4, Tunables.wallSpeedComboTier5]
        let scalars = combos.map { Tunables.wallTimingScalar(forCombo: $0, openingBoost: 0) }
        for (a, b) in zip(scalars, scalars.dropFirst()) {
            XCTAssertLessThan(b, a, "wall timing scalar must strictly decrease as tier rises")
        }
        // Tier 5 is explicitly tighter than the 1.0 baseline used elsewhere in the
        // game ("absurd — Flappy end-game feel"), not just smaller than tier 0.
        XCTAssertLessThan(Tunables.wallTimingScalarTier5, 1.0)
    }

    func testOpeningBoostOnlyAppliesInTierZero() {
        // Full opening grace (boost = 1) adds +0.16 on top of the tier-0 base —
        // this is the "very generous on-ramp" the doc comment promises.
        XCTAssertEqual(
            Tunables.wallTimingScalar(forCombo: 0, openingBoost: 1.0),
            Tunables.wallTimingScalarTier0 + 0.16,
            accuracy: 1e-9
        )
        // Partial decay (boost = 0.5) is exactly half that bonus.
        XCTAssertEqual(
            Tunables.wallTimingScalar(forCombo: 0, openingBoost: 0.5),
            Tunables.wallTimingScalarTier0 + 0.08,
            accuracy: 1e-9
        )
        // Once combo has left tier 0, the opening boost must NOT leak into later
        // tiers — a stale non-zero boost value should have zero effect here.
        XCTAssertEqual(
            Tunables.wallTimingScalar(forCombo: Tunables.wallSpeedComboTier1, openingBoost: 1.0),
            Tunables.wallTimingScalarTier1,
            accuracy: 1e-9
        )
        XCTAssertEqual(
            Tunables.wallTimingScalar(forCombo: Tunables.wallSpeedComboTier5, openingBoost: 1.0),
            Tunables.wallTimingScalarTier5,
            accuracy: 1e-9
        )
    }

    // MARK: - wall return depth and urgency

    func testWallReentryGrowsFromWallDepthToStrikePlane() {
        let state = RallyReentryBallState(
            startTime: 10,
            arrivalTime: 10 + Tunables.wallReturnTravelSeconds,
            strikeTime: 10 + Tunables.wallReturnTravelSeconds,
            startPoint: CGPoint(x: 180, y: 520),
            strikePoint: CGPoint(x: 260, y: 160),
            config: .rallyDefault,
            handoffXScale: Tunables.wallExchangeDepthFarScale,
            handoffYScale: Tunables.wallExchangeDepthFarScale,
            handoffShadowAlpha: 0.18
        )

        let start = state.frame(at: state.startTime)
        let middle = state.frame(at: state.startTime + state.travelSeconds * 0.5)
        let end = state.frame(at: state.arrivalTime)

        XCTAssertEqual(start.xScale, Tunables.wallExchangeDepthFarScale, accuracy: 1e-6)
        XCTAssertEqual(start.yScale, Tunables.wallExchangeDepthFarScale, accuracy: 1e-6)
        XCTAssertGreaterThan(middle.xScale, start.xScale)
        XCTAssertGreaterThan(middle.yScale, start.yScale)
        XCTAssertEqual(end.xScale, 1.0, accuracy: 1e-6)
        XCTAssertEqual(end.yScale, 1.0, accuracy: 1e-6)
        XCTAssertGreaterThan(end.shadowAlpha, start.shadowAlpha)
    }

    func testWallReentrySpeedScalarAcceleratesTowardPlayer() {
        let state = RallyReentryBallState(
            startTime: 4,
            arrivalTime: 4 + Tunables.wallReturnTravelSeconds,
            strikeTime: 4 + Tunables.wallReturnTravelSeconds,
            startPoint: CGPoint(x: 220, y: 520),
            strikePoint: CGPoint(x: 220, y: 160),
            config: .rallyDefault,
            handoffXScale: Tunables.wallExchangeDepthFarScale,
            handoffYScale: Tunables.wallExchangeDepthFarScale,
            handoffShadowAlpha: 0.18
        )

        let early = state.frame(at: state.startTime + state.travelSeconds * 0.10)
        let middle = state.frame(at: state.startTime + state.travelSeconds * 0.50)
        let late = state.frame(at: state.startTime + state.travelSeconds * 0.90)

        XCTAssertLessThan(early.speedScalar, middle.speedScalar)
        XCTAssertLessThan(middle.speedScalar, late.speedScalar)
        XCTAssertGreaterThan(late.speedScalar, 0.80)
    }

    // MARK: - wall spawn watchdog

    func testWallSpawnWatchdogDeadlineRespectsScheduledDelayPlusGrace() {
        let requestedAt: TimeInterval = 100
        let delay: TimeInterval = 0.68

        let deadline = Tunables.wallSpawnWatchdogDeadline(
            requestedAt: requestedAt,
            delay: delay
        )

        XCTAssertEqual(
            deadline,
            requestedAt + delay + Tunables.wallSpawnWatchdogGraceSeconds,
            accuracy: 1e-9
        )
        XCTAssertFalse(
            Tunables.isWallSpawnWatchdogExpired(now: requestedAt + delay, deadline: deadline)
        )
        XCTAssertFalse(
            Tunables.isWallSpawnWatchdogExpired(now: deadline, deadline: deadline)
        )
        XCTAssertTrue(
            Tunables.isWallSpawnWatchdogExpired(now: deadline + 0.001, deadline: deadline)
        )
    }

    func testWallSpawnWatchdogUsesOneClockDomainForRequestAndExpiry() {
        let requestedAt: TimeInterval = 1_000
        let delay: TimeInterval = 0.22

        let deadline = Tunables.wallSpawnWatchdogDeadline(
            requestedAt: requestedAt,
            delay: delay
        )

        XCTAssertFalse(
            Tunables.isWallSpawnWatchdogExpired(
                now: requestedAt + delay * 0.5,
                deadline: deadline
            )
        )
    }

    func testWallEmptyCourtRescueFeedIsFasterThanNormalFeed() {
        XCTAssertGreaterThan(
            Tunables.wallEmptyCourtRescueSeconds,
            Tunables.wallFeedDelaySeconds,
            "rescue should only engage after the normal empty-court feed had time to fire"
        )
        XCTAssertLessThan(
            Tunables.wallFeedRescueDelaySeconds,
            Tunables.wallFeedDelaySeconds,
            "rescue feed must be a near-immediate recovery, not another normal wait"
        )
        XCTAssertLessThan(
            Tunables.wallFeedRescueDelaySeconds,
            Tunables.wallEmptyCourtRescueSeconds,
            "rescue delay should never exceed the empty-court stall threshold"
        )
    }

    func testOpeningFeedCueStaysVisibleThroughLearningWindow() {
        XCTAssertTrue(
            Tunables.shouldShowWallOpeningFeedCue(
                spawnedBallCount: Tunables.wallOpeningFeedCueBallCount,
                openingProgress: 1
            )
        )
        XCTAssertFalse(
            Tunables.shouldShowWallOpeningFeedCue(
                spawnedBallCount: Tunables.wallOpeningFeedCueBallCount + 1,
                openingProgress: 1
            )
        )
        XCTAssertTrue(
            Tunables.shouldShowWallOpeningFeedCue(
                spawnedBallCount: Tunables.wallOpeningFeedCueBallCount + 1,
                openingProgress: 0.2
            ),
            "early opening progress should keep the path guide visible even if a replay/rescue increments the feed count"
        )
    }

    func testOpeningFeedCueStrengthHasReadableFloor() {
        XCTAssertGreaterThanOrEqual(
            Tunables.wallOpeningFeedCueStrength(openingProgress: 1),
            Tunables.wallOpeningFeedCueMinStrength
        )
        XCTAssertGreaterThan(
            Tunables.wallOpeningFeedCueStrength(openingProgress: 0),
            Tunables.wallOpeningFeedCueStrength(openingProgress: 1)
        )
    }

    func testOpeningProgressFadesAcrossNamedFeedCount() {
        XCTAssertEqual(Tunables.wallOpeningProgress(spawnedBallCount: 0), 0, accuracy: 1e-9)
        XCTAssertEqual(Tunables.wallOpeningProgress(spawnedBallCount: 1), 0, accuracy: 1e-9)
        XCTAssertEqual(
            Tunables.wallOpeningProgress(spawnedBallCount: Tunables.wallOpeningProgressFeedCount + 1),
            1,
            accuracy: 1e-9
        )
        XCTAssertEqual(
            Tunables.wallOpeningProgress(spawnedBallCount: Tunables.wallOpeningProgressFeedCount + 4),
            1,
            accuracy: 1e-9
        )
        XCTAssertGreaterThan(
            Tunables.wallOpeningProgress(spawnedBallCount: 4),
            Tunables.wallOpeningProgress(spawnedBallCount: 3)
        )
    }

    // MARK: - survival miss copy priority

    func testSurvivalMissCopyShowsResetForMeaningfulNonLastLifeBreak() {
        let priority = Tunables.wallMissCopyPriority(
            previousCombo: 12,
            livesBeforeMiss: 3,
            beatBestThisRun: false
        )

        XCTAssertTrue(priority.showResetBanner)
        XCTAssertTrue(priority.showMissInstruction)
    }

    func testSurvivalMissCopySuppressesResetAndInstructionWhenEnteringLastLife() {
        let priority = Tunables.wallMissCopyPriority(
            previousCombo: 12,
            livesBeforeMiss: 2,
            beatBestThisRun: false
        )

        XCTAssertFalse(priority.showResetBanner)
        XCTAssertFalse(priority.showMissInstruction)
    }

    func testSurvivalMissCopyKeepsQuietMissesFromShowingReset() {
        let priority = Tunables.wallMissCopyPriority(
            previousCombo: 0,
            livesBeforeMiss: 3,
            beatBestThisRun: false
        )

        XCTAssertFalse(priority.showResetBanner)
        XCTAssertTrue(priority.showMissInstruction)
    }

    func testSurvivalMissCopyLetsNewBestOwnTheRewardBeat() {
        let priority = Tunables.wallMissCopyPriority(
            previousCombo: 18,
            livesBeforeMiss: 3,
            beatBestThisRun: true
        )

        XCTAssertFalse(priority.showResetBanner)
        XCTAssertTrue(priority.showMissInstruction)
    }

    // MARK: - opening rally mercy

    func testOpeningMissMercyForgivesZeroScoreWarmupMisses() {
        XCTAssertTrue(
            Tunables.Survival.shouldForgiveOpeningMiss(
                sessionTime: Tunables.Survival.openingNoLifeLossSeconds * 0.5,
                score: 0,
                previousCombo: 0,
                forgivenMissesUsed: 0
            )
        )
        XCTAssertTrue(
            Tunables.Survival.shouldForgiveOpeningMiss(
                sessionTime: Tunables.Survival.openingNoLifeLossSeconds,
                score: 0,
                previousCombo: 0,
                forgivenMissesUsed: Tunables.Survival.openingNoLifeLossMisses - 1
            )
        )
    }

    func testOpeningMissMercyEndsAfterLimitOrRealRally() {
        XCTAssertFalse(
            Tunables.Survival.shouldForgiveOpeningMiss(
                sessionTime: Tunables.Survival.openingNoLifeLossSeconds + 0.01,
                score: 0,
                previousCombo: 0,
                forgivenMissesUsed: 0
            )
        )
        XCTAssertFalse(
            Tunables.Survival.shouldForgiveOpeningMiss(
                sessionTime: 1,
                score: 0,
                previousCombo: 0,
                forgivenMissesUsed: Tunables.Survival.openingNoLifeLossMisses
            )
        )
        XCTAssertFalse(
            Tunables.Survival.shouldForgiveOpeningMiss(
                sessionTime: 1,
                score: 10,
                previousCombo: 0,
                forgivenMissesUsed: 0
            )
        )
        XCTAssertFalse(
            Tunables.Survival.shouldForgiveOpeningMiss(
                sessionTime: 1,
                score: 0,
                previousCombo: 1,
                forgivenMissesUsed: 0
            )
        )
    }
}
