import SwiftUI
import SwiftData
import PhotosUI

/// Composer patterned after **Day One** / **Journey**: calm dark surfaces, focus
/// buckets, guided prompts, mood & tags — persisted with `JournalFocus` + optional `promptId`.
struct JournalEditorView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var date: Date
    @State private var title: String
    @State private var body_: String
    @State private var photoData: Data?
    @State private var mood: Int
    @State private var tags: [String]
    @State private var tagInput: String = ""
    @State private var focus: JournalFocus
    @State private var promptId: String
    @State private var selectedPhotoItem: PhotosPickerItem?

    private let existing: JournalEntry?

    init(entry: JournalEntry?, seedPrompt: JournalPrompt? = nil) {
        self.existing = entry
        if let entry = entry {
            _date = State(initialValue: entry.date)
            _title = State(initialValue: entry.title)
            _body_ = State(initialValue: entry.body)
            _photoData = State(initialValue: entry.photoData)
            _mood = State(initialValue: entry.mood)
            _tags = State(initialValue: entry.tags)
            _focus = State(initialValue: entry.focus)
            _promptId = State(initialValue: entry.promptId)
        } else if let seed = seedPrompt {
            _date = State(initialValue: Date())
            _title = State(initialValue: seed.title)
            _body_ = State(initialValue: seed.bodyStarter)
            _photoData = State(initialValue: nil)
            _mood = State(initialValue: 3)
            _tags = State(initialValue: [])
            _focus = State(initialValue: seed.focus)
            _promptId = State(initialValue: seed.id)
        } else {
            _date = State(initialValue: Date())
            _title = State(initialValue: "")
            _body_ = State(initialValue: "")
            _photoData = State(initialValue: nil)
            _mood = State(initialValue: 3)
            _tags = State(initialValue: [])
            _focus = State(initialValue: .general)
            _promptId = State(initialValue: "")
        }
    }

    private var promptsForFocus: [JournalPrompt] {
        JournalPromptLibrary.prompts(for: focus)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                focusSection
                promptsSection
                cardSection(title: "When") {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(spacing: 10) {
                            RallyUIKit.IconBadge(systemName: "calendar", tint: RallyUIKit.Palette.cyan, size: 30)
                            VStack(alignment: .leading, spacing: 3) {
                                Text("Memory moment")
                                    .font(RallyUIKit.Typography.body(.subheadline, weight: .bold))
                                    .foregroundStyle(RallyUIKit.Palette.frost)
                                Text("Choose when this entry belongs in your Rally timeline.")
                                    .font(RallyUIKit.Typography.body(.caption, weight: .medium))
                                    .foregroundStyle(RallyUIKit.Palette.cloud.opacity(0.58))
                            }
                        }

                        DatePicker("Date & time", selection: $date, displayedComponents: [.date, .hourAndMinute])
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

                cardSection(title: "Entry") {
                    TextField("Title", text: $title)
                        .rallyTextFieldStyle()

                    ZStack(alignment: .topLeading) {
                        if body_.isEmpty {
                            Text("Write freely…")
                                .foregroundStyle(RallyUIKit.Palette.cloud.opacity(0.28))
                                .padding(.horizontal, 16)
                                .padding(.vertical, 14)
                        }
                        TextEditor(text: $body_)
                            .scrollContentBackground(.hidden)
                            .foregroundStyle(RallyUIKit.Palette.frost.opacity(0.92))
                            .frame(minHeight: 200)
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

                cardSection(title: "Photo") {
                    if let preview = previewImage {
                        ZStack(alignment: .topTrailing) {
                            Image(uiImage: preview)
                                .resizable()
                                .scaledToFill()
                                .frame(maxWidth: .infinity)
                                .frame(height: 210)
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
                        Label(photoData == nil ? "Add memory photo" : "Swap photo", systemImage: "photo.fill.on.rectangle.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(SecondaryButtonStyle(tint: RallyUIKit.Palette.cyan))

                    Text("Use this for match moments, practice snapshots, or a doubles photo you want attached to the entry.")
                        .font(RallyUIKit.Typography.body(.caption, weight: .medium))
                        .foregroundStyle(RallyUIKit.Palette.cloud.opacity(0.52))
                }

                cardSection(title: "Mood") {
                    HStack(spacing: 6) {
                        ForEach(1...5, id: \.self) { i in
                            Button {
                                mood = i
                            } label: {
                                Text(moodEmoji(i))
                                    .font(.system(size: 30))
                                    .opacity(mood == i ? 1 : 0.35)
                                    .scaleEffect(mood == i ? 1.12 : 1)
                            }
                            .buttonStyle(.plain)
                            .frame(maxWidth: .infinity)
                        }
                    }
                }

                cardSection(title: "Tags") {
                    HStack {
                        TextField("Add tag, press return", text: $tagInput)
                            .foregroundStyle(.white)
                            .textInputAutocapitalization(.never)
                            .onSubmit(addTag)
                        Button(action: addTag) {
                            Image(systemName: "plus.circle.fill")
                                .foregroundStyle(.cyan)
                        }
                    }
                    .padding(12)
                    .background(RoundedRectangle(cornerRadius: 10).fill(Color.white.opacity(0.06)))

                    if !tags.isEmpty {
                        FlowTagWrap(tags: tags, onRemove: { tag in
                            tags.removeAll { $0 == tag }
                        })
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .padding(.bottom, 40)
        }
        .background(Color.black.ignoresSafeArea())
        .navigationTitle(existing == nil ? "New entry" : "Edit entry")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("Cancel") { dismiss() }
                    .foregroundStyle(.white.opacity(0.85))
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button("Save") {
                    save()
                    dismiss()
                }
                .fontWeight(.bold)
                .foregroundStyle(.cyan)
            }
        }
        .onChange(of: focus) { _, _ in
            if promptsForFocus.allSatisfy({ $0.id != promptId }) {
                promptId = ""
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

    // MARK: - Sections

    private var focusSection: some View {
        cardSection(title: "Practice · Match · Game") {
            Text("Where does this entry live? (filters your timeline)")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.45))
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                ForEach(JournalFocus.allCases) { f in
                    Button {
                        focus = f
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: f.symbolName)
                            Text(f.displayName)
                                .font(.caption.weight(.semibold))
                                .lineLimit(1)
                                .minimumScaleFactor(0.85)
                        }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(focus == f ? RallyUIKit.Palette.cyan.opacity(0.28) : Color.white.opacity(0.06))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(focus == f ? RallyUIKit.Palette.cyan : Color.white.opacity(0.08), lineWidth: 1)
                            )
                            .foregroundStyle(focus == f ? RallyUIKit.Palette.obsidian : RallyUIKit.Palette.frost.opacity(0.88))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var promptsSection: some View {
        cardSection(title: "Guided prompts") {
            Text("Templates like Journey — tap to insert text (you can edit everything).")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.45))

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(promptsForFocus) { prompt in
                        Button {
                            apply(prompt)
                        } label: {
                            VStack(alignment: .leading, spacing: 6) {
                                Text(prompt.title)
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(.white)
                                    .lineLimit(2)
                                Text("Tap to use")
                                    .font(.caption2.weight(.semibold))
                                    .foregroundStyle(.cyan.opacity(0.9))
                            }
                            .padding(12)
                            .frame(width: 160, alignment: .leading)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(prompt.id == promptId ? Color.yellow.opacity(0.14) : Color.white.opacity(0.06))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(prompt.id == promptId ? Color.yellow.opacity(0.55) : Color.white.opacity(0.08), lineWidth: 1)
                            )
                        }
                        .buttonStyle(.plain)
                    }

                    Button {
                        let daily = JournalPromptLibrary.dailyPrompt(for: date, focus: focus)
                        apply(daily)
                    } label: {
                        VStack(spacing: 6) {
                            Image(systemName: "shuffle")
                                .font(.title3)
                            Text("Today's pick")
                                .font(.caption.weight(.bold))
                                .multilineTextAlignment(.center)
                        }
                        .foregroundStyle(.white.opacity(0.85))
                        .padding(12)
                        .frame(width: 100, height: 76)
                        .background(RoundedRectangle(cornerRadius: 12).fill(RallyUIKit.Palette.rose.opacity(0.22)))
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(RallyUIKit.Palette.rose.opacity(0.45), lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                }
            }

            if !promptId.isEmpty {
                Button("Clear guided template link") {
                    promptId = ""
                }
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white.opacity(0.45))
            }
        }
    }

    private func cardSection(title: String, @ViewBuilder content: () -> some View) -> some View {
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

    private func apply(_ prompt: JournalPrompt) {
        title = prompt.title
        body_ = prompt.bodyStarter
        focus = prompt.focus
        promptId = prompt.id
    }

    private func moodEmoji(_ i: Int) -> String {
        switch i {
        case 1: return "😞"
        case 2: return "😕"
        case 3: return "😐"
        case 4: return "🙂"
        default: return "🔥"
        }
    }

    private func addTag() {
        let cleaned = tagInput.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !cleaned.isEmpty, !tags.contains(cleaned) else { return }
        tags.append(cleaned)
        tagInput = ""
    }

    private func save() {
        if let existing = existing {
            existing.date = date
            existing.title = title
            existing.body = body_
            existing.photoData = photoData
            existing.mood = mood
            existing.tags = tags
            existing.focus = focus
            existing.promptId = promptId
        } else {
            let new = JournalEntry(
                date: date,
                title: title,
                body: body_,
                photoData: photoData,
                mood: mood,
                tags: tags,
                focus: focus,
                promptId: promptId
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

// MARK: - Simple tag flow wrap

private struct FlowTagWrap: View {
    let tags: [String]
    let onRemove: (String) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(tags, id: \.self) { tag in
                    HStack(spacing: 4) {
                        Text("#\(tag)")
                        Button {
                            onRemove(tag)
                        } label: {
                            Image(systemName: "xmark.circle.fill").imageScale(.small)
                        }
                    }
                    .font(.caption.weight(.medium))
                    .padding(.vertical, 6)
                    .padding(.horizontal, 10)
                    .background(Capsule().fill(RallyUIKit.Palette.cyan.opacity(0.16)))
                    .foregroundStyle(RallyUIKit.Palette.cyan)
                }
            }
        }
    }
}
