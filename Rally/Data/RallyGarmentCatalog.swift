import Foundation

enum RallyGarmentSlot: String, Decodable, Equatable {
    case top, shorts

    var gearSlot: RallyGearSlot { self == .top ? .top : .shorts }
}

enum RallyGarmentKind: String, Decodable, Equatable {
    case tee, polo, tank, shorts, skort

    var slot: RallyGarmentSlot {
        switch self {
        case .tee, .polo, .tank: return .top
        case .shorts, .skort: return .shorts
        }
    }
}

enum RallyGarmentRepresentation: String, Decodable, Equatable {
    case referenceOnly, skuAuthored, brandSupplied
}

struct RallyGarmentMeshes: Decodable, Equatable {
    let male: String?
    let female: String?

    func name(for model: RallyAthleteModel) -> String? {
        model == .male ? male : female
    }
}

/// Product references describe a specific item; photographs do not establish a 3D garment asset.
struct RallyGarmentReference: Decodable, Identifiable, Equatable {
    let id: String
    let brand: String
    let productName: String
    let slot: RallyGarmentSlot
    let styleID: String
    let colorwayCode: String?
    let colorwayName: String
    let officialURL: URL
    let verifiedAt: String
    let referenceImageURLs: [URL]
    let fabric: String?
    let construction: [String]
    let sizes: [String]
    let garmentKind: RallyGarmentKind
    let representation: RallyGarmentRepresentation
    let meshes: RallyGarmentMeshes

    /// Names are full Avatar3D resource basenames, without a path or extension.
    func meshName(for model: RallyAthleteModel, bundle: Bundle = .main) -> String? {
        guard representation != .referenceOnly,
              let name = meshes.name(for: model),
              bundle.url(forResource: name, withExtension: "json", subdirectory: "Avatar3D") != nil else {
            return nil
        }
        return name
    }

    func effectiveRepresentation(for model: RallyAthleteModel, bundle: Bundle = .main) -> RallyGarmentRepresentation {
        meshName(for: model, bundle: bundle) == nil ? .referenceOnly : representation
    }
}

struct RallyGarmentCatalog: Decodable {
    enum ValidationError: Error, Equatable {
        case emptyID
        case duplicateID(String)
        case mismatchedSlot(String)
        case invalidURL(String)
        case invalidMeshName(String)
    }

    let references: [RallyGarmentReference]
    private let referencesByID: [String: RallyGarmentReference]

    static let shared: RallyGarmentCatalog = {
        guard let url = Bundle.main.url(forResource: "RallyGarmentCatalog", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let catalog = try? RallyGarmentCatalog(data: data) else {
            return RallyGarmentCatalog(references: [])
        }
        return catalog
    }()

    init(data: Data) throws {
        self = try JSONDecoder().decode(Self.self, from: data)
    }

    private enum CodingKeys: String, CodingKey { case garments }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let decoded = try container.decode([RallyGarmentReference].self, forKey: .garments)
        var seen = Set<String>()
        for reference in decoded {
            guard !reference.id.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                throw ValidationError.emptyID
            }
            guard seen.insert(reference.id).inserted else {
                throw ValidationError.duplicateID(reference.id)
            }
            guard reference.slot == reference.garmentKind.slot else {
                throw ValidationError.mismatchedSlot(reference.id)
            }
            for url in [reference.officialURL] + reference.referenceImageURLs {
                guard url.scheme?.lowercased() == "https", let host = url.host, !host.isEmpty else {
                    throw ValidationError.invalidURL(reference.id)
                }
            }
            for name in [reference.meshes.male, reference.meshes.female].compactMap({ $0 }) {
                guard name.range(of: "^[A-Za-z0-9][A-Za-z0-9_-]*$", options: .regularExpression) != nil else {
                    throw ValidationError.invalidMeshName(reference.id)
                }
            }
        }
        self.init(references: decoded)
    }

    private init(references: [RallyGarmentReference]) {
        self.references = references
        // Decoded records reach this initializer only after duplicate validation.
        referencesByID = Dictionary(references.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
    }

    func reference(for id: String, slot: RallyGearSlot) -> RallyGarmentReference? {
        guard let reference = referencesByID[id], reference.slot.gearSlot == slot else { return nil }
        return reference
    }

    func garmentKind(for id: String?, slot: RallyGearSlot) -> RallyGarmentKind {
        if let id, let reference = reference(for: id, slot: slot) { return reference.garmentKind }
        if let id, let kind = Self.legacyKinds[id], kind.slot.gearSlot == slot { return kind }
        return slot == .shorts ? .shorts : .tee
    }

    /// Explicit compatibility for shipped clothing IDs; new items need an exact manifest entry.
    static let legacyKinds: [String: RallyGarmentKind] = [
        "rally.default.top": .tee,
        "rally.default.bottom": .shorts,
        "newbalance.tournament.tank.white": .tank,
        "nike.dri-fit.tee.cobalt": .tee,
        "adidas.club.polo.lime": .polo,
        "uniqlo.dry.polo.white": .polo,
        "lacoste.croc.polo.green": .polo,
        "newbalance.tournament.skort.white": .skort,
        "nike.court.short.black": .shorts,
        "adidas.gameset.short.navy": .shorts,
        "uniqlo.dry.short.gray": .shorts,
    ]
}
