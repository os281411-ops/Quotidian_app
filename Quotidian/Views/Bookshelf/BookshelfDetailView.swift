import SwiftUI
import UIKit

/// The full page for a book on your shelf: big cover, details, a short
/// description from Open Library, and the Bookshop.org link.
struct BookshelfDetailView: View {
    /// The book as it was when the page opened; `current` has your latest edits.
    let book: ShelfBook

    @EnvironmentObject private var shelf: BookshelfStore
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL

    @State private var about: String?
    @State private var isLoadingAbout = true
    @State private var isOpeningShop = false
    @State private var confirmingRemove = false
    @State private var thoughts = ""
    @FocusState private var isWritingThoughts: Bool

    private var current: ShelfBook { shelf.books.first { $0.id == book.id } ?? book }

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.background.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 24) {
                        cover

                        VStack(spacing: 6) {
                            Text(book.title)
                                .font(Theme.Font.serif(26, weight: .semibold))
                                .foregroundStyle(Theme.textPrimary)
                                .multilineTextAlignment(.center)
                            if let author = book.author {
                                Text(author)
                                    .font(Theme.Font.serif(17))
                                    .foregroundStyle(Theme.textSecondary)
                            }
                            if let year = book.year {
                                Text("First published \(String(year))")
                                    .font(.caption.weight(.semibold))
                                    .trackedCaps(1.2)
                                    .foregroundStyle(Theme.textSecondary)
                                    .padding(.top, 2)
                            }
                        }

                        StarRating(rating: current.rating) { shelf.setRating($0, for: book) }

                        shopButton

                        thoughtsSection

                        aboutSection

                        details

                        Button(role: .destructive) {
                            confirmingRemove = true
                        } label: {
                            Label("Remove from Shelf", systemImage: "trash")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(Color(hex: 0xFF6B6B))
                        }
                        .buttonStyle(.plain)
                        .padding(.top, 4)
                    }
                    .padding(24)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(Theme.accent)
                }
            }
        }
        .presentationDetents([.large])
        .onAppear { thoughts = current.thoughts ?? "" }
        .task {
            if let id = book.openLibraryID {
                about = await BookSearch.description(openLibraryID: id)
            }
            isLoadingAbout = false
        }
        .alert("Remove \u{201C}\(book.title)\u{201D}?", isPresented: $confirmingRemove) {
            Button("Remove", role: .destructive) {
                shelf.remove(book)
                dismiss()
            }
            Button("Cancel", role: .cancel) {}
        }
    }

    // MARK: - Pieces

    private var cover: some View {
        AsyncImage(url: book.largeCoverURL) { phase in
            if let image = phase.image {
                image.resizable().scaledToFill()
            } else {
                ZStack {
                    Theme.surfaceElevated
                    Image(systemName: "book.closed.fill")
                        .font(.system(size: 44))
                        .foregroundStyle(Theme.accentDim)
                }
            }
        }
        .frame(width: 160, height: 240)
        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 6, style: .continuous).stroke(Theme.divider, lineWidth: 1))
        .shadow(color: .black.opacity(0.4), radius: 14, y: 8)
        .padding(.top, 8)
    }

    /// Opens the book on Bookshop.org (or a search, if they don't stock it).
    private var shopButton: some View {
        Button {
            guard !isOpeningShop else { return }
            isOpeningShop = true
            Task {
                let url = await BookshopAffiliate.workingURL(for: book.asBook)
                isOpeningShop = false
                openURL(url)
            }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "bag")
                Text("Buy on Bookshop.org")
                    .font(.subheadline.weight(.bold))
                    .trackedCaps(1.2)
                if isOpeningShop {
                    ProgressView().controlSize(.small).tint(Theme.accent)
                } else {
                    Image(systemName: "arrow.up.right")
                        .font(.caption.weight(.bold))
                }
            }
            .foregroundStyle(Theme.accent)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity)
            .background(Capsule().fill(Theme.surface))
            .overlay(Capsule().stroke(Theme.divider, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    /// Your own notes on the book, saved as you type.
    private var thoughtsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Your Thoughts")
                .font(.caption.weight(.semibold))
                .trackedCaps(1.5)
                .foregroundStyle(Theme.textSecondary)
            TextField(
                "",
                text: $thoughts,
                prompt: Text("What did you think of it?").foregroundStyle(Theme.textSecondary.opacity(0.6)),
                axis: .vertical
            )
            .lineLimit(3...12)
            .font(Theme.Font.serif(16))
            .foregroundStyle(Theme.textPrimary)
            .tint(Theme.accent)
            .focused($isWritingThoughts)
            .onChange(of: thoughts) { _, newValue in
                if newValue.count > BookshelfStore.thoughtsLimit {
                    thoughts = String(newValue.prefix(BookshelfStore.thoughtsLimit))
                    return
                }
                shelf.setThoughts(newValue, for: book)
            }
            Label("Private. Saved only on this iPhone.", systemImage: "lock.fill")
                .font(.caption2)
                .foregroundStyle(Theme.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(Theme.surface))
        .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(Theme.divider, lineWidth: 1))
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") { isWritingThoughts = false }
                    .foregroundStyle(Theme.accent)
            }
        }
    }

    @ViewBuilder
    private var aboutSection: some View {
        if isLoadingAbout {
            ProgressView().tint(Theme.accent)
        } else if let about {
            VStack(alignment: .leading, spacing: 10) {
                Text("About this book")
                    .font(.caption.weight(.semibold))
                    .trackedCaps(1.5)
                    .foregroundStyle(Theme.textSecondary)
                Text(about)
                    .font(Theme.Font.serif(16))
                    .foregroundStyle(Theme.textPrimary)
                    .lineSpacing(4)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(18)
            .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(Theme.surface))
            .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(Theme.divider, lineWidth: 1))
        }
    }

    private var details: some View {
        VStack(spacing: 0) {
            detailRow("Shelved", book.addedAt.formatted(date: .abbreviated, time: .omitted))
            // Kept small: it's only useful for finding this exact edition.
            if let isbn = current.isbn13 {
                Text("ISBN \(isbn)")
                    .font(.caption2)
                    .monospacedDigit()
                    .foregroundStyle(Theme.textSecondary.opacity(0.7))
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .padding(.top, -6)
                    .padding(.bottom, 12)
            }
        }
        .padding(.horizontal, 18)
        .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(Theme.surface))
        .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(Theme.divider, lineWidth: 1))
    }

    private func detailRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundStyle(Theme.textSecondary)
            Spacer()
            Text(value)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(Theme.textPrimary)
        }
        .padding(.vertical, 14)
    }
}

/// Five tappable stars. Tap the current rating again to clear it.
struct StarRating: View {
    let rating: Int?
    let onChange: (Int?) -> Void

    var body: some View {
        VStack(spacing: 6) {
            HStack(spacing: 10) {
                ForEach(1...5, id: \.self) { star in
                    Button {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        onChange(rating == star ? nil : star)
                    } label: {
                        Image(systemName: star <= (rating ?? 0) ? "star.fill" : "star")
                            .font(.system(size: 26))
                            .foregroundStyle(star <= (rating ?? 0) ? Theme.accent : Theme.textSecondary.opacity(0.5))
                            .contentTransition(.symbolEffect(.replace))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("\(star) star\(star == 1 ? "" : "s")")
                    .accessibilityAddTraits(star == rating ? .isSelected : [])
                }
            }
            Text(rating == nil ? "Tap to rate" : "Your rating")
                .font(.caption2.weight(.semibold))
                .trackedCaps(1)
                .foregroundStyle(Theme.textSecondary)
        }
        .animation(.easeOut(duration: 0.15), value: rating)
    }
}
