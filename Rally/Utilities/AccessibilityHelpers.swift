import SwiftUI

/// Accessibility helpers for Rally
extension View {
    /// Apply reduced motion if user prefers reduced animations
    func respectsReducedMotion<V: View>(@ViewBuilder fullMotion: @escaping () -> V, @ViewBuilder reducedMotion: @escaping () -> V) -> some View {
        Group {
            if UIAccessibility.isReduceMotionEnabled {
                reducedMotion()
            } else {
                fullMotion()
            }
        }
    }

    /// Add VoiceOver label with hint
    func voiceOverLabel(_ label: String, hint: String = "") -> some View {
        accessibility(label: Text(label))
            .accessibility(hint: Text(hint))
    }

    /// Mark as button for VoiceOver
    func accessibleButton(_ label: String) -> some View {
        accessibility(label: Text(label))
            .accessibility(traits: .isButton)
    }

    /// Mark as header for VoiceOver
    func accessibleHeader(_ label: String) -> some View {
        accessibility(label: Text(label))
            .accessibility(traits: .isHeader)
    }
}

/// High contrast colors for accessibility
struct AccessibilityColors {
    static let highContrastCyan = Color(red: 0.0, green: 0.8, blue: 1.0)
    static let highContrastPink = Color(red: 1.0, green: 0.2, blue: 0.5)
    static let highContrastYellow = Color(red: 1.0, green: 0.9, blue: 0.0)
    static let highContrastGreen = Color(red: 0.2, green: 0.9, blue: 0.4)
}

/// Determines if user prefers reduced opacity/transparency
let prefersReducedTransparency = UIAccessibility.isReduceTransparencyEnabled
