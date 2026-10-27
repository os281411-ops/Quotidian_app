import Supabase
import SwiftUI

/// Sheet behind the ⓘ button in a club chat: description, members,
/// join/leave, and deleting the club for its owner.
struct ClubInfoView: View {
    @EnvironmentObject private var auth: AuthManager
    @EnvironmentObject private var clubs: ClubStore
    @Environment(\.dismiss) private var dismiss

    @Binding var club: BookClub
    /// Called after leaving a private club or deleting the club, so the chat closes too.
    let onLeftOrDeleted: () -> Void

    @State private var members: [ClubMember] = []
    @State private var isLoadingMembers = true
    @State private var confirmingLeave = false
    @State private var confirmingDelete = false
    @State private var profileToShow: ClubMember?
    @State private var inviteCode: String?
    @State private var confirmingNewCode = false
    @State private var editingReadingNow = false

    private var myRole: ClubMember.Role? { clubs.role(in: club) }
    private var canModerate: Bool { myRole == .owner || myRole == .moderator }

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.background.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        titleBlock
                        membershipAction
                        CommunityErrorText(message: clubs.errorMessage)
                        ReadingNowCard(club: club, canEdit: canModerate) {
                            editingReadingNow = true
                        }
                        if canModerate {
                            inviteCard
                        }
                        membersCard
                        if myRole == .owner {
                            deleteButton
                        }
                    }
                    .padding(24)
                }
                .refreshable { await reload() }
            }
            .navigationTitle("Club Info")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(Theme.accent)
                }
            }
        }
        .task { await reload() }
        .sheet(isPresented: $editingReadingNow) {
            EditReadingNowView(club: club) { updated in
                club = updated
            }
        }
        .sheet(item: $profileToShow) { member in
            MemberProfileView(member: member)
        }
        .alert("Leave \(club.name)?", isPresented: $confirmingLeave) {
            Button("Leave", role: .destructive) {
                Task {
                    guard let userID = auth.userID else { return }
                    if await clubs.leave(club, userID: userID) {
                        if club.isPrivate {
                            dismiss()
                            onLeftOrDeleted()
                        } else {
                            await reload()
                        }
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
                    if await clubs.delete(club, userID: userID) {
                        dismiss()
                        onLeftOrDeleted()
                    }
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This removes the club and its whole chat for every member. This can't be undone.")
        }
    }

    private func reload() async {
        if let fresh = await clubs.fetchClub(id: club.id) {
            club = fresh
        }
        members = await clubs.fetchMembers(clubID: club.id)
        isLoadingMembers = false
        if canModerate {
            inviteCode = await clubs.inviteCode(for: club)
        }
    }

    private var inviteMessage: String {
        "Join my book club \u{201C}\(club.name)\u{201D} on Quotidian. In the Bookclub tab, tap + → Join with Invite Code and enter: \(inviteCode ?? "")"
    }

    private var inviteCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Invite")
                .font(.caption.weight(.semibold))
                .trackedCaps(1.5)
                .foregroundStyle(Theme.textSecondary)

            if let inviteCode {
                Text(inviteCode)
                    .font(.system(size: 28, weight: .semibold, design: .monospaced))
                    .tracking(5)
                    .foregroundStyle(Theme.textPrimary)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)

                Text(club.isPrivate
                     ? "Anyone with this code can join. Joining a private club needs Premium."
                     : "Anyone with this code can join straight away.")
                    .font(.caption)
                    .foregroundStyle(Theme.textSecondary)

                HStack(spacing: 10) {
                    ShareLink(item: inviteMessage) {
                        Label("Share", systemImage: "square.and.arrow.up")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Theme.background)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 11)
                            .background(Capsule().fill(Theme.accent))
                    }
                    Button {
                        confirmingNewCode = true
                    } label: {
                        Label("New Code", systemImage: "arrow.triangle.2.circlepath")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Theme.textPrimary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 11)
                            .background(Capsule().stroke(Theme.divider, lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                }
            } else {
                ProgressView().tint(Theme.accent).frame(maxWidth: .infinity)
            }
        }
        .padding(18)
        .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(Theme.surface))
        .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(Theme.accent.opacity(0.3), lineWidth: 1))
        .alert("Make a new invite code?", isPresented: $confirmingNewCode) {
            Button("New Code", role: .destructive) {
                Task {
                    if let code = await clubs.regenerateInviteCode(for: club) {
                        inviteCode = code
                    }
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("The current code will stop working. People already in the club stay in.")
        }
    }

    // MARK: - Sections

    private var titleBlock: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(club.name)
                .font(Theme.Font.serif(28, weight: .semibold))
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

    private var membersCard: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Members")
                .font(.caption.weight(.semibold))
                .trackedCaps(1.5)
                .foregroundStyle(Theme.textSecondary)
                .padding(.bottom, 8)

            if isLoadingMembers {
                ProgressView()
                    .tint(Theme.accent)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
            } else {
                ForEach(members) { member in
                    Button { profileToShow = member } label: { memberRow(member) }
                        .buttonStyle(.plain)
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
            MemberAvatar(name: name ?? username, size: 36)
            VStack(alignment: .leading, spacing: 1) {
                Text(name ?? "@\(username)")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(Theme.textPrimary)
                if let book = member.profile?.currentlyReading {
                    Label(book.title, systemImage: "book.closed")
                        .font(.caption)
                        .foregroundStyle(Theme.textSecondary)
                        .lineLimit(1)
                } else if name != nil {
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
        .contentShape(Rectangle())
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
}

/// Circle with the first letter of someone's name.
struct MemberAvatar: View {
    let name: String
    var size: CGFloat = 36

    var body: some View {
        Circle()
            .fill(Theme.surfaceElevated)
            .frame(width: size, height: size)
            .overlay(
                Text(String(name.drop { $0 == "@" }.prefix(1)).uppercased())
                    .font(Theme.Font.serif(size * 0.45, weight: .semibold))
                    .foregroundStyle(Theme.accent)
            )
    }
}

/// Another reader's profile: name, username and what they're reading.
struct MemberProfileView: View {
    let member: ClubMember
    /// Called after blocking or unblocking, so an open chat can refresh.
    var onBlockChanged: (() -> Void)? = nil

    @EnvironmentObject private var auth: AuthManager
    @EnvironmentObject private var safety: SafetyStore
    @Environment(\.dismiss) private var dismiss
    @State private var currentlyReading: Book?
    @State private var isLoading = true
    @State private var confirmingBlock = false
    @State private var showReportReasons = false
    @State private var reportSent = false

    private var isMe: Bool { member.userID == auth.userID }
    private var isBlocked: Bool { safety.isBlocked(member.userID) }
    private var handle: String { "@\(member.profile?.username ?? "reader")" }

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.background.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 16) {
                        VStack(spacing: 8) {
                            MemberAvatar(name: displayName, size: 64)
                            if let name = member.profile?.displayName {
                                Text(name)
                                    .font(Theme.Font.serif(24, weight: .semibold))
                                    .foregroundStyle(Theme.textPrimary)
                            }
                            Text("@\(member.profile?.username ?? "reader")")
                                .font(.subheadline)
                                .foregroundStyle(Theme.textSecondary)
                        }

                        VStack(alignment: .leading, spacing: 12) {
                            Text("Currently Reading")
                                .font(.caption.weight(.semibold))
                                .trackedCaps(1.5)
                                .foregroundStyle(Theme.textSecondary)
                            if isLoading {
                                ProgressView().tint(Theme.accent)
                            } else if let book = currentlyReading {
                                BookCard(book: book)
                            } else {
                                Text("Nothing shared yet.")
                                    .font(.subheadline)
                                    .foregroundStyle(Theme.textSecondary)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(16)
                        .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(Theme.surface))
                        .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(Theme.divider, lineWidth: 1))

                        if !isMe {
                            safetyActions
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 24)
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
        // A little taller than half the screen so Block and Report both
        // show without scrolling.
        .presentationDetents([.fraction(0.62), .large])
        .task { await load() }
        .alert("Block \(handle)?", isPresented: $confirmingBlock) {
            Button("Block", role: .destructive) {
                Task {
                    guard let me = auth.userID else { return }
                    if await safety.block(member.userID, me: me) {
                        onBlockChanged?()
                        dismiss()
                    }
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("You won't see their messages in any club. They won't be told. You can unblock them from Account → Blocked Readers.")
        }
        .confirmationDialog("Report \(handle)?", isPresented: $showReportReasons, titleVisibility: .visible) {
            ForEach(ReportReason.allCases) { reason in
                Button(reason.label) {
                    Task {
                        guard let me = auth.userID else { return }
                        if await safety.report(member.userID, reason: reason, me: me) {
                            reportSent = true
                        }
                    }
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Reports are reviewed within 24 hours.")
        }
        .alert("Thanks for reporting", isPresented: $reportSent) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("We'll review it within 24 hours. You can also block them so you don't see their messages.")
        }
    }

    private var safetyActions: some View {
        VStack(spacing: 0) {
            Button {
                if isBlocked {
                    Task {
                        guard let me = auth.userID else { return }
                        if await safety.unblock(member.userID, me: me) { onBlockChanged?() }
                    }
                } else {
                    confirmingBlock = true
                }
            } label: {
                safetyRow(isBlocked ? "Unblock \(handle)" : "Block \(handle)",
                          icon: isBlocked ? "hand.raised.slash" : "hand.raised",
                          color: isBlocked ? Theme.textPrimary : Color(hex: 0xFF6B6B))
            }
            .disabled(safety.isWorking)

            Divider().overlay(Theme.divider)

            Button {
                showReportReasons = true
            } label: {
                safetyRow("Report \(handle)", icon: "flag", color: Color(hex: 0xFF6B6B))
            }

            CommunityErrorText(message: safety.errorMessage)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 6)
        .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(Theme.surface))
        .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(Theme.divider, lineWidth: 1))
    }

    private func safetyRow(_ title: String, icon: String, color: Color) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon).frame(width: 22)
            Text(title)
            Spacer()
        }
        .font(.body)
        .foregroundStyle(color)
        .padding(.vertical, 12)
        .contentShape(Rectangle())
    }

    private var displayName: String {
        member.profile?.displayName ?? member.profile?.username ?? "?"
    }

    /// The members list already includes the book; chat messages don't, so fetch it.
    private func load() async {
        if let book = member.profile?.currentlyReading {
            currentlyReading = book
        } else {
            let profile: CommunityProfile? = try? await supabase
                .from("profiles")
                .select(CommunityProfile.columns)
                .eq("id", value: member.userID)
                .single()
                .execute()
                .value
            currentlyReading = profile?.currentlyReading
        }
        isLoading = false
    }
}
