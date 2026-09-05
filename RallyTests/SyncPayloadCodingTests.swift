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
            athletePresetRaw: RallyAthletePreset.femaleAsian.rawValue,
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
        XCTAssertEqual(decoded.athletePresetRaw, original.athletePresetRaw)
        XCTAssertEqual(decoded.hasCompletedSetup, original.hasCompletedSetup)
    }

    @MainActor
    func testLegacyAvatarPayloadKeepsLocalPlayerSelection() throws {
        let data = Data("""
        {
          "id": "00000000-0000-0000-0000-000000000001",
          "playerName": "Returning player",
          "skinToneRaw": "medium",
          "hairStyleRaw": "medium",
          "hairColorHex": "#050507",
          "bodyTypeRaw": "athletic",
          "equippedTopID": "remote.top",
          "equippedBottomID": "remote.bottom",
          "equippedShoesID": "remote.shoes",
          "equippedRacketID": "remote.racket",
          "hasCompletedSetup": true
        }
        """.utf8)
        let oldPayload = try JSONDecoder().decode(AvatarPayload.self, from: data)
        XCTAssertNil(oldPayload.athletePresetRaw)
        let config = AvatarConfig()
        config.athletePreset = .femaleBlack

        RallySyncCoordinator.applyAvatar(oldPayload, to: config)

        XCTAssertEqual(config.athletePreset, .femaleBlack)
        XCTAssertEqual(config.equippedTopID, "remote.top")
        XCTAssertEqual(config.playerName, "Returning player")
    }

    @MainActor
    func testSyncedPlayerChoiceUpdatesIdentityAndIgnoresUnknownPreset() {
        let config = AvatarConfig()
        var payload = AvatarPayload(
            id: config.id,
            playerName: "Test player",
            skinToneRaw: "light",
            hairStyleRaw: "short",
            hairColorHex: "#080809",
            bodyTypeRaw: "athletic",
            athletePresetRaw: RallyAthletePreset.femaleEuropean.rawValue,
            equippedTopID: ShopCatalog.defaultTopID,
            equippedBottomID: ShopCatalog.defaultBottomID,
            equippedShoesID: ShopCatalog.defaultShoesID,
            equippedRacketID: ShopCatalog.defaultRacketID,
            hasCompletedSetup: true
        )

        RallySyncCoordinator.applyAvatar(payload, to: config)
        XCTAssertEqual(config.athletePreset, .femaleEuropean)
        XCTAssertEqual(RallyAvatarAppearance(config: config).athleteModel, .female)

        payload.athletePresetRaw = "future-player"
        RallySyncCoordinator.applyAvatar(payload, to: config)
        XCTAssertEqual(config.athletePreset, .femaleEuropean)
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
