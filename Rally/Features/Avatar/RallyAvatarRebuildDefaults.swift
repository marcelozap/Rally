import CoreGraphics
import SwiftUI
import UIKit

enum RallyAvatarRebuildDefaults {
    // MARK: - Identity Attributes

    enum Identity {
        static let skinToneHex = "#E0AD84"
        static let hairColorHex = "#030305"
        static let topColorHex = "#0E1B25"
        static let shortsColorHex = "#080A0E"
        static let shoesColorHex = "#F0F7FA"
        static let shoesAccentHex = "#00D6EF"
        static let racketColorHex = "#C7C7C7"
        static let racketAccentHex = "#00E5FF"
        static let bodyProfile: RallyAvatarBodyProfile = .athletic
        static let hairStyle: RallyAvatarHairProfile = .zukoJetBlack
        static let pose: RallyAvatarPose = .confidentAsymmetricIdle
    }

    // MARK: - Gear Slots

    enum Gear {
        static let defaultRacket = RallyGearReference(
            id: "default-racket",
            colorwayHex: Identity.racketColorHex,
            accentHex: Identity.racketAccentHex
        )
        static let defaultTop = RallyGearReference(
            id: "default-top",
            colorwayHex: Identity.topColorHex,
            accentHex: "#65DFF2"
        )
        static let defaultShorts = RallyGearReference(
            id: "default-shorts",
            colorwayHex: Identity.shortsColorHex,
            accentHex: "#171A22"
        )
        static let defaultShoes = RallyGearReference(
            id: "default-shoes",
            colorwayHex: Identity.shoesColorHex,
            accentHex: Identity.shoesAccentHex
        )
    }

    // MARK: - Face

    enum Face {
        static let friendlyMouthPitchRadians: CGFloat = 0.044
        static let friendlyMouthRollRadians: CGFloat = 0.012
        static let smileCornerLift: CGFloat = 0.24
        static let smileRotationDegrees: CGFloat = -2.5
        static let glassesFrameUIColor = UIColor(red: 0.16, green: 0.15, blue: 0.14, alpha: 0.64)
        static let lensFillUIColor = UIColor.white.withAlphaComponent(0.04)
    }

    // MARK: - Editorial

    enum Editorial {
        static let yawDegrees: CGFloat = 27
        static let yawRadians: CGFloat = 0.49
        static let stagingOffsetX: CGFloat = 0.11
        static let hipPitchRadians: CGFloat = 0.08
        static let perspective: CGFloat = 0.62
        static let offsetXRatio: CGFloat = 0.07
        static let offsetYRatio: CGFloat = 0.03
        static let rollDegrees: CGFloat = 2.5
        static let homeStageLeadingPadding: CGFloat = 28
        static let shopStageLeadingPadding: CGFloat = 24
        static let lockerStageLeadingPadding: CGFloat = 22
        static let gameplayIdleYaw: CGFloat = 0.11
        static let gameplayIdleDepthScale: CGFloat = 0.93
    }

    // MARK: - Proportions

    enum Proportions {
        static func headSizeRatio(for profile: RallyAvatarBodyProfile) -> CGFloat {
            switch profile {
            case .slim:
                return 0.116
            case .athletic:
                return 0.112
            case .strong:
                return 0.116
            }
        }

        static func legHeightRatio(for profile: RallyAvatarBodyProfile) -> CGFloat {
            switch profile {
            case .slim:
                return 0.415
            case .athletic:
                return 0.430
            case .strong:
                return 0.420
            }
        }

        static func torsoWidthRatio(for profile: RallyAvatarBodyProfile) -> CGFloat {
            switch profile {
            case .slim:
                return 0.286
            case .athletic:
                return 0.318
            case .strong:
                return 0.350
            }
        }

        static func shoulderSpanMultiplier(for profile: RallyAvatarBodyProfile) -> CGFloat {
            switch profile {
            case .slim:
                return 1.18
            case .athletic:
                return 1.24
            case .strong:
                return 1.20
            }
        }
    }

    // MARK: - Court Layout

    struct CourtLayout {
        let legHeight: CGFloat
        let trailLegHeight: CGFloat
        let legY: CGFloat
        let torsoY: CGFloat
        let neckY: CGFloat
        let headY: CGFloat
        let hairY: CGFloat
        let headPathScale: CGFloat

        static func make(profile: RallyAvatarBodyProfile, scale: CGFloat) -> CourtLayout {
            let legBoost: CGFloat
            let headShrink: CGFloat

            switch profile {
            case .slim:
                legBoost = 0.96
                headShrink = 0.74          // ~1:7 head:body (was 0.88 — Mii-like)
            case .athletic:
                legBoost = 0.98
                headShrink = 0.70          // ~1:7.2 head:body (was 0.86 — Mii-like)
            case .strong:
                legBoost = 0.94
                headShrink = 0.76          // ~1:7 head:body (was 0.90 — Mii-like)
            }

            return CourtLayout(
                legHeight: 108 * scale * legBoost,
                trailLegHeight: 102 * scale * legBoost,
                legY: 32 * scale,
                torsoY: 112 * scale,
                neckY: 144 * scale,
                headY: 168 * scale,
                hairY: 180 * scale,
                headPathScale: scale * headShrink
            )
        }
    }
}

enum AvatarShopEmote: String, CaseIterable, Identifiable {
    case idle
    case wave
    case celebrate
    case shopLook

    var id: String { rawValue }

    var label: String {
        switch self {
        case .idle:
            return "Idle"
        case .wave:
            return "Wave"
        case .celebrate:
            return "Celebrate"
        case .shopLook:
            return "Shop"
        }
    }

    var systemImage: String {
        switch self {
        case .idle:
            return "figure.stand"
        case .wave:
            return "hand.wave.fill"
        case .celebrate:
            return "sparkles"
        case .shopLook:
            return "bag.fill"
        }
    }
}
