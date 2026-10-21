import SwiftUI

/// Small book cover with a placeholder while it loads (or if there isn't one).
struct BookCover: View {
    let url: URL?
    var width: CGFloat = 44

    var body: some View {
        AsyncImage(url: url) { phase in
            if let image = phase.image {
                image.resizable().scaledToFill()
            } else {
                ZStack {
                    Theme.surfaceElevated
                    Image(systemName: "book.closed.fill")
                        .font(.system(size: width * 0.4))
                        .foregroundStyle(Theme.accentDim)
                }
            }
        }
        .frame(width: width, height: width * 1.5)
        .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 4, style: .continuous).stroke(Theme.divider, lineWidth: 1))
    }
}

/// A book with a Bookshop.org button. Used in chat messages and on profiles.
struct BookCard: View {
    let book: Book
    var compact = false

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            BookCover(url: book.cover, width: compact ? 40 : 52)

            VStack(alignment: .leading, spacing: 4) {
                Text(book.title)
                    .font(Theme.Font.serif(compact ? 15 : 17, weight: .semibold))
                    .foregroundStyle(Theme.textPrimary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                if let author = book.author {
                    Text(author)
                        .font(.caption)
                        .foregroundStyle(Theme.textSecondary)
                        .lineLimit(1)
                }
                Link(destination: book.bookshopURL) {
                    HStack(spacing: 4) {
                        Image(systemName: "bag")
                        Text("Bookshop.org")
                        Image(systemName: "arrow.up.right")
                            .font(.caption2.weight(.bold))
                    }
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Theme.accent)
                }
                .padding(.top, 2)
            }
            Spacer(minLength: 0)
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Theme.background.opacity(0.35)))
        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(Theme.divider, lineWidth: 1))
    }
}

/// Sheet to search Open Library and pick a book.
struct BookPickerView: View {
    let title: String
    let onPick: (Book) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var query = ""
    @State private var results: [BookSearchResult] = []
    @State private var isSearching = false
    @State private var savingID: String?
    @State private var errorMessage: String?
    @FocusState private var isFocused: Bool

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.background.ignoresSafeArea()

                VStack(spacing: 16) {
                    searchField

                    CommunityErrorText(message: errorMessage)

                    ScrollView {
                        LazyVStack(spacing: 10) {
                            if isSearching && results.isEmpty {
                                ProgressView().tint(Theme.accent).padding(.top, 30)
                            } else if results.isEmpty {
                                Text(query.count < 2
                                     ? "Search by title or author."
                                     : "No books found. Try the author's surname or fewer words.")
                                    .font(.subheadline)
                                    .foregroundStyle(Theme.textSecondary)
                                    .multilineTextAlignment(.center)
                                    .padding(.top, 30)
                            }
                            ForEach(results) { result in
                                Button { pick(result) } label: { resultRow(result) }
                                    .buttonStyle(.plain)
                                    .disabled(savingID != nil)
                            }
                        }
                        .padding(.bottom, 24)
                    }
                    .scrollDismissesKeyboard(.interactively)
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(Theme.textSecondary)
                }
            }
        }
        .onAppear { isFocused = true }
        .task(id: query) {
            try? await Task.sleep(for: .milliseconds(400))
            guard !Task.isCancelled else { return }
            await runSearch()
        }
    }

    private var searchField: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(Theme.textSecondary)
            TextField("Title or author", text: $query)
                .foregroundStyle(Theme.textPrimary)
                .tint(Theme.accent)
                .autocorrectionDisabled()
                .submitLabel(.search)
                .focused($isFocused)
            if isSearching {
                ProgressView().controlSize(.small).tint(Theme.textSecondary)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Theme.surface))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(Theme.divider, lineWidth: 1))
    }

    private func resultRow(_ result: BookSearchResult) -> some View {
        HStack(spacing: 12) {
            BookCover(url: result.coverURL, width: 40)
            VStack(alignment: .leading, spacing: 3) {
                Text(result.title)
                    .font(Theme.Font.serif(16, weight: .semibold))
                    .foregroundStyle(Theme.textPrimary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                Text([result.author, result.year.map(String.init)].compactMap { $0 }.joined(separator: " · "))
                    .font(.caption)
                    .foregroundStyle(Theme.textSecondary)
                    .lineLimit(1)
            }
            Spacer()
            if savingID == result.id {
                ProgressView().tint(Theme.accent)
            }
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Theme.surface))
        .contentShape(Rectangle())
    }

    private func runSearch() async {
        let current = query
        guard current.trimmingCharacters(in: .whitespaces).count >= 2 else {
            results = []
            return
        }
        isSearching = true
        defer { isSearching = false }
        do {
            let found = try await BookSearch.search(current)
            guard current == query else { return }
            results = found
            errorMessage = nil
        } catch is CancellationError {
            return
        } catch {
            if (error as? URLError)?.code == .cancelled { return }
            errorMessage = "Couldn't search right now. Check your connection."
        }
    }

    private func pick(_ result: BookSearchResult) {
        savingID = result.id
        Task {
            defer { savingID = nil }
            do {
                let book = try await BookSearch.save(result)
                onPick(book)
                dismiss()
            } catch {
                errorMessage = "Couldn't add that book. Please try again."
            }
        }
    }
}
