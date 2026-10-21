import SwiftUI

/// The Community tab once someone is signed in: their clubs, public clubs
/// to discover, and a way to start a new one.
struct CommunityHomeView: View {
    @EnvironmentObject private var auth: AuthManager
    @EnvironmentObject private var clubs: ClubStore

    enum Section: String, CaseIterable {
        case mine = "My Clubs"
        case discover = "Discover"
    }

    @State private var section: Section = .mine
    @State private var searchText = ""
    @State private var showCreate = false
    @State private var showAccount = false
    @State private var path: [BookClub] = []
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
                .refreshable { await reload() }
            }
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(for: BookClub.self) { club in
                ClubDetailView(initialClub: club)
            }
        }
        .task(id: auth.userID) { await reload() }
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
    }

    private func reload() async {
        guard let userID = auth.userID else { return }
        await clubs.refreshMine(userID: userID)
        await clubs.refreshDiscover(search: searchText)
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .top) {
            CommunityHeader(title: "Bookclub", subtitle: "Read Together")
            Spacer()
            HStack(spacing: 10) {
                headerButton("plus", label: "Start a club") { showCreate = true }
                headerButton("person.crop.circle", label: "Account") { showAccount = true }
            }
            .padding(.top, 12)
        }
    }

    private func headerButton(_ systemImage: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 17, weight: .medium))
                .foregroundStyle(Theme.textPrimary)
                .frame(width: 40, height: 40)
                .background(Circle().fill(Theme.surface))
                .overlay(Circle().stroke(Theme.divider, lineWidth: 1))
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

    @ViewBuilder
    private var myClubsList: some View {
        if clubs.myClubs.isEmpty {
            if clubs.isLoadingMine {
                loadingState
            } else {
                emptyState(
                    icon: "books.vertical",
                    title: "No clubs yet",
                    message: "Join a club to read along with others, or start your own and invite friends.",
                    primary: ("Discover Clubs", { withAnimation { section = .discover } }),
                    secondary: ("Start a Club", { showCreate = true })
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
                    primary: ("Start a Club", { showCreate = true }),
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
        VStack(spacing: 14) {
            ForEach(list) { club in
                NavigationLink(value: club) {
                    ClubRow(club: club, role: clubs.role(in: club))
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

/// One club in a list.
struct ClubRow: View {
    let club: BookClub
    let role: ClubMember.Role?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(club.name)
                    .font(Theme.Font.serif(19, weight: .semibold))
                    .foregroundStyle(Theme.textPrimary)
                    .lineLimit(2)
                if club.isPrivate {
                    Image(systemName: "lock.fill")
                        .font(.caption)
                        .foregroundStyle(Theme.textSecondary)
                }
                Spacer(minLength: 8)
                if let role, role != .member {
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

            if let description = club.description, !description.isEmpty {
                Text(description)
                    .font(.subheadline)
                    .foregroundStyle(Theme.textSecondary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
            }

            Label("\(club.memberCount) \(club.memberCount == 1 ? "member" : "members")", systemImage: "person.2")
            .font(.caption)
            .foregroundStyle(Theme.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(Theme.surface))
        .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(Theme.divider, lineWidth: 1))
        .contentShape(Rectangle())
    }
}

#Preview {
    ZStack {
        Theme.background.ignoresSafeArea()
        CommunityHomeView()
    }
    .environmentObject(AuthManager())
    .environmentObject(ClubStore())
}
