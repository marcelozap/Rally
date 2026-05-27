import SwiftUI

/// Combined logbook tab. The user toggles between training-session and match
/// entries at the top. We keep the segmented control as a sibling to each
/// list (rather than inside the NavigationStack) so it doesn't get duplicated
/// on push.
struct LogsView: View {
    @Binding var section: LogsSection

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                RallyUIKit.IconBadge(
                    systemName: section == .training ? "figure.tennis" : "trophy.fill",
                    tint: section == .training ? RallyUIKit.Palette.cyan : RallyUIKit.Palette.gold,
                    size: 36
                )

                Picker("Section", selection: $section) {
                    ForEach(LogsSection.allCases) { s in
                        Text(s.displayName).tag(s)
                    }
                }
                .pickerStyle(.segmented)
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 18)
                    .fill(Color.white.opacity(0.05))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18)
                    .stroke(Color.white.opacity(0.08), lineWidth: 1)
            )
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
