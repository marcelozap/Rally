import SwiftUI
import SwiftData

/// Editor + creator. `session == nil` ⇒ create new; otherwise edit in place.
struct TrainingEditorView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var date: Date
    @State private var durationMinutes: Int
    @State private var drillType: String
    @State private var intensity: Int
    @State private var notes: String

    private let existing: TrainingSession?

    private static let drillSuggestions = [
        "Baseline drills", "Volleys", "Serve practice",
        "Match play", "Footwork", "Backhand focus",
        "Forehand focus", "Conditioning", "Mental rehearsal"
    ]

    init(session: TrainingSession?) {
        self.existing = session
        _date = State(initialValue: session?.date ?? Date())
        _durationMinutes = State(initialValue: session?.durationMinutes ?? 60)
        _drillType = State(initialValue: session?.drillType ?? "")
        _intensity = State(initialValue: session?.intensity ?? 3)
        _notes = State(initialValue: session?.notes ?? "")
    }

    var body: some View {
        Form {
            Section("When") {
                DatePicker("Date", selection: $date, displayedComponents: [.date, .hourAndMinute])
            }

            Section("Focus") {
                TextField("Drill or focus area", text: $drillType)
                if drillType.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(Self.drillSuggestions, id: \.self) { d in
                                Chip(label: d, selected: false) {
                                    drillType = d
                                }
                            }
                        }
                    }
                }
            }

            Section("Duration") {
                Stepper(value: $durationMinutes, in: 5...240, step: 5) {
                    HStack {
                        Text("Minutes")
                        Spacer()
                        Text("\(durationMinutes)")
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Section("Intensity") {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("Effort")
                        Spacer()
                        Text(intensityLabel)
                            .foregroundStyle(.secondary)
                    }
                    HStack(spacing: 6) {
                        ForEach(1...5, id: \.self) { i in
                            Button {
                                intensity = i
                            } label: {
                                Capsule()
                                    .fill(i <= intensity ? Color.cyan : Color.white.opacity(0.12))
                                    .frame(height: 14)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }

            Section("Notes") {
                TextEditor(text: $notes)
                    .frame(minHeight: 100)
            }
        }
        .navigationTitle(existing == nil ? "Log training" : "Edit training")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("Cancel") { dismiss() }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button("Save") {
                    save()
                    dismiss()
                }
                .bold()
            }
        }
    }

    private var intensityLabel: String {
        switch intensity {
        case 1: return "Recovery"
        case 2: return "Light"
        case 3: return "Steady"
        case 4: return "Hard"
        default: return "Max"
        }
    }

    private func save() {
        if let existing = existing {
            existing.date = date
            existing.durationMinutes = durationMinutes
            existing.drillType = drillType
            existing.intensity = intensity
            existing.notes = notes
        } else {
            let new = TrainingSession(
                date: date,
                durationMinutes: durationMinutes,
                drillType: drillType,
                intensity: intensity,
                notes: notes
            )
            modelContext.insert(new)
        }
        try? modelContext.save()
        RallySyncTriggers.pushAfterLocalSave(modelContext: modelContext)
    }
}
