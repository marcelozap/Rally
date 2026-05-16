import SwiftUI

/// Visual effects and custom shapes for modern app aesthetic
struct RallyUIKit {
    
    /// Premium gradient background used for hero sections
    static var premiumGradient: LinearGradient {
        LinearGradient(
            colors: [
                Color.cyan.opacity(0.15),
                Color.blue.opacity(0.08),
                Color.black.opacity(0.3)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    /// Glassmorphic card effect (frosted glass)
    struct GlassmorphicCard<Content: View>: View {
        let content: Content
        let opacity: Double

        init(opacity: Double = 0.08, @ViewBuilder content: @escaping () -> Content) {
            self.content = content()
            self.opacity = opacity
        }

        var body: some View {
            content
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.white.opacity(opacity))
                )
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.2),
                                    Color.white.opacity(0.05)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )
                .shadow(color: Color.black.opacity(0.1), radius: 20, x: 0, y: 10)
        }
    }

    /// Shimmer loading animation
    struct ShimmerEffect: View {
        @State private var isAnimating = false

        var body: some View {
            LinearGradient(
                gradient: Gradient(colors: [
                    Color.white.opacity(0.1),
                    Color.white.opacity(0.3),
                    Color.white.opacity(0.1)
                ]),
                startPoint: .leading,
                endPoint: .trailing
            )
            .offset(x: isAnimating ? 300 : -300)
            .animation(
                Animation.linear(duration: 1.5).repeatForever(autoreverses: false),
                value: isAnimating
            )
            .onAppear {
                isAnimating = true
            }
        }
    }

    /// Pulsing badge for new content indicators
    struct PulsingBadge: View {
        @State private var scale: CGFloat = 1.0

        var body: some View {
            Circle()
                .fill(Color.red)
                .scaleEffect(scale)
                .animation(
                    Animation.easeInOut(duration: 1.0)
                        .repeatForever(autoreverses: true),
                    value: scale
                )
                .onAppear {
                    scale = 1.1
                }
                .frame(width: 12, height: 12)
        }
    }

    /// Bottom sheet presentation style
    static func bottomSheetTransition() -> AnyTransition {
        AnyTransition.asymmetric(
            insertion: .move(edge: .bottom).combined(with: .opacity),
            removal: .move(edge: .bottom).combined(with: .opacity)
        )
    }
}

/// Custom button styles for consistency
struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(.headline, design: .rounded).weight(.bold))
            .foregroundStyle(.black)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                LinearGradient(
                    colors: [Color.cyan, Color(red: 0.4, green: 0.95, blue: 1.0)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .cornerRadius(14)
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .opacity(configuration.isPressed ? 0.9 : 1.0)
            .animation(.easeOut(duration: 0.1), value: configuration.isPressed)
    }
}

struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(.subheadline, design: .rounded).weight(.semibold))
            .foregroundStyle(.cyan)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.cyan.opacity(0.5), lineWidth: 1)
            )
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(.easeOut(duration: 0.1), value: configuration.isPressed)
    }
}

/// Improved stat tile with animation
struct AnimatedStatTile: View {
    let value: String
    let label: String
    let tint: Color
    @State private var isAnimated = false

    var body: some View {
        VStack(spacing: 6) {
            Text(value)
                .font(.system(.title, design: .rounded).weight(.bold))
                .foregroundStyle(tint)
                .monospacedDigit()
                .scaleEffect(isAnimated ? 1.0 : 0.8)
            Text(label.uppercased())
                .font(.system(.caption2, design: .rounded).weight(.semibold))
                .tracking(2)
                .foregroundStyle(.white.opacity(0.55))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 18)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.04))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(tint.opacity(0.35), lineWidth: 1)
        )
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.6).delay(0.1)) {
                isAnimated = true
            }
        }
    }
}

// MARK: - Color Extensions

extension Color {
    /// Create color from hex string (e.g., "#00D9FF")
    init?(hex: String) {
        var hexSanitized = hex.trimmingCharacters(in: .whitespaces)
        hexSanitized = hexSanitized.hasPrefix("#") ? String(hexSanitized.dropFirst()) : hexSanitized

        var rgb: UInt64 = 0

        guard Scanner(string: hexSanitized).scanHexInt64(&rgb) else {
            return nil
        }

        let r = Double((rgb >> 16) & 0xFF) / 255.0
        let g = Double((rgb >> 8) & 0xFF) / 255.0
        let b = Double(rgb & 0xFF) / 255.0

        self.init(red: r, green: g, blue: b)
    }
}
