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
    var athletePresetRaw: String = RallyAthletePreset.maleEuropean.rawValue

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

    var athletePreset: RallyAthletePreset {
        get { RallyAthletePreset(rawValue: athletePresetRaw) ?? .maleEuropean }
        set { athletePresetRaw = newValue.rawValue }
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
        let isBlankName = trimmedName.isEmpty
        let isLegacyStarterName = staleStarterNames.contains(trimmedName.lowercased())
        let shouldApplyStarterIdentity = !hasCompletedSetup

        if isBlankName || (shouldApplyStarterIdentity && isLegacyStarterName) {
            playerName = "Player"
        }

        if shouldApplyStarterIdentity &&
            (hairColorHex == "#3A2A1A" || hairColorHex == "#2C221D" || hairColorHex == "#101114" || isLegacyStarterName) {
            hairColorHex = "#050507"
        }
        if shouldApplyStarterIdentity && hairStyle == .bald {
            hairStyle = .medium
        }

        guard shouldApplyStarterIdentity else { return }

        skinTone = .light
        bodyType = .athletic
        hairStyle = .medium
    }
}

/// The two shared tennis physiques used by the six-player roster.
enum RallyAthleteModel: String, Codable, CaseIterable, Identifiable {
    case male, female

    var id: String { rawValue }
    var displayName: String { self == .male ? "Man" : "Woman" }
}

/// Fixed player identities. Clothing and racket choices remain independent.
enum RallyAthletePreset: String, Codable, CaseIterable, Identifiable {
    case maleEuropean, maleAsian, maleBlack
    case femaleEuropean, femaleAsian, femaleBlack

    var id: String { rawValue }
    var athleteModel: RallyAthleteModel {
        switch self {
        case .maleEuropean, .maleAsian, .maleBlack: return .male
        case .femaleEuropean, .femaleAsian, .femaleBlack: return .female
        }
    }

    var displayName: String {
        switch self {
        case .maleEuropean: return "Alex"
        case .maleAsian: return "Kai"
        case .maleBlack: return "Miles"
        case .femaleEuropean: return "Emma"
        case .femaleAsian: return "Maya"
        case .femaleBlack: return "Zoe"
        }
    }

    var heritageDescription: String {
        switch self {
        case .maleEuropean, .femaleEuropean: return "White / European"
        case .maleAsian, .femaleAsian: return "Asian"
        case .maleBlack, .femaleBlack: return "Black"
        }
    }

    var skinTone: AvatarSkinTone {
        switch self {
        case .maleEuropean, .femaleEuropean: return .light
        case .maleAsian, .femaleAsian: return .light
        case .maleBlack, .femaleBlack: return .deep
        }
    }

    var hairStyle: AvatarHairStyle {
        switch self {
        case .maleEuropean, .maleAsian, .maleBlack: return .short
        case .femaleEuropean, .femaleAsian, .femaleBlack: return .ponytail
        }
    }

    var hairColorHex: String {
        switch self {
        case .maleEuropean, .femaleEuropean: return "#4A3228"
        default: return "#080809"
        }
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
    static var customizerCases: [AvatarHairStyle] {
        [.short, .medium, .long, .headband, .cap, .ponytail, .bun]
    }
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
