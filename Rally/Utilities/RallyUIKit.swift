import SwiftUI

/// Visual effects and custom shapes for modern app aesthetic
struct RallyUIKit {
    enum Spacing {
        static let xxs: CGFloat = 4
        static let xs: CGFloat = 8
        static let sm: CGFloat = 12
        static let md: CGFloat = 16
        static let lg: CGFloat = 20
        static let xl: CGFloat = 24
    }

    enum Radius {
        static let sm: CGFloat = 12
        static let md: CGFloat = 16
        static let lg: CGFloat = 20
        static let xl: CGFloat = 24
    }

    struct Palette {
        // Shared tennis-club colors keep every surface in the same visual world.
        static let obsidian = Color(red: 0.035, green: 0.065, blue: 0.055)
        static let ink = Color(red: 0.055, green: 0.105, blue: 0.090)
        static let slate = Color(red: 0.105, green: 0.175, blue: 0.145)
        static let graphite = Color(red: 0.19, green: 0.26, blue: 0.22)
        static let mist = Color.white.opacity(0.07)
        static let line = Color(red: 0.84, green: 0.88, blue: 0.79).opacity(0.16)
        static let cloud = Color(red: 0.78, green: 0.83, blue: 0.77)
        static let frost = Color(red: 0.97, green: 0.96, blue: 0.91)
        static let cyan = Color(red: 0.79, green: 0.89, blue: 0.56)
        static let iconCyan = Color(red: 0.85, green: 0.94, blue: 0.64)
        static let teal = Color(red: 0.37, green: 0.65, blue: 0.55)
        static let lime = Color(red: 0.82, green: 0.92, blue: 0.48)
        static let coral = Color(red: 0.86, green: 0.52, blue: 0.36)
        static let rose = Color(red: 0.73, green: 0.49, blue: 0.43)
        static let gold = Color(red: 0.83, green: 0.73, blue: 0.47)
        static let champagne = Color(red: 0.95, green: 0.91, blue: 0.79)
        static let smoke = Color(red: 0.57, green: 0.65, blue: 0.59)
    }

    enum Typography {
        static func display(_ size: CGFloat, weight: Font.Weight = .semibold) -> Font {
            .system(size: size, weight: weight, design: .serif)
        }

        static func title(_ textStyle: Font.TextStyle, weight: Font.Weight = .bold) -> Font {
            .system(textStyle, design: .serif).weight(weight)
        }

        static func label(_ textStyle: Font.TextStyle, weight: Font.Weight = .semibold) -> Font {
            .system(textStyle, design: .rounded).weight(weight)
        }

        static func body(_ textStyle: Font.TextStyle, weight: Font.Weight = .medium) -> Font {
            .system(textStyle, design: .default).weight(weight)
        }
    }

    enum Shadow {
        static let depthColor = Color.black.opacity(0.18)
        static let depthRadius: CGFloat = 18
        static let depthY: CGFloat = 10

        static func glow(_ tint: Color) -> Color {
            tint.opacity(0.07)
        }
    }

    /// Premium gradient background used for hero sections
    static var premiumGradient: LinearGradient {
        LinearGradient(
            colors: [
                Palette.champagne.opacity(0.12),
                Palette.cyan.opacity(0.20),
                Palette.teal.opacity(0.08),
                Palette.obsidian
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    static var screenBackground: some View {
        ZStack {
            LinearGradient(colors: [Palette.ink, Palette.obsidian],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
            RadialGradient(colors: [Palette.teal.opacity(0.12), .clear],
                           center: .topLeading, startRadius: 0, endRadius: 460)
            LinearGradient(colors: [Palette.champagne.opacity(0.035), .clear],
                           startPoint: .top, endPoint: .center)
        }
        .ignoresSafeArea()
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
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(opacity + 0.03),
                                    Color.white.opacity(opacity * 0.65)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                )
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.24),
                                    Color.white.opacity(0.04)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )
                .shadow(color: Color.black.opacity(0.22), radius: 28, x: 0, y: 16)
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

    static func accentGradient(_ color: Color) -> LinearGradient {
        LinearGradient(
            colors: [color, color.opacity(0.88)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    struct SectionCard<Content: View>: View {
        let stroke: Color
        let content: Content

        init(stroke: Color = Palette.mist, @ViewBuilder content: () -> Content) {
            self.stroke = stroke
            self.content = content()
        }

        var body: some View {
            content
                .padding(Spacing.lg - 2)
                .background(
                    RoundedRectangle(cornerRadius: Radius.lg)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.07),
                                    Color.white.opacity(0.035)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                )
                .background(
                    RoundedRectangle(cornerRadius: Radius.lg)
                        .fill(.ultraThinMaterial.opacity(0.25))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: Radius.lg)
                        .stroke(stroke, lineWidth: 1)
                )
                .shadow(color: Shadow.depthColor, radius: Shadow.depthRadius, x: 0, y: Shadow.depthY)
        }
    }

    struct LuxePanel<Content: View>: View {
        let tint: Color
        let content: Content

        init(tint: Color = Palette.champagne, @ViewBuilder content: () -> Content) {
            self.tint = tint
            self.content = content()
        }

        var body: some View {
            content
                .padding(Spacing.lg - 2)
                .background(
                    RoundedRectangle(cornerRadius: Radius.xl)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.11),
                                    Color.white.opacity(0.03),
                                    Color.black.opacity(0.08)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                )
                .background(
                    RoundedRectangle(cornerRadius: Radius.xl)
                        .fill(.ultraThinMaterial.opacity(0.26))
                )
                .overlay(alignment: .top) {
                    RoundedRectangle(cornerRadius: Radius.xl)
                        .fill(
                            LinearGradient(
                                colors: [Color.white.opacity(0.18), .clear],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .frame(height: 72)
                        .clipShape(
                            RoundedRectangle(cornerRadius: Radius.xl, style: .continuous)
                        )
                        .allowsHitTesting(false)
                }
                .overlay(
                    RoundedRectangle(cornerRadius: Radius.xl)
                        .stroke(
                            LinearGradient(
                                colors: [
                                    tint.opacity(0.24),
                                    Color.white.opacity(0.10),
                                    Color.clear
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )
                .shadow(color: Shadow.glow(tint), radius: 12, x: 0, y: 5)
                .shadow(color: Color.black.opacity(0.28), radius: 32, x: 0, y: 18)
        }
    }

    struct EditorialEyebrow: View {
        let text: String
        let tint: Color

        var body: some View {
            Text(text.uppercased())
                .font(Typography.label(.caption, weight: .bold))
                .tracking(2.8)
                .foregroundStyle(tint)
                .padding(.horizontal, Spacing.sm)
                .padding(.vertical, 7)
                .background(
                    Capsule()
                        .fill(tint.opacity(0.14))
                )
                .overlay(
                    Capsule()
                        .stroke(tint.opacity(0.28), lineWidth: 1)
                )
        }
    }

    struct IconBadge: View {
        let systemName: String
        let tint: Color
        var size: CGFloat = 48

        var body: some View {
            ZStack {
                RoundedRectangle(cornerRadius: size * 0.34)
                    .fill(RallyUIKit.accentGradient(tint))
                    .overlay(
                        RoundedRectangle(cornerRadius: size * 0.34)
                            .stroke(Color.white.opacity(0.16), lineWidth: 1)
                    )

                Image(systemName: systemName)
                    .font(.system(size: size * 0.36, weight: .bold))
                    .foregroundStyle(.white)
            }
            .frame(width: size, height: size)
            .shadow(color: Shadow.glow(tint), radius: 16, x: 0, y: 10)
        }
    }

    struct SurfaceTile<Content: View>: View {
        let tint: Color
        let content: Content

        init(tint: Color = Palette.line, @ViewBuilder content: () -> Content) {
            self.tint = tint
            self.content = content()
        }

        var body: some View {
            content
                .padding(Spacing.md)
                .background(
                    RoundedRectangle(cornerRadius: Radius.md)
                        .fill(
                            LinearGradient(
                                colors: [Color.white.opacity(0.055), Color.white.opacity(0.025)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: Radius.md)
                        .stroke(tint.opacity(0.24), lineWidth: 1)
                )
        }
    }

    struct PremiumStage<Content: View>: View {
        let tint: Color
        let content: Content

        init(tint: Color = Palette.cyan, @ViewBuilder content: () -> Content) {
            self.tint = tint
            self.content = content()
        }

        var body: some View {
            ZStack {
                RoundedRectangle(cornerRadius: 24)
                    .fill(
                        LinearGradient(
                            colors: [
                                Palette.ink,
                                Palette.slate,
                                Color.black
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )

                Circle()
                    .fill(tint.opacity(0.14))
                    .frame(width: 180, height: 180)
                    .blur(radius: 26)
                    .offset(x: -80, y: -78)

                Circle()
                    .fill(Palette.champagne.opacity(0.12))
                    .frame(width: 160, height: 160)
                    .blur(radius: 22)
                    .offset(x: 86, y: 98)

                VStack {
                    HStack {
                        Capsule()
                            .fill(Color.white.opacity(0.16))
                            .frame(width: 120, height: 16)
                            .blur(radius: 10)
                            .rotationEffect(.degrees(14))
                            .offset(x: 12, y: -6)
                        Spacer()
                    }
                    Spacer()
                }
                .padding(18)

                content
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)

                RoundedRectangle(cornerRadius: 24)
                    .stroke(
                        LinearGradient(
                            colors: [tint.opacity(0.28), Color.white.opacity(0.10), Color.clear],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            }
            .shadow(color: Shadow.glow(tint), radius: 18, x: 0, y: 10)
        }
    }
}

/// Custom button styles for consistency
struct PrimaryButtonStyle: ButtonStyle {
    var tint: Color = RallyUIKit.Palette.cyan

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(RallyUIKit.Typography.label(.headline, weight: .bold))
            .tracking(0.3)
            .foregroundStyle(RallyUIKit.Palette.obsidian)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 17)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(RallyUIKit.accentGradient(tint))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .fill(
                        LinearGradient(
                            colors: [Color.white.opacity(0.22), .clear],
                            startPoint: .top,
                            endPoint: .center
                        )
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 16))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.white.opacity(0.18), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(configuration.isPressed ? 0.12 : 0.20), radius: 20, x: 0, y: 14)
            .shadow(color: tint.opacity(configuration.isPressed ? 0.10 : 0.20), radius: 24, x: 0, y: 16)
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .opacity(configuration.isPressed ? 0.94 : 1.0)
            .animation(.easeOut(duration: 0.1), value: configuration.isPressed)
    }
}

struct SecondaryButtonStyle: ButtonStyle {
    var tint: Color = RallyUIKit.Palette.cyan

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(RallyUIKit.Typography.label(.subheadline, weight: .semibold))
            .foregroundStyle(RallyUIKit.Palette.frost)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 13)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(
                        LinearGradient(
                            colors: [tint.opacity(0.16), Color.white.opacity(0.05)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(tint.opacity(0.24), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.16), radius: 14, x: 0, y: 10)
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .opacity(configuration.isPressed ? 0.92 : 1)
            .animation(.easeOut(duration: 0.1), value: configuration.isPressed)
    }
}

struct GhostButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(RallyUIKit.Typography.label(.subheadline, weight: .semibold))
            .foregroundStyle(RallyUIKit.Palette.frost)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 13)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(
                        LinearGradient(
                            colors: [Color.white.opacity(0.08), Color.white.opacity(0.03)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(RallyUIKit.Palette.line, lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.14), radius: 14, x: 0, y: 10)
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .opacity(configuration.isPressed ? 0.92 : 1)
            .animation(.easeOut(duration: 0.1), value: configuration.isPressed)
    }
}

struct RallyTextFieldModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(RallyUIKit.Typography.body(.body, weight: .medium))
            .foregroundStyle(RallyUIKit.Palette.frost)
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(
                        LinearGradient(
                            colors: [Color.white.opacity(0.08), Color.white.opacity(0.04)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(RallyUIKit.Palette.line, lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.12), radius: 12, x: 0, y: 8)
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

extension View {
    func rallyTextFieldStyle() -> some View {
        modifier(RallyTextFieldModifier())
    }
}
