import SwiftUI

/// Admin-only: every reported message with open reports, across all clubs.
/// Remove keeps it hidden; Keep restores it. Apple expects reports to be
/// handled within 24 hours.
struct ModerationView: View {
    @StateObject private var store = ModerationStore()
    @State private var confirming: (item: ReportedItem, decision: ModerationStore.Decision)?

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Messages with open reports, newest first. Messages reported by 3 people are already hidden until you decide.")
                        .font(.footnote)
                        .foregroundStyle(Theme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)

                    CommunityErrorText(message: store.errorMessage)

                    if store.items.isEmpty {
                        if store.isLoading {
                            ProgressView().tint(Theme.accent)
                                .frame(maxWidth: .infinity)
                                .padding(.top, 40)
                        } else {
                            emptyState
                        }
                    }

                    ForEach(store.items) { item in
                        reportCard(item)
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
            confirming?.decision == .remove ? "Remove this message?" : "Keep this message?",
            isPresented: Binding(get: { confirming != nil }, set: { if !$0 { confirming = nil } }),
            titleVisibility: .visible,
            presenting: confirming
        ) { pending in
            Button(pending.decision == .remove ? "Remove" : "Keep",
                   role: pending.decision == .remove ? .destructive : nil) {
                Task { await store.decide(pending.decision, on: pending.item) }
            }
            Button("Cancel", role: .cancel) {}
        } message: { pending in
            Text(pending.decision == .remove
                 ? "It stays hidden from everyone except club moderators and admins."
                 : "It becomes visible again and the reports are dismissed.")
        }
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
