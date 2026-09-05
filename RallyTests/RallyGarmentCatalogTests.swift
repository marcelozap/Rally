import XCTest
@testable import Rally

final class RallyGarmentCatalogTests: XCTestCase {
    func testBundledReferencesMatchSixExactProductsAndShopSlots() throws {
        let catalog = RallyGarmentCatalog.shared
        let expectedIDs: Set<String> = [
            "nike.advantage.top.fz6910.010",
            "nike.advantage.short.fz6913.010",
            "adidas.ergo.pro.short.kv4294",
            "uniqlo.dryex.quarterzip.482306.00",
            "newbalance.tournament.tank.white",
            "newbalance.tournament.skort.wb61s4jj.white",
        ]
        XCTAssertEqual(Set(catalog.references.map(\.id)), expectedIDs)
        XCTAssertEqual(catalog.references.count, 6, "Missing or malformed bundled manifest must be caught before shipping")

        for reference in catalog.references {
            XCTAssertNotNil(catalog.reference(for: reference.id, slot: reference.slot.gearSlot))
            XCTAssertFalse(reference.referenceImageURLs.isEmpty, reference.id)
            XCTAssertEqual(reference.representation, .referenceOnly, reference.id)
            XCTAssertNil(reference.meshes.male, reference.id)
            XCTAssertNil(reference.meshes.female, reference.id)
            if reference.id == "uniqlo.dryex.quarterzip.482306.00" {
                XCTAssertNil(ShopCatalog.item(id: reference.id), "The source-only item has no verified price")
                continue
            }
            let item = try XCTUnwrap(ShopCatalog.item(id: reference.id), reference.id)
            XCTAssertEqual(item.brand, reference.brand, reference.id)
            XCTAssertEqual(item.productURL, reference.officialURL, reference.id)
            XCTAssertEqual(item.category, reference.slot == .top ? .top : .bottom, reference.id)
        }
    }

    func testDuplicateIDsAreRejectedBeforeLookup() throws {
        let record = fixture()
        XCTAssertThrowsError(try catalog([record, record])) { error in
            XCTAssertEqual(error as? RallyGarmentCatalog.ValidationError, .duplicateID("test.tee.white"))
        }
    }

    func testLookupRequiresExactIDAndExpectedSlot() throws {
        let catalog = try catalog([fixture()])
        XCTAssertNotNil(catalog.reference(for: "test.tee.white", slot: .top))
        XCTAssertNil(catalog.reference(for: "test.tee.white", slot: .shorts))
        XCTAssertNil(catalog.reference(for: "test.tee.white", slot: .shoes))
        XCTAssertNil(catalog.reference(for: "TEST.TEE.WHITE", slot: .top))
        XCTAssertNil(catalog.reference(for: "other.test.tee.white", slot: .top))
    }

    func testDeclaredSlotAndGarmentKindMustAgree() throws {
        var record = fixture()
        record["slot"] = "shorts"
        XCTAssertThrowsError(try catalog([record])) { error in
            XCTAssertEqual(error as? RallyGarmentCatalog.ValidationError, .mismatchedSlot("test.tee.white"))
        }
    }

    func testLegacyKindsUseExplicitIDsAndNeverCrossSlots() throws {
        let empty = try catalog([])
        XCTAssertEqual(empty.garmentKind(for: "adidas.club.polo.lime", slot: .top), .polo)
        XCTAssertEqual(empty.garmentKind(for: "newbalance.tournament.tank.white", slot: .top), .tank)
        XCTAssertEqual(empty.garmentKind(for: "newbalance.tournament.skort.white", slot: .shorts), .skort)
        XCTAssertEqual(empty.garmentKind(for: "adidas.club.polo.lime", slot: .shorts), .shorts)
        XCTAssertEqual(empty.garmentKind(for: "newbalance.tournament.skort.white", slot: .top), .tee)
        XCTAssertEqual(empty.garmentKind(for: "unknown.polo.tank", slot: .top), .tee)
        XCTAssertEqual(empty.garmentKind(for: "unknown.skort", slot: .shorts), .shorts)
        XCTAssertEqual(empty.garmentKind(for: nil, slot: .top), .tee)
    }

    func testReferenceImagesDoNotClaimAuthoredMeshes() throws {
        var record = fixture()
        // A generic mesh name must never turn a photo reference into a product model.
        record["meshes"] = ["male": "shirt", "female": "female-shirt"]
        let reference = try XCTUnwrap(catalog([record]).reference(for: "test.tee.white", slot: .top))
        XCTAssertFalse(reference.referenceImageURLs.isEmpty)
        XCTAssertEqual(reference.representation, .referenceOnly)
        for model in RallyAthleteModel.allCases {
            XCTAssertNil(reference.meshName(for: model))
            XCTAssertEqual(reference.effectiveRepresentation(for: model), .referenceOnly)
        }
    }

    func testMissingDeclaredAssetFallsBackToReferenceOnly() throws {
        var record = fixture()
        record["representation"] = "skuAuthored"
        record["meshes"] = ["male": "nonexistent-product-mesh-for-test"]
        let reference = try XCTUnwrap(catalog([record]).reference(for: "test.tee.white", slot: .top))
        XCTAssertNil(reference.meshName(for: .male))
        XCTAssertEqual(reference.effectiveRepresentation(for: .male), .referenceOnly)
        XCTAssertEqual(reference.effectiveRepresentation(for: .female), .referenceOnly)
    }

    func testUnsafeMeshPathsAndNonHTTPSReferencesAreRejected() throws {
        var record = fixture()
        record["meshes"] = ["male": "../outside"]
        XCTAssertThrowsError(try catalog([record]))
        record = fixture()
        record["officialURL"] = "file:///tmp/product.html"
        XCTAssertThrowsError(try catalog([record]))
        XCTAssertThrowsError(try RallyGarmentCatalog(data: Data("invalid json".utf8)))
    }

    private func catalog(_ garments: [[String: Any]]) throws -> RallyGarmentCatalog {
        try RallyGarmentCatalog(data: JSONSerialization.data(withJSONObject: ["garments": garments]))
    }

    private func fixture() -> [String: Any] {
        [
            "id": "test.tee.white",
            "brand": "Test Brand",
            "productName": "Tennis Tee",
            "slot": "top",
            "styleID": "TEST-100",
            "colorwayName": "White",
            "officialURL": "https://example.com/products/test-100",
            "verifiedAt": "2026-09-05",
            "referenceImageURLs": ["https://example.com/products/test-100-front.jpg"],
            "construction": ["Crew neck"],
            "sizes": ["S", "M", "L"],
            "garmentKind": "tee",
            "representation": "referenceOnly",
            "meshes": [:] as [String: String],
        ]
    }
}
