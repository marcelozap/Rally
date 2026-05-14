import SwiftUI

/// Combined logbook tab. The user toggles between training-session and match
/// entries at the top. We keep the segmented control as a sibling to each
/// list (rather than inside the NavigationStack) so it doesn't get duplicated
/// on push.
struct LogsView: View {
    @Binding var section: LogsSection

    var body: some View {
        VStack(spacing: 0) {
            Picker("Section", selection: $section) {
                ForEach(LogsSection.allCases) { s in
                    Text(s.displayName).tag(s)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 4)

            switch section {
            case .training: TrainingLogView()
            case .matches:  MatchLogView()
            }
        }
        .background(Color.black.ignoresSafeArea())
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
