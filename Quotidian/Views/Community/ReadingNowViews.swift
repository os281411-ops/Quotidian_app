import SwiftUI

/// Slim banner pinned to the top of a club's chat.
struct ReadingNowBanner: View {
    let club: BookClub
    let canEdit: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 10) {
                if let book = club.readingBook {
                    BookCover(url: book.cover, width: 22)
                } else {
                    Image(systemName: "bookmark.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(Theme.accent)
                        .frame(width: 22)
                }

                if let summary = club.readingSummary {
                    VStack(alignment: .leading, spacing: 1) {
                        Text("Now Reading")
                            .font(.caption2.weight(.bold))
                            .trackedCaps(1)
                            .foregroundStyle(Theme.accent)
                        Text(summary)
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(Theme.textPrimary)
                            .lineLimit(1)
                    }
                } else {
                    Text("Set what the club is reading")
                        .font(.subheadline)
                        .foregroundStyle(Theme.textSecondary)
                }

                Spacer(minLength: 8)

                if let deadline = club.readingDeadlineText {
                    Text(deadline)
                        .font(.caption)
                        .foregroundStyle(Theme.textSecondary)
                        .lineLimit(1)
                }
                Image(systemName: canEdit ? "pencil" : "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Theme.textSecondary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Theme.surface))
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(Theme.accent.opacity(0.25), lineWidth: 1))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(club.readingSummary.map { "Now reading: \($0)" } ?? "Set what the club is reading")
    }
}

/// "Now Reading" card in Club Info.
struct ReadingNowCard: View {
    let club: BookClub
    let canEdit: Bool
    let onEdit: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Now Reading")
                    .font(.caption.weight(.semibold))
                    .trackedCaps(1.5)
                    .foregroundStyle(Theme.textSecondary)
                Spacer()
                if canEdit {
                    Button(club.hasReadingNow ? "Edit" : "Set") { onEdit() }
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Theme.accent)
                }
            }

            if club.hasReadingNow {
                if let progress = club.readingProgress {
                    Text(progress)
                        .font(Theme.Font.serif(20, weight: .semibold))
                        .foregroundStyle(Theme.textPrimary)
                }
                if let deadline = club.readingDeadlineText {
                    Label(deadline.prefix(1).uppercased() + deadline.dropFirst(), systemImage: "calendar")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Theme.textSecondary)
                }
                if let book = club.readingBook {
                    BookCard(book: book)
                }
            } else {
                Text(canEdit
                     ? "Tag the book and chapters the club is on, so everyone reads along."
                     : "The club hasn't set what it's reading yet.")
                    .font(.subheadline)
                    .foregroundStyle(Theme.textSecondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(Theme.surface))
        .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(Theme.divider, lineWidth: 1))
    }
}

/// Sheet for owners/moderators to set what the club is reading.
struct EditReadingNowView: View {
    @EnvironmentObject private var clubs: ClubStore
    @Environment(\.dismiss) private var dismiss

    let club: BookClub
    let onSaved: (BookClub) -> Void

    @State private var book: Book?
    @State private var progress: String
    @State private var hasDeadline: Bool
    @State private var deadline: Date
    @State private var showBookPicker = false

    init(club: BookClub, onSaved: @escaping (BookClub) -> Void) {
        self.club = club
        self.onSaved = onSaved
        _book = State(initialValue: club.readingBook)
        _progress = State(initialValue: club.readingProgress ?? "")
        _hasDeadline = State(initialValue: club.readingUntilDate != nil)
        _deadline = State(initialValue: club.readingUntilDate
                          ?? Calendar.current.date(byAdding: .day, value: 7, to: Date()) ?? Date())
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.background.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 22) {
                        section("Book (optional)") {
                            if let book {
                                HStack(spacing: 12) {
                                    BookCover(url: book.cover, width: 36)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(book.title)
                                            .font(Theme.Font.serif(16, weight: .semibold))
                                            .foregroundStyle(Theme.textPrimary)
                                            .lineLimit(2)
                                        if let author = book.author {
                                            Text(author)
                                                .font(.caption)
                                                .foregroundStyle(Theme.textSecondary)
                                        }
                                    }
                                    Spacer()
                                    Menu {
                                        Button("Change Book") { showBookPicker = true }
                                        Button("Remove Book", role: .destructive) { self.book = nil }
                                    } label: {
                                        Image(systemName: "ellipsis.circle")
                                            .foregroundStyle(Theme.textSecondary)
                                    }
                                }
                            } else {
                                Button { showBookPicker = true } label: {
                                    Label("Choose a Book", systemImage: "book")
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundStyle(Theme.accent)
                                }
                            }
                        }

                        section("Section") {
                            TextField("", text: $progress, prompt: Text("e.g. Chapters 1–5, Part Two, pp. 1–120").foregroundStyle(Theme.textSecondary.opacity(0.5)))
                                .foregroundStyle(Theme.textPrimary)
                                .tint(Theme.accent)
                                .onChange(of: progress) { _, newValue in
                                    if newValue.count > BookClub.readingProgressLimit {
                                        progress = String(newValue.prefix(BookClub.readingProgressLimit))
                                    }
                                }
                        }

                        section("Finish By") {
                            Toggle("Set a date", isOn: $hasDeadline)
                                .foregroundStyle(Theme.textPrimary)
                                .tint(Theme.accent)
                            if hasDeadline {
                                DatePicker("Date", selection: $deadline, in: Date()..., displayedComponents: .date)
                                    .foregroundStyle(Theme.textPrimary)
                                    .tint(Theme.accent)
                            }
                        }

                        CommunityErrorText(message: clubs.errorMessage)

                        CommunityPrimaryButton(title: "Save", isWorking: clubs.isWorking) {
                            save(book: book, progress: progress, until: hasDeadline ? deadline : nil)
                        }

                        if club.hasReadingNow {
                            Button("Clear Now Reading", role: .destructive) {
                                save(book: nil, progress: "", until: nil)
                            }
                            .font(.subheadline)
                            .frame(maxWidth: .infinity)
                        }
                    }
                    .padding(24)
                }
                .scrollDismissesKeyboard(.interactively)
            }
            .navigationTitle("Now Reading")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(Theme.textSecondary)
                }
            }
        }
        .onAppear { clubs.errorMessage = nil }
        .sheet(isPresented: $showBookPicker) {
            BookPickerView(title: "Choose a Book") { picked in
                book = picked
            }
        }
    }

    private func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.caption.weight(.semibold))
                .trackedCaps(1.5)
                .foregroundStyle(Theme.textSecondary)
            VStack(alignment: .leading, spacing: 12) {
                content()
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Theme.surface))
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Theme.divider, lineWidth: 1))
        }
    }

    private func save(book: Book?, progress: String, until: Date?) {
        Task {
            if let updated = await clubs.setReadingNow(for: club, book: book, progress: progress, until: until) {
                onSaved(updated)
                dismiss()
            }
        }
    }
}
