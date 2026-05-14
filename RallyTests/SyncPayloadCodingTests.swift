import XCTest
@testable import Rally

final class SyncPayloadCodingTests: XCTestCase {

    func testAvatarPayloadRoundtrip() throws {
        let id = UUID()
        let original = AvatarPayload(
            id: id,
            playerName: "Test Player",
            skinToneRaw: "medium",
            hairStyleRaw: "short",
            hairColorHex: "#112233",
            bodyTypeRaw: "athletic",
            equippedTopID: ShopCatalog.defaultTopID,
            equippedBottomID: ShopCatalog.defaultBottomID,
            equippedShoesID: ShopCatalog.defaultShoesID,
            equippedRacketID: ShopCatalog.defaultRacketID,
            hasCompletedSetup: true
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        let data = try encoder.encode(original)
        let decoded = try decoder.decode(AvatarPayload.self, from: data)

        XCTAssertEqual(decoded.id, original.id)
        XCTAssertEqual(decoded.playerName, original.playerName)
        XCTAssertEqual(decoded.skinToneRaw, original.skinToneRaw)
        XCTAssertEqual(decoded.hasCompletedSetup, original.hasCompletedSetup)
    }

    func testSetScoreCSVCodec() {
        let sets = [
            SetScore(won: 6, lost: 4, tiebreak: nil),
            SetScore(won: 7, lost: 6, tiebreak: 5),
        ]
        let csv = SetScore.encode(sets)
        let roundtrip = SetScore.decode(csv)
        XCTAssertEqual(roundtrip.count, 2)
        XCTAssertEqual(roundtrip[0].won, 6)
        XCTAssertEqual(roundtrip[1].tiebreak, 5)
    }
}
