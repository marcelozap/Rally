import XCTest
@testable import Rally

final class RhythmSpawnerTests: XCTestCase {

    func testLaneRunsAreCapped() {
        let coordinator = MatchFlowCoordinator(sessionDurationSeconds: 180)
        coordinator.update(trackTime: 90, combo: 20)

        var notes: [BeatmapNote] = []
        let spawner = RhythmSpawner(flow: coordinator, travelSeconds: Tunables.ballTravelSeconds, seed: 7) {
            notes.append($0)
        }

        for tick in stride(from: 0.0, through: 18.0, by: 0.1) {
            spawner.tick(trackTime: tick)
        }

        let normalLanes = notes
            .filter { $0.kind == .normal }
            .map(\.lane)

        XCTAssertFalse(normalLanes.isEmpty)

        var run = 1
        var maxRun = 1
        for idx in 1..<normalLanes.count {
            if normalLanes[idx] == normalLanes[idx - 1] {
                run += 1
                maxRun = max(maxRun, run)
            } else {
                run = 1
            }
        }

        XCTAssertLessThanOrEqual(maxRun, Tunables.maxSameLaneRun)
    }

    func testDoublesHaveBreathingRoom() {
        let coordinator = MatchFlowCoordinator(sessionDurationSeconds: 180)
        coordinator.update(trackTime: 170, combo: 45)

        var notes: [BeatmapNote] = []
        let spawner = RhythmSpawner(flow: coordinator, travelSeconds: Tunables.ballTravelSeconds, seed: 99) {
            notes.append($0)
        }

        for tick in stride(from: 0.0, through: 22.0, by: 0.1) {
            spawner.tick(trackTime: tick)
        }

        let doubleArrivals = notes
            .filter { $0.kind == .double }
            .map(\.arrivalTime)
            .sorted()

        let minimumGap = max(
            (60.0 / coordinator.profile(for: .breaker).bpm) * Tunables.minimumDoubleGapBeats,
            0.8
        )

        for pair in zip(doubleArrivals, doubleArrivals.dropFirst()) {
            XCTAssertGreaterThanOrEqual(pair.1 - pair.0, minimumGap - 0.0001)
        }
    }

    func testWarmUpAlternatesForehandBackhandOpener() {
        let coordinator = MatchFlowCoordinator(sessionDurationSeconds: 180)
        coordinator.update(trackTime: 5, combo: 0)

        var notes: [BeatmapNote] = []
        let spawner = RhythmSpawner(flow: coordinator, travelSeconds: Tunables.ballTravelSeconds, seed: 3) {
            notes.append($0)
        }

        for tick in stride(from: 0.0, through: 6.0, by: 0.1) {
            spawner.tick(trackTime: tick)
        }

        let normalLanes = notes.filter { $0.kind == .normal }.map(\.lane)
        XCTAssertGreaterThanOrEqual(normalLanes.count, 2)
        XCTAssertNotEqual(normalLanes[0], normalLanes[1])
    }

    func testPressureAlternatesAcrossBothDirections() {
        let coordinator = MatchFlowCoordinator(sessionDurationSeconds: 180)
        coordinator.update(trackTime: 120, combo: 25)

        var notes: [BeatmapNote] = []
        let spawner = RhythmSpawner(flow: coordinator, travelSeconds: Tunables.ballTravelSeconds, seed: 17) {
            notes.append($0)
        }

        for tick in stride(from: 0.0, through: 10.0, by: 0.1) {
            spawner.tick(trackTime: tick)
        }

        let normalLanes = notes.filter { $0.kind == .normal }.map(\.lane)
        XCTAssertGreaterThanOrEqual(normalLanes.count, 4)

        for pair in zip(normalLanes, normalLanes.dropFirst()) {
            XCTAssertNotEqual(pair.0, pair.1)
        }

        XCTAssertTrue(normalLanes.contains(.left))
        XCTAssertTrue(normalLanes.contains(.right))
    }
}
