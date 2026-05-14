import SwiftUI

/// A unit of unlockable visual flair. Designed so that shipping a new skin
/// requires only:
///   1. dropping a texture / particle into `Resources/`
///   2. appending an entry in `Resources/cosmetics.json`
///
/// Behavioral tweaks live in `CosmeticModifiers` so a skin can also feel
/// different (e.g. a "Plasma" trail with a longer afterimage), not just look
/// different.
struct Cosmetic: Identifiable, Codable, Hashable {
    typealias ID = String

    enum Kind: String, Codable {
        case ballSkin
        case trail
        case hitBurst
        case theme
    }

    enum Rarity: String, Codable {
        case common
        case rare
        case epic
        case mythic
    }

    enum Unlock: Codable, Hashable {
        case freeAtLaunch
        case scoreThreshold(Int)
        case comboMilestone(Int)
        case promo(code: String)
        case purchase(productID: String)
    }

    let id: ID
    let kind: Kind
    let displayName: String
    let rarity: Rarity
    let unlock: Unlock

    let textureName: String?
    let particleName: String?
    let tint: CodableColor?

    let modifiers: CosmeticModifiers?
}

struct CosmeticModifiers: Codable, Hashable {
    var trailLengthMultiplier: Double = 1.0
    var hitBurstParticleCountMultiplier: Double = 1.0
    var screenShakeMultiplier: Double = 1.0
}

/// Codable bridge for `Color` so a JSON catalog can ship colors directly.
struct CodableColor: Codable, Hashable {
    let r: Double
    let g: Double
    let b: Double
    let a: Double

    var color: Color {
        Color(.sRGB, red: r, green: g, blue: b, opacity: a)
    }
}
