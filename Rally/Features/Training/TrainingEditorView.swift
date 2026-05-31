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
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                editorCard(title: "When") {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(spacing: 10) {
                            RallyUIKit.IconBadge(systemName: "calendar", tint: RallyUIKit.Palette.cyan, size: 30)
                            VStack(alignment: .leading, spacing: 3) {
                                Text("Session moment")
                                    .font(RallyUIKit.Typography.body(.subheadline, weight: .bold))
                                    .foregroundStyle(RallyUIKit.Palette.frost)
                                Text("Stamp when this practice block actually happened.")
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

                editorCard(title: "Focus") {
                    TextField("Drill or focus area", text: $drillType)
                        .rallyTextFieldStyle()
                    if drillType.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(Self.drillSuggestions, id: \.self) { d in
                                    suggestionChip(d) { drillType = d }
                                }
                            }
                        }
                    }
                }

                editorCard(title: "Duration") {
                    HStack(alignment: .center, spacing: 12) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Minutes")
                                .font(RallyUIKit.Typography.body(.subheadline, weight: .bold))
                                .foregroundStyle(RallyUIKit.Palette.frost)
                            Text("Shape your session length before you log it.")
                                .font(RallyUIKit.Typography.body(.caption, weight: .medium))
                                .foregroundStyle(RallyUIKit.Palette.cloud.opacity(0.52))
                        }
                        Spacer()
                        quantityStepper(
                            value: $durationMinutes,
                            range: 5...240,
                            step: 5,
                            tint: RallyUIKit.Palette.cyan
                        )
                        Text("\(durationMinutes)")
                            .font(RallyUIKit.Typography.display(28, weight: .bold))
                            .foregroundStyle(RallyUIKit.Palette.cyan)
                            .monospacedDigit()
                    }
                }

                editorCard(title: "Intensity") {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Effort")
                                .font(RallyUIKit.Typography.body(.subheadline, weight: .bold))
                                .foregroundStyle(RallyUIKit.Palette.frost)
                            Spacer()
                            Text(intensityLabel)
                                .font(RallyUIKit.Typography.body(.caption, weight: .semibold))
                                .foregroundStyle(RallyUIKit.Palette.gold)
                        }
                        HStack(spacing: 8) {
                            ForEach(1...5, id: \.self) { i in
                                Button {
                                    intensity = i
                                } label: {
                                    Capsule()
                                        .fill(i <= intensity ? AnyShapeStyle(RallyUIKit.accentGradient(RallyUIKit.Palette.cyan)) : AnyShapeStyle(Color.white.opacity(0.10)))
                                        .frame(height: 16)
                                        .overlay(
                                            Capsule()
                                                .stroke(i == intensity ? Color.white.opacity(0.28) : Color.clear, lineWidth: 1)
                                        )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }

                editorCard(title: "Notes") {
                    ZStack(alignment: .topLeading) {
                        if notes.isEmpty {
                            Text("What clicked, what felt off, what to repeat next time.")
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
        .navigationTitle(existing == nil ? "Log training" : "Edit training")
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

    private func suggestionChip(_ label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(RallyUIKit.Typography.body(.caption, weight: .semibold))
                .foregroundStyle(RallyUIKit.Palette.frost)
                .padding(.horizontal, 12)
                .padding(.vertical, 9)
                .background(
                    Capsule()
                        .fill(Color.white.opacity(0.08))
                )
                .overlay(
                    Capsule()
                        .stroke(RallyUIKit.Palette.line, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }

    private func quantityStepper(value: Binding<Int>, range: ClosedRange<Int>, step: Int, tint: Color) -> some View {
        HStack(spacing: 8) {
            stepperButton(systemName: "minus", isEnabled: value.wrappedValue > range.lowerBound, tint: tint) {
                value.wrappedValue = max(range.lowerBound, value.wrappedValue - step)
            }
            stepperButton(systemName: "plus", isEnabled: value.wrappedValue < range.upperBound, tint: tint) {
                value.wrappedValue = min(range.upperBound, value.wrappedValue + step)
            }
        }
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
