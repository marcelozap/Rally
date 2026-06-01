import UIKit

// MARK: - UIColor (hex)

extension UIColor {
    convenience init?(hex: String) {
        let cleaned = hex.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: "#", with: "")
        guard cleaned.count == 6, let value = UInt32(cleaned, radix: 16) else { return nil }
        let r = CGFloat((value >> 16) & 0xFF) / 255
        let g = CGFloat((value >> 8) & 0xFF) / 255
        let b = CGFloat(value & 0xFF) / 255
        self.init(red: r, green: g, blue: b, alpha: 1)
    }

    /// RGBA for RealityKit `SimpleMaterial` / tinting (forces RGB fallback).
    var rkComponents: (Float, Float, Float, Float) {
        var r: CGFloat = 1, g: CGFloat = 1, b: CGFloat = 1, a: CGFloat = 1
        if getRed(&r, green: &g, blue: &b, alpha: &a) {
            return (Float(r), Float(g), Float(b), Float(a))
        }
        guard let c = cgColor.components, c.count >= 3 else {
            return (1, 1, 1, 1)
        }
        let alpha = Float(cgColor.alpha)
        return (Float(c[0]), Float(c[1]), Float(c[2]), alpha)
    }

    func multiplied(by other: UIColor) -> UIColor {
        let (r1, g1, b1, a1) = rkComponents
        let (r2, g2, b2, a2) = other.rkComponents
        return UIColor(
            red: CGFloat(r1 * r2),
            green: CGFloat(g1 * g2),
            blue: CGFloat(b1 * b2),
            alpha: CGFloat(a1 * a2)
        )
    }

    func mixed(with other: UIColor, ratio: CGFloat) -> UIColor {
        let clamped = min(max(ratio, 0), 1)
        let (r1, g1, b1, a1) = rkComponents
        let (r2, g2, b2, a2) = other.rkComponents
        let inv = Float(1 - clamped)
        let mix = Float(clamped)
        return UIColor(
            red: CGFloat((r1 * inv) + (r2 * mix)),
            green: CGFloat((g1 * inv) + (g2 * mix)),
            blue: CGFloat((b1 * inv) + (b2 * mix)),
            alpha: CGFloat((a1 * inv) + (a2 * mix))
        )
    }

    func brightened(_ amount: CGFloat) -> UIColor {
        mixed(with: .white, ratio: amount)
    }

    func darkened(_ amount: CGFloat) -> UIColor {
        mixed(with: .black, ratio: amount)
    }
}

// MARK: - Visual spec

/// Shared between SceneKit / RealityKit backends — UIKit colors only.
struct AvatarVisualSpec: Equatable {
    enum BodyProfile: Equatable {
        case slim
        case athletic
        case strong
    }

    enum HairProfile: Equatable {
        case bald
        case short
        case medium
        case long
        case ponytail
        case bun
    }

    var skin: UIColor
    var hair: UIColor
    var showsHair: Bool
    var hairProfile: HairProfile
    var top: UIColor
    var topAccent: UIColor
    var bottom: UIColor
    var bottomAccent: UIColor
    var shoes: UIColor
    var shoesAccent: UIColor
    var racket: UIColor
    var racketAccent: UIColor
    var bodyScale: CGFloat
    var bodyProfile: BodyProfile

    static func from(config: AvatarConfig, preview: (slot: ShopItem.Category, item: ShopItem)?) -> AvatarVisualSpec {
        func ui(hex: String, fallback: UIColor = .lightGray) -> UIColor {
            UIColor(hex: hex) ?? fallback
        }
        let skin = ui(hex: config.skinTone.hex, fallback: UIColor(red: 0.76, green: 0.56, blue: 0.42, alpha: 1))
        let hair = ui(hex: config.hairColorHex, fallback: UIColor(white: 0.2, alpha: 1))

        func item(_ cat: ShopItem.Category) -> ShopItem? {
            if let preview = preview, preview.slot == cat { return preview.item }
            switch cat {
            case .top:    return ShopCatalog.item(id: config.equippedTopID)
            case .bottom: return ShopCatalog.item(id: config.equippedBottomID)
            case .shoes:  return ShopCatalog.item(id: config.equippedShoesID)
            case .racket: return ShopCatalog.item(id: config.equippedRacketID)
            case .bag, .accessory: return nil
            }
        }

        let topIt = item(.top)
        let botIt = item(.bottom)
        let shoIt = item(.shoes)
        let rakIt = item(.racket)

        let bodyProfile: BodyProfile = {
            switch config.bodyType {
            case .slim:     return .slim
            case .athletic: return .athletic
            case .strong:   return .strong
            }
        }()

        let hairProfile: HairProfile = {
            switch config.hairStyle {
            case .bald: return .bald
            case .short: return .short
            case .medium: return .medium
            case .long: return .long
            case .ponytail: return .ponytail
            case .bun: return .bun
            }
        }()

        let scale: CGFloat = {
            switch bodyProfile {
            case .slim: return 0.94
            case .athletic: return 1.0
            case .strong: return 1.08
            }
        }()

        return AvatarVisualSpec(
            skin: skin,
            hair: hair,
            showsHair: hairProfile != .bald,
            hairProfile: hairProfile,
            top: topIt.map { ui(hex: $0.colorHex) } ?? .white,
            topAccent: topIt?.accentHex.flatMap { ui(hex: $0) } ?? .clear,
            bottom: botIt.map { ui(hex: $0.colorHex) } ?? UIColor(white: 0.1, alpha: 1),
            bottomAccent: botIt?.accentHex.flatMap { ui(hex: $0) } ?? .clear,
            shoes: shoIt.map { ui(hex: $0.colorHex) } ?? .white,
            shoesAccent: shoIt?.accentHex.flatMap { ui(hex: $0) } ?? UIColor(red: 0, green: 0.9, blue: 1, alpha: 1),
            racket: rakIt.map { ui(hex: $0.colorHex) } ?? UIColor(white: 0.75, alpha: 1),
            racketAccent: rakIt?.accentHex.flatMap { ui(hex: $0) } ?? UIColor(red: 0, green: 0.9, blue: 1, alpha: 1),
            bodyScale: scale,
            bodyProfile: bodyProfile
        )
    }
}

// MARK: - Emotes

enum AvatarShopEmote: String, CaseIterable, Identifiable {
    case idle
    case wave
    case celebrate
    case shopLook

    var id: String { rawValue }

    var label: String {
        switch self {
        case .idle:      return "Idle"
        case .wave:      return "Wave"
        case .celebrate: return "Celebrate"
        case .shopLook:  return "Browsing"
        }
    }

    var symbolName: String {
        switch self {
        case .idle:      return "figure.stand"
        case .wave:      return "hand.wave.fill"
        case .celebrate: return "hands.sparkles.fill"
        case .shopLook:  return "eye.fill"
        }
    }
}
