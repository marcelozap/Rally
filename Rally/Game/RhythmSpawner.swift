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

    enum Kind: String, Codable, Hashable {
        case normal
        case double   // requires both-lane simultaneous swipe
        case hold     // requires held swipe (future)
    }

    enum CodingKeys: String, CodingKey {
        case arrivalTime = "t"
        case lane
        case kind
    }
}

extension Lane: Codable {}

struct Beatmap: Codable {
    let trackID: String
    let bpm: Double
    let notes: [BeatmapNote]
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
            notes.append(BeatmapNote(arrivalTime: t, lane: lane, kind: .normal))
            lastLane = lane

            if progress > 0.6, rng.bool(p: 0.05) {
                notes.append(BeatmapNote(arrivalTime: t, lane: lane.opposite, kind: .double))
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
            let arrival = nextArrivalTime

            // Density: occasionally insert a rest (chart hole).
            if rng.unit() < profile.density {
                let lane: Lane = rng.bool(p: 0.75) ? lastLane.opposite : lastLane
                sink(BeatmapNote(arrivalTime: arrival, lane: lane, kind: .normal))
                lastLane = lane

                if rng.bool(p: profile.doubleNoteProbability) {
                    sink(BeatmapNote(arrivalTime: arrival, lane: lane.opposite, kind: .double))
                }
            }

            let subdivision = profile.subdivisions[
                rng.weightedIndex(weights: profile.subdivisionWeights)
            ]
            let beatSeconds = 60.0 / profile.bpm
            nextArrivalTime += beatSeconds * subdivision
        }
    }

    func reset() {
        nextIndex = 0
        nextArrivalTime = leadInSeconds
    }
}
