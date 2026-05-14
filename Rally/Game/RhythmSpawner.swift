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

/// Pulls notes out of a `Beatmap` and emits them to a sink as their
/// _spawn_ time arrives, accounting for travel time from spawn point to
/// strike line.
final class RhythmSpawner {

    /// How long a ball takes to traverse the screen, in seconds, at the
    /// current difficulty. The scene owns this and updates it as the run
    /// progresses.
    var travelSeconds: Double

    private let beatmap: Beatmap
    private var nextIndex: Int = 0

    /// `sink` is invoked at the moment a note should be spawned.
    private let sink: (BeatmapNote) -> Void

    init(beatmap: Beatmap, travelSeconds: Double, sink: @escaping (BeatmapNote) -> Void) {
        self.beatmap = beatmap
        self.travelSeconds = travelSeconds
        self.sink = sink
    }

    /// Drive this every frame from `GameScene.update(_:)`. `trackTime` is
    /// the current playhead position of the soundtrack, in seconds.
    func tick(trackTime: Double) {
        let spawnHorizon = trackTime + travelSeconds
        while nextIndex < beatmap.notes.count,
              beatmap.notes[nextIndex].arrivalTime <= spawnHorizon
        {
            sink(beatmap.notes[nextIndex])
            nextIndex += 1
        }
    }

    func reset() { nextIndex = 0 }
}
