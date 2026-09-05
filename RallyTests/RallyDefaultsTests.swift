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
        XCTAssertEqual(decoded.top, original.top)
        XCTAssertEqual(decoded.shorts, original.shorts)
        XCTAssertEqual(decoded.shoes, original.shoes)
        XCTAssertEqual(decoded.racket, original.racket)
    }

    func testEveryPlayerAppearanceRoundTrips() throws {
        for preset in RallyAthletePreset.allCases {
            let appearance = RallyAvatarAppearance(athletePreset: preset)
            let decoded = try JSONDecoder().decode(RallyAvatarAppearance.self, from: JSONEncoder().encode(appearance))
            XCTAssertEqual(decoded, appearance)
            XCTAssertEqual(decoded.athleteModel, preset.athleteModel)
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
            config.equippedTopID = "persisted.top"
            context.insert(config)
            try context.save()
        }

        let reopenedContainer = try ModelContainer(for: AvatarConfig.self, configurations: ModelConfiguration(url: storeURL))
        let reopenedContext = ModelContext(reopenedContainer)
        let savedConfig = try XCTUnwrap(reopenedContext.fetch(FetchDescriptor<AvatarConfig>()).first)
        XCTAssertEqual(savedConfig.athletePreset, .femaleBlack)
        let store = RallyAvatarAppearanceStore()
        store.sync(from: savedConfig)
        XCTAssertEqual(store.appearance.athletePreset, .femaleBlack)
        XCTAssertEqual(store.appearance.top?.id, "persisted.top")

        savedConfig.athletePreset = .maleAsian
        store.sync(from: savedConfig)
        XCTAssertEqual(store.appearance.athletePreset, .maleAsian)
        XCTAssertEqual(store.appearance.top?.id, "persisted.top")
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
