import SwiftUI

/// Sheet for starting a new book club.
struct CreateClubView: View {
    @EnvironmentObject private var auth: AuthManager
    @EnvironmentObject private var clubs: ClubStore
    @Environment(\.dismiss) private var dismiss

    /// Called with the new club so the caller can open it.
    let onCreated: (BookClub) -> Void

    @State private var name = ""
    @State private var description = ""
    @State private var isPrivate = false
    @FocusState private var focusedField: Field?

    private enum Field { case name, description }

    private var trimmedName: String { name.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var canCreate: Bool { BookClub.nameLimit.contains(trimmedName.count) }

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.background.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        field(
                            label: "Name",
                            hint: "\(trimmedName.count)/\(BookClub.nameLimit.upperBound)"
                        ) {
                            TextField("", text: $name, prompt: Text("e.g. Middlemarch, Russian Classics").foregroundStyle(Theme.textSecondary.opacity(0.5)))
                                .font(Theme.Font.serif(18))
                                .foregroundStyle(Theme.textPrimary)
                                .focused($focusedField, equals: .name)
                                .submitLabel(.next)
                                .onSubmit { focusedField = .description }
                                .onChange(of: name) { _, newValue in
                                    if newValue.count > BookClub.nameLimit.upperBound {
                                        name = String(newValue.prefix(BookClub.nameLimit.upperBound))
                                    }
                                }
                        }

                        field(
                            label: "About",
                            hint: "\(description.count)/\(BookClub.descriptionLimit)"
                        ) {
                            TextField("", text: $description, prompt: Text("What's it about? A book, an author, a genre, a character…").foregroundStyle(Theme.textSecondary.opacity(0.5)), axis: .vertical)
                                .lineLimit(3...6)
                                .foregroundStyle(Theme.textPrimary)
                                .focused($focusedField, equals: .description)
                                .onChange(of: description) { _, newValue in
                                    if newValue.count > BookClub.descriptionLimit {
                                        description = String(newValue.prefix(BookClub.descriptionLimit))
                                    }
                                }
                        }

                        Text("A club can be about anything: one book, an author, a genre or a favourite character. For a single book, just name the club after it.")
                            .font(.caption)
                            .foregroundStyle(Theme.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)

                        privacyCard

                        CommunityErrorText(message: clubs.errorMessage)

                        CommunityPrimaryButton(
                            title: "Start Club",
                            isWorking: clubs.isWorking,
                            isEnabled: canCreate,
                            action: create
                        )
                    }
                    .padding(24)
                }
                .scrollDismissesKeyboard(.interactively)
            }
            .navigationTitle("New Club")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(Theme.textSecondary)
                }
            }
        }
        .onAppear {
            clubs.errorMessage = nil
            focusedField = .name
        }
    }

    private func field<Content: View>(label: String, hint: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(label)
                    .font(.caption.weight(.semibold))
                    .trackedCaps(1.5)
                    .foregroundStyle(Theme.textSecondary)
                Spacer()
                Text(hint)
                    .font(.caption2)
                    .monospacedDigit()
                    .foregroundStyle(Theme.textSecondary.opacity(0.7))
            }
            content()
                .tint(Theme.accent)
                .padding(14)
                .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Theme.surface))
                .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(Theme.divider, lineWidth: 1))
        }
    }

    private var privacyCard: some View {
        Toggle(isOn: $isPrivate) {
            VStack(alignment: .leading, spacing: 3) {
                Text("Private club")
                    .font(Theme.Font.serif(17))
                    .foregroundStyle(Theme.textPrimary)
                Text(isPrivate
                     ? "Hidden from Discover. Only people you invite can join (invites are coming soon)."
                     : "Anyone can find this club in Discover and join.")
                    .font(.caption)
                    .foregroundStyle(Theme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .tint(Theme.accent)
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Theme.surface))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Theme.divider, lineWidth: 1))
    }

    private func create() {
        guard canCreate, let userID = auth.userID else { return }
        focusedField = nil
        Task {
            if let club = await clubs.create(
                name: name,
                description: description,
                isPrivate: isPrivate,
                userID: userID
            ) {
                dismiss()
                onCreated(club)
            }
        }
    }
}
