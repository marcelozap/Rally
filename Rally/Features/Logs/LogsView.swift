import SwiftUI

/// Combined logbook tab. The user toggles between training-session and match
/// entries at the top. We keep the segmented control as a sibling to each
/// list (rather than inside the NavigationStack) so it doesn't get duplicated
/// on push.
struct LogsView: View {
    @Binding var section: LogsSection

    var body: some View {
        VStack(spacing: 0) {
            RallyUIKit.SectionCard(stroke: activeTint.opacity(0.24)) {
                VStack(alignment: .leading, spacing: 14) {
                    HStack(spacing: 12) {
                        RallyUIKit.IconBadge(
                            systemName: section == .training ? "figure.tennis" : "trophy.fill",
                            tint: activeTint,
                            size: 36
                        )

                        VStack(alignment: .leading, spacing: 3) {
                            Text("Player logbook")
                                .font(RallyUIKit.Typography.body(.headline, weight: .bold))
                                .foregroundStyle(RallyUIKit.Palette.frost)
                            Text("Move between your training blocks and match record.")
                                .font(RallyUIKit.Typography.body(.caption, weight: .medium))
                                .foregroundStyle(RallyUIKit.Palette.cloud.opacity(0.58))
                        }
                    }

                    HStack(spacing: 10) {
                        ForEach(LogsSection.allCases) { value in
                            logSectionButton(value)
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 8)

            switch section {
            case .training: TrainingLogView()
            case .matches:  MatchLogView()
            }
        }
        .background(RallyUIKit.screenBackground)
    }

    private var activeTint: Color {
        section == .training ? RallyUIKit.Palette.cyan : RallyUIKit.Palette.gold
    }

    private func logSectionButton(_ value: LogsSection) -> some View {
        let selected = value == section
        return Button {
            withAnimation(.spring(response: 0.28, dampingFraction: 0.84)) {
                section = value
            }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: value == .training ? "figure.tennis" : "trophy.fill")
                    .font(.system(size: 12, weight: .bold))
                Text(value.displayName)
                    .font(RallyUIKit.Typography.label(.subheadline, weight: .semibold))
                    .lineLimit(1)
            }
            .foregroundStyle(selected ? Color.black : RallyUIKit.Palette.frost.opacity(0.9))
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 14)
            .padding(.vertical, 11)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(selected ? AnyShapeStyle(RallyUIKit.accentGradient(value == .training ? RallyUIKit.Palette.cyan : RallyUIKit.Palette.gold)) : AnyShapeStyle(Color.white.opacity(0.05)))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(selected ? Color.white.opacity(0.26) : Color.white.opacity(0.08), lineWidth: 1)
            )
            .shadow(color: selected ? activeTint.opacity(0.18) : .clear, radius: 12, x: 0, y: 6)
            .contentShape(RoundedRectangle(cornerRadius: 16))
        }
        .buttonStyle(.plain)
    }
}

enum LogsSection: String, CaseIterable, Identifiable, Hashable {
    case training
    case matches

    var id: String { rawValue }
    var displayName: String {
        switch self {
        case .training: return "Training"
        case .matches:  return "Matches"
        }
    }
}
