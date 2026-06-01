import Foundation
import SwiftData

@Model
final class AvatarConfig {
    var id: UUID = UUID()
    var playerName: String = ""
    var skinToneRaw: String = AvatarSkinTone.medium.rawValue
    var hairStyleRaw: String = AvatarHairStyle.short.rawValue
    var hairColorHex: String = "#3A2A1A"
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
        let trimmedName = playerName.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedName.isEmpty || ["player", "sam"].contains(trimmedName.lowercased()) {
            playerName = "Marcy"
        }

        if hairColorHex == "#3A2A1A" {
            hairColorHex = "#2C221D"
        }

        guard !hasCompletedSetup || isUsingStarterLoadout else { return }

        skinTone = .light
        bodyType = .athletic
        hairStyle = .short
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
        case .rich: return "#3D2718"
        }
    }
    var displayName: String { rawValue.capitalized }
}

enum AvatarHairStyle: String, CaseIterable, Identifiable {
    case bald, short, medium, long, ponytail, bun
    var id: String { rawValue }
    var displayName: String { rawValue.capitalized }
}

enum AvatarBodyType: String, CaseIterable, Identifiable {
    case slim, athletic, strong
    var id: String { rawValue }
    var displayName: String { rawValue.capitalized }
}
