import SwiftUI

/// Account → Blocked Readers: everyone you've blocked, with Unblock.
struct BlockedReadersView: View {
    @EnvironmentObject private var auth: AuthManager
    @EnvironmentObject private var safety: SafetyStore

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("You won't see messages from people you've blocked in any club. They aren't told you blocked them.")
                        .font(.footnote)
                        .foregroundStyle(Theme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)

                    CommunityErrorText(message: safety.errorMessage)

                    if safety.blocked.isEmpty {
                        Text("You haven't blocked anyone.")
                            .font(.subheadline)
                            .foregroundStyle(Theme.textSecondary)
                            .frame(maxWidth: .infinity)
                            .padding(.top, 40)
                    } else {
                        VStack(spacing: 0) {
                            ForEach(safety.blocked) { reader in
                                HStack(spacing: 12) {
                                    MemberAvatar(name: reader.name, size: 36)
                                    VStack(alignment: .leading, spacing: 1) {
                                        Text(reader.name)
                                            .font(.subheadline.weight(.medium))
                                            .foregroundStyle(Theme.textPrimary)
                                        Text("Blocked \(reader.createdAt.formatted(date: .abbreviated, time: .omitted))")
                                            .font(.caption)
                                            .foregroundStyle(Theme.textSecondary)
                                    }
                                    Spacer()
                                    Button("Unblock") {
                                        Task {
                                            guard let me = auth.userID else { return }
                                            await safety.unblock(reader.blockedID, me: me)
                                        }
                                    }
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(Theme.accent)
                                    .disabled(safety.isWorking)
                                }
                                .padding(.vertical, 10)
                                if reader.id != safety.blocked.last?.id {
                                    Divider().overlay(Theme.divider)
                                }
                            }
                        }
                        .padding(.horizontal, 18)
                        .padding(.vertical, 6)
                        .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(Theme.surface))
                        .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(Theme.divider, lineWidth: 1))
                    }
                }
                .padding(20)
            }
            .refreshable { await safety.load() }
        }
        .navigationTitle("Blocked Readers")
        .navigationBarTitleDisplayMode(.inline)
        .task { await safety.load() }
    }
}
