import CoreGraphics
import Foundation

/// Central knob room for "game feel". The single source of truth for every
/// number that affects how the game _feels_ — input latency, frame-stop
/// durations, shake amplitudes, audio envelopes, haptic intensities.
///
/// Rules:
/// 1. No `Tunables` value is ever computed at runtime. They are all baked at
///    build time so the feel is reproducible commit-to-commit.
/// 2. If a tweakable number appears in more than one file, it goes here.
/// 3. The names read like a designer's spreadsheet, not a programmer's
///    variables — `frameStopHitMs`, not `tFreeze`.
enum Tunables {

    // MARK: - Frame-stop ("hit pause")
    //
    // Two regimes:
    //
    // 1. Per-hit "weight" pause — strictly sub-frame at 60 Hz. Just enough
    //    to make the brain interpret the moment as heavier than it is,
    //    without ever costing a full vsync. Follows GDD §1.1 (6 / 3 / 0 ms).
    //    A previous draft used 24 / 12 / 0 ms (GDD §0.5) which was full
    //    visible hitches at 60 Hz — that broke the 16th-note flow.
    //
    // 2. Death pause — the iconic Flappy freeze. Long, deliberate, the
    //    "oh no" moment. Coincides with the red flash, screen shake, and
    //    descending death tone.

    static let frameStopFrameMs: Double = 1000.0 / 60.0
    static let frameStopHitFrames: Double = 3
    static let frameStopPerfectFrames: Double = 5
    static let frameStopPerfectMs: Double = frameStopFrameMs * frameStopPerfectFrames
    static let frameStopGreatMs:   Double = frameStopFrameMs * frameStopHitFrames
    static let frameStopGoodMs:    Double = frameStopFrameMs * frameStopHitFrames
    static let frameStopMissMs:    Double = 0

    /// Extended freeze on a combo break — the "you died" moment.
    static let frameStopDeathMs:   Double = 200

    // MARK: - Screen shake (in points, applied to the camera)

    static let shakeAmplitudePerfect: CGFloat = 11
    static let shakeAmplitudeGreat:   CGFloat = 6.5
    static let shakeAmplitudeGood:    CGFloat = 2.5
    static let shakeAmplitudeMiss:    CGFloat = 0
    static let shakeAmplitudeDeath:   CGFloat = 18    // The "Flappy hit"

    static let shakeDurationHitMs:    Double = 120
    static let shakeDurationDeathMs:  Double = 340

    // MARK: - Visual feedback timing

    static let hitBurstDurationMs:    Double = 430
    static let perfectBurstDurationMs: Double = 640
    static let scoreTweenDurationMs:  Double = 220
    static let redFlashDurationMs:    Double = 380
    static let tierFlashDurationMs:   Double = 520

    // MARK: - Strike-line anticipation pulse
    //
    // A short brighten + expand on the strike line, scheduled so its rise
    // peak lands `strikePulseLeadMs` before a ball is due to land on it.

    /// How far ahead of the ball's arrival the pulse *peaks* — the Wii Tennis
    /// "swing now" moment (~0.40–0.50 s before contact), not pulse onset.
    static let strikePulseLeadMs: Double = 500

    /// Total pulse duration (rise + fall).
    static let strikePulseDurationMs: Double = 340

    /// Peak glow width during the pulse — additive over the strike line's
    /// resting glow.
    static let strikePulseGlowWidth: CGFloat = 50

    /// Peak alpha during the pulse, 0...1.
    static let strikePulsePeakAlpha: CGFloat = 1.0
    static let wallReadLabelLift: CGFloat = 54
    static let wallFocusReadLabelLift: CGFloat = 98
    static let wallAnticipationBarWidth: CGFloat = 186
    static let wallAnticipationBarHeight: CGFloat = 24
    /// Visual anticipation peak — bar fill and ring pulse target this lead
    /// before wall contact (same 0.40–0.50 s swing-now window).
    static let wallAnticipationLeadMs: Double = 520
    static let wallReboundBandYRatio: CGFloat = 0.902
    static let minimalHUDScoreYRatio: CGFloat = 0.742
    static let wallHUDScoreFontMax: CGFloat = 24
    static let wallHUDScoreFontMid: CGFloat = 21
    static let wallHUDScoreFontMin: CGFloat = 18
    static let wallHUDScorePunchMaxScale: CGFloat = 1.10
    static let wallHUDScoreCompactThreshold: Int = 100_000
    static let wallReboundCueDurationMs: Double = 260
    /// Normal wait before feeding the next wall-rally ball once the court is empty.
    static let wallFeedDelaySeconds: TimeInterval = 0.22
    /// If the court stays empty this long, feed almost immediately instead of
    /// waiting through another normal delay. This protects the "one more try"
    /// loop from ever feeling frozen after a lifecycle hiccup.
    static let wallEmptyCourtRescueSeconds: TimeInterval = 0.70
    static let wallFeedRescueDelaySeconds: TimeInterval = 0.035
    /// Extra grace after a scheduled wall-feed delay. If the token survives
    /// past `requestedAt + delay + grace`, scene timing likely overtook the
    /// callback, so the empty-court watchdog can safely schedule a fresh ball.
    static let wallSpawnWatchdogGraceSeconds: TimeInterval = 0.38

    static func wallSpawnWatchdogDeadline(
        requestedAt currentTime: TimeInterval,
        delay: TimeInterval
    ) -> TimeInterval {
        currentTime + delay + wallSpawnWatchdogGraceSeconds
    }

    static func isWallSpawnWatchdogExpired(
        now currentTime: TimeInterval,
        deadline: TimeInterval
    ) -> Bool {
        currentTime > deadline
    }

    static let wallContactRingRadius: CGFloat = 38
    static let wallApproachWindowRatio: CGFloat = 0.50
    static let wallSurfaceHeight: CGFloat = 20
    static let wallSurfaceWidthRatio: CGFloat = 0.42
    static let wallSurfaceYRatio: CGFloat = 0.902
    static let wallTargetPanelWidthRatio: CGFloat = 0.20
    static let wallTargetPanelHeight: CGFloat = 54
    static let wallLaunchHoldProgress: CGFloat = 0.07
    static let wallLaunchReleaseProgress: CGFloat = 0.19
    static let wallCruiseProgress: CGFloat = 0.76
    static let wallRacketCompressionCenter: CGFloat = 0.955
    static let wallRacketCompressionWidth: CGFloat = 0.055
    static let wallRacketCompressionAmount: CGFloat = 0.72
    static let wallInboundLiftRatio: CGFloat = 0.006
    static let wallInboundGravityRatio: CGFloat = 0.042
    static let wallOutboundCompressionAmount: CGFloat = 0.82
    static let wallOutboundDwellSeconds: Double = 0.028
    static let wallOutboundCompressionSeconds: Double = 0.06
    static let wallOutboundReleaseSeconds: Double = 0.082
    static let wallOutboundReboundLiftRatio: CGFloat = 0.012
    /// Ball speed coming off the wall, as a fraction of terminal return speed.
    /// Low = visible brake at the wall, then a building sprint back at the player.
    static let wallReturnExitSpeedScalar: CGFloat = 0.70
    /// Quadratic acceleration gain on the return leg. With exit 0.70 / gain 0.65
    /// the ball ends the return ~2.9× faster than it left the wall — the
    /// "accelerating back toward the player" read from the North Star.
    static let wallReturnAccelerationGain: CGFloat = 0.65
    /// Total wall→player return flight time (seconds).
    static let wallReturnTravelSeconds: Double = 0.56

    // MARK: - Survival loop ("one more try")
    //
    // The wall rally is a Flappy-Bird-style survival run: every miss costs a
    // life, the run ends the instant lives hit zero, and there is no clock —
    // you play until you fail and chase your best score. This is the entire
    // stakes/payoff structure the sandbox loop was missing.
    enum Survival {
        /// Master switch. When true the wall rally is a survival run.
        static let enabled = true
        /// Misses allowed before the run ends. Flappy is 1; 3 gives a tennis
        /// rally a little more rope while still making every ball matter.
        static let lives = 3
        /// Difficulty ramp: the return ball comes back faster as score climbs.
        /// The travel-time scalar lerps from 1.0 (base) at `rampStartScore`
        /// down to `rampMinTravelScalar` at `rampFullScore`.
        static let rampStartScore = 60
        static let rampFullScore = 1400
        /// Fastest return as a fraction of `wallReturnTravelSeconds`. 0.72 =
        /// the late-run ball returns ~28% quicker than the opening ball.
        static let rampMinTravelScalar: Double = 0.72
        /// One-life warning: a short Flappy-style pressure beat. It should
        /// make the next rally feel dangerous without adding permanent HUD.
        static let lastLifeBannerHoldSeconds: TimeInterval = 0.34
        static let lastLifeLivesPunchScale: CGFloat = 1.34
        static let lastLifeLivesPunchOutSeconds: TimeInterval = 0.08
        static let lastLifeLivesPunchBackSeconds: TimeInterval = 0.18
        static let lastLifeCameraDipPoints: CGFloat = 4.5
        static let lostLifePipSpacing: CGFloat = 13
        static let lostLifePipLift: CGFloat = 10
        static let lostLifePipScale: CGFloat = 1.65
        static let lostLifePipFadeSeconds: TimeInterval = 0.34
        static let suppressMissInstructionOnLastLife = true
    }
    /// Ball-node scale at the wall plane during the racket→wall exchange,
    /// relative to its scale at racket release. Sells the outbound depth leg.
    static let wallExchangeDepthFarScale: CGFloat = 0.58
    /// Safety prune for any finished wall exchange that failed to hand off.
    /// Keeps a stranded exchange object from blocking the next ball feed.
    static let wallExchangeStrandedGraceSeconds: TimeInterval = 0.45
    /// Return-leg tail alpha at exit speed (slow) and terminal speed (fast).
    static let wallReturnTailAlphaFloor: CGFloat = 0.10
    static let wallReturnTailAlphaPeak: CGFloat = 0.38
    static let wallImpactMarkFadeSeconds: TimeInterval = 0.6
    static let contactFlashRingDuration: TimeInterval = 0.15
    static let contactSparkMinCount: Int = 6
    static let contactSparkPerfectCount: Int = 10
    static let racketContactApproachSeconds: Double = 0.038
    static let racketContactDwellSeconds: Double = 0.024
    static let racketContactReleaseSeconds: Double = 0.078
    static let racketContactCompressionScaleX: CGFloat = 1.34
    static let racketContactCompressionScaleY: CGFloat = 0.68
    static let racketContactReleaseScaleX: CGFloat = 0.92
    static let racketContactReleaseScaleY: CGFloat = 1.18
    static let racketContactExitDistance: CGFloat = 34
    static let racketStringFlexDistance: CGFloat = 9

    // MARK: - Haptic intensity (0...1)

    static let hapticPerfect: Float = 1.0
    static let hapticGreat:   Float = 0.90
    static let hapticGood:    Float = 0.56
    static let hapticMiss:    Float = 0.3
    static let hapticDeath:   Float = 1.0

    /// Soft transient fired on finger touch-down — the swing "start" tap.
    /// Flappy's tap fired a haptic on every touch regardless of outcome;
    /// having one here gives the swing a tactile beginning, not just a
    /// tactile end. Kept low so it never competes with the strike haptic.
    static let hapticTouchDown: Float = 0.22

    // MARK: - Audio envelope (the Flappy SFX palette, synthesized)
    //
    // See Audio/ToneSynth.swift. Each tuple is (frequencyHz, durationMs).

    enum Audio {
        // Per-hit "point" chime. Flappy used a quick high-pitched ding.
        static let pointFreqHz:     Double = 1320
        static let pointGlideHz:    Double = 1760
        static let pointDurationMs: Double = 148
        static let pointWaveform:   ToneSynth.Waveform = .sine

        // Perfect-hit "thump" — closer to Flappy's hit.wav: a low percussive
        // bonk with a noisy attack.
        static let hitFreqHz:        Double = 220
        static let hitGlideHz:       Double = 110
        static let hitDurationMs:    Double = 252
        static let hitNoiseMix:      Float  = 0.42
        static let hitWaveform:      ToneSynth.Waveform = .triangle

        // Miss/swing — Flappy's wing.wav was a soft filtered whoosh.
        static let wingFreqHz:       Double = 520
        static let wingGlideHz:      Double = 220
        static let wingDurationMs:   Double = 90
        static let wingNoiseMix:     Float  = 0.65
        static let wingWaveform:     ToneSynth.Waveform = .triangle

        // Combo-break "die" — falling tone, the Flappy death wail.
        static let dieFreqHz:        Double = 330
        static let dieGlideHz:       Double = 80
        static let dieDurationMs:    Double = 520
        static let dieNoiseMix:      Float  = 0.10
        static let dieWaveform:      ToneSynth.Waveform = .sawtooth

        // Combo-tier "level up" stinger. Quick ascending chord.
        static let tierBaseFreqHz:   Double = 660
        static let tierStepHz:       Double = 110
        static let tierDurationMs:   Double = 200
        static let tierWaveform:     ToneSynth.Waveform = .square

        // Envelope shape (ADSR-ish, but compact for casual game SFX).
        static let attackMs:  Double = 4
        static let releaseMs: Double = 60
        static let peakLevel: Float  = 0.92
    }

    // MARK: - Ball physics / spawn

    static let ballRadiusPoints:      CGFloat = 22
    static let ballTravelSeconds:     Double  = 1.52
    static let strikeLineYRatio:      CGFloat = 0.345
    static let gameplayCameraYOffsetRatio: CGFloat = -0.125
    static let gameplayCourtNearOverscanRatio: CGFloat = 0.30
    static let gameplayCourtFarYRatio: CGFloat = 0.865
    static let gameplayCourtNearHalfWidthRatio: CGFloat = 0.96
    static let gameplayCourtFarHalfWidthRatio: CGFloat = 0.145
    static let gameplayCourtNetDepthRatio: CGFloat = 0.47
    static let gameplayCourtNetNearHalfScalar: CGFloat = 0.62
    static let gameplayCourtNetFarHalfScalar: CGFloat = 0.98
    static let gameplayPlayerRootYRatio: CGFloat = 0.142
    static let gameplayPlayerVisualScale: CGFloat = 0.72
    /// SpriteKit gameplay needs shoes smaller than the locker hero view because
    /// the court camera compresses the feet near the bottom of the frame.
    static let gameplayShoeVisualScale: CGFloat = 0.86
    static let spawnLineYRatio:       CGFloat = 1.05
    static let cullBelowStrikePoints: CGFloat = 40
    static let horizonLaneInsetRatio: CGFloat = 0.12
    static let strikeLaneInsetRatio:  CGFloat = 0.30
    static let ballSpawnScale:        CGFloat = 0.44
    static let ballStrikeDiameterSceneWidthRatio: CGFloat = 0.055
    static let ballStrikeScale:       CGFloat = 1.14
    static let ballOverrunScale:      CGFloat = 1.28
    static let laneCurveAmount:       CGFloat = 0.08
    static let driveArcHeight:        CGFloat = 10
    static let topspinArcHeight:      CGFloat = 44
    static let skidArcHeight:         CGFloat = 6
    static let floaterArcHeight:      CGFloat = 58
    static let driveBounceProgress:   CGFloat = 0.76
    static let topspinBounceProgress: CGFloat = 0.71
    static let skidBounceProgress:    CGFloat = 0.82
    static let floaterBounceProgress: CGFloat = 0.68
    static let driveBounceKick:       CGFloat = 18
    static let topspinBounceKick:     CGFloat = 34
    static let skidBounceKick:        CGFloat = 8
    static let floaterBounceKick:     CGFloat = 24
    static let driveBounceCompression: CGFloat = 0.16
    static let topspinBounceCompression: CGFloat = 0.12
    static let skidBounceCompression: CGFloat = 0.22
    static let floaterBounceCompression: CGFloat = 0.08
    static let drivePostBounceAcceleration: CGFloat = 1.08
    static let topspinPostBounceAcceleration: CGFloat = 1.15
    static let skidPostBounceAcceleration: CGFloat = 1.22
    static let floaterPostBounceAcceleration: CGFloat = 0.95
    static let bounceShadowAlpha:     CGFloat = 0.32
    /// Ball shadow scale when the ball is at the player's feet (near / ground).
    /// Drives the 3-D height read: large shadow = ball is on the court surface.
    static let ballShadowGroundScale: CGFloat = 0.90
    /// Ball shadow scale when the ball is at the far wall (small / distant).
    static let ballShadowFarScale:    CGFloat = 0.30
    /// How much altitude (mid-arc lift) further shrinks the shadow per unit of altitudeScalar.
    static let ballShadowAltitudeShrink: CGFloat = 0.18
    /// Alpha scalar for the shadow when the ball is at the far/wall end of travel.
    static let ballShadowFarAlphaScalar: CGFloat = 0.38
    /// Forcing strict side-to-side alternation: max consecutive hits on the same
    /// lane before the spawner is required to cross over. 1 = every ball alternates.
    static let maxSameLaneRun:        Int      = 1
    static let maxConsecutiveSixteenths: Int   = 2
    static let minimumDoubleGapBeats: Double   = 3.0
    static let minimumPatternLength:  Int      = 2
    static let maximumPatternLength:  Int      = 4

    // MARK: - Swing gesture (Pokemon-Go-style drag-and-release)

    /// Minimum drag distance in points before a pan registers as a swing.
    /// Shorter motions are treated as accidental contact and ignored.
    static let swingMinDistance:      CGFloat = 28

    /// Pan velocity (pt/s) above which the swing counts as "committed."
    /// Below this we still register the swing but emit a softer trail.
    static let swingFastVelocity:     CGFloat = 1400

    /// In wall rally, lane intent comes from the side of the court the swipe
    /// begins on, not from crossing the center line. This preserves the
    /// "swipe up on left / swipe up on right" mental model.
    static let swingLaneSideStartWeight: CGFloat = 0.92
    static let swingLaneCenterDeadZoneRatio: CGFloat = 0.075
    static let swingWallMinUpwardRisePoints: CGFloat = 10

    /// Extra grace added on top of the `.good` timing window when deciding
    /// whether a ball is a legitimate target for the current swing. This is
    /// slightly wider than scoring itself so we prefer "you swung at the
    /// right ball but missed the timing" over "there was no target at all."
    static let swingTargetSlackSeconds: Double = 0.064

    /// Two notes with arrival times inside this threshold are treated as the
    /// same "double" exchange and can be cleared together.
    static let doubleArrivalToleranceSeconds: Double = 0.018

    /// How long the onboarding hint remains visible once the session begins.
    static let openingHintSeconds: Double = 8.0

    /// Vertical drag thresholds used to interpret the swing as a heavier
    /// topspin lift, flatter drive, or carving slice.
    static let swingTopspinRisePoints: CGFloat = 42
    static let swingSliceDropPoints:   CGFloat = -28
    static let racketReachBasePoints:  CGFloat = 112
    static let racketReachFromSwingScalar: CGFloat = 0.14
    static let racketSweetSpotRadius:  CGFloat = 44
    static let racketOffCenterRadius:  CGFloat = 78
    static let racketMissRadius:       CGFloat = 122
    static let recoveryBaseSeconds:    Double = 0.25
    static let recoveryStretchSeconds: Double = 0.18
    static let recoveryOppositeLanePenalty: CGFloat = 1.0
    static let recoverySameLanePenalty: CGFloat = 0.52
    static let recoveryReachPenalty:   CGFloat = 0.26
    static let recoveryTimingPenalty:  Double = 0.22
    static let recoveryCenterOffsetRatio: CGFloat = 0.11

    /// Trail color & visual.
    static let swingTrailGlowWidth:   CGFloat = 14
    static let swingTrailLineWidth:   CGFloat = 5
    static let wallSwingTrailCoreAlphaMultiplier: CGFloat = 0.42
    static let wallSwingTrailGlowAlphaMultiplier: CGFloat = 0.18
    static let wallSwingTrailLineWidthMultiplier: CGFloat = 0.62
    static let wallSwingTrailGlowWidthMultiplier: CGFloat = 0.12
    static let wallSwingTrailTipAlphaMultiplier: CGFloat = 0.34

    // MARK: - Tennis physics (post-hit impulse; swipe angle sets direction)

    /// Base impulse scale — multiplied by hit quality and swipe speed factor.
    static let tennisImpulseBase: CGFloat = 480

    /// Small upward kick when the swipe is nearly horizontal so returns
    /// still clear the net; swipe angle carries most of the trajectory.
    static let tennisImpulseUpBias: CGFloat = 160

    /// Gravity after the ball is struck (points / s²). Incoming balls stay kinematic until contact.
    static let tennisGravityDy: CGFloat = -680

    /// Incoming ball lateral jitter around center court (points).
    static let tennisSpawnJitterX: CGFloat = 72

    /// Balls scale from this (far) toward `ballDepthScaleNear` as they approach.
    static let ballDepthScaleFar:  CGFloat = 0.55
    static let ballDepthScaleNear: CGFloat = 1.0
    static let ballTrailMinSpeedScalar: CGFloat = 0.12
    static let ballTrailMaxSpeedScalar: CGFloat = 1.0
    static let ballShadowHighAlphaScalar: CGFloat = 0.42

    // MARK: - In-game avatar motion

    static let avatarBreathingPeriodSeconds: Double = 0.8
    static let avatarBreathingScaleAmplitude: CGFloat = 0.02
    static let avatarWeightShiftPoints: CGFloat = 8
    static let avatarBackswingSeconds: Double = 0.10
    static let avatarFollowThroughSeconds: Double = 0.18
    static let avatarRecoverySeconds: Double = 0.25

    /// Frames where pose interpolation is suppressed after a perfect/great hit.
    /// Creates a visible "punch" pause that makes contact feel physical.
    static let swingHitStopSeconds: Double = 0.054

    /// Radius of the white radial burst spawned at the racket head on contact.
    static let contactRacketBurstRadius: CGFloat = 13
    static let contactRacketBurstAlphaMultiplier: CGFloat = 0.52
    static let contactRacketBurstScaleMultiplier: CGFloat = 0.62
    static let contactRacketBurstGlowMultiplier: CGFloat = 0.58
    static let wallStrikeTransitionIntensityMultiplier: CGFloat = 0.045
    static let wallStrikeTransitionHaloFillBaseAlpha: CGFloat = 0.004
    static let wallStrikeTransitionHaloFillBoostAlpha: CGFloat = 0.007
    static let wallStrikeTransitionHaloRestAlpha: CGFloat = 0.003
    static let wallStrikeTransitionHaloAlpha: CGFloat = 0.014
    static let wallStrikeTransitionSweepAlpha: CGFloat = 0.026
    static let wallStrikeTransitionSweepPeakAlpha: CGFloat = 0.055

    /// Wall-mode ball/fx stays readable without swallowing the player body.
    static let wallBallVisualScalar: CGFloat = 0.36
    static let wallBallAuraAlphaScalar: CGFloat = 0.28
    static let wallBallCoreAlphaScalar: CGFloat = 0.72
    static let wallBallCoreScaleScalar: CGFloat = 0.76
    static let wallBallContactScaleBoost: CGFloat = 0.0
    static let wallBallAuraMaxAlpha: CGFloat = 0.018
    static let wallBallAuraScale: CGFloat = 0.24
    static let wallBallWarningMaxAlpha: CGFloat = 0.045
    static let wallBallWarningScale: CGFloat = 0.34
    static let wallBallFocusMaxAlpha: CGFloat = 0.052
    static let wallBallFocusScale: CGFloat = 0.32
    static let wallBallRingGlowWidth: CGFloat = 0.75
    static let wallBallTailAlphaMultiplier: CGFloat = 0.16
    static let wallBallTailXScaleMultiplier: CGFloat = 0.22
    static let wallBallTailYScaleMultiplier: CGFloat = 0.30
    static let wallBallTailOffsetMultiplier: CGFloat = 0.50
    static let wallLaneGlowBaseAlpha: CGFloat = 0.025
    static let wallLaneGlowRestAlpha: CGFloat = 0.035
    static let wallLaneGlowPeakPerfect: CGFloat = 0.14
    static let wallLaneGlowPeakGreat: CGFloat = 0.09
    static let wallLaneGlowPeakGood: CGFloat = 0.06
    static let wallLaneGlowWidth: CGFloat = 4
    static let wallLaneMissWrongAlpha: CGFloat = 0.025
    static let wallLaneMissCorrectPeakAlpha: CGFloat = 0.16
    static let wallLaneMissCorrectRestAlpha: CGFloat = 0.07
    static let wallRacketContactHaloAlphaMultiplier: CGFloat = 0.10
    static let wallRacketContactHaloGlowMultiplier: CGFloat = 0.12
    static let wallRacketContactHaloScaleMultiplier: CGFloat = 0.34
    static let wallContactProxyBallGlowWidth: CGFloat = 1.4
    static let wallContactProxyBallAuraAlpha: CGFloat = 0.014
    static let wallContactProxyBallCoreAlpha: CGFloat = 0.18
    static let wallContactProxyBallFocusAlpha: CGFloat = 0.010
    static let wallRacketContactLegacyHaloAlpha: CGFloat = 0.035
    static let wallRacketContactLegacyHaloGlow: CGFloat = 0.22
    static let wallRacketContactLegacyHaloScaleX: CGFloat = 0.62
    static let wallRacketContactLegacyHaloScaleY: CGFloat = 0.34
    static let wallRacketContactBurstZPosition: CGFloat = 13.20
    static let standardRacketContactBurstZPosition: CGFloat = 13.45
    static let standardRacketContactRingZPosition: CGFloat = 13.40
    static let wallContactImprintRingAlphaMultiplier: CGFloat = 0.20
    static let wallContactImprintRingGlowMultiplier: CGFloat = 0.20
    static let wallContactImprintSlashAlphaMultiplier: CGFloat = 0.92
    static let wallContactImprintSlashGlowMultiplier: CGFloat = 0.24
    static let wallContactImprintSparkTravelMultiplier: CGFloat = 1.42
    static let wallContactImprintStreakCount: Int = 3
    static let wallContactImprintStreakWidth: CGFloat = 16
    static let wallContactImprintStreakHeight: CGFloat = 1.6
    static let wallContactImprintStreakAlpha: CGFloat = 0.42
    static let wallContactImprintStreakGlow: CGFloat = 0.35
    static let wallContactImprintStreakTravel: CGFloat = 22
    static let wallContactBurstRingScaleMultiplier: CGFloat = 0.14
    static let wallContactBurstFlashScaleMultiplier: CGFloat = 0.052
    static let wallContactBurstAlphaMultiplier: CGFloat = 0.055
    static let wallContactBurstGlowMultiplier: CGFloat = 0.035
    static let wallContactSparkGlowMultiplier: CGFloat = 0.055
    static let wallContactSparkStreakWidth: CGFloat = 10
    static let wallContactSparkStreakHeight: CGFloat = 2
    static let wallContactPocketMaxAlpha: CGFloat = 0.20
    static let wallContactPocketBaseAlpha: CGFloat = 0.026
    static let wallContactPocketApproachAlpha: CGFloat = 0.10
    static let wallContactPocketFillAlpha: CGFloat = 0.006
    static let wallContactPocketGlowBase: CGFloat = 0.20
    static let wallContactPocketGlowApproach: CGFloat = 1.20
    static let wallContactPocketScaleBase: CGFloat = 0.78
    static let wallContactPocketScaleApproach: CGFloat = 0.12
    static let wallContactProxyBallAuraScale: CGFloat = 0.42
    static let wallContactProxyBallFocusScale: CGFloat = 0.46
    static let wallReturnTrailAlphaMultiplier: CGFloat = 0.08
    static let wallReturnTrailWidthMultiplier: CGFloat = 0.24
    static let wallReturnTrailGlowMultiplier: CGFloat = 0.04
    static let wallReturnGhostAlphaMultiplier: CGFloat = 0.26
    static let wallReturnEchoAlphaMultiplier: CGFloat = 0.06
    static let wallReturnImpactPulseAlphaMultiplier: CGFloat = 0.026
    static let wallReturnImpactPulseGlowWidth: CGFloat = 0.10
    static let wallLiveExchangeAuraScale: CGFloat = 0.20
    static let wallLiveExchangeAuraAlphaMultiplier: CGFloat = 0.16
    static let wallLiveExchangeCoreAlphaMultiplier: CGFloat = 1.0
    static let wallLiveExchangeTailAlphaFloor: CGFloat = 0.07
    static let wallLiveExchangeTailAlphaRebound: CGFloat = 0.20
    static let wallLiveExchangeTailApproachXScale: CGFloat = 0.92
    static let wallLiveExchangeTailReboundXScale: CGFloat = 1.28
    static let wallLiveExchangeTailYScale: CGFloat = 0.18
    static let wallContactPocketOutwardOffset: CGFloat = 22
    static let wallContactPocketVerticalOffset: CGFloat = -28
    static let wallRacketBurstAlphaMultiplier: CGFloat = 0.12
    static let wallRacketBurstScaleMultiplier: CGFloat = 0.20
    static let wallRacketBurstGlowMultiplier: CGFloat = 0.10
    static let wallTimingPopupFontScale: CGFloat = 0.66
    static let wallTimingPopupSideOffset: CGFloat = 74
    static let wallTimingPopupYOffset: CGFloat = 82
    static let wallTimingPopupRise: CGFloat = 10
    static let wallTimingPopupPeakScale: CGFloat = 1.02
    static let wallTimingPopupLabelAlpha: CGFloat = 0.76
    static let wallTimingPopupShadowAlpha: CGFloat = 0.24
    static let wallMomentBannerYRatio: CGFloat = 0.755
    static let wallMomentBannerStartScale: CGFloat = 0.76
    static let wallMomentBannerPeakScale: CGFloat = 0.92

    /// Blend fraction applied to all pose targets during hit-stop (near-zero = frozen).
    static let hitStopBlendFraction: CGFloat = 0.03

    // MARK: - Swing body mechanics (TopSpin 2K25 model)

    /// Swing phase boundaries — 0…1 maps full backswing to end of follow-through.
    static let swingLoadPhaseEnd:    CGFloat = 0.40
    static let swingContactPhaseEnd: CGFloat = 0.58
    static let swingContactPhaseCenter: CGFloat = 0.50
    static let swingContactPhaseRadius: CGFloat = 0.09

    /// TopSpin-style body-coil targets. Positive/negative are screen-space rotations.
    static let forehandLoadTorsoRotation: CGFloat = -0.46   // deeper shoulder coil on backswing
    static let backhandLoadTorsoRotation: CGFloat = 0.80   // stronger two-hander load
    static let torsoContactUncoilMultiplier: CGFloat = 5.2  // explosive torso release at contact — drives through ball
    static let forehandFollowTorsoRotation: CGFloat = 0.74  // full chest-to-target rotation through shot
    static let backhandFollowTorsoRotation: CGFloat = 0.18  // backhand rotates through more

    static let forehandLeadArmLoadRotation: CGFloat = -0.82 // arm coils deeper behind torso on load
    static let forehandLeadShoulderFollowDip: CGFloat = -28.0 // hitting shoulder dips hard into follow (pro tilt)
    static let forehandFollowHandleX: CGFloat = -64.0       // racket wraps far over opposite shoulder
    static let forehandFollowHandleY: CGFloat = 182.0       // high finish — racket over left shoulder
    static let backhandFollowHandleX: CGFloat = -82.0
    static let backhandFollowHandleY: CGFloat = 182.0
    static let backhandFollowHeadX: CGFloat = -110.0
    static let backhandFollowHeadY: CGFloat = 216.0
    static let backhandSupportHandGripSeparation: CGFloat = 12.5
    static let backhandContactGripLockBlend: CGFloat = 0.72

    /// Extra hip-lead over shoulders during backswing coil (radians).
    static let torsoHipLeadAngle: CGFloat = 0.18            // hips clearly lead shoulders

    /// Racket handle waits until torso has reached this fraction of its target
    /// rotation before fully committing to load targets — simulates kinetic chain lag.
    static let racketHandLagTorsoFrac: CGFloat = 0.55       // arm commits a bit earlier but still lags

    /// Torso uncoil velocity accumulates at this lerp weight per frame during load.
    static let torsoVelocityAccumRate: CGFloat = 0.17       // loads torso velocity faster
    /// And releases (decays toward zero) at this rate per frame after contact.
    static let torsoVelocityDecayRate: CGFloat = 0.62       // faster uncoil burst at contact

    /// Racket-head overshoot amplitude on contact wrist-snap (points).
    static let wristSnapAmplitude: CGFloat = 24.0           // more visible snap through ball
    static let wristSnapHoldSeconds: Double = 0.042
    /// Exponential decay rate for wrist snap (units: 1/second).
    static let wristSnapDecayRate: CGFloat  = 22.0          // slower decay = snap lingers longer
    static let forehandWristSnapAxisX: CGFloat = 0.94
    static let forehandWristSnapAxisY: CGFloat = 0.34
    static let backhandWristSnapAxisX: CGFloat = -0.92
    static let backhandWristSnapAxisY: CGFloat = 0.38

    /// Exponent for easeOut on follow-through positions: pow(1−t, exp).
    static let followEaseOutPow: CGFloat = 2.4              // snaps through faster, decelerates more smoothly

    // MARK: - Footwork system (TopSpin 2K25 model)

    /// Duration of the full split-step up→down animation (seconds).
    static let splitStepDuration: Double = 0.195             // slightly longer — more athletic hop
    /// Peak vertical lift during split-step (points).
    static let splitStepHeight: CGFloat = 8.0               // bigger hop — more visible anticipation
    /// approachProgress threshold that triggers the split-step.
    static let splitStepApproachTrigger: CGFloat = 0.36
    /// approachProgress threshold where the player commits the outside foot.
    static let footworkSideCommitTrigger: CGFloat = 0.46
    /// Max lateral drift toward the live lane before contact.
    static let footworkRootLoadShiftPoints: CGFloat = 10.0
    /// Extra space between feet during split/load.
    static let footworkStanceWidenPoints: CGFloat = 12.0
    /// Outside foot steps wider than the neutral leg target.
    static let footworkOutsidePlantPoints: CGFloat = 15.0
    /// Inside foot pushes/cross-recovers after contact.
    static let footworkInsidePushPoints: CGFloat = 7.0
    /// Slight body drop during the split-step landing.
    static let footworkSplitLandCompression: CGFloat = 0.042  // more body drop on split-step landing
    /// Crouch into the loaded outside foot.
    static let footworkLoadCrouchScale: CGFloat = 0.068       // noticeably sinks into loaded leg
    /// Extra compression at the exact contact stomp.
    static let footworkContactCompressionScale: CGFloat = 0.050  // body squats at contact moment
    /// Toe-out angle for the planted outside shoe.
    static let footworkOutsideToeOutRadians: CGFloat = 0.38
    /// Neutral ready-stance toe-out so both shoes angle away from centre.
    static let footworkReadyToeOutRadians: CGFloat = 0.34
    /// Trail-foot drag/toe angle during recovery.
    static let footworkRecoveryToeDragRadians: CGFloat = 0.12
    /// Blend speed for side-to-side weight transfer.
    static let footworkWeightShiftBlend: CGFloat = 0.22
    /// Extra maximum blend toward lane target in wall-rally mode.
    static let footworkLaneBlendMax: CGFloat = 0.56

    /// Non-planted foot lift during weight transfer (points, positive = up).
    static let weightTransferLiftPt: CGFloat = 5.0           // off-foot lifts more — visible weight shift
    /// Planted foot stomp depth at contact (points, negative = into court).
    static let footStompPt: CGFloat = 3.5                    // planted foot drives into court harder
    /// Time to recover both feet to neutral split stance after contact (seconds).
    static let footRecoveryDuration: Double = 0.220

    // MARK: - Wrist / racket-face angles (TopSpin 2K25 model)

    /// Racket face tilts back by this many radians during load (wrist cock).
    static let wristCockAngleLoad: CGFloat = -0.46           // more laid-back wrist on backswing
    /// Extra pronation at end of forehand follow-through (butt cap faces up).
    static let wristPronateFinal: CGFloat   = 0.24           // full pronation — butt cap clearly up
    /// Racket-face angle at contact for each shot shape.
    static let racketFaceFlat:     CGFloat  =  0.00
    static let racketFaceTopspin:  CGFloat  = -0.24   // closes toward court
    static let racketFaceSlice:    CGFloat  =  0.14   // opens away from court

    /// Shadow lateral shift per unit of weightSide (points).
    static let shadowWeightShiftPt: CGFloat = 4.0

    // MARK: - Timing popup

    static let timingPopupDuration: TimeInterval = 0.50
    static let timingPopupRise: CGFloat = 14

    // MARK: - Tennis ball feed (no rhythm chart)

    /// First arrival at the strike window, in seconds from session start (after countdown).
    static let tennisFeedLeadInSeconds: Double = 2.0

    /// Spacing between feeds at the start vs end of a run (seconds between arrivals).
    static let tennisFeedBaseInterval: Double = 1.78
    static let tennisFeedMinInterval: Double = 0.92

    // MARK: - Session difficulty ramp (time-based; no combo chart)

    /// Travel time multiplier: slower balls early, faster late (`× ballTravelSeconds`).
    static let sessionTravelScalarStart: Double = 1.14
    static let sessionTravelScalarEnd:   Double = 0.86

    /// Hit timing window: wider early, tighter late (see `HitQuality`).
    static let sessionTimingWindowScalarStart: Double = 1.24
    static let sessionTimingWindowEnd:          Double = 0.92

    /// Music `phaseFloor` thresholds — fractions of session duration.
    static let sessionPhaseWarmUpCutoff:   Double = 0.14
    static let sessionPhaseExchangeCutoff: Double = 0.42
    static let sessionPhasePressureCutoff: Double = 0.72

    // MARK: - Wall rally escalation (Flappy Bird speed ramp)
    //
    // The ball gets faster as combo grows — generous on-ramp, terrifying by 55.
    // Travel time = ballTravelSeconds × matchPace.travelScalar × wallSpeedScalar(combo).
    //
    // Tier 0: combo 0–4    → 1.04× (forgiving on-ramp)
    // Tier 1: combo 5–11   → 0.92× ("oh, it's a bit faster")
    // Tier 2: combo 12–21  → 0.81× (noticeable)
    // Tier 3: combo 22–34  → 0.71× (scary)
    // Tier 4: combo 35–54  → 0.61× (hard)
    // Tier 5: combo 55+    → 0.52× (absurd — Flappy end-game feel)

    static let wallSpeedComboTier1: Int    = 5
    static let wallSpeedComboTier2: Int    = 12
    static let wallSpeedComboTier3: Int    = 22
    static let wallSpeedComboTier4: Int    = 35
    static let wallSpeedComboTier5: Int    = 55

    static let wallSpeedScalarTier0: Double = 1.04
    static let wallSpeedScalarTier1: Double = 0.92
    static let wallSpeedScalarTier2: Double = 0.81
    static let wallSpeedScalarTier3: Double = 0.71
    static let wallSpeedScalarTier4: Double = 0.61
    static let wallSpeedScalarTier5: Double = 0.52

    /// Map a combo count to its 0…5 speed tier.
    static func wallSpeedTier(forCombo combo: Int) -> Int {
        switch combo {
        case ..<wallSpeedComboTier1: return 0
        case ..<wallSpeedComboTier2: return 1
        case ..<wallSpeedComboTier3: return 2
        case ..<wallSpeedComboTier4: return 3
        case ..<wallSpeedComboTier5: return 4
        default:                     return 5
        }
    }

    /// Travel-time scalar for the current combo.
    static func wallSpeedScalar(forCombo combo: Int) -> Double {
        switch wallSpeedTier(forCombo: combo) {
        case 0:  return wallSpeedScalarTier0
        case 1:  return wallSpeedScalarTier1
        case 2:  return wallSpeedScalarTier2
        case 3:  return wallSpeedScalarTier3
        case 4:  return wallSpeedScalarTier4
        default: return wallSpeedScalarTier5
        }
    }

    // MARK: - Wall rally timing taper (mirrors the speed ramp)
    //
    // As balls arrive faster (wallSpeedScalar shrinks), the hit window tapers
    // proportionally — so tier 5 is genuinely harder, not trivially easy relative
    // to ball speed. The opening forgiveness bonus still applies in tier 0 only.
    //
    // Tier 0: combo 0–4    → 1.78  (+ openingBoost × 0.16 — very generous on-ramp)
    // Tier 1: combo 5–11   → 1.62
    // Tier 2: combo 12–21  → 1.44
    // Tier 3: combo 22–34  → 1.26
    // Tier 4: combo 35–54  → 1.10
    // Tier 5: combo 55+    → 0.96  (tighter than baseline — Flappy end-game)
    static let wallTimingScalarTier0: Double = 1.78
    static let wallTimingScalarTier1: Double = 1.62
    static let wallTimingScalarTier2: Double = 1.44
    static let wallTimingScalarTier3: Double = 1.26
    static let wallTimingScalarTier4: Double = 1.10
    static let wallTimingScalarTier5: Double = 0.96

    /// Timing-window multiplier for wall rally. Tightens with combo tier to
    /// match the speed ramp. `openingBoost` is the 0…1 grace value from GameScene
    /// (decays over the first 7 hits).
    static func wallTimingScalar(forCombo combo: Int, openingBoost: Double) -> Double {
        switch wallSpeedTier(forCombo: combo) {
        case 0:  return wallTimingScalarTier0 + openingBoost * 0.16
        case 1:  return wallTimingScalarTier1
        case 2:  return wallTimingScalarTier2
        case 3:  return wallTimingScalarTier3
        case 4:  return wallTimingScalarTier4
        default: return wallTimingScalarTier5
        }
    }

    /// Copy-priority policy for survival misses. The visual rule is that the
    /// one-life warning owns the frame: it suppresses normal RESET/coaching copy
    /// unless the miss also earned a new-best reward banner.
    static func wallMissCopyPriority(
        previousCombo: Int,
        livesBeforeMiss: Int,
        beatBestThisRun: Bool
    ) -> (showResetBanner: Bool, showMissInstruction: Bool) {
        let entersLastLife = Survival.enabled && livesBeforeMiss == 2
        let showResetBanner = previousCombo >= 5 && !entersLastLife && !beatBestThisRun
        let showMissInstruction = !entersLastLife || !Survival.suppressMissInstructionOnLastLife
        return (showResetBanner, showMissInstruction)
    }

    /// UserDefaults key for the all-time best wall rally combo.
    static let wallHighComboKey = "rally.wallRally.highCombo"
    /// When the player is this many hits from their all-time wall combo,
    /// the HUD switches from passive "BEST 18" to active "3 TO BEST".
    static let wallNearBestComboWindow: Int = 5

    // MARK: - Scoring

    static let comboTier1: Int = 5
    static let comboTier2: Int = 15
    static let comboTier3: Int = 30
    static let comboTier4: Int = 50

    /// Map a raw combo count to the discrete tier (0...4) used by every
    /// "the player is on fire" subsystem (music stems, haptic ramps, juice
    /// multipliers). Single source of truth.
    static func comboTier(forCombo combo: Int) -> Int {
        switch combo {
        case 0..<comboTier1: return 0
        case comboTier1..<comboTier2: return 1
        case comboTier2..<comboTier3: return 2
        case comboTier3..<comboTier4: return 3
        default: return 4
        }
    }

    /// Per-tier multiplier applied to per-hit feel: shake amplitude, burst
    /// size, glow width. Tier 0 hits feel like the spec values; tier 4
    /// hits feel ~70% punchier. Audibly the SFX is also transposed up by
    /// `2 * tier` semitones (see `AudioManager.handleHit`).
    ///
    /// The multiplier is intentionally sub-linear past tier 2 so the
    /// game doesn't shake the screen off at sustained breaker-phase combos.
    static func tierJuiceMultiplier(tier: Int) -> CGFloat {
        switch max(0, min(tier, 4)) {
        case 0: return 1.00
        case 1: return 1.15
        case 2: return 1.30
        case 3: return 1.50
        default: return 1.70
        }
    }

    // MARK: - Match-flow phases (see MatchFlow.swift)
    //
    // Phase progression is driven by *whichever of clock-time or combo is
    // higher*. The clock-time thresholds keep the late session interesting
    // even when the player isn't comboing; the combo thresholds let a strong
    // player accelerate into Pressure / Breaker early.

    enum MatchFlow {
        /// 0…1 fractions of session duration at which the clock-driven phase
        /// floor escalates. A player at 0 combo who never misses still moves
        /// `warm-up → exchange → pressure → breaker` at these marks.
        static let warmUpProgress:   Double = 0.28
        static let pressureProgress: Double = 0.68
        static let breakerProgress:  Double = 0.91

        /// BPM per phase. The procedural beatmap regenerates chart chunks at
        /// these tempos so the spawn density visibly shifts.
        static let bpmWarmUp:    Double = 76
        static let bpmExchange:  Double = 102
        static let bpmPressure:  Double = 126
        static let bpmBreaker:   Double = 148

        /// How long the spawner stays in `.recovery` after a combo break.
        /// Short — just enough to clear the death-freeze + a beat or two.
        static let recoverySeconds: TimeInterval = 3.8
    }
}

extension Double {
    var seconds: TimeInterval { self / 1000.0 }
}

// MARK: - Live (runtime-mutable) feel knobs
//
// `Tunables` static-lets are the *spec*. `Tunables.live` is a small
// mirror of the feel knobs a designer actually wants to nudge at runtime
// (in the in-game DEBUG overlay), without rebuilding. The static-lets
// remain the authoritative defaults so a clean install always boots to
// the spec.
//
// Only the knobs included here are runtime-mutable. Everything else is
// still compiled in.

/// Snapshot of feel knobs that can be edited at runtime. Read-only from
/// gameplay; written only by the DEBUG tunables overlay.
///
/// IMPORTANT: All access is on the SpriteKit main thread. There is no
/// locking. If we ever expose this off-thread, switch to `OSAllocatedUnfairLock`.
struct LiveTunables {
    // Per-hit frame-stop (ms).
    var frameStopPerfectMs: Double = Tunables.frameStopPerfectMs
    var frameStopGreatMs:   Double = Tunables.frameStopGreatMs
    var frameStopDeathMs:   Double = Tunables.frameStopDeathMs

    // Camera shake amplitudes (points).
    var shakeAmplitudePerfect: CGFloat = Tunables.shakeAmplitudePerfect
    var shakeAmplitudeDeath:   CGFloat = Tunables.shakeAmplitudeDeath

    // Input.
    var swingMinDistance: CGFloat = Tunables.swingMinDistance

    // Anticipation pulse.
    var strikePulseLeadMs: Double = Tunables.strikePulseLeadMs

    // Ball pacing.
    var ballTravelSeconds: Double = Tunables.ballTravelSeconds

    // Haptic touch-down intensity is intentionally *not* exposed: the
    // `CHHapticPattern` is built once at engine warmup and would need a
    // rebuild to retake effect. Add it here if/when patterns can be
    // hot-rebuilt.
}

extension Tunables {
    /// Single mutable feel-knob bag. Migrate hot-path call sites to read
    /// from this instead of the static lets so the DEBUG overlay can
    /// retune them without a rebuild.
    static var live = LiveTunables()
}
