import SwiftUI

/// Sheet for sending a quote (from Today or the Library) into one of your
/// clubs, with an optional comment. The quote arrives as a passage with its
/// book attached, so it shows a Bookshop.org button in the chat.
struct ShareToClubView: View {
    let quote: Quote

    @EnvironmentObject private var auth: AuthManager
    @EnvironmentObject private var clubs: ClubStore
    @Environment(\.dismiss) private var dismiss

    @State private var selectedClubID: UUID?
    @State private var comment = ""
    @State private var isSending = false
    @State private var errorMessage: String?
    @State private var sentTo: String?

    private var selectedClub: BookClub? {
        clubs.myClubs.first { $0.id == selectedClubID }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.background.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 22) {
                        quotePreview

                        if auth.phase != .ready {
                            notice("Sign in to Bookclub to share quotes with your clubs. You'll find it in the Bookclub tab.")
                        } else if clubs.myClubs.isEmpty {
                            if clubs.isLoadingMine {
                                ProgressView().tint(Theme.accent).frame(maxWidth: .infinity)
                            } else {
                                notice("You're not in any clubs yet. Join or start one in the Bookclub tab.")
                            }
                        } else {
                            clubPicker
                            commentField
                            CommunityErrorText(message: errorMessage)
                            CommunityPrimaryButton(
                                title: selectedClub.map { "Share to \($0.name)" } ?? "Choose a Club",
                                isWorking: isSending,
                                isEnabled: selectedClub != nil,
                                action: send
                            )
                        }
                    }
                    .padding(24)
                }
                .scrollDismissesKeyboard(.interactively)
            }
            .navigationTitle("Share to a Club")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(Theme.textSecondary)
                }
            }
            .alert("Shared", isPresented: Binding(get: { sentTo != nil }, set: { if !$0 { sentTo = nil; dismiss() } })) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("Your quote is in \(sentTo ?? "the club").")
            }
        }
        .task {
            if let userID = auth.userID, clubs.myClubs.isEmpty {
                await clubs.refreshMine(userID: userID)
            }
            if clubs.myClubs.count == 1 { selectedClubID = clubs.myClubs.first?.id }
        }
    }

    // MARK: - Pieces

    private var quotePreview: some View {
        HStack(alignment: .top, spacing: 12) {
            RoundedRectangle(cornerRadius: 1).fill(Theme.accent).frame(width: 2)
            VStack(alignment: .leading, spacing: 6) {
                Text(quote.text)
                    .font(Theme.Font.serif(17).italic())
                    .foregroundStyle(Theme.textPrimary)
                    .lineLimit(6)
                    .fixedSize(horizontal: false, vertical: true)
                Text(quote.hasBook ? "\(quote.author), \(quote.book)" : quote.author)
                    .font(.caption)
                    .foregroundStyle(Theme.textSecondary)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Theme.surface))
    }

    private var clubPicker: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Your Clubs")
                .font(.caption.weight(.semibold))
                .trackedCaps(1.5)
                .foregroundStyle(Theme.textSecondary)

            VStack(spacing: 0) {
                ForEach(clubs.myClubs) { club in
                    Button {
                        selectedClubID = club.id
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: selectedClubID == club.id ? "checkmark.circle.fill" : "circle")
                                .foregroundStyle(selectedClubID == club.id ? Theme.accent : Theme.textSecondary)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(club.name)
                                    .font(Theme.Font.serif(16))
                                    .foregroundStyle(Theme.textPrimary)
                                    .lineLimit(1)
                                if let reading = club.readingSummary {
                                    Text("Reading \(reading)")
                                        .font(.caption)
                                        .foregroundStyle(Theme.textSecondary)
                                        .lineLimit(1)
                                }
                            }
                            Spacer()
                            if club.isPrivate {
                                Image(systemName: "lock.fill")
                                    .font(.caption)
                                    .foregroundStyle(Theme.textSecondary)
                            }
                        }
                        .padding(.vertical, 12)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)

                    if club.id != clubs.myClubs.last?.id {
                        Divider().overlay(Theme.divider)
                    }
                }
            }
            .padding(.horizontal, 16)
            .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Theme.surface))
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Theme.divider, lineWidth: 1))
        }
    }

    private var commentField: some View {
        TextField("", text: $comment, prompt: Text("Add a thought (optional)").foregroundStyle(Theme.textSecondary.opacity(0.6)), axis: .vertical)
            .lineLimit(1...5)
            .foregroundStyle(Theme.textPrimary)
            .tint(Theme.accent)
            .padding(14)
            .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Theme.surface))
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(Theme.divider, lineWidth: 1))
    }

    private func notice(_ text: String) -> some View {
        Text(text)
            .font(.subheadline)
            .foregroundStyle(Theme.textSecondary)
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Theme.surface))
    }

    private func send() {
        guard let club = selectedClub, let userID = auth.userID else { return }
        isSending = true
        errorMessage = nil
        Task {
            defer { isSending = false }
            do {
                let book = try? await BookSearch.book(forQuote: quote)
                try await ChatRoom.post(
                    clubID: club.id,
                    userID: userID,
                    body: comment,
                    quote: quote.text,
                    bookID: book?.id
                )
                sentTo = club.name
            } catch {
                errorMessage = ChatRoom.sendErrorMessage(for: error)
            }
        }
    }
}
