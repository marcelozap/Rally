import XCTest
import UIKit
import SwiftData
@testable import Rally

@MainActor
final class RallyMerchImageResolverTests: XCTestCase {
    func testReleaseCatalogUsesOriginalFreeGearWithoutRetailerImages() {
        XCTAssertFalse(ShopCatalog.allItems.isEmpty)
        XCTAssertTrue(ShopCatalog.productPhotography.isEmpty)
        XCTAssertTrue(RallyReferralCatalog.allItems.isEmpty)
        XCTAssertEqual(Set(ShopCatalog.allItems.map(\.id)).count, ShopCatalog.allItems.count)
        for item in ShopCatalog.allItems {
            XCTAssertEqual(item.brand, "Vela", item.id)
            XCTAssertEqual(item.vendorID, "vela", item.id)
            XCTAssertEqual(item.priceUSD, 0, item.id)
            XCTAssertNil(item.checkoutPromoCode, item.id)
            XCTAssertNil(RallyMerchImageResolver.bundledProductImage(for: item), item.id)
            XCTAssertNil(RallyMerchImageResolver.productImageURL(for: item), item.id)
            XCTAssertEqual(item.productURL.host, "apps.apple.com", item.id)
        }
        XCTAssertNil(UIImage(named: "ShopPhoto-FZ6910-010"))
        XCTAssertNotNil(ShopCatalog.item(id: ShopCatalog.defaultRacketID))
        XCTAssertNotNil(ShopCatalog.item(id: ShopCatalog.defaultShoesID))
    }

    func testOneTapEquipmentAndHeadbandPersistAcrossDatabaseReopen() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("wardrobe.store")
        let top = try XCTUnwrap(ShopCatalog.item(id: "newbalance.tournament.tank.white"))
        let band = try XCTUnwrap(ShopCatalog.items(in: .accessory).first)
        let racket = try XCTUnwrap(ShopCatalog.items(in: .racket).first { $0.id != ShopCatalog.defaultRacketID })
        let pants = try XCTUnwrap(ShopCatalog.items(in: .bottom).first { $0.id != ShopCatalog.defaultBottomID })
        try autoreleasepool {
            let container = try ModelContainer(for: AvatarConfig.self, MatchEntry.self, JournalEntry.self, configurations: ModelConfiguration(url: url))
            let context = ModelContext(container)
            let config = AvatarConfig()
            config.athletePreset = .femaleBlack
            context.insert(config)
            context.insert(MatchEntry(opponentName: "Local opponent", notes: "Saved without an account"))
            context.insert(JournalEntry(title: "Local practice", body: "Saved without a server"))
            XCTAssertTrue(try config.equip(racket, in: context))
            XCTAssertTrue(try config.equip(pants, in: context))
            let store = RallyAvatarAppearanceStore()
            store.tryOn(top, from: config)
            XCTAssertEqual(config.equippedRacketID, racket.id)
            XCTAssertEqual(config.equippedBottomID, pants.id)
            XCTAssertEqual(config.equippedTopID, ShopCatalog.defaultTopID)
            XCTAssertEqual(store.appearance.racket?.id, racket.id)
            XCTAssertEqual(store.appearance.shorts?.id, pants.id)
            XCTAssertEqual(store.appearance.top?.id, top.id)
            store.clearTryOn(from: config)
            XCTAssertEqual(store.appearance.top?.id, ShopCatalog.defaultTopID)
            XCTAssertTrue(try config.equip(top, in: context))
            XCTAssertTrue(try config.equip(band, in: context))
        }
        let reopened = try ModelContainer(for: AvatarConfig.self, MatchEntry.self, JournalEntry.self, configurations: ModelConfiguration(url: url))
        let reopenedContext = ModelContext(reopened)
        let config = try XCTUnwrap(reopenedContext.fetch(FetchDescriptor<AvatarConfig>()).first)
        XCTAssertEqual(try reopenedContext.fetch(FetchDescriptor<MatchEntry>()).first?.notes, "Saved without an account")
        XCTAssertEqual(try reopenedContext.fetch(FetchDescriptor<JournalEntry>()).first?.body, "Saved without a server")
        XCTAssertEqual(config.equippedRacketID, racket.id)
        XCTAssertEqual(config.equippedBottomID, pants.id)
        XCTAssertEqual(config.equippedTopID, top.id)
        XCTAssertEqual(config.equippedHeadbandID, band.id)
        XCTAssertEqual(config.athletePreset, .femaleBlack)
        let appearance = RallyAvatarAppearance(config: config)
        XCTAssertEqual(appearance.racket?.id, racket.id)
        XCTAssertEqual(appearance.shorts?.id, pants.id)
        XCTAssertEqual(appearance.top?.id, top.id)
        XCTAssertEqual(appearance.headband?.id, band.id)
        XCTAssertEqual(appearance.headband?.colorwayHex, band.colorHex)
        XCTAssertEqual(RallyGarmentCatalog.shared.garmentKind(for: top.id, slot: .top), .tee)
        try config.removeHeadband(in: reopenedContext)
        XCTAssertNil(config.equippedHeadbandID)
        XCTAssertNil(RallyAvatarAppearance(config: config).headband)
        let finalContainer = try ModelContainer(for: AvatarConfig.self, MatchEntry.self, JournalEntry.self, configurations: ModelConfiguration(url: url))
        let finalContext = ModelContext(finalContainer)
        XCTAssertNil(try finalContext.fetch(FetchDescriptor<AvatarConfig>()).first?.equippedHeadbandID)
    }

    func testBundledPhotographyRejectsWrongCategoryAndChangedProductDestination() throws {
        let original = try XCTUnwrap(ShopCatalog.item(id: "nike.advantage.top.fz6910.010"))
        for (category, url) in [(ShopItem.Category.shoes, original.productURL),
                                (.top, URL(string: "https://example.com/different-product")!)] {
            let changed = ShopItem(id: original.id, category: category, name: original.name,
                                   brand: original.brand, vendorID: original.vendorID, productURL: url,
                                   priceUSD: original.priceUSD, colorHex: original.colorHex, accentHex: original.accentHex)
            XCTAssertNil(ShopCatalog.photograph(for: changed))
            XCTAssertNil(RallyMerchImageResolver.bundledProductImage(for: changed))
        }
    }

    func testExactProductAndColorwayWinsOverOtherProductsFromTheBrand() throws {
        let item = shopItem(id: "brand.polo.white")
        let black = try referral(id: "brand.polo.black")
        let white = try referral(id: item.id)
        let other = try referral(id: "brand.training.tee")
        let match = RallyMerchImageResolver.referralItem(for: item, in: [black, other, white])
        XCTAssertEqual(match?.id, white.id)
        XCTAssertEqual(match?.productImageURL, white.productImageURL)
    }

    func testMissingProductDoesNotBorrowSameBrandNameOrCategoryPhotography() throws {
        let item = shopItem(id: "brand.polo.white")
        let wrongColor = try referral(id: "brand.polo.black")
        let sameName = try referral(id: "other.polo.white", brand: "Other brand", name: item.name)
        let sameSlot = try referral(id: "third.tee", brand: "Third brand", name: "Training tee")
        for catalog in [[wrongColor], [sameName], [sameSlot], [wrongColor, sameName, sameSlot]] {
            XCTAssertNil(RallyMerchImageResolver.referralItem(for: item, in: catalog))
        }
    }

    func testMatchingIDWithWrongSlotDoesNotShowUnrelatedGoods() throws {
        let item = shopItem(id: "brand.polo.white")
        let invalid = try referral(id: item.id, slot: .shoes)
        XCTAssertNil(RallyMerchImageResolver.referralItem(for: item, in: [invalid]))
    }

    func testMissingImageRemainsMissingForAnExactCatalogEntry() throws {
        let item = shopItem(id: "brand.polo.white")
        let exact = try referral(id: item.id, includesImage: false)
        let unrelated = try referral(id: "brand.polo.black")
        let match = RallyMerchImageResolver.referralItem(for: item, in: [unrelated, exact])
        XCTAssertEqual(match?.id, item.id)
        XCTAssertNil(match?.productImageURL)
    }

    func testVerifiedSKUReferencePhotoTakesPriorityForTheExactItemAndSlot() throws {
        let item = shopItem(id: "brand.polo.white")
        let referencePhoto = URL(string: "https://example.com/verified/product-white.png")!
        let oldReferral = try referral(id: item.id)
        let result = RallyMerchImageResolver.productImageURL(for: item, referenceImages: { id, slot in
            XCTAssertEqual(id, item.id)
            XCTAssertEqual(slot, .top)
            return [referencePhoto]
        }, referralCatalog: [oldReferral])
        XCTAssertEqual(result, referencePhoto)
    }

    func testNoVerifiedPhotoFallsBackOnlyToExactReferralPhotography() throws {
        let item = shopItem(id: "brand.polo.white")
        let exact = try referral(id: item.id)
        let unrelated = try referral(id: "brand.polo.black")
        let noReference: (String, RallyGearSlot) -> [URL] = { _, _ in [] }
        XCTAssertEqual(RallyMerchImageResolver.productImageURL(
            for: item, referenceImages: noReference, referralCatalog: [unrelated, exact]
        ), exact.productImageURL)
        XCTAssertNil(RallyMerchImageResolver.productImageURL(
            for: item, referenceImages: noReference, referralCatalog: [unrelated]
        ))
    }

    private func shopItem(id: String) -> ShopItem {
        ShopItem(id: id, category: .top, name: "Court polo", brand: "Example brand", vendorID: "example",
                 productURL: URL(string: "https://example.com/products/\(id)")!,
                 priceUSD: 50, colorHex: "#FFFFFF", accentHex: nil)
    }

    private func referral(
        id: String, slot: ReferralGearSlot = .top, brand: String = "Example brand",
        name: String = "Court polo", includesImage: Bool = true
    ) throws -> RallyGearItem {
        var json: [String: Any] = [
            "id": id, "brand": brand, "name": name, "slot": slot.rawValue,
            "colorwayName": "Example colorway", "priceDisplay": "$50", "accentColorHex": "#FFFFFF",
            "referralURL": "https://example.com/products/\(id)"
        ]
        if includesImage { json["productImageURL"] = "https://example.com/images/\(id).png" }
        return try JSONDecoder().decode(RallyGearItem.self, from: JSONSerialization.data(withJSONObject: json))
    }
}
