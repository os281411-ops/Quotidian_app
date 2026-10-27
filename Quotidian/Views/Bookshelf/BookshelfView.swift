import SwiftUI

/// The Bookshelf tab: every book you've scanned or searched for, four to a
/// row. Tap a cover to flip it over (title, author, year); tap again to
/// open the full page.
struct BookshelfView: View {
    @EnvironmentObject private var shelf: BookshelfStore

    @State private var flippedID: UUID?
    @State private var selected: ShelfBook?
    @State private var showScanner = false
    @State private var showSearch = false
    @State private var toast: String?
    @State private var showHelp = false

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 12), count: 4)

    var body: some View {
        ZStack(alignment: .top) {
            Theme.background.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    header

                    if shelf.books.isEmpty {
                        emptyState
                    } else {
                        LazyVGrid(columns: columns, spacing: 16) {
                            ForEach(shelf.books) { book in
                                FlippableCover(book: book, isFlipped: flippedID == book.id)
                                    .onTapGesture { tap(book) }
                                    .contextMenu {
                                        Button {
                                            selected = book
                                        } label: {
                                            Label("Details", systemImage: "info.circle")
                                        }
                                        Button(role: .destructive) {
                                            withAnimation { shelf.remove(book) }
                                        } label: {
                                            Label("Remove from Shelf", systemImage: "trash")
                                        }
                                    }
                            }
                        }
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 140)
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            // Tap anywhere that isn't a book to turn every cover back to the front.
            .onTapGesture { flipAllBack() }

            // Small help button, floating above the tab bar.
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    helpButton
                }
            }
            .padding(.trailing, 20)
            .padding(.bottom, 88)

            if let toast {
                Text(toast)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.textPrimary)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(Capsule().fill(Theme.surfaceElevated))
                    .overlay(Capsule().stroke(Theme.divider, lineWidth: 1))
                    .padding(.top, 8)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .sheet(item: $selected) { book in
            BookshelfDetailView(book: book)
        }
        .sheet(isPresented: $showSearch) {
            BookPickerView(title: "Add to Bookshelf", onPick: { _ in }, onPickResult: add)
        }
        .fullScreenCover(isPresented: $showScanner) {
            BookScannerView(onFound: add)
        }
    }

    // MARK: - Pieces

    private var header: some View {
        HStack(alignment: .top) {
            CommunityHeader(
                title: "Bookshelf",
                subtitle: shelf.books.isEmpty ? "Your Books" : "\(shelf.books.count) \(shelf.books.count == 1 ? "Book" : "Books")"
            )
            Spacer()
            addMenu
                .padding(.top, 12)
        }
    }

    private var addMenu: some View {
        Menu {
            Button { showScanner = true } label: {
                Label("Scan a Barcode", systemImage: "barcode.viewfinder")
            }
            Button { showSearch = true } label: {
                Label("Search for a Book", systemImage: "magnifyingglass")
            }
        } label: {
            Image(systemName: "plus")
                .font(.system(size: 17, weight: .medium))
                .foregroundStyle(Theme.textPrimary)
                .frame(width: 40, height: 40)
                .background(Circle().fill(Theme.surface))
                .overlay(Circle().stroke(Theme.divider, lineWidth: 1))
        }
        .accessibilityLabel("Add a book")
    }

    private var helpButton: some View {
        Button { showHelp = true } label: {
            Image(systemName: "questionmark")
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(Theme.background)
                .frame(width: 40, height: 40)
                .background(Circle().fill(Theme.accent))
                .shadow(color: .black.opacity(0.35), radius: 8, y: 3)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("How the bookshelf works")
        .popover(isPresented: $showHelp, arrowEdge: .bottom) {
            VStack(alignment: .leading, spacing: 10) {
                Label("Tap a cover to flip it and see the title, author and year.", systemImage: "arrow.left.arrow.right")
                Label("Tap it again to open the book's page: rating, your thoughts and where to buy it.", systemImage: "book")
                Label("Press and hold a cover to remove it.", systemImage: "hand.tap")
            }
            .font(.footnote)
            .foregroundStyle(Theme.textPrimary)
            .padding(16)
            .frame(width: 280, alignment: .leading)
            .presentationCompactAdaptation(.popover)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 14) {
            Image(systemName: "books.vertical")
                .font(.system(size: 32))
                .foregroundStyle(Theme.accentDim)
            Text("Your shelf is empty")
                .font(Theme.Font.serif(20, weight: .semibold))
                .foregroundStyle(Theme.textPrimary)
            Text("Scan the barcode on a book you own, or search for one you've read, to start your shelf.")
                .font(.subheadline)
                .foregroundStyle(Theme.textSecondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            CommunityPrimaryButton(title: "Scan a Barcode") { showScanner = true }
                .padding(.top, 6)
            Button("Search for a Book") { showSearch = true }
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Theme.accent)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
        .padding(.horizontal, 24)
        .background(RoundedRectangle(cornerRadius: 24, style: .continuous).fill(Theme.surface))
        .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).stroke(Theme.divider, lineWidth: 1))
    }

    // MARK: - Actions

    /// First tap flips the cover; tapping the flipped cover opens the page.
    private func tap(_ book: ShelfBook) {
        if flippedID == book.id {
            selected = book
        } else {
            flippedID = book.id
        }
    }

    private func flipAllBack() {
        guard flippedID != nil else { return }
        flippedID = nil
    }

    private func add(_ result: BookSearchResult) {
        let added = shelf.add(result)
        flippedID = nil
        show(added ? "Shelved \u{201C}\(result.title)\u{201D}" : "Already on your shelf")
    }

    private func show(_ message: String) {
        withAnimation(.easeOut(duration: 0.25)) { toast = message }
        Task {
            try? await Task.sleep(for: .seconds(2))
            withAnimation(.easeIn(duration: 0.25)) {
                if toast == message { toast = nil }
            }
        }
    }
}

// MARK: - Flipping cover

/// A book cover that turns over to show its details on the back.
/// The turn happens in two halves: the front swings away edge-on, the
/// sides swap, then the back swings into view.
struct FlippableCover: View {
    let book: ShelfBook
    let isFlipped: Bool

    @State private var showingBack = false
    @State private var rotation: Double = 0

    var body: some View {
        ZStack {
            if showingBack { back } else { front }
        }
        .aspectRatio(2.0 / 3.0, contentMode: .fit)
        .rotation3DEffect(.degrees(rotation), axis: (x: 0, y: 1, z: 0), perspective: 0.4)
        .contentShape(Rectangle())
        .onAppear { showingBack = isFlipped }
        .onChange(of: isFlipped) { _, flipped in turn(toBack: flipped) }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel([book.title, book.author].compactMap { $0 }.joined(separator: ", "))
        .accessibilityHint(isFlipped ? "Opens the book's page" : "Shows the title and author")
        .accessibilityAddTraits(.isButton)
    }

    private func turn(toBack: Bool) {
        let direction: Double = toBack ? 1 : -1
        withAnimation(.easeIn(duration: 0.14)) {
            rotation = 90 * direction
        } completion: {
            showingBack = toBack
            var jump = Transaction()
            jump.disablesAnimations = true
            withTransaction(jump) { rotation = -90 * direction }
            withAnimation(.easeOut(duration: 0.18)) { rotation = 0 }
        }
    }

    private var front: some View {
        GeometryReader { geometry in
            AsyncImage(url: book.coverURL) { phase in
                if let image = phase.image {
                    image.resizable().scaledToFill()
                } else {
                    // No cover: a plain cloth-bound look with the title.
                    ZStack {
                        Theme.surfaceElevated
                        Text(book.title)
                            .font(Theme.Font.serif(11, weight: .semibold))
                            .foregroundStyle(Theme.textPrimary)
                            .multilineTextAlignment(.center)
                            .lineLimit(5)
                            .minimumScaleFactor(0.7)
                            .padding(6)
                    }
                }
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
        }
        .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 4, style: .continuous).stroke(Theme.divider, lineWidth: 1))
        .shadow(color: .black.opacity(0.3), radius: 4, y: 2)
    }

    private var back: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(book.title)
                .font(Theme.Font.serif(11, weight: .semibold))
                .foregroundStyle(Theme.textPrimary)
                .lineLimit(4)
                .minimumScaleFactor(0.75)
            if let author = book.author {
                Text(author)
                    .font(.system(size: 9))
                    .foregroundStyle(Theme.textSecondary)
                    .lineLimit(2)
            }
            Spacer(minLength: 0)
            if let rating = book.rating {
                HStack(spacing: 1) {
                    ForEach(1...5, id: \.self) { star in
                        Image(systemName: star <= rating ? "star.fill" : "star")
                            .font(.system(size: 7))
                    }
                }
                .foregroundStyle(Theme.accent)
            }
            if let year = book.year {
                Text(String(year))
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(Theme.accent)
            }
        }
        .padding(7)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(RoundedRectangle(cornerRadius: 4, style: .continuous).fill(Theme.surface))
        .overlay(RoundedRectangle(cornerRadius: 4, style: .continuous).stroke(Theme.accent.opacity(0.4), lineWidth: 1))
    }
}
