import SwiftUI
import SwiftData
import PhotosUI

struct MatchEditorView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var date: Date
    @State private var opponentName: String
    @State private var location: String
    @State private var photoData: Data?
    @State private var surface: CourtSurface
    @State private var resultWon: Bool
    @State private var sets: [SetScore]
    @State private var notes: String
    @State private var selectedPhotoItem: PhotosPickerItem?

    private let existing: MatchEntry?

    init(match: MatchEntry?) {
        self.existing = match
        _date         = State(initialValue: match?.date ?? Date())
        _opponentName = State(initialValue: match?.opponentName ?? "")
        _location     = State(initialValue: match?.location ?? "")
        _photoData    = State(initialValue: match?.photoData)
        _surface      = State(initialValue: match?.surface ?? .hard)
        _resultWon    = State(initialValue: match?.resultWon ?? true)
        _sets         = State(initialValue: match?.sets ?? [SetScore(won: 6, lost: 4, tiebreak: nil)])
        _notes        = State(initialValue: match?.notes ?? "")
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                editorCard(title: "When") {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(spacing: 10) {
                            RallyUIKit.IconBadge(systemName: "calendar", tint: RallyUIKit.Palette.cyan, size: 30)
                            VStack(alignment: .leading, spacing: 3) {
                                Text("Match moment")
                                    .font(RallyUIKit.Typography.body(.subheadline, weight: .bold))
                                    .foregroundStyle(RallyUIKit.Palette.frost)
                                Text("Pin the exact day and time you want this result to live on your timeline.")
                                    .font(RallyUIKit.Typography.body(.caption, weight: .medium))
                                    .foregroundStyle(RallyUIKit.Palette.cloud.opacity(0.58))
                            }
                        }

                        DatePicker("Date", selection: $date, displayedComponents: [.date, .hourAndMinute])
                            .foregroundStyle(RallyUIKit.Palette.frost)
                            .tint(RallyUIKit.Palette.cyan)
                            .padding(12)
                            .background(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .fill(Color.white.opacity(0.05))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .stroke(RallyUIKit.Palette.line, lineWidth: 1)
                            )
                    }
                }

                editorCard(title: "Opponent & venue") {
                    TextField("Opponent", text: $opponentName)
                        .rallyTextFieldStyle()
                    TextField("Location", text: $location)
                        .rallyTextFieldStyle()

                    VStack(alignment: .leading, spacing: 10) {
                        Text("SURFACE")
                            .font(RallyUIKit.Typography.label(.caption, weight: .bold))
                            .tracking(1.1)
                            .foregroundStyle(RallyUIKit.Palette.cloud.opacity(0.42))
                        HStack(spacing: 8) {
                            ForEach(CourtSurface.allCases) { s in
                                surfaceChip(s)
                            }
                        }
                    }
                }

                editorCard(title: "Photo") {
                    if let preview = previewImage {
                        ZStack(alignment: .topTrailing) {
                            Image(uiImage: preview)
                                .resizable()
                                .scaledToFill()
                                .frame(maxWidth: .infinity)
                                .frame(height: 220)
                                .clipShape(RoundedRectangle(cornerRadius: 16))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16)
                                        .stroke(RallyUIKit.Palette.line, lineWidth: 1)
                                )

                            Button {
                                photoData = nil
                                selectedPhotoItem = nil
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.title3.weight(.bold))
                                    .foregroundStyle(.white, Color.black.opacity(0.45))
                            }
                            .padding(10)
                        }
                    }

                    PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                        Label(photoData == nil ? "Add match photo" : "Swap photo", systemImage: "photo.fill.on.rectangle.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(SecondaryButtonStyle(tint: RallyUIKit.Palette.gold))

                    Text("Perfect for a team picture, doubles partner moment, or one shot you want to remember with the score.")
                        .font(RallyUIKit.Typography.body(.caption, weight: .medium))
                        .foregroundStyle(RallyUIKit.Palette.cloud.opacity(0.52))
                }

                editorCard(title: "Result") {
                    HStack(spacing: 10) {
                        resultChip(title: "Won", isActive: resultWon) { resultWon = true }
                        resultChip(title: "Lost", isActive: !resultWon) { resultWon = false }
                    }
                }

                editorCard(title: "Sets") {
                    VStack(spacing: 10) {
                        ForEach(sets.indices, id: \.self) { i in
                            SetScoreEditor(score: $sets[i])
                        }

                        Button {
                            sets.append(SetScore(won: 0, lost: 0, tiebreak: nil))
                        } label: {
                            Label("Add set", systemImage: "plus.circle.fill")
                        }
                        .buttonStyle(SecondaryButtonStyle(tint: RallyUIKit.Palette.cyan))
                    }
                }

                editorCard(title: "Notes") {
                    ZStack(alignment: .topLeading) {
                        if notes.isEmpty {
                            Text("How the match felt, what changed, and what to bring into the next one.")
                                .font(RallyUIKit.Typography.body(.body, weight: .medium))
                                .foregroundStyle(RallyUIKit.Palette.cloud.opacity(0.30))
                                .padding(.horizontal, 16)
                                .padding(.vertical, 14)
                        }
                        TextEditor(text: $notes)
                            .scrollContentBackground(.hidden)
                            .foregroundStyle(RallyUIKit.Palette.frost.opacity(0.92))
                            .frame(minHeight: 120)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 6)
                    }
                    .background(
                        RoundedRectangle(cornerRadius: 14)
                            .fill(
                                LinearGradient(
                                    colors: [Color.white.opacity(0.07), Color.white.opacity(0.035)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(RallyUIKit.Palette.line, lineWidth: 1)
                    )
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .padding(.bottom, 40)
        }
        .background(RallyUIKit.screenBackground)
        .navigationTitle(existing == nil ? "Log match" : "Edit match")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("Cancel") { dismiss() }
                    .foregroundStyle(RallyUIKit.Palette.frost.opacity(0.82))
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button("Save") {
                    save()
                    dismiss()
                }
                .font(RallyUIKit.Typography.label(.subheadline, weight: .bold))
                .foregroundStyle(RallyUIKit.Palette.cyan)
            }
        }
        .task(id: selectedPhotoItem) {
            guard let selectedPhotoItem else { return }
            if let data = try? await selectedPhotoItem.loadTransferable(type: Data.self),
               let normalized = normalizedImageData(from: data) {
                photoData = normalized
            }
        }
    }

    private func editorCard<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        RallyUIKit.SectionCard(stroke: RallyUIKit.Palette.line) {
            VStack(alignment: .leading, spacing: 12) {
                Text(title.uppercased())
                    .font(RallyUIKit.Typography.label(.caption, weight: .bold))
                    .tracking(1.1)
                    .foregroundStyle(RallyUIKit.Palette.cloud.opacity(0.42))
                content()
            }
        }
    }

    private func surfaceChip(_ courtSurface: CourtSurface) -> some View {
        let isSelected = surface == courtSurface
        return Button {
            surface = courtSurface
        } label: {
            Text(courtSurface.displayName)
                .font(RallyUIKit.Typography.body(.caption, weight: .semibold))
                .foregroundStyle(isSelected ? RallyUIKit.Palette.obsidian : RallyUIKit.Palette.frost)
                .padding(.horizontal, 12)
                .padding(.vertical, 9)
                .background(
                    Capsule()
                        .fill(isSelected ? AnyShapeStyle(RallyUIKit.accentGradient(RallyUIKit.Palette.gold)) : AnyShapeStyle(Color.white.opacity(0.08)))
                )
                .overlay(
                    Capsule()
                        .stroke(isSelected ? Color.white.opacity(0.18) : RallyUIKit.Palette.line, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }

    private func resultChip(title: String, isActive: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(RallyUIKit.Typography.body(.subheadline, weight: .bold))
                .foregroundStyle(isActive ? RallyUIKit.Palette.obsidian : RallyUIKit.Palette.frost)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(isActive ? AnyShapeStyle(RallyUIKit.accentGradient(title == "Won" ? RallyUIKit.Palette.lime : RallyUIKit.Palette.rose)) : AnyShapeStyle(Color.white.opacity(0.08)))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(isActive ? Color.white.opacity(0.18) : RallyUIKit.Palette.line, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }

    private func save() {
        if let existing = existing {
            existing.date = date
            existing.opponentName = opponentName
            existing.location = location
            existing.photoData = photoData
            existing.surface = surface
            existing.resultWon = resultWon
            existing.sets = sets
            existing.notes = notes
        } else {
            let new = MatchEntry(
                date: date,
                opponentName: opponentName,
                location: location,
                photoData: photoData,
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

    private var previewImage: UIImage? {
        guard let photoData else { return nil }
        return UIImage(data: photoData)
    }

    private func normalizedImageData(from data: Data) -> Data? {
        guard let image = UIImage(data: data) else { return nil }
        return image.jpegData(compressionQuality: 0.82)
    }
}

// MARK: - Set score editor

private struct SetScoreEditor: View {
    @Binding var score: SetScore

    var body: some View {
        HStack(spacing: 12) {
            scoreControl(title: "You", value: $score.won, tint: RallyUIKit.Palette.lime)
            scoreControl(title: "Them", value: $score.lost, tint: RallyUIKit.Palette.rose)
        }
    }

    private func scoreControl(title: String, value: Binding<Int>, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(RallyUIKit.Typography.label(.subheadline, weight: .bold))
                .foregroundStyle(RallyUIKit.Palette.frost)

            HStack(spacing: 8) {
                stepperButton(systemName: "minus", isEnabled: value.wrappedValue > 0, tint: tint) {
                    value.wrappedValue = max(0, value.wrappedValue - 1)
                }

                Text("\(value.wrappedValue)")
                    .font(RallyUIKit.Typography.display(24, weight: .bold))
                    .foregroundStyle(tint)
                    .monospacedDigit()
                    .frame(maxWidth: .infinity)

                stepperButton(systemName: "plus", isEnabled: value.wrappedValue < 20, tint: tint) {
                    value.wrappedValue = min(20, value.wrappedValue + 1)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.white.opacity(0.05))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(RallyUIKit.Palette.line, lineWidth: 1)
        )
    }

    private func stepperButton(systemName: String, isEnabled: Bool, tint: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(isEnabled ? RallyUIKit.Palette.obsidian : RallyUIKit.Palette.cloud.opacity(0.35))
                .frame(width: 34, height: 34)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(isEnabled ? AnyShapeStyle(RallyUIKit.accentGradient(tint)) : AnyShapeStyle(Color.white.opacity(0.06)))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(isEnabled ? Color.white.opacity(0.18) : RallyUIKit.Palette.line.opacity(0.7), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
    }
}
