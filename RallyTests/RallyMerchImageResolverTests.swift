import XCTest
@testable import Rally

@MainActor
final class RallyMerchImageResolverTests: XCTestCase {
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
