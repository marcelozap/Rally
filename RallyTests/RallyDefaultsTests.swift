import XCTest
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

    private func clearSoundKeys() {
        defaults.removeObject(forKey: UserDefaultsKeys.soundEnabled)
        defaults.removeObject(forKey: UserDefaultsKeys.soundPreferenceExplicitlySet)
        defaults.removeObject(forKey: UserDefaultsKeys.soundQuietDefaultApplied)
    }
}
