import SwiftUI

/// Admin-only: every reported message with open reports, across all clubs.
/// Remove keeps it hidden; Keep restores it. Apple expects reports to be
/// handled within 24 hours.
struct ModerationView: View {
    @StateObject private var store = ModerationStore()
    @State private var confirming: (item: ReportedItem, decision: ModerationStore.Decision)?
    @State private var confirmingPerson: (person: ReportedPerson, decision: ModerationStore.PersonDecision)?

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Open reports, newest first. Messages reported by 3 people are already hidden until you decide. Banning someone stops them posting, starting or joining clubs, and hides all their messages.")
                        .font(.footnote)
                        .foregroundStyle(Theme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)

                    CommunityErrorText(message: store.errorMessage)

                    if store.items.isEmpty && store.people.isEmpty {
                        if store.isLoading {
                            ProgressView().tint(Theme.accent)
                                .frame(maxWidth: .infinity)
                                .padding(.top, 40)
                        } else {
                            emptyState
                        }
                    }

                    if !store.items.isEmpty {
                        sectionLabel("Messages")
                        ForEach(store.items) { item in
                            reportCard(item)
                        }
                    }

                    if !store.people.isEmpty {
                        sectionLabel("People")
                            .padding(.top, 8)
                        ForEach(store.people) { person in
                            personCard(person)
                        }
                    }
                }
                .padding(20)
            }
            .refreshable { await store.load() }
        }
        .navigationTitle("Review Reports")
        .navigationBarTitleDisplayMode(.inline)
        .task { await store.load() }
        .confirmationDialog(
            confirmTitle(confirming?.decision),
            isPresented: Binding(get: { confirming != nil }, set: { if !$0 { confirming = nil } }),
            titleVisibility: .visible,
            presenting: confirming
        ) { pending in
            Button(confirmButton(pending.decision),
                   role: pending.decision == .keep ? nil : .destructive) {
                Task { await store.decide(pending.decision, on: pending.item) }
            }
            Button("Cancel", role: .cancel) {}
        } message: { pending in
            switch pending.decision {
            case .remove:
                Text("It stays hidden from everyone except club moderators and admins.")
            case .keep:
                Text("It becomes visible again and the reports are dismissed.")
            case .removeAndBan:
                Text("The message is hidden, and its author is banned: they can't post, start or join clubs, and all their messages are hidden.")
            }
        }
        .confirmationDialog(
            confirmingPerson?.decision == .ban ? "Ban this reader?" : "Dismiss these reports?",
            isPresented: Binding(get: { confirmingPerson != nil }, set: { if !$0 { confirmingPerson = nil } }),
            titleVisibility: .visible,
            presenting: confirmingPerson
        ) { pending in
            Button(pending.decision == .ban ? "Ban \(pending.person.name)" : "Dismiss",
                   role: pending.decision == .ban ? .destructive : nil) {
                Task { await store.decide(pending.decision, on: pending.person) }
            }
            Button("Cancel", role: .cancel) {}
        } message: { pending in
            Text(pending.decision == .ban
                 ? "They won't be able to post, start or join clubs, and all their messages will be hidden."
                 : "No action is taken against them.")
        }
    }

    private func confirmTitle(_ decision: ModerationStore.Decision?) -> String {
        switch decision {
        case .remove: "Remove this message?"
        case .keep: "Keep this message?"
        case .removeAndBan: "Remove and ban the author?"
        case nil: ""
        }
    }

    private func confirmButton(_ decision: ModerationStore.Decision) -> String {
        switch decision {
        case .remove: "Remove"
        case .keep: "Keep"
        case .removeAndBan: "Remove & Ban"
        }
    }

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(.caption.weight(.semibold))
            .trackedCaps(1.5)
            .foregroundStyle(Theme.textSecondary)
    }

    private func personCard(_ person: ReportedPerson) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                MemberAvatar(name: person.name, size: 36)
                VStack(alignment: .leading, spacing: 1) {
                    Text(person.name)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Theme.textPrimary)
                    if let username = person.profile?.username, person.profile?.displayName != nil {
                        Text("@\(username)")
                            .font(.caption)
                            .foregroundStyle(Theme.textSecondary)
                    }
                }
                Spacer()
                Text(person.latestReport.formatted(.relative(presentation: .named)))
                    .font(.caption2)
                    .foregroundStyle(Theme.textSecondary)
            }

            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Label("\(person.reports.count) \(person.reports.count == 1 ? "report" : "reports")", systemImage: "flag.fill")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color(hex: 0xFF6B6B))
                Text(person.reasonSummary)
                    .font(.caption)
                    .foregroundStyle(Theme.textSecondary)
                    .lineLimit(2)
            }

            HStack(spacing: 10) {
                decisionButton("Dismiss", systemImage: "xmark", tint: Theme.textPrimary) {
                    confirmingPerson = (person, .dismiss)
                }
                decisionButton("Ban", systemImage: "nosign", tint: Color(hex: 0xFF6B6B)) {
                    confirmingPerson = (person, .ban)
                }
            }
            .disabled(store.workingOn != nil)
            .overlay {
                if store.workingOn == person.id {
                    ProgressView().tint(Theme.accent)
                }
            }
        }
        .padding(18)
        .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(Theme.surface))
        .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(Theme.divider, lineWidth: 1))
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "checkmark.seal")
                .font(.system(size: 32))
                .foregroundStyle(Theme.accent)
            Text("All clear")
                .font(Theme.Font.serif(20, weight: .semibold))
                .foregroundStyle(Theme.textPrimary)
            Text("There are no open reports.")
                .font(.subheadline)
                .foregroundStyle(Theme.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 50)
    }

    private func reportCard(_ item: ReportedItem) -> some View {
        let message = item.message
        let author = message.author?.displayName ?? message.author?.username.map { "@\($0)" } ?? "Reader"

        return VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Label(message.club?.name ?? "Unknown club", systemImage: "books.vertical")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Theme.textSecondary)
                    .lineLimit(1)
                Spacer()
                if message.isHidden {
                    Text("Hidden")
                        .font(.caption2.weight(.bold))
                        .trackedCaps(1)
                        .foregroundStyle(Color(hex: 0xFF6B6B))
                }
            }

            Text(author)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Theme.textPrimary)

            if let quote = message.quoteText {
                HStack(alignment: .top, spacing: 10) {
                    RoundedRectangle(cornerRadius: 1).fill(Theme.accent).frame(width: 2)
                    Text(quote)
                        .font(Theme.Font.serif(15).italic())
                        .foregroundStyle(Theme.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            if let body = message.body {
                Text(body)
                    .font(.body)
                    .foregroundStyle(Theme.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                    .textSelection(.enabled)
            }
            if let book = message.book {
                Label(book.title, systemImage: "book.closed")
                    .font(.caption)
                    .foregroundStyle(Theme.textSecondary)
            }

            Divider().overlay(Theme.divider)

            HStack(alignment: .firstTextBaseline) {
                Label("\(item.reports.count) \(item.reports.count == 1 ? "report" : "reports")", systemImage: "flag.fill")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color(hex: 0xFF6B6B))
                Text(item.reasonSummary)
                    .font(.caption)
                    .foregroundStyle(Theme.textSecondary)
                    .lineLimit(2)
                Spacer()
                Text(item.latestReport.formatted(.relative(presentation: .named)))
                    .font(.caption2)
                    .foregroundStyle(Theme.textSecondary)
            }

            HStack(spacing: 10) {
                decisionButton("Keep", systemImage: "arrow.uturn.backward", tint: Theme.textPrimary) {
                    confirming = (item, .keep)
                }
                decisionButton("Remove", systemImage: "eye.slash", tint: Color(hex: 0xFF6B6B)) {
                    confirming = (item, .remove)
                }
            }
            .disabled(store.workingOn != nil)
            .overlay {
                if store.workingOn == item.id {
                    ProgressView().tint(Theme.accent)
                }
            }

            Button {
                confirming = (item, .removeAndBan)
            } label: {
                Label("Remove & Ban Author", systemImage: "nosign")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color(hex: 0xFF6B6B))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.plain)
            .disabled(store.workingOn != nil)
        }
        .padding(18)
        .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(Theme.surface))
        .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(Theme.divider, lineWidth: 1))
    }

    private func decisionButton(_ title: String, systemImage: String, tint: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(tint)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 11)
                .background(Capsule().stroke(tint.opacity(0.4), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }
}
