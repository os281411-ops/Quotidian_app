import SwiftUI

/// A single book club: what it's about, what it's reading, who's in it,
/// and joining or leaving.
struct ClubDetailView: View {
    @EnvironmentObject private var auth: AuthManager
    @EnvironmentObject private var clubs: ClubStore
    @Environment(\.dismiss) private var dismiss

    @State private var club: BookClub
    @State private var members: [ClubMember] = []
    @State private var isLoadingMembers = true
    @State private var confirmingLeave = false
    @State private var confirmingDelete = false

    init(initialClub: BookClub) {
        _club = State(initialValue: initialClub)
    }

    private var myRole: ClubMember.Role? { clubs.role(in: club) }

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    titleBlock
                    membershipAction
                    CommunityErrorText(message: clubs.errorMessage)
                    currentBookCard
                    discussionCard
                    membersCard
                    if myRole == .owner {
                        deleteButton
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 8)
                .padding(.bottom, 140)
            }
            .refreshable { await reload() }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Theme.background, for: .navigationBar)
        .task { await reload() }
        .onAppear { clubs.errorMessage = nil }
        .alert("Leave \(club.name)?", isPresented: $confirmingLeave) {
            Button("Leave", role: .destructive) {
                Task {
                    guard let userID = auth.userID else { return }
                    if await clubs.leave(club, userID: userID) {
                        if club.isPrivate { dismiss() } else { await reload() }
                    }
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text(club.isPrivate
                 ? "This is a private club, so you'll need an invite to rejoin."
                 : "You can join again any time.")
        }
        .alert("Delete \(club.name)?", isPresented: $confirmingDelete) {
            Button("Delete Club", role: .destructive) {
                Task {
                    guard let userID = auth.userID else { return }
                    if await clubs.delete(club, userID: userID) { dismiss() }
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This removes the club and all its posts for every member. This can't be undone.")
        }
    }

    private func reload() async {
        if let fresh = await clubs.fetchClub(id: club.id) {
            club = fresh
        }
        members = await clubs.fetchMembers(clubID: club.id)
        isLoadingMembers = false
    }

    // MARK: - Sections

    private var titleBlock: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(club.name)
                .font(Theme.Font.serif(30, weight: .semibold))
                .foregroundStyle(Theme.textPrimary)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 14) {
                Label(club.isPrivate ? "Private" : "Public",
                      systemImage: club.isPrivate ? "lock.fill" : "globe")
                Label("\(club.memberCount) \(club.memberCount == 1 ? "member" : "members")",
                      systemImage: "person.2")
            }
            .font(.caption.weight(.semibold))
            .trackedCaps(1)
            .foregroundStyle(Theme.textSecondary)

            if let description = club.description, !description.isEmpty {
                Text(description)
                    .font(Theme.Font.serif(16))
                    .foregroundStyle(Theme.textSecondary)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 4)
            }
        }
    }

    @ViewBuilder
    private var membershipAction: some View {
        switch myRole {
        case nil:
            CommunityPrimaryButton(title: "Join Club", isWorking: clubs.isWorking) {
                Task {
                    guard let userID = auth.userID else { return }
                    if await clubs.join(club, userID: userID) { await reload() }
                }
            }
        case .owner:
            Label("You started this club", systemImage: "crown")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Theme.accent)
        case .moderator, .member:
            HStack {
                Label(myRole == .moderator ? "You're a moderator" : "You're a member",
                      systemImage: "checkmark.circle.fill")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.accent)
                Spacer()
                Button("Leave") { confirmingLeave = true }
                    .font(.subheadline)
                    .foregroundStyle(Theme.textSecondary)
                    .disabled(clubs.isWorking)
            }
        }
    }

    private var currentBookCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionLabel("Currently Reading")
            if let book = club.currentBook {
                HStack(spacing: 14) {
                    Image(systemName: "book.closed.fill")
                        .font(.system(size: 26))
                        .foregroundStyle(Theme.accent)
                        .frame(width: 44, height: 60)
                        .background(RoundedRectangle(cornerRadius: 6).fill(Theme.surfaceElevated))
                    VStack(alignment: .leading, spacing: 3) {
                        Text(book.title)
                            .font(Theme.Font.serif(18, weight: .semibold))
                            .foregroundStyle(Theme.textPrimary)
                        if let author = book.author {
                            Text(author)
                                .font(.subheadline)
                                .foregroundStyle(Theme.textSecondary)
                        }
                    }
                }
            } else {
                Text(myRole == .owner || myRole == .moderator
                     ? "No book chosen yet. Picking one is coming soon."
                     : "The club hasn't picked a book yet.")
                    .font(.subheadline)
                    .foregroundStyle(Theme.textSecondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(Theme.surface))
        .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(Theme.divider, lineWidth: 1))
    }

    private var discussionCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionLabel("Discussion")
            Text(myRole == nil
                 ? "Join to share passages and talk about the book."
                 : "Sharing passages and discussing them is coming next.")
                .font(.subheadline)
                .foregroundStyle(Theme.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(Theme.surface))
        .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(Theme.divider, lineWidth: 1))
    }

    private var membersCard: some View {
        VStack(alignment: .leading, spacing: 4) {
            sectionLabel("Members")
                .padding(.bottom, 8)

            if isLoadingMembers {
                ProgressView()
                    .tint(Theme.accent)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
            } else {
                ForEach(members) { member in
                    memberRow(member)
                    if member.id != members.last?.id {
                        Divider().overlay(Theme.divider)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(Theme.surface))
        .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(Theme.divider, lineWidth: 1))
    }

    private func memberRow(_ member: ClubMember) -> some View {
        let username = member.profile?.username ?? "reader"
        let name = member.profile?.displayName
        return HStack(spacing: 12) {
            Circle()
                .fill(Theme.surfaceElevated)
                .frame(width: 36, height: 36)
                .overlay(
                    Text(String((name ?? username).prefix(1)).uppercased())
                        .font(Theme.Font.serif(16, weight: .semibold))
                        .foregroundStyle(Theme.accent)
                )
            VStack(alignment: .leading, spacing: 1) {
                Text(name ?? "@\(username)")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(Theme.textPrimary)
                if name != nil {
                    Text("@\(username)")
                        .font(.caption)
                        .foregroundStyle(Theme.textSecondary)
                }
            }
            Spacer()
            if member.userID == auth.userID {
                Text("You")
                    .font(.caption2.weight(.bold))
                    .trackedCaps(1)
                    .foregroundStyle(Theme.textSecondary)
            }
            if member.role != .member {
                Text(member.role.label)
                    .font(.caption2.weight(.bold))
                    .trackedCaps(1)
                    .foregroundStyle(Theme.accent)
            }
        }
        .padding(.vertical, 8)
    }

    private var deleteButton: some View {
        Button {
            confirmingDelete = true
        } label: {
            Label("Delete Club", systemImage: "trash")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color(hex: 0xFF6B6B))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Capsule().stroke(Color(hex: 0xFF6B6B).opacity(0.4), lineWidth: 1))
        }
        .buttonStyle(.plain)
        .disabled(clubs.isWorking)
        .padding(.top, 8)
    }

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(.caption.weight(.semibold))
            .trackedCaps(1.5)
            .foregroundStyle(Theme.textSecondary)
    }
}
