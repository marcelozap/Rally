import XCTest
import SwiftData
@testable import Rally

final class RallyDefaultsTests: XCTestCase {

    private var defaults: UserDefaults!
    private var suiteName: String!

    override func setUp() {
        super.setUp()
        suiteName = "RallyDefaultsTests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)!
        clearSoundKeys()
    }

    override func tearDown() {
        clearSoundKeys()
        defaults.removePersistentDomain(forName: suiteName)
        defaults = nil
        suiteName = nil
        super.tearDown()
    }

    func testSoundDefaultsToOffForFreshInstall() {
        XCTAssertFalse(RallyDefaults.resolvedSoundEnabled(defaults))
    }

    func testQuietDefaultMigrationForcesSoundOffOnce() {
        defaults.set(true, forKey: UserDefaultsKeys.soundEnabled)

        RallyDefaults.applyQuietSoundDefaultIfNeeded(defaults)

        XCTAssertTrue(defaults.bool(forKey: UserDefaultsKeys.soundQuietDefaultApplied))
        XCTAssertTrue(defaults.bool(forKey: UserDefaultsKeys.soundPreferenceExplicitlySet))
        XCTAssertFalse(defaults.bool(forKey: UserDefaultsKeys.soundEnabled))
        XCTAssertFalse(RallyDefaults.resolvedSoundEnabled(defaults))
    }

    func testPlayerCanOptBackIntoSoundAfterMigration() {
        RallyDefaults.applyQuietSoundDefaultIfNeeded(defaults)
        defaults.set(true, forKey: UserDefaultsKeys.soundEnabled)
        defaults.set(true, forKey: UserDefaultsKeys.soundPreferenceExplicitlySet)

        RallyDefaults.applyQuietSoundDefaultIfNeeded(defaults)

        XCTAssertTrue(RallyDefaults.resolvedSoundEnabled(defaults))
    }

    func testAutoplayLaunchForcesSoundOffEvenAfterOptIn() {
        RallyDefaults.applyQuietSoundDefaultIfNeeded(defaults)
        defaults.set(true, forKey: UserDefaultsKeys.soundEnabled)
        defaults.set(true, forKey: UserDefaultsKeys.soundPreferenceExplicitlySet)

        XCTAssertFalse(
            RallyDefaults.resolvedSoundEnabled(defaults, arguments: ["Rally", "-RallyAutoPlay"])
        )
    }

    func testRosterContainsThreeMenAndThreeWomen() {
        XCTAssertEqual(RallyAthletePreset.allCases.count, 6)
        for model in RallyAthleteModel.allCases {
            let players = RallyAthletePreset.allCases.filter { $0.athleteModel == model }
            XCTAssertEqual(players.count, 3)
            XCTAssertEqual(Set(players.map(\.heritageDescription)), ["White / European", "Asian", "Black"])
            XCTAssertEqual(players.map(\.displayName), ["Model 1", "Model 2", "Model 3"])
        }
    }

    func testLegacyAppearanceWithoutPresetDecodesAndRetainsOutfit() throws {
        let original = RallyAvatarAppearance()
        let data = try JSONEncoder().encode(original)
        var object = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        object.removeValue(forKey: "athletePreset")
        let legacyData = try JSONSerialization.data(withJSONObject: object)

        let decoded = try JSONDecoder().decode(RallyAvatarAppearance.self, from: legacyData)

        XCTAssertEqual(decoded.athletePreset, .maleEuropean)
        XCTAssertNil(decoded.skinToneOverrideHex)
        XCTAssertNil(decoded.hairColorOverrideHex)
        XCTAssertEqual(decoded.top, original.top)
        XCTAssertEqual(decoded.shorts, original.shorts)
        XCTAssertEqual(decoded.shoes, original.shoes)
        XCTAssertEqual(decoded.racket, original.racket)
    }

    func testEveryPlayerAppearanceRoundTrips() throws {
        for preset in RallyAthletePreset.allCases {
            for appearance in [
                RallyAvatarAppearance(athletePreset: preset),
                RallyAvatarAppearance(athletePreset: preset, skinToneOverrideHex: "#A06B40", hairColorOverrideHex: "#D9B477")
            ] {
                let decoded = try JSONDecoder().decode(RallyAvatarAppearance.self, from: JSONEncoder().encode(appearance))
                XCTAssertEqual(decoded, appearance)
                XCTAssertEqual(decoded.athleteModel, preset.athleteModel)
            }
        }
    }

    @MainActor
    func testRosterSelectionOverridesLegacyCustomizationAndKeepsClothes() {
        let config = AvatarConfig()
        config.bodyType = .strong
        config.skinTone = .fair
        config.hairStyle = .bald
        config.hairColorHex = "#FF00FF"
        config.equippedTopID = "player.selected.top"
        config.equippedBottomID = "player.selected.bottom"
        config.equippedShoesID = "player.selected.shoes"
        config.equippedRacketID = "player.selected.racket"

        for preset in RallyAthletePreset.allCases {
            config.athletePreset = preset
            let appearance = RallyAvatarAppearance(config: config)
            XCTAssertEqual(appearance.athletePreset, preset)
            XCTAssertEqual(appearance.bodyProfile, .athletic)
            XCTAssertEqual(appearance.skinToneHex, preset.skinTone.hex)
            XCTAssertEqual(appearance.hairColorHex, preset.hairColorHex)
            XCTAssertNil(appearance.skinToneOverrideHex)
            XCTAssertNil(appearance.hairColorOverrideHex)
            XCTAssertEqual(appearance.hairStyle, RallyAvatarHairProfile(hairStyle: preset.hairStyle, hairColorHex: preset.hairColorHex))
            XCTAssertEqual(appearance.top?.id, "player.selected.top")
            XCTAssertEqual(appearance.shorts?.id, "player.selected.bottom")
            XCTAssertEqual(appearance.shoes?.id, "player.selected.shoes")
            XCTAssertEqual(appearance.racket?.id, "player.selected.racket")
        }
    }

    @MainActor
    func testPlayerSelectionPersistsAndFeedsSharedAppearanceStore() throws {
        let storeDirectory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: storeDirectory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: storeDirectory) }
        let storeURL = storeDirectory.appendingPathComponent("players.store")

        try autoreleasepool {
            let container = try ModelContainer(for: AvatarConfig.self, configurations: ModelConfiguration(url: storeURL))
            let context = ModelContext(container)
            let config = AvatarConfig()
            config.athletePreset = .femaleBlack
            config.skinToneOverride = .tan
            config.hairColorOverrideHex = AvatarHairColor.blonde.hex
            config.equippedTopID = "persisted.top"
            context.insert(config)
            try context.save()
        }

        let reopenedContainer = try ModelContainer(for: AvatarConfig.self, configurations: ModelConfiguration(url: storeURL))
        let reopenedContext = ModelContext(reopenedContainer)
        let savedConfig = try XCTUnwrap(reopenedContext.fetch(FetchDescriptor<AvatarConfig>()).first)
        XCTAssertEqual(savedConfig.athletePreset, .femaleBlack)
        XCTAssertEqual(savedConfig.skinToneOverride, .tan)
        XCTAssertEqual(savedConfig.hairColorOverrideHex, AvatarHairColor.blonde.hex)
        let store = RallyAvatarAppearanceStore()
        store.sync(from: savedConfig)
        XCTAssertEqual(store.appearance.athletePreset, .femaleBlack)
        XCTAssertEqual(store.appearance.top?.id, "persisted.top")
        XCTAssertEqual(store.appearance.skinToneOverrideHex, AvatarSkinTone.tan.hex)
        XCTAssertEqual(store.appearance.hairColorOverrideHex, AvatarHairColor.blonde.hex)

        savedConfig.athletePreset = .maleAsian
        store.sync(from: savedConfig)
        XCTAssertEqual(store.appearance.athletePreset, .maleAsian)
        XCTAssertEqual(store.appearance.top?.id, "persisted.top")
        XCTAssertEqual(store.appearance.skinToneHex, AvatarSkinTone.tan.hex)
        XCTAssertEqual(store.appearance.hairColorHex, AvatarHairColor.blonde.hex)
    }

    @MainActor
    func testExplicitColorChoicesKeepModelHairShapeAndClothing() {
        let config = AvatarConfig()
        config.athletePreset = .femaleAsian
        let original = RallyAvatarAppearance(config: config)

        config.skinToneOverride = .rich
        config.hairColorOverrideHex = AvatarHairColor.auburn.hex
        let colored = RallyAvatarAppearance(config: config)

        XCTAssertEqual(colored.skinToneOverrideHex, AvatarSkinTone.rich.hex)
        XCTAssertEqual(colored.skinToneHex, AvatarSkinTone.rich.hex)
        XCTAssertEqual(colored.hairColorOverrideHex, AvatarHairColor.auburn.hex)
        XCTAssertEqual(colored.hairColorHex, AvatarHairColor.auburn.hex)
        XCTAssertEqual(colored.athletePreset, original.athletePreset)
        XCTAssertEqual(colored.hairStyle, original.hairStyle)
        XCTAssertEqual(colored.bodyProfile, original.bodyProfile)
        XCTAssertEqual(colored.top, original.top)
        XCTAssertEqual(colored.shorts, original.shorts)
        XCTAssertEqual(colored.shoes, original.shoes)
        XCTAssertEqual(colored.racket, original.racket)
    }

    func testAppearanceOverrideMutationUpdatesEffectiveColors() {
        var appearance = RallyAvatarAppearance(athletePreset: .maleAsian)
        appearance.skinToneOverrideHex = AvatarSkinTone.fair.hex
        appearance.hairColorOverrideHex = AvatarHairColor.silver.hex
        XCTAssertEqual(appearance.skinToneHex, AvatarSkinTone.fair.hex)
        XCTAssertEqual(appearance.hairColorHex, AvatarHairColor.silver.hex)
        XCTAssertEqual(appearance.athletePreset, .maleAsian)
        XCTAssertEqual(appearance.hairStyle, .short)
    }

    func testChangingModelRefreshesDefaultsAndRetainsExplicitColors() {
        var appearance = RallyAvatarAppearance(athletePreset: .maleEuropean)
        let originalTop = appearance.top
        appearance.athletePreset = .femaleBlack
        XCTAssertEqual(appearance.skinToneHex, RallyAthletePreset.femaleBlack.skinTone.hex)
        XCTAssertEqual(appearance.hairColorHex, RallyAthletePreset.femaleBlack.hairColorHex)
        XCTAssertEqual(appearance.hairStyle, .ponytail)
        XCTAssertNil(appearance.skinToneOverrideHex)
        XCTAssertNil(appearance.hairColorOverrideHex)

        appearance.skinToneOverrideHex = AvatarSkinTone.fair.hex
        appearance.hairColorOverrideHex = AvatarHairColor.blonde.hex
        appearance.athletePreset = .maleAsian
        XCTAssertEqual(appearance.skinToneHex, AvatarSkinTone.fair.hex)
        XCTAssertEqual(appearance.hairColorHex, AvatarHairColor.blonde.hex)
        XCTAssertEqual(appearance.hairStyle, .short)
        XCTAssertEqual(appearance.top, originalTop)
    }

    func testExplicitDefaultHairColorSurvivesCodingAfterAnotherColor() throws {
        var appearance = RallyAvatarAppearance(athletePreset: .maleAsian)
        appearance.hairColorOverrideHex = AvatarHairColor.blonde.hex
        appearance.hairColorOverrideHex = RallyAthletePreset.maleAsian.hairColorHex

        let restored = try JSONDecoder().decode(RallyAvatarAppearance.self, from: JSONEncoder().encode(appearance))

        XCTAssertEqual(restored.hairColorHex, RallyAthletePreset.maleAsian.hairColorHex)
        XCTAssertEqual(restored.hairColorOverrideHex, RallyAthletePreset.maleAsian.hairColorHex)
        XCTAssertEqual(restored.hairStyle, .short)
        XCTAssertNotEqual(restored, RallyAvatarAppearance(athletePreset: .maleAsian),
                          "An explicit color choice remains distinct from the untouched authored texture")
    }

    @MainActor
    func testUnknownSavedPresetResolvesToDefaultPlayer() {
        let config = AvatarConfig()
        config.athletePresetRaw = "retired-player"
        XCTAssertEqual(config.athletePreset, .maleEuropean)
        XCTAssertEqual(RallyAvatarAppearance(config: config).athletePreset, .maleEuropean)
    }

    private func clearSoundKeys() {
        defaults.removeObject(forKey: UserDefaultsKeys.soundEnabled)
        defaults.removeObject(forKey: UserDefaultsKeys.soundPreferenceExplicitlySet)
        defaults.removeObject(forKey: UserDefaultsKeys.soundQuietDefaultApplied)
    }
}
