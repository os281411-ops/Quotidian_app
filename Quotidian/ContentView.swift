//
//  ContentView.swift
//  Quotidian
//
//  Created by Oliver Scott on 20/07/2026.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var library = LibraryStore()
    @StateObject private var streak = StreakManager()
    @StateObject private var notifications = NotificationManager()
    @StateObject private var keyboard = KeyboardObserver()
    @StateObject private var subscriptions = SubscriptionManager()
    @StateObject private var paywall = PaywallPresenter()
    @StateObject private var themeManager = ThemeManager()
    @State private var selectedTab: AppTab = .today

    var body: some View {
        ZStack(alignment: .bottom) {
            Theme.background.ignoresSafeArea()

            Group {
                switch selectedTab {
                case .today: TodayView()
                case .archive: ArchiveView()
                case .library: LibraryView()
                case .profile: ProfileView()
                }
            }

            if !keyboard.isVisible {
                CustomTabBar(selection: $selectedTab)
                    .padding(.bottom, 8)
                    .transition(.opacity)
            }
        }
        .animation(.easeOut(duration: 0.2), value: keyboard.isVisible)
        .environmentObject(library)
        .environmentObject(streak)
        .environmentObject(notifications)
        .environmentObject(subscriptions)
        .environmentObject(paywall)
        .environmentObject(themeManager)
        .sheet(item: $paywall.trigger) { trigger in
            PaywallView(trigger: trigger)
        }
        .onChange(of: subscriptions.isSubscribed) { _, isSubscribed in
            themeManager.enforceFreeTier(isSubscribed: isSubscribed)
            if !isSubscribed {
                notifications.setEveningReminderEnabled(false)
            }
        }
    }
}

#Preview {
    ContentView()
}
