import Foundation
import SwiftData

@Model
final class AvatarConfig {
    var id: UUID = UUID()
    var playerName: String = ""
    var skinToneRaw: String = AvatarSkinTone.light.rawValue
    var hairStyleRaw: String = AvatarHairStyle.medium.rawValue
    var hairColorHex: String = "#050507"
    var bodyTypeRaw: String = AvatarBodyType.athletic.rawValue

    var equippedTopID: String = ShopCatalog.defaultTopID
    var equippedBottomID: String = ShopCatalog.defaultBottomID
    var equippedShoesID: String = ShopCatalog.defaultShoesID
    var equippedRacketID: String = ShopCatalog.defaultRacketID

    var hasCompletedSetup: Bool = false

    init() {
        self.id = UUID()
    }

    var isUsingStarterLoadout: Bool {
        equippedTopID == ShopCatalog.defaultTopID &&
        equippedBottomID == ShopCatalog.defaultBottomID &&
        equippedShoesID == ShopCatalog.defaultShoesID &&
        equippedRacketID == ShopCatalog.defaultRacketID
    }

    var skinTone: AvatarSkinTone {
        get { AvatarSkinTone(rawValue: skinToneRaw) ?? .medium }
        set { skinToneRaw = newValue.rawValue }
    }

    var hairStyle: AvatarHairStyle {
        get { AvatarHairStyle(rawValue: hairStyleRaw) ?? .short }
        set { hairStyleRaw = newValue.rawValue }
    }

    var bodyType: AvatarBodyType {
        get { AvatarBodyType(rawValue: bodyTypeRaw) ?? .athletic }
        set { bodyTypeRaw = newValue.rawValue }
    }

    func refreshForCurrentVisualSystem() {
        if equippedRacketID == "rally.default.racket" {
            equippedRacketID = ShopCatalog.defaultRacketID
        }
        if equippedShoesID == "rally.default.shoes" {
            equippedShoesID = ShopCatalog.defaultShoesID
        }

        let trimmedName = playerName.trimmingCharacters(in: .whitespacesAndNewlines)
        let staleStarterNames = ["player", "sam", "marcy"]
        let isStarterIdentity = trimmedName.isEmpty || staleStarterNames.contains(trimmedName.lowercased())
        if isStarterIdentity {
            playerName = "Player"
        }

        if hairColorHex == "#3A2A1A" || hairColorHex == "#2C221D" || hairColorHex == "#101114" || isStarterIdentity {
            hairColorHex = "#050507"
        }

        guard isStarterIdentity || !hasCompletedSetup || isUsingStarterLoadout else { return }

        skinTone = .light
        bodyType = .athletic
        hairStyle = .medium
    }
}

enum AvatarSkinTone: String, CaseIterable, Identifiable {
    case fair, light, medium, tan, deep, rich
    var id: String { rawValue }
    var hex: String {
        switch self {
        case .fair: return "#F5D6BB"
        case .light: return "#E0B79A"
        case .medium: return "#C58F66"
        case .tan: return "#A06B40"
        case .deep: return "#6D4326"
        case .rich: return "#5A341F"
        }
    }
    var displayName: String { rawValue.capitalized }
}

enum AvatarHairStyle: String, CaseIterable, Identifiable {
    case bald, short, medium, long, ponytail, bun, headband, cap
    var id: String { rawValue }
    var displayName: String {
        switch self {
        case .bald: return "Bald"
        case .short: return "Short"
        case .medium: return "Medium"
        case .long: return "Long"
        case .ponytail: return "Ponytail"
        case .bun: return "Bun"
        case .headband: return "Tie band"
        case .cap: return "Court cap"
        }
    }
}

enum AvatarBodyType: String, CaseIterable, Identifiable {
    case slim, athletic, strong
    var id: String { rawValue }
    var displayName: String { rawValue.capitalized }
}
