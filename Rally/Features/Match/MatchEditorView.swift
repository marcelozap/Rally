import SwiftUI
import SwiftData

struct MatchEditorView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var date: Date
    @State private var opponentName: String
    @State private var location: String
    @State private var surface: CourtSurface
    @State private var resultWon: Bool
    @State private var sets: [SetScore]
    @State private var notes: String

    private let existing: MatchEntry?

    init(match: MatchEntry?) {
        self.existing = match
        _date         = State(initialValue: match?.date ?? Date())
        _opponentName = State(initialValue: match?.opponentName ?? "")
        _location     = State(initialValue: match?.location ?? "")
        _surface      = State(initialValue: match?.surface ?? .hard)
        _resultWon    = State(initialValue: match?.resultWon ?? true)
        _sets         = State(initialValue: match?.sets ?? [SetScore(won: 6, lost: 4, tiebreak: nil)])
        _notes        = State(initialValue: match?.notes ?? "")
    }

    var body: some View {
        Form {
            Section("When") {
                DatePicker("Date", selection: $date, displayedComponents: [.date, .hourAndMinute])
            }

            Section("Opponent & venue") {
                TextField("Opponent", text: $opponentName)
                TextField("Location", text: $location)
                Picker("Surface", selection: $surface) {
                    ForEach(CourtSurface.allCases) { s in
                        Text(s.displayName).tag(s)
                    }
                }
            }

            Section("Result") {
                Picker("Outcome", selection: $resultWon) {
                    Text("Won").tag(true)
                    Text("Lost").tag(false)
                }
                .pickerStyle(.segmented)
            }

            Section("Sets") {
                ForEach(sets.indices, id: \.self) { i in
                    SetScoreEditor(score: $sets[i])
                }
                .onDelete { offsets in
                    sets.remove(atOffsets: offsets)
                }
                Button {
                    sets.append(SetScore(won: 0, lost: 0, tiebreak: nil))
                } label: {
                    Label("Add set", systemImage: "plus.circle")
                        .foregroundStyle(.cyan)
                }
            }

            Section("Notes") {
                TextEditor(text: $notes)
                    .frame(minHeight: 100)
            }
        }
        .scrollContentBackground(.hidden)
        .background(RallyUIKit.screenBackground)
        .navigationTitle(existing == nil ? "Log match" : "Edit match")
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
                .font(.system(.subheadline, design: .rounded).weight(.bold))
            }
        }
    }

    private func save() {
        if let existing = existing {
            existing.date = date
            existing.opponentName = opponentName
            existing.location = location
            existing.surface = surface
            existing.resultWon = resultWon
            existing.sets = sets
            existing.notes = notes
        } else {
            let new = MatchEntry(
                date: date,
                opponentName: opponentName,
                location: location,
                surface: surface,
                resultWon: resultWon,
                sets: sets,
                notes: notes
            )
            modelContext.insert(new)
        }
        try? modelContext.save()
        RallySyncTriggers.pushAfterLocalSave(modelContext: modelContext)
    }
}

// MARK: - Set score editor

private struct SetScoreEditor: View {
    @Binding var score: SetScore

    var body: some View {
        HStack(spacing: 12) {
            Stepper(value: $score.won, in: 0...20) {
                HStack {
                    Text("You")
                    Spacer()
                    Text("\(score.won)").foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity)

            Stepper(value: $score.lost, in: 0...20) {
                HStack {
                    Text("Them")
                    Spacer()
                    Text("\(score.lost)").foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity)
        }
    }
}
