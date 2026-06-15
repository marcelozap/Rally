import XCTest
@testable import Rally

/// Locks the client-side mirror of the server merge rule so a regression
/// can't silently let a stale device blow away accrued progress.
final class ProgressMergeTests: XCTestCase {

    private func payload(
        coins: Int = 0, xp: Int = 0,
        bestScore: Int = 0, bestCombo: Int = 0,
        totalSessions: Int = 0,
        totalPerfectHits: Int = 0, totalGreatHits: Int = 0,
        totalGoodHits: Int = 0, totalMisses: Int = 0,
        dailyStreak: Int = 0, lastPlayDate: Date? = nil,
        id: UUID = UUID()
    ) -> ProgressPayload {
        ProgressPayload(
            id: id, coins: coins, xp: xp,
            bestScore: bestScore, bestCombo: bestCombo,
            totalSessions: totalSessions,
            totalPerfectHits: totalPerfectHits, totalGreatHits: totalGreatHits,
            totalGoodHits: totalGoodHits, totalMisses: totalMisses,
            dailyStreak: dailyStreak, lastPlayDate: lastPlayDate
        )
    }

    func testNumericsTakeMaxOnEachSide() {
        let server = payload(coins: 200, xp: 500, bestScore: 1200, bestCombo: 40, totalSessions: 10)
        let client = payload(coins: 150, xp: 600, bestScore: 900,  bestCombo: 55, totalSessions: 8)
        let merged = ProgressPayload.mergedMaxWins(server: server, client: client)
        XCTAssertEqual(merged.coins, 200)
        XCTAssertEqual(merged.xp, 600)
        XCTAssertEqual(merged.bestScore, 1200)
        XCTAssertEqual(merged.bestCombo, 55)
        XCTAssertEqual(merged.totalSessions, 10)
    }

    func testIdFollowsClientSide() {
        let serverID = UUID()
        let clientID = UUID()
        let merged = ProgressPayload.mergedMaxWins(
            server: payload(id: serverID),
            client: payload(id: clientID)
        )
        XCTAssertEqual(merged.id, clientID)
    }

    func testLastPlayDateKeepsTheLater() {
        let early = Date(timeIntervalSince1970: 1_000_000)
        let later = Date(timeIntervalSince1970: 2_000_000)
        let merged = ProgressPayload.mergedMaxWins(
            server: payload(lastPlayDate: later),
            client: payload(lastPlayDate: early)
        )
        XCTAssertEqual(merged.lastPlayDate, later)
    }

    func testLastPlayDateHandlesNils() {
        let date = Date(timeIntervalSince1970: 1_500_000)
        let withDate = payload(lastPlayDate: date)
        let noDate = payload(lastPlayDate: nil)
        XCTAssertEqual(ProgressPayload.mergedMaxWins(server: noDate, client: withDate).lastPlayDate, date)
        XCTAssertEqual(ProgressPayload.mergedMaxWins(server: withDate, client: noDate).lastPlayDate, date)
        XCTAssertNil(ProgressPayload.mergedMaxWins(server: noDate, client: noDate).lastPlayDate)
    }

    func testStaleClientCannotLowerBestScore() {
        // The headline scenario the merge exists to prevent.
        let serverBest = 5000
        let server = payload(bestScore: serverBest, bestCombo: 80)
        let staleClient = payload(bestScore: 100, bestCombo: 10) // never played long enough to know about 5000
        let merged = ProgressPayload.mergedMaxWins(server: server, client: staleClient)
        XCTAssertEqual(merged.bestScore, serverBest, "Stale client must never overwrite a higher server best")
        XCTAssertEqual(merged.bestCombo, 80)
    }

    func testSyncRevisionStoreRoundTripsAndClears() {
        let suite = "RallySyncRevisionStoreTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer {
            defaults.removePersistentDomain(forName: suite)
        }

        XCTAssertNil(RallySyncRevisionStore.load(defaults: defaults))
        RallySyncRevisionStore.save(42, defaults: defaults)
        XCTAssertEqual(RallySyncRevisionStore.load(defaults: defaults), 42)
        RallySyncRevisionStore.clear(defaults: defaults)
        XCTAssertNil(RallySyncRevisionStore.load(defaults: defaults))
    }
}
