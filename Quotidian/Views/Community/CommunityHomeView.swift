import SwiftUI

/// The Community tab once someone is signed in: their clubs, public clubs
/// to discover, and a way to start a new one.
struct CommunityHomeView: View {
    @EnvironmentObject private var auth: AuthManager
    @EnvironmentObject private var clubs: ClubStore
    @EnvironmentObject private var subscriptions: SubscriptionManager
    @EnvironmentObject private var paywall: PaywallPresenter
    @EnvironmentObject private var router: AppRouter

    enum Section: String, CaseIterable {
        case mine = "My Clubs"
        case discover = "Discover"
    }

    @State private var section: Section = .mine
    @State private var searchText = ""
    @State private var showCreate = false
    @State private var showAccount = false
    @State private var showJoinWithCode = false
    @State private var path: [BookClub] = []
    @AppStorage(TutorialChat.completedKey) private var tutorialDone = false
    @FocusState private var isSearchFocused: Bool

    var body: some View {
        NavigationStack(path: $path) {
            ZStack {
                Theme.background.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        header
                        sectionPicker

                        if section == .discover {
                            searchField
                        }

                        CommunityErrorText(message: clubs.errorMessage)

                        switch section {
                        case .mine: myClubsList
                        case .discover: discoverList
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 140)
                }
                .scrollDismissesKeyboard(.interactively)
                // Run the reload in its own task: SwiftUI cancels the pull-to-
                // refresh task as soon as the list redraws, which used to cut
                // the request off and show "Couldn't load your clubs".
                .refreshable { await Task { await reload() }.value }
            }
            // Today's discussion: a small button floating above the tab bar.
            .overlay(alignment: .bottomTrailing) {
                DailyRoomButton { openDailyRoom() }
                    .padding(.trailing, 20)
                    .padding(.bottom, 88)
            }
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(for: BookClub.self) { club in
                if club.id == TutorialChat.clubID {
                    TutorialChatView(onOpenDailyRoom: { path = [DailyRoom.club] })
                } else {
                    ClubDetailView(initialClub: club)
                }
            }
        }
        .task(id: auth.userID) { await reload() }
        .onAppear { openDailyRoomIfAsked() }
        .onChange(of: router.wantsDailyRoom) { _, _ in openDailyRoomIfAsked() }
        .task(id: searchText) {
            // Wait for a pause in typing before searching.
            if !searchText.isEmpty { try? await Task.sleep(for: .milliseconds(350)) }
            guard !Task.isCancelled else { return }
            await clubs.refreshDiscover(search: searchText)
        }
        .sheet(isPresented: $showCreate) {
            CreateClubView { newClub in
                section = .mine
                path.append(newClub)
            }
        }
        .sheet(isPresented: $showAccount) {
            CommunityAccountView()
        }
        .sheet(isPresented: $showJoinWithCode) {
            JoinWithCodeView { club in
                section = .mine
                path.append(club)
            }
        }
    }

    /// Starting a club is a Premium feature.
    private func startClub() {
        if subscriptions.isSubscribed {
            showCreate = true
        } else {
            paywall.present(.bookclub)
        }
    }

    private func reload() async {
        guard let userID = auth.userID else { return }
        clubs.errorMessage = nil
        await clubs.refreshMine(userID: userID)
        await clubs.refreshUnread()
        await clubs.refreshDiscover(search: searchText)
    }

    private func openDailyRoom() {
        path = [DailyRoom.club]
    }

    /// "Discuss today's quote" on Today asks for the room via the router.
    private func openDailyRoomIfAsked() {
        guard router.wantsDailyRoom else { return }
        router.wantsDailyRoom = false
        openDailyRoom()
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .top) {
            CommunityHeader(title: "Bookclub", subtitle: "Read Together")
            Spacer()
            HStack(spacing: 10) {
                Menu {
                    Button { startClub() } label: {
                        Label(subscriptions.isSubscribed ? "Start a Club" : "Start a Club (Premium)", systemImage: "plus")
                    }
                    Button { showJoinWithCode = true } label: {
                        Label("Join with Invite Code", systemImage: "ticket")
                    }
                } label: {
                    headerIcon("plus")
                }
                .accessibilityLabel("Start or join a club")
                headerButton("person.crop.circle", label: "Account") { showAccount = true }
            }
            .padding(.top, 12)
        }
    }

    private func headerIcon(_ systemImage: String) -> some View {
        Image(systemName: systemImage)
            .font(.system(size: 17, weight: .medium))
            .foregroundStyle(Theme.textPrimary)
            .frame(width: 40, height: 40)
            .background(Circle().fill(Theme.surface))
            .overlay(Circle().stroke(Theme.divider, lineWidth: 1))
    }

    private func headerButton(_ systemImage: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            headerIcon(systemImage)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }

    private var sectionPicker: some View {
        HStack(spacing: 4) {
            ForEach(Section.allCases, id: \.self) { option in
                Button {
                    withAnimation(.easeOut(duration: 0.2)) { section = option }
                    isSearchFocused = false
                } label: {
                    Text(option.rawValue)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(section == option ? Theme.accent : Theme.textSecondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(
                            Capsule().fill(section == option ? Theme.surfaceElevated : .clear)
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .background(Capsule().fill(Theme.surface))
        .overlay(Capsule().stroke(Theme.divider, lineWidth: 1))
    }

    private var searchField: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(Theme.textSecondary)

            TextField("Search clubs", text: $searchText)
                .foregroundStyle(Theme.textPrimary)
                .tint(Theme.accent)
                .autocorrectionDisabled()
                .focused($isSearchFocused)

            if !searchText.isEmpty {
                Button {
                    searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(Theme.textSecondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Theme.surface))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(Theme.divider, lineWidth: 1))
    }

    // MARK: - Lists

    /// The private tour chat: first in My Clubs until finished, then a
    /// small link at the bottom.
    private var tutorialLink: some View {
        NavigationLink(value: TutorialChat.club) {
            TutorialRow(isComplete: tutorialDone)
        }
        .buttonStyle(.plain)
    }

    private var myClubsList: some View {
        VStack(spacing: 10) {
            if !tutorialDone { tutorialLink }
            myClubsContent
            if tutorialDone { tutorialLink }
        }
    }

    @ViewBuilder
    private var myClubsContent: some View {
        if clubs.myClubs.isEmpty {
            if clubs.isLoadingMine {
                loadingState
            } else {
                emptyState(
                    icon: "books.vertical",
                    title: "No clubs yet",
                    message: "Join a club to read along with others, start your own, or join a private one with an invite code.",
                    primary: ("Discover Clubs", { withAnimation { section = .discover } }),
                    secondary: ("Start a Club", { startClub() })
                )
            }
        } else {
            clubList(clubs.myClubs)
        }
    }

    @ViewBuilder
    private var discoverList: some View {
        if clubs.discoverClubs.isEmpty {
            if clubs.isLoadingDiscover {
                loadingState
            } else if searchText.isEmpty {
                emptyState(
                    icon: "sparkles",
                    title: "Be the first",
                    message: "There aren't any public clubs yet. Start one and other readers will find it here.",
                    primary: ("Start a Club", { startClub() }),
                    secondary: nil
                )
            } else {
                Text("No clubs match \u{201C}\(searchText)\u{201D}.")
                    .font(.subheadline)
                    .foregroundStyle(Theme.textSecondary)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 24)
            }
        } else {
            clubList(clubs.discoverClubs)
        }
    }

    private func clubList(_ list: [BookClub]) -> some View {
        VStack(spacing: 10) {
            ForEach(list) { club in
                NavigationLink(value: club) {
                    ClubRow(club: club, role: clubs.role(in: club), unread: clubs.unread(in: club))
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var loadingState: some View {
        ProgressView()
            .tint(Theme.accent)
            .frame(maxWidth: .infinity)
            .padding(.top, 40)
    }

    private func emptyState(
        icon: String,
        title: String,
        message: String,
        primary: (String, () -> Void),
        secondary: (String, () -> Void)?
    ) -> some View {
        VStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 32))
                .foregroundStyle(Theme.accentDim)
            Text(title)
                .font(Theme.Font.serif(20, weight: .semibold))
                .foregroundStyle(Theme.textPrimary)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(Theme.textSecondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            CommunityPrimaryButton(title: primary.0, action: primary.1)
                .padding(.top, 6)

            if let secondary {
                Button(secondary.0, action: secondary.1)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.accent)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
        .padding(.horizontal, 24)
        .background(RoundedRectangle(cornerRadius: 24, style: .continuous).fill(Theme.surface))
        .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).stroke(Theme.divider, lineWidth: 1))
    }
}

/// One club in a list: a compact row, so the list reads as separate
/// items rather than more of the controls above it.
struct ClubRow: View {
    let club: BookClub
    let role: ClubMember.Role?
    var unread = 0

    private var subtitle: String {
        let members = "\(club.memberCount) \(club.memberCount == 1 ? "member" : "members")"
        let detail = club.readingSummary.map { "Reading \($0)" } ?? club.description
        return [members, detail].compactMap { $0?.isEmpty == false ? $0 : nil }.joined(separator: " \u{00B7} ")
    }

    var body: some View {
        HStack(spacing: 12) {
            Text(String(club.name.prefix(1)).uppercased())
                .font(Theme.Font.serif(16, weight: .semibold))
                .foregroundStyle(Theme.accent)
                .frame(width: 34, height: 34)
                .background(Circle().fill(Theme.surfaceElevated))
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(club.name)
                        .font(Theme.Font.serif(16, weight: .semibold))
                        .foregroundStyle(Theme.textPrimary)
                        .lineLimit(1)
                    if club.isPrivate {
                        Image(systemName: "lock.fill")
                            .font(.caption2)
                            .foregroundStyle(Theme.textSecondary)
                            .accessibilityLabel("Private")
                    }
                }
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(Theme.textSecondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            if unread > 0 {
                Text(unread > 99 ? "99+" : "\(unread)")
                    .font(.caption2.weight(.bold))
                    .monospacedDigit()
                    .foregroundStyle(Theme.background)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(Capsule().fill(Theme.accent))
                    .accessibilityLabel("\(unread) new \(unread == 1 ? "message" : "messages")")
            } else if let role, role != .member {
                Text(role.label)
                    .font(.caption2.weight(.bold))
                    .trackedCaps(1)
                    .foregroundStyle(Theme.accent)
            } else if role == .member {
                Image(systemName: "checkmark.circle.fill")
                    .font(.subheadline)
                    .foregroundStyle(Theme.accent)
                    .accessibilityLabel("Joined")
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Theme.surface))
        .overlay(alignment: .leading) {
            if unread > 0 {
                // Gold edge on clubs with new messages.
                UnevenRoundedRectangle(topLeadingRadius: 14, bottomLeadingRadius: 14, style: .continuous)
                    .fill(Theme.accent)
                    .frame(width: 3)
            }
        }
        .contentShape(Rectangle())
    }
}

/// Floating button that opens today's Quote of the Day discussion.
struct DailyRoomButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "quote.bubble.fill")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(Theme.background)
                .frame(width: 54, height: 54)
                .background(Circle().fill(Theme.accent))
                .shadow(color: .black.opacity(0.35), radius: 10, y: 4)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Discuss today's quote")
    }
}

#Preview {
    ZStack {
        Theme.background.ignoresSafeArea()
        CommunityHomeView()
    }
    .environmentObject(AuthManager())
    .environmentObject(ClubStore())
    .environmentObject(AppRouter())
}
