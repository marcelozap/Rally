import SwiftUI
import UIKit

// MARK: - Identity Attributes

enum RallyAvatarBodyProfile: String, Codable, Equatable {
    case slim
    case athletic
    case strong

    init(bodyType: AvatarBodyType) {
        switch bodyType {
        case .slim:
            self = .slim
        case .athletic:
            self = .athletic
        case .strong:
            self = .strong
        }
    }
}

enum RallyAvatarHairProfile: String, Codable, Equatable {
    case bald
    case short
    case medium
    case long
    case ponytail
    case bun
    case headband
    case cap
    case zukoJetBlack

    init(hairStyle: AvatarHairStyle, hairColorHex: String) {
        let isJetBlack = UIColor(rallyAvatarHex: hairColorHex)?.isNearBlack ?? false
        if hairStyle == .headband {
            self = .headband
            return
        }
        if hairStyle == .cap {
            self = .cap
            return
        }
        if isJetBlack, hairStyle == .medium {
            self = .zukoJetBlack
            return
        }

        switch hairStyle {
        case .bald:
            self = .bald
        case .short:
            self = .short
        case .medium:
            self = .medium
        case .long:
            self = .long
        case .ponytail:
            self = .ponytail
        case .bun:
            self = .bun
        case .headband:
            self = .headband
        case .cap:
            self = .cap
        }
    }
}

enum RallyAvatarPose: String, Codable, Equatable {
    case confidentAsymmetricIdle
}

// MARK: - Gear Slots

enum RallyGearSlot: String, Codable, CaseIterable, Identifiable {
    case racket
    case top
    case shorts
    case shoes
    case socks
    case headband

    var id: String { rawValue }
}

struct RallyGearReference: Codable, Equatable, Identifiable {
    let id: String
    let colorwayHex: String
    let accentHex: String?

    init(id: String, colorwayHex: String, accentHex: String? = nil) {
        self.id = id
        self.colorwayHex = colorwayHex
        self.accentHex = accentHex
    }
}

struct RallyAvatarAppearance: Codable, Equatable {
    var skinToneHex: String
    var hairColorHex: String
    var hairStyle: RallyAvatarHairProfile
    var bodyProfile: RallyAvatarBodyProfile
    var pose: RallyAvatarPose

    var racket: RallyGearReference?
    var top: RallyGearReference?
    var shorts: RallyGearReference?
    var shoes: RallyGearReference?
    var socks: RallyGearReference?
    var headband: RallyGearReference?

    init(
        skinToneHex: String = RallyAvatarRebuildDefaults.Identity.skinToneHex,
        hairColorHex: String = RallyAvatarRebuildDefaults.Identity.hairColorHex,
        hairStyle: RallyAvatarHairProfile = RallyAvatarRebuildDefaults.Identity.hairStyle,
        bodyProfile: RallyAvatarBodyProfile = RallyAvatarRebuildDefaults.Identity.bodyProfile,
        pose: RallyAvatarPose = RallyAvatarRebuildDefaults.Identity.pose,
        racket: RallyGearReference? = RallyAvatarRebuildDefaults.Gear.defaultRacket,
        top: RallyGearReference? = RallyAvatarRebuildDefaults.Gear.defaultTop,
        shorts: RallyGearReference? = RallyAvatarRebuildDefaults.Gear.defaultShorts,
        shoes: RallyGearReference? = RallyAvatarRebuildDefaults.Gear.defaultShoes,
        socks: RallyGearReference? = nil,
        headband: RallyGearReference? = nil
    ) {
        self.skinToneHex = skinToneHex
        self.hairColorHex = hairColorHex
        self.hairStyle = hairStyle
        self.bodyProfile = bodyProfile
        self.pose = pose
        self.racket = racket
        self.top = top
        self.shorts = shorts
        self.shoes = shoes
        self.socks = socks
        self.headband = headband
    }

    init(config: AvatarConfig, previewItem: ShopItem? = nil) {
        let skinTone = config.skinTone.hex
        let body = RallyAvatarBodyProfile(bodyType: config.bodyType)
        let hair = RallyAvatarHairProfile(hairStyle: config.hairStyle, hairColorHex: config.hairColorHex)

        self.init(
            skinToneHex: skinTone,
            hairColorHex: config.hairColorHex,
            hairStyle: hair,
            bodyProfile: body,
            pose: .confidentAsymmetricIdle,
            racket: Self.gearReference(
                id: config.equippedRacketID,
                fallbackColorHex: RallyAvatarRebuildDefaults.Identity.racketColorHex,
                fallbackAccentHex: RallyAvatarRebuildDefaults.Identity.racketAccentHex
            ),
            top: Self.gearReference(
                id: config.equippedTopID,
                fallbackColorHex: RallyAvatarRebuildDefaults.Identity.topColorHex,
                fallbackAccentHex: "#65DFF2"
            ),
            shorts: Self.gearReference(
                id: config.equippedBottomID,
                fallbackColorHex: RallyAvatarRebuildDefaults.Identity.shortsColorHex,
                fallbackAccentHex: "#171A22"
            ),
            shoes: Self.gearReference(
                id: config.equippedShoesID,
                fallbackColorHex: RallyAvatarRebuildDefaults.Identity.shoesColorHex,
                fallbackAccentHex: RallyAvatarRebuildDefaults.Identity.shoesAccentHex
            )
        )

        if let previewItem {
            equipPreview(previewItem)
        }
    }

    private static func gearReference(
        id: String,
        fallbackColorHex: String,
        fallbackAccentHex: String?
    ) -> RallyGearReference {
        if let item = ShopCatalog.item(id: id) {
            return RallyGearReference(
                id: item.id,
                colorwayHex: item.colorHex,
                accentHex: item.accentHex ?? fallbackAccentHex
            )
        }

        return RallyGearReference(
            id: id,
            colorwayHex: fallbackColorHex,
            accentHex: fallbackAccentHex
        )
    }

    var bodyScale: CGFloat {
        switch bodyProfile {
        case .slim:
            return 0.93
        case .athletic:
            return 0.97
        case .strong:
            return 1.06
        }
    }

    var skinUIColor: UIColor { UIColor(rallyAvatarHex: skinToneHex) ?? UIColor(red: 0.88, green: 0.68, blue: 0.52, alpha: 1) }
    var hairUIColor: UIColor { UIColor(rallyAvatarHex: hairColorHex) ?? UIColor(red: 0.008, green: 0.008, blue: 0.012, alpha: 0.98) }
    var topUIColor: UIColor { UIColor(rallyAvatarHex: top?.colorwayHex ?? RallyAvatarRebuildDefaults.Identity.topColorHex) ?? UIColor(red: 0.055, green: 0.105, blue: 0.145, alpha: 1) }
    var shortsUIColor: UIColor { UIColor(rallyAvatarHex: shorts?.colorwayHex ?? RallyAvatarRebuildDefaults.Identity.shortsColorHex) ?? UIColor(red: 0.030, green: 0.040, blue: 0.055, alpha: 1) }
    var shoesUIColor: UIColor { UIColor(rallyAvatarHex: shoes?.colorwayHex ?? RallyAvatarRebuildDefaults.Identity.shoesColorHex) ?? UIColor(red: 0.94, green: 0.97, blue: 0.98, alpha: 1) }
    var shoesAccentUIColor: UIColor { UIColor(rallyAvatarHex: shoes?.accentHex ?? RallyAvatarRebuildDefaults.Identity.shoesAccentHex) ?? UIColor(red: 0.0, green: 0.84, blue: 0.94, alpha: 1) }
    var racketUIColor: UIColor { UIColor(rallyAvatarHex: racket?.colorwayHex ?? RallyAvatarRebuildDefaults.Identity.racketColorHex) ?? UIColor(white: 0.78, alpha: 1) }
    var racketAccentUIColor: UIColor { UIColor(rallyAvatarHex: racket?.accentHex ?? RallyAvatarRebuildDefaults.Identity.racketAccentHex) ?? UIColor(red: 0, green: 0.9, blue: 1, alpha: 1) }
    var headbandUIColor: UIColor { UIColor(rallyAvatarHex: headband?.colorwayHex ?? "#F5EFE0") ?? UIColor(red: 0.96, green: 0.92, blue: 0.84, alpha: 1) }

    var skinColor: Color { Color(uiColor: skinUIColor) }
    var hairColor: Color { Color(uiColor: hairUIColor) }
    var topColor: Color { Color(uiColor: topUIColor) }
    var shortsColor: Color { Color(uiColor: shortsUIColor) }
    var shoesColor: Color { Color(uiColor: shoesUIColor) }
    var shoesAccentColor: Color { Color(uiColor: shoesAccentUIColor) }
    var racketColor: Color { Color(uiColor: racketUIColor) }
    var racketAccentColor: Color { Color(uiColor: racketAccentUIColor) }
    var headbandColor: Color { Color(uiColor: headbandUIColor) }

    mutating func set(_ gear: RallyGearReference?, for slot: RallyGearSlot) {
        switch slot {
        case .racket:
            racket = gear
        case .top:
            top = gear
        case .shorts:
            shorts = gear
        case .shoes:
            shoes = gear
        case .socks:
            socks = gear
        case .headband:
            headband = gear
        }
    }

    mutating func equipPreview(_ item: ShopItem) {
        let reference = RallyGearReference(
            id: item.id,
            colorwayHex: item.colorHex,
            accentHex: item.accentHex
        )

        switch item.category {
        case .racket:
            set(reference, for: .racket)
        case .top:
            set(reference, for: .top)
        case .bottom:
            set(reference, for: .shorts)
        case .shoes:
            set(reference, for: .shoes)
        case .accessory:
            set(reference, for: .headband)
        case .bag:
            break
        }
    }
}

// MARK: - Appearance Store

final class RallyAvatarAppearanceStore: ObservableObject {
    @Published var appearance: RallyAvatarAppearance

    init(appearance: RallyAvatarAppearance = RallyAvatarAppearance()) {
        self.appearance = appearance
    }

    func sync(from config: AvatarConfig?) {
        guard let config else { return }
        appearance = RallyAvatarAppearance(config: config)
    }

    func appearance(for config: AvatarConfig?, previewItem: ShopItem? = nil) -> RallyAvatarAppearance {
        guard let config else {
            var fallback = appearance
            if let previewItem {
                fallback.equipPreview(previewItem)
            }
            return fallback
        }
        return RallyAvatarAppearance(config: config, previewItem: previewItem)
    }

    func equip(_ gear: RallyGearReference?, for slot: RallyGearSlot) {
        appearance.set(gear, for: slot)
    }
}

private extension UIColor {
    convenience init?(rallyAvatarHex: String) {
        var hex = rallyAvatarHex.trimmingCharacters(in: .whitespacesAndNewlines)
        if hex.hasPrefix("#") {
            hex.removeFirst()
        }
        guard hex.count == 6, let value = UInt64(hex, radix: 16) else {
            return nil
        }
        let red = CGFloat((value >> 16) & 0xFF) / 255.0
        let green = CGFloat((value >> 8) & 0xFF) / 255.0
        let blue = CGFloat(value & 0xFF) / 255.0
        self.init(red: red, green: green, blue: blue, alpha: 1)
    }

    var isNearBlack: Bool {
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        return red < 0.06 && green < 0.06 && blue < 0.08
    }
}
