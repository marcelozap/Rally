import SwiftUI
import SwiftData

struct JournalEditorView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var date: Date
    @State private var title: String
    @State private var body_: String
    @State private var mood: Int
    @State private var tags: [String]
    @State private var tagInput: String = ""

    private let existing: JournalEntry?

    init(entry: JournalEntry?) {
        self.existing = entry
        _date  = State(initialValue: entry?.date ?? Date())
        _title = State(initialValue: entry?.title ?? "")
        _body_ = State(initialValue: entry?.body ?? "")
        _mood  = State(initialValue: entry?.mood ?? 3)
        _tags  = State(initialValue: entry?.tags ?? [])
    }

    var body: some View {
        Form {
            Section("When") {
                DatePicker("Date", selection: $date, displayedComponents: [.date, .hourAndMinute])
            }

            Section("Entry") {
                TextField("Title", text: $title)
                TextEditor(text: $body_)
                    .frame(minHeight: 180)
            }

            Section("Mood") {
                HStack {
                    ForEach(1...5, id: \.self) { i in
                        Button {
                            mood = i
                        } label: {
                            Text(moodEmoji(i))
                                .font(.system(size: 28))
                                .opacity(mood == i ? 1 : 0.35)
                                .scaleEffect(mood == i ? 1.15 : 1)
                        }
                        .buttonStyle(.plain)
                        .frame(maxWidth: .infinity)
                    }
                }
            }

            Section("Tags") {
                HStack {
                    TextField("Add tag (then return)", text: $tagInput)
                        .autocapitalization(.none)
                        .onSubmit(addTag)
                    Button {
                        addTag()
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .foregroundStyle(.cyan)
                    }
                }
                if !tags.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(tags, id: \.self) { tag in
                                HStack(spacing: 4) {
                                    Text("#\(tag)")
                                    Button {
                                        tags.removeAll { $0 == tag }
                                    } label: {
                                        Image(systemName: "xmark.circle.fill")
                                            .imageScale(.small)
                                    }
                                }
                                .font(.caption.weight(.medium))
                                .padding(.vertical, 4)
                                .padding(.horizontal, 8)
                                .background(
                                    Capsule().fill(Color.cyan.opacity(0.18))
                                )
                                .foregroundStyle(.cyan)
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle(existing == nil ? "New entry" : "Edit entry")
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
            existing.mood = mood
            existing.tags = tags
        } else {
            let new = JournalEntry(
                date: date,
                title: title,
                body: body_,
                mood: mood,
                tags: tags
            )
            modelContext.insert(new)
        }
        try? modelContext.save()
    }
}
