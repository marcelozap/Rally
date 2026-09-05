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
            skinToneOverrideRaw: AvatarSkinTone.tan.rawValue,
            hairColorOverrideHex: AvatarHairColor.blonde.hex,
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
        XCTAssertEqual(decoded.skinToneOverrideRaw, original.skinToneOverrideRaw)
        XCTAssertEqual(decoded.hairColorOverrideHex, original.hairColorOverrideHex)
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
        XCTAssertNil(oldPayload.skinToneOverrideRaw)
        XCTAssertNil(oldPayload.hairColorOverrideHex)
        let config = AvatarConfig()
        config.athletePreset = .femaleBlack
        config.skinToneOverride = .deep
        config.hairColorOverrideHex = AvatarHairColor.brown.hex

        RallySyncCoordinator.applyAvatar(oldPayload, to: config)

        XCTAssertEqual(config.athletePreset, .femaleBlack)
        XCTAssertEqual(config.skinToneOverride, .deep)
        XCTAssertEqual(config.hairColorOverrideHex, AvatarHairColor.brown.hex)
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
            skinToneOverrideRaw: AvatarSkinTone.medium.rawValue,
            hairColorOverrideHex: "#d9b477",
            equippedTopID: ShopCatalog.defaultTopID,
            equippedBottomID: ShopCatalog.defaultBottomID,
            equippedShoesID: ShopCatalog.defaultShoesID,
            equippedRacketID: ShopCatalog.defaultRacketID,
            hasCompletedSetup: true
        )

        RallySyncCoordinator.applyAvatar(payload, to: config)
        XCTAssertEqual(config.athletePreset, .femaleEuropean)
        XCTAssertEqual(RallyAvatarAppearance(config: config).athleteModel, .female)
        XCTAssertEqual(config.skinToneOverride, .medium)
        XCTAssertEqual(config.hairColorOverrideHex, "#D9B477")

        payload.athletePresetRaw = "future-player"
        payload.skinToneOverrideRaw = "unknown-tone"
        payload.hairColorOverrideHex = "invalid-color"
        RallySyncCoordinator.applyAvatar(payload, to: config)
        XCTAssertEqual(config.athletePreset, .femaleEuropean)
        XCTAssertEqual(config.skinToneOverride, .medium)
        XCTAssertEqual(config.hairColorOverrideHex, "#D9B477")

        payload.skinToneOverrideRaw = nil
        payload.hairColorOverrideHex = nil
        RallySyncCoordinator.applyAvatar(payload, to: config)
        XCTAssertEqual(config.skinToneOverride, .medium)
        XCTAssertEqual(config.hairColorOverrideHex, "#D9B477")
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

    @MainActor
    func testExplicitNullColorFieldsFromOlderClientsPreserveLocalChoices() throws {
        let config = AvatarConfig()
        config.skinToneOverride = .tan
        config.hairColorOverrideHex = AvatarHairColor.blonde.hex
        let json: [String: Any] = [
            "id": config.id.uuidString,
            "playerName": "Player",
            "skinToneRaw": "light",
            "hairStyleRaw": "short",
            "hairColorHex": "#080809",
            "bodyTypeRaw": "athletic",
            "skinToneOverrideRaw": NSNull(),
            "hairColorOverrideHex": NSNull(),
            "equippedTopID": config.equippedTopID,
            "equippedBottomID": config.equippedBottomID,
            "equippedShoesID": config.equippedShoesID,
            "equippedRacketID": config.equippedRacketID,
            "hasCompletedSetup": true,
        ]
        let payload = try JSONDecoder().decode(AvatarPayload.self, from: JSONSerialization.data(withJSONObject: json))

        RallySyncCoordinator.applyAvatar(payload, to: config)

        XCTAssertEqual(config.skinToneOverride, .tan)
        XCTAssertEqual(config.hairColorOverrideHex, AvatarHairColor.blonde.hex)
    }
}
