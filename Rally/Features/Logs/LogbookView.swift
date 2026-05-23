import SwiftUI

/// Combined training, match, and journal history — one **Logbook** destination.
struct LogbookView: View {
    @Binding var section: LogbookSection
    @State private var showJournalComposer = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("Section", selection: $section) {
                    ForEach(LogbookSection.allCases) { s in
                        Text(s.displayName).tag(s)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 4)

                switch section {
                case .training:
                    TrainingLogView()
                case .matches:
                    MatchLogView()
                case .journal:
                    JournalLogSection(showComposer: $showJournalComposer)
                }
            }
            .background(Color.black.ignoresSafeArea())
            .navigationTitle("Logbook")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    HStack(spacing: 10) {
                        if section == .journal {
                            Button {
                                showJournalComposer = true
                            } label: {
                                Image(systemName: "square.and.pencil")
                                    .foregroundStyle(.cyan)
                            }
                        }
                        SoundToggleButton()
                    }
                }
            }
        }
    }
}

enum LogbookSection: String, CaseIterable, Identifiable, Hashable {
    case training
    case matches
    case journal

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .training: return "Training"
        case .matches:  return "Matches"
        case .journal:  return "Journal"
        }
    }
}
