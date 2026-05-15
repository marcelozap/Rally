import XCTest
@testable import Rally

/// Locks in the shop visibility filter so a regression doesn't silently
/// expose tour-edition cosmetics to players who haven't checked in.
final class CourtUnlockTests: XCTestCase {

    func testCourtGatedItemsHiddenByDefault() {
        let visible = ShopCatalog.visibleItems(
            ShopCatalog.allItems,
            unlockedCourtIDs: []
        )
        let ids = Set(visible.map(\.id))
        for gated in ShopCatalog.courtGatedItemIDs {
            XCTAssertFalse(ids.contains(gated), "Gated item \(gated) should be hidden when no courts are unlocked")
        }
    }

    func testCourtUnlockSurfacesMatchingItem() {
        let visible = ShopCatalog.visibleItems(
            ShopCatalog.allItems,
            unlockedCourtIDs: ["wimbledon.cc"]
        )
        let ids = Set(visible.map(\.id))
        XCTAssertTrue(ids.contains("rally.wristband.tour.wimbledon"))
        // Other tour items still hidden
        XCTAssertFalse(ids.contains("rally.wristband.tour.roland"))
    }

    func testEquippedTourItemStaysVisibleEvenIfRelocked() {
        let visible = ShopCatalog.visibleItems(
            ShopCatalog.allItems,
            unlockedCourtIDs: [],
            equippedIDs: ["rally.wristband.tour.wimbledon"]
        )
        XCTAssertTrue(visible.contains { $0.id == "rally.wristband.tour.wimbledon" })
    }

    func testCourtUnlocksPersistsToDefaults() {
        let store = UserDefaults(suiteName: #function)!
        store.removePersistentDomain(forName: #function)
        let u = CourtUnlocks(defaults: store)
        XCTAssertFalse(u.isUnlocked(courtID: "wimbledon.cc"))
        u.unlock(courtID: "wimbledon.cc")
        XCTAssertTrue(u.isUnlocked(courtID: "wimbledon.cc"))

        // New instance reads back the same set.
        let u2 = CourtUnlocks(defaults: store)
        XCTAssertTrue(u2.isUnlocked(courtID: "wimbledon.cc"))
    }
}
