import SwiftUI

struct ProfileView: View {
    @EnvironmentObject private var library: LibraryStore
    @EnvironmentObject private var streak: StreakManager
    @EnvironmentObject private var notifications: NotificationManager

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 32) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Profile")
                            .font(Theme.Font.serif(34, weight: .semibold))
                            .foregroundStyle(Theme.textPrimary)
                        Text("Your Progress")
                            .font(.caption.weight(.semibold))
                            .trackedCaps(1.5)
                            .foregroundStyle(Theme.textSecondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, 8)

                    VStack(spacing: 10) {
                        Image(systemName: "flame.fill")
                            .font(.system(size: 40))
                            .foregroundStyle(Theme.accent)
                        Text("\(streak.currentStreak)")
                            .font(Theme.Font.serif(56, weight: .semibold))
                            .foregroundStyle(Theme.textPrimary)
                        Text(streak.currentStreak == 1 ? "Day Streak" : "Day Streak")
                            .font(.caption.weight(.bold))
                            .trackedCaps(2)
                            .foregroundStyle(Theme.accent)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 28)
                    .background(RoundedRectangle(cornerRadius: 24, style: .continuous).fill(Theme.surface))
                    .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).stroke(Theme.accent.opacity(0.25), lineWidth: 1))

                    milestoneCard

                    HStack(spacing: 14) {
                        StatCard(value: "\(streak.longestStreak)", label: "Longest Streak")
                        StatCard(value: "\(library.savedQuotes.count)", label: "Saved Passages")
                    }

                    reminderCard

                    VStack(spacing: 6) {
                        Text("Quotidian")
                            .font(Theme.Font.serif(15))
                            .foregroundStyle(Theme.textSecondary)
                        Text("A quote a day from the world's great books")
                            .font(.caption)
                            .foregroundStyle(Theme.textSecondary.opacity(0.7))
                    }
                    .padding(.top, 12)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 140)
            }
        }
    }

    private var milestoneCard: some View {
        let next = StreakMilestone.next(for: streak.currentStreak)
        let remaining = max(0, next - streak.currentStreak)

        return VStack(spacing: 14) {
            BookProgressView(progress: StreakMilestone.progress(for: streak.currentStreak))

            VStack(spacing: 4) {
                Text("\(streak.currentStreak) / \(next) Days")
                    .font(Theme.Font.serif(17))
                    .foregroundStyle(Theme.textPrimary)
                Text(remaining == 0 ? "Milestone reached!" : "\(remaining) day\(remaining == 1 ? "" : "s") to next milestone")
                    .font(.caption.weight(.semibold))
                    .trackedCaps(1)
                    .foregroundStyle(Theme.textSecondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .background(RoundedRectangle(cornerRadius: 24, style: .continuous).fill(Theme.surface))
        .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).stroke(Theme.divider, lineWidth: 1))
    }

    private var reminderCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Daily Reminder")
                        .font(Theme.Font.serif(17))
                        .foregroundStyle(Theme.textPrimary)
                    Text("A nudge to keep your streak alive")
                        .font(.caption2)
                        .foregroundStyle(Theme.textSecondary)
                }
                Spacer()
                Toggle("", isOn: Binding(
                    get: { notifications.isReminderEnabled },
                    set: { notifications.setReminderEnabled($0) }
                ))
                .labelsHidden()
                .tint(Theme.accent)
            }

            if notifications.isReminderEnabled {
                Divider().overlay(Theme.divider)
                DatePicker(
                    "Time",
                    selection: Binding(
                        get: { notifications.reminderTime },
                        set: { notifications.updateReminderTime($0) }
                    ),
                    displayedComponents: .hourAndMinute
                )
                .datePickerStyle(.compact)
                .labelsHidden()
                .tint(Theme.accent)
            }

            if notifications.permissionDenied {
                Text("Notifications are turned off for Quotidian. Enable them in Settings to use reminders.")
                    .font(.caption2)
                    .foregroundStyle(Theme.textSecondary)
            }
        }
        .padding(18)
        .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Theme.surface))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(Theme.divider, lineWidth: 1))
    }
}

#Preview {
    ProfileView()
        .environmentObject(LibraryStore())
        .environmentObject(StreakManager())
        .environmentObject(NotificationManager())
}
