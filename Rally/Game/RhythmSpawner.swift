import Foundation

/// Beatmap-driven ball spawner. See `GDD.md §1.3`.
///
/// This is intentionally engine-agnostic: it computes _when_ a ball should
/// be spawned (relative to track time) and lets the scene decide _how_ to
/// spawn it. That makes the spawner trivially unit-testable.
struct BeatmapNote: Codable, Hashable {
    /// Time at which the ball should _arrive at the strike line_, in
    /// seconds from track start.
    let arrivalTime: Double
    let lane: Lane
    let kind: Kind
    let role: Role

    enum Kind: String, Codable, Hashable {
        case normal
        case double   // requires both-lane simultaneous swipe
        case hold     // requires held swipe (future)
    }

    enum Role: String, Codable, Hashable {
        case serve
        case returnBall
        case rally
        case changeup
    }

    enum CodingKeys: String, CodingKey {
        case arrivalTime = "t"
        case lane
        case kind
        case role
    }
}

extension Lane: Codable {}

struct Beatmap: Codable {
    let trackID: String
    let bpm: Double
    let notes: [BeatmapNote]
}

struct RallyInfluence {
    enum Shape {
        case drive
        case topspin
        case slice
        case defensive
    }

    let preferredLane: Lane
    let alternateLane: Lane
    let shape: Shape
    let pressure: Double
}

extension Beatmap {
    /// Build a difficulty-ramping procedural beatmap when no authored chart
    /// is available. Subdivisions get tighter as the run progresses:
    ///
    /// ```
    /// 0 → 25% elapsed:   quarter notes               (slow, instructional)
    /// 25 → 50% elapsed:  quarter/eighth mix
    /// 50 → 75% elapsed:  eighth notes                (peak flow state)
    /// 75 → 100% elapsed: eighth/sixteenth mix        (high-pressure)
    /// ```
    ///
    /// Lane choice favors alternation (so the player physically rocks back
    /// and forth) but with deliberate "same-lane repeats" sprinkled in to
    /// keep them honest. A 5% double-ball probability kicks in past 60%
    /// elapsed for the visual impact of two simultaneous neon hits.
    ///
    /// Retained as a fallback / unit-test fixture; live gameplay now uses
    /// `RhythmSpawner` in phase-driven mode (see `MatchFlowCoordinator`).
    static func procedural(
        durationSeconds: Double,
        startBPM: Double = 90,
        endBPM:   Double = 150,
        leadInSeconds: Double = 1.5,
        seed: UInt64 = 0xBADC0FFEE
    ) -> Beatmap {
        var rng = SeededRandom(seed: seed)
        var notes: [BeatmapNote] = []
        var lastLane: Lane = .left
        var t: Double = leadInSeconds

        while t < durationSeconds {
            let progress = min(1, max(0, (t - leadInSeconds) / (durationSeconds - leadInSeconds)))
            let currentBPM = startBPM + (endBPM - startBPM) * progress
            let beatSeconds = 60.0 / currentBPM

            let subdivision: Double
            switch progress {
            case ..<0.25: subdivision = 1.0
            case ..<0.50: subdivision = rng.bool(p: 0.6) ? 1.0 : 0.5
            case ..<0.75: subdivision = 0.5
            default:      subdivision = rng.bool(p: 0.7) ? 0.5 : 0.25
            }

            // Alternate lanes 75% of the time; same-lane repeat 25%.
            let lane: Lane = rng.bool(p: 0.75) ? lastLane.opposite : lastLane
            notes.append(BeatmapNote(arrivalTime: t, lane: lane, kind: .normal, role: .rally))
            lastLane = lane

            if progress > 0.6, rng.bool(p: 0.05) {
                notes.append(BeatmapNote(arrivalTime: t, lane: lane.opposite, kind: .double, role: .changeup))
            }

            t += beatSeconds * subdivision
        }

        return Beatmap(
            trackID: "procedural-v1",
            bpm: (startBPM + endBPM) / 2,
            notes: notes
        )
    }
}

/// Tiny xorshift PRNG — deterministic, fast, allocation-free. Used by the
/// procedural beatmap so a given seed always produces an identical chart.
struct SeededRandom {
    private var state: UInt64

    init(seed: UInt64) {
        // Avoid the zero state which xorshift can't escape.
        self.state = seed == 0 ? 0xCAFEBABE_DEADBEEF : seed
    }

    mutating func next() -> UInt64 {
        var x = state
        x ^= x << 13
        x ^= x >> 7
        x ^= x << 17
        state = x
        return x
    }

    mutating func unit() -> Double {
        Double(next() >> 11) / Double(1 << 53)
    }

    mutating func bool(p: Double) -> Bool { unit() < p }

    /// Pick an index according to non-negative weights.
    mutating func weightedIndex(weights: [Double]) -> Int {
        let total = weights.reduce(0, +)
        guard total > 0 else { return 0 }
        let r = unit() * total
        var acc: Double = 0
        for (i, w) in weights.enumerated() {
            acc += w
            if r <= acc { return i }
        }
        return weights.count - 1
    }
}

/// Spawner. Two operating modes:
///
/// 1. **Precomputed beatmap** (legacy / test fixture) — feed a `Beatmap` and
///    notes are emitted as their arrival horizon is reached.
///
/// 2. **Phase-driven** — feed a `MatchFlowCoordinator` and the spawner
///    authors the next note on the fly using the coordinator's current
///    `PhaseProfile`. BPM, density, double-ball probability and subdivision
///    weights all change as the match flow shifts.
final class RhythmSpawner {

    private enum RallyPattern {
        case neutralCrosscourt
        case pressureChange
        case servePlusOne
        case returnScramble
    }

    /// How long a ball takes to traverse the screen, in seconds, at the
    /// current difficulty. Scene owns this and updates it as the phase
    /// changes (warm-up = slower, breaker = faster).
    var travelSeconds: Double

    private let sink: (BeatmapNote) -> Void

    // Mode 1 (precomputed)
    private let beatmap: Beatmap?
    private var nextIndex: Int = 0

    // Mode 2 (phase-driven)
    private let flow: MatchFlowCoordinator?
    private let leadInSeconds: Double
    private var rng: SeededRandom
    /// Arrival time of the *next* not-yet-emitted note in phase-driven mode.
    private var nextArrivalTime: Double
    private var lastLane: Lane = .left
    private var sameLaneRunLength: Int = 1
    private var lastSubdivision: Double = 1.0
    private var consecutiveSixteenthCount: Int = 0
    private var lastDoubleArrivalTime: Double = -.infinity
    private var currentPattern: RallyPattern = .neutralCrosscourt
    private var patternRemainingNotes: Int = 0
    private var serveSeedLane: Lane = .right
    private var pendingInfluence: RallyInfluence?
    private var emittedNoteCount: Int = 0

    /// Designated init for legacy precomputed-beatmap mode.
    init(beatmap: Beatmap, travelSeconds: Double, sink: @escaping (BeatmapNote) -> Void) {
        self.beatmap = beatmap
        self.flow = nil
        self.travelSeconds = travelSeconds
        self.sink = sink
        self.leadInSeconds = 0
        self.rng = SeededRandom(seed: 0)
        self.nextArrivalTime = 0
    }

    /// Designated init for phase-driven live authoring. `flow` provides the
    /// `PhaseProfile` used for each new note.
    init(
        flow: MatchFlowCoordinator,
        travelSeconds: Double,
        leadInSeconds: Double = 1.5,
        seed: UInt64 = 0xBADC0FFEE,
        sink: @escaping (BeatmapNote) -> Void
    ) {
        self.beatmap = nil
        self.flow = flow
        self.travelSeconds = travelSeconds
        self.sink = sink
        self.leadInSeconds = leadInSeconds
        self.rng = SeededRandom(seed: seed)
        self.nextArrivalTime = leadInSeconds
    }

    /// Drive this every frame from `GameScene.update(_:)`. `trackTime` is
    /// the current playhead position of the soundtrack, in seconds.
    func tick(trackTime: Double) {
        let spawnHorizon = trackTime + travelSeconds

        if let beatmap = beatmap {
            while nextIndex < beatmap.notes.count,
                  beatmap.notes[nextIndex].arrivalTime <= spawnHorizon
            {
                sink(beatmap.notes[nextIndex])
                nextIndex += 1
            }
            return
        }

        guard let flow = flow else { return }

        // Phase-driven authoring. Emit *all* notes whose arrival time has
        // dropped past the spawn horizon, then advance `nextArrivalTime` by
        // one phase-shaped beat increment for the next call.
        while nextArrivalTime <= spawnHorizon {
            let profile = flow.currentProfile()
            let phase = flow.currentPhase
            let arrival = nextArrivalTime

            // Density: occasionally insert a rest (chart hole).
            if rng.unit() < profile.density {
                let lane = chooseLane(for: phase)
                let role = roleForCurrentPattern()
                sink(BeatmapNote(arrivalTime: arrival, lane: lane, kind: .normal, role: role))
                emittedNoteCount += 1

                if shouldEmitDouble(
                    profile: profile,
                    phase: phase,
                    arrivalTime: arrival,
                    subdivision: lastSubdivision
                ) {
                    sink(BeatmapNote(arrivalTime: arrival, lane: lane.opposite, kind: .double, role: .changeup))
                    lastDoubleArrivalTime = arrival
                }
            }

            let subdivision = chooseSubdivision(for: profile, phase: phase)
            let beatSeconds = 60.0 / profile.bpm
            nextArrivalTime += beatSeconds * subdivision
        }
    }

    func reset() {
        nextIndex = 0
        nextArrivalTime = leadInSeconds
        lastLane = .left
        sameLaneRunLength = 1
        lastSubdivision = 1.0
        consecutiveSixteenthCount = 0
        lastDoubleArrivalTime = -.infinity
        currentPattern = .neutralCrosscourt
        patternRemainingNotes = 0
        serveSeedLane = .right
        pendingInfluence = nil
        emittedNoteCount = 0
    }

    func applyInfluence(_ influence: RallyInfluence) {
        pendingInfluence = influence
    }

    private func chooseLane(for phase: MatchFlowPhase) -> Lane {
        if phase == .warmUp, emittedNoteCount < 6 {
            let lane: Lane = emittedNoteCount.isMultiple(of: 2) ? .right : .left
            updateLaneRunTracking(with: lane)
            return lane
        }

        refreshPatternIfNeeded(for: phase)

        if let influencedLane = consumeInfluencedLane(for: phase) {
            patternRemainingNotes = max(0, patternRemainingNotes - 1)
            updateLaneRunTracking(with: influencedLane)
            return influencedLane
        }

        let patternLane: Lane
        switch currentPattern {
        case .neutralCrosscourt:
            patternLane = chooseAlternatingLane(repeatProbability: repeatProbability(for: phase) * 0.45)
        case .pressureChange:
            patternLane = choosePressureLane()
        case .servePlusOne:
            patternLane = chooseServePlusOneLane()
        case .returnScramble:
            patternLane = chooseReturnScrambleLane()
        }

        let lane = laneCappedToAlternation(patternLane)
        patternRemainingNotes = max(0, patternRemainingNotes - 1)
        updateLaneRunTracking(with: lane)
        return lane
    }

    private func consumeInfluencedLane(for phase: MatchFlowPhase) -> Lane? {
        guard let pendingInfluence else { return nil }

        let sameLaneAllowed = sameLaneRunLength < Tunables.maxSameLaneRun
        let preferred = pendingInfluence.preferredLane
        let fallback = pendingInfluence.alternateLane

        let preferredProbability: Double
        switch pendingInfluence.shape {
        case .drive:
            preferredProbability = phase == .pressure || phase == .breaker ? 0.78 : 0.68
        case .topspin:
            preferredProbability = phase == .pressure || phase == .breaker ? 0.62 : 0.54
        case .slice:
            preferredProbability = 0.42
        case .defensive:
            preferredProbability = 0.34
        }

        let weightedPreferred = min(0.9, max(0.18, preferredProbability + pendingInfluence.pressure * 0.16))
        let choosePreferred = rng.bool(p: weightedPreferred)

        self.pendingInfluence = nil

        if choosePreferred, (preferred != lastLane || sameLaneAllowed) {
            return preferred
        }
        if fallback != lastLane || sameLaneAllowed {
            return fallback
        }
        return lastLane.opposite
    }

    private func refreshPatternIfNeeded(for phase: MatchFlowPhase) {
        guard patternRemainingNotes == 0 else { return }

        if phase == .warmUp, emittedNoteCount < 6 {
            currentPattern = .servePlusOne
            patternRemainingNotes = 2
            serveSeedLane = emittedNoteCount < 2 ? .right : .left
            return
        }

        currentPattern = pickPattern(for: phase)
        patternRemainingNotes = patternLength(for: currentPattern, phase: phase)
        if currentPattern == .servePlusOne || currentPattern == .returnScramble {
            serveSeedLane = rng.bool(p: 0.5) ? .left : .right
        }
    }

    private func pickPattern(for phase: MatchFlowPhase) -> RallyPattern {
        switch phase {
        case .warmUp:
            return .servePlusOne
        case .recovery:
            return .returnScramble
        case .exchange:
            let roll = rng.unit()
            if roll < 0.18 { return .servePlusOne }
            if roll < 0.30 { return .returnScramble }
            return .neutralCrosscourt
        case .pressure:
            let roll = rng.unit()
            if roll < 0.52 { return .pressureChange }
            if roll < 0.72 { return .servePlusOne }
            return .neutralCrosscourt
        case .breaker:
            let roll = rng.unit()
            if roll < 0.6 { return .pressureChange }
            if roll < 0.82 { return .returnScramble }
            return .servePlusOne
        }
    }

    private func patternLength(for pattern: RallyPattern, phase: MatchFlowPhase) -> Int {
        switch pattern {
        case .neutralCrosscourt:
            return min(Tunables.maximumPatternLength, phase == .breaker ? 3 : 4)
        case .pressureChange:
            return max(Tunables.minimumPatternLength, 3)
        case .servePlusOne:
            return 2
        case .returnScramble:
            return phase == .recovery ? 2 : 3
        }
    }

    private func chooseAlternatingLane(repeatProbability: Double) -> Lane {
        let canRepeat = sameLaneRunLength < Tunables.maxSameLaneRun
        let shouldRepeat = canRepeat && rng.bool(p: repeatProbability)
        return shouldRepeat ? lastLane : lastLane.opposite
    }

    private func laneCappedToAlternation(_ lane: Lane) -> Lane {
        if lane == lastLane, sameLaneRunLength >= Tunables.maxSameLaneRun {
            return lastLane.opposite
        }
        return lane
    }

    private func choosePressureLane() -> Lane {
        if patternRemainingNotes <= 1 {
            return lastLane.opposite
        }
        let pinProbability = patternRemainingNotes == 3 ? 0.22 : 0.38
        let canRepeat = sameLaneRunLength < Tunables.maxSameLaneRun
        if canRepeat && rng.bool(p: pinProbability) {
            return lastLane
        }
        return lastLane.opposite
    }

    private func chooseServePlusOneLane() -> Lane {
        switch patternRemainingNotes {
        case let n where n >= 2:
            return serveSeedLane
        default:
            return serveSeedLane.opposite
        }
    }

    private func chooseReturnScrambleLane() -> Lane {
        switch patternRemainingNotes {
        case let n where n >= 3:
            return serveSeedLane.opposite
        case 2:
            return serveSeedLane
        default:
            return rng.bool(p: 0.7) ? serveSeedLane.opposite : serveSeedLane
        }
    }

    private func roleForCurrentPattern() -> BeatmapNote.Role {
        if emittedNoteCount < 2 {
            return .serve
        }
        if emittedNoteCount < 4 {
            return .returnBall
        }

        switch currentPattern {
        case .neutralCrosscourt:
            return .rally
        case .pressureChange:
            return patternRemainingNotes <= 1 ? .changeup : .rally
        case .servePlusOne:
            return patternRemainingNotes >= 2 ? .serve : .returnBall
        case .returnScramble:
            if patternRemainingNotes >= 3 { return .returnBall }
            return patternRemainingNotes == 2 ? .rally : .changeup
        }
    }

    private func repeatProbability(for phase: MatchFlowPhase) -> Double {
        let sameLaneProbability: Double
        switch phase {
        case .warmUp, .recovery:
            sameLaneProbability = 0.10
        case .exchange:
            sameLaneProbability = 0.16
        case .pressure:
            sameLaneProbability = 0.22
        case .breaker:
            sameLaneProbability = 0.28
        }
        return sameLaneProbability
    }

    private func updateLaneRunTracking(with lane: Lane) {
        if lane == lastLane {
            sameLaneRunLength += 1
        } else {
            sameLaneRunLength = 1
        }
        lastLane = lane
    }

    private func chooseSubdivision(for profile: PhaseProfile, phase: MatchFlowPhase) -> Double {
        if phase == .warmUp, emittedNoteCount < 8 {
            lastSubdivision = 1.0
            consecutiveSixteenthCount = 0
            return 1.0
        }

        var subdivision = profile.subdivisions[
            rng.weightedIndex(weights: profile.subdivisionWeights)
        ]

        if subdivision == 0.25 {
            let hardCapReached = consecutiveSixteenthCount >= Tunables.maxConsecutiveSixteenths
            let phaseTooCalm = phase == .warmUp || phase == .exchange || phase == .recovery
            let cameRightAfterDouble = nextArrivalTime - lastDoubleArrivalTime < 0.4
            if hardCapReached || phaseTooCalm || cameRightAfterDouble {
                subdivision = 0.5
            }
        }

        if subdivision == 0.25 {
            consecutiveSixteenthCount += 1
        } else {
            consecutiveSixteenthCount = 0
        }
        lastSubdivision = subdivision
        return subdivision
    }

    private func shouldEmitDouble(
        profile: PhaseProfile,
        phase: MatchFlowPhase,
        arrivalTime: Double,
        subdivision: Double
    ) -> Bool {
        guard profile.doubleNoteProbability > 0 else { return false }
        guard phase == .pressure || phase == .breaker else { return false }
        guard subdivision >= 0.5 else { return false }

        let beatSeconds = 60.0 / profile.bpm
        let minimumGap = max(beatSeconds * Tunables.minimumDoubleGapBeats, 0.8)
        guard arrivalTime - lastDoubleArrivalTime >= minimumGap else { return false }

        return rng.bool(p: profile.doubleNoteProbability)
    }
}
