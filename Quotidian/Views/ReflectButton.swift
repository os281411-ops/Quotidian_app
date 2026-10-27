import SwiftUI

/// Round "Reflect" button for Today. Tapping it opens a menu: how did the
/// quote make you feel (six moods), write a thought, or clear. Once a mood
/// is picked, the button shows that mood's icon in the accent colour.
struct ReflectButton: View {
    let quote: Quote

    @EnvironmentObject private var reflections: ReflectionStore
    @State private var showNote = false

    private var current: Reflection? { reflections.reflection(for: quote) }
    private var hasNote: Bool {
        !(current?.note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true)
    }

    var body: some View {
        Menu {
            Section("How did this make you feel?") {
                ForEach(ReflectionMood.allCases) { mood in
                    Button {
                        reflections.setMood(current?.mood == mood ? nil : mood, for: quote)
                    } label: {
                        if current?.mood == mood {
                            Label(mood.label, systemImage: "checkmark")
                        } else {
                            Label(mood.label, systemImage: mood.symbol)
                        }
                    }
                }
            }

            Section {
                Button {
                    showNote = true
                } label: {
                    Label(hasNote ? "Edit Your Thought" : "Write a Thought…", systemImage: "square.and.pencil")
                }

                if current != nil {
                    Button(role: .destructive) {
                        reflections.clear(for: quote)
                    } label: {
                        Label("Clear Reflection", systemImage: "trash")
                    }
                }
            }
        } label: {
            CircleIconButtonLabel(
                systemImage: current?.mood?.selectedSymbol ?? (current != nil ? "heart.text.square.fill" : "heart.text.square"),
                label: "Reflect",
                isActive: current != nil
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(current?.mood.map { "Reflect. You felt \($0.label)." } ?? "Reflect")
        .sheet(isPresented: $showNote) {
            ReflectionNoteSheet(quote: quote)
        }
    }
}

/// Sheet for writing a private thought about a quote.
struct ReflectionNoteSheet: View {
    let quote: Quote

    @EnvironmentObject private var reflections: ReflectionStore
    @Environment(\.dismiss) private var dismiss
    @State private var note = ""
    @FocusState private var isFocused: Bool

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.background.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        HStack(alignment: .top, spacing: 12) {
                            RoundedRectangle(cornerRadius: 1).fill(Theme.accent).frame(width: 2)
                            VStack(alignment: .leading, spacing: 6) {
                                Text(quote.text)
                                    .font(Theme.Font.serif(17).italic())
                                    .foregroundStyle(Theme.textPrimary)
                                    .fixedSize(horizontal: false, vertical: true)
                                Text(quote.author)
                                    .font(.caption)
                                    .foregroundStyle(Theme.textSecondary)
                            }
                        }

                        moodPicker

                        TextField(
                            "",
                            text: $note,
                            prompt: Text("What did it make you think of?")
                                .foregroundStyle(Theme.textSecondary.opacity(0.6)),
                            axis: .vertical
                        )
                        .lineLimit(5...14)
                        .font(Theme.Font.serif(17))
                        .foregroundStyle(Theme.textPrimary)
                        .tint(Theme.accent)
                        .focused($isFocused)
                        .padding(16)
                        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Theme.surface))
                        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Theme.divider, lineWidth: 1))
                        .onChange(of: note) { _, newValue in
                            if newValue.count > ReflectionStore.noteLimit {
                                note = String(newValue.prefix(ReflectionStore.noteLimit))
                                return
                            }
                            reflections.setNote(newValue, for: quote)
                        }

                        Label("Private. Saved only on this iPhone.", systemImage: "lock.fill")
                            .font(.caption)
                            .foregroundStyle(Theme.textSecondary)
                    }
                    .padding(24)
                }
            }
            .navigationTitle("Your Thought")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(Theme.accent)
                }
            }
        }
        .presentationDetents([.medium, .large])
        .onAppear {
            note = reflections.reflection(for: quote)?.note ?? ""
            // Opening from Today's menu goes straight to typing; from the
            // Library you may only want to change the mood.
            isFocused = note.isEmpty
        }
    }

    /// How it made you feel; tap again to clear.
    private var moodPicker: some View {
        let current = reflections.reflection(for: quote)?.mood
        return ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(ReflectionMood.allCases) { mood in
                    let isOn = current == mood
                    Button {
                        reflections.setMood(isOn ? nil : mood, for: quote)
                    } label: {
                        Label(mood.label, systemImage: isOn ? mood.selectedSymbol : mood.symbol)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(isOn ? Theme.background : Theme.textSecondary)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(Capsule().fill(isOn ? Theme.accent : Theme.surface))
                            .overlay(Capsule().stroke(isOn ? Theme.accent : Theme.divider, lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(isOn ? .isSelected : [])
                }
            }
        }
    }
}
