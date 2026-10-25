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
    @StateObject private var auth = AuthManager()
    @StateObject private var clubs = ClubStore()
    @StateObject private var safety = SafetyStore()
    @StateObject private var tabBar = TabBarVisibility()
    @StateObject private var reflections = ReflectionStore()
    @StateObject private var router = AppRouter()
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage("onboarding.paywallShown") private var hasShownOnboardingPaywall = false

    var body: some View {
        ZStack(alignment: .bottom) {
            Theme.background.ignoresSafeArea()

            Group {
                switch router.selectedTab {
                case .today: TodayView()
                case .library: LibraryView()
                case .community: CommunityView()
                case .profile: ProfileView()
                }
            }

            if !keyboard.isVisible && !tabBar.isHidden {
                CustomTabBar(
                    selection: $router.selectedTab,
                    badged: clubs.totalUnread > 0 ? [.community] : []
                )
                    .padding(.bottom, 8)
                    .transition(.opacity)
            }
        }
        .animation(.easeOut(duration: 0.2), value: keyboard.isVisible)
        .animation(.easeOut(duration: 0.2), value: tabBar.isHidden)
        .environmentObject(library)
        .environmentObject(streak)
        .environmentObject(notifications)
        .environmentObject(subscriptions)
        .environmentObject(paywall)
        .environmentObject(themeManager)
        .environmentObject(auth)
        .environmentObject(clubs)
        .environmentObject(safety)
        .environmentObject(tabBar)
        .environmentObject(reflections)
        .environmentObject(router)
        .task { await auth.start() }
        .onChange(of: auth.userID) { _, userID in
            if userID == nil { clubs.reset() }
        }
        .task(id: auth.userID) {
            if auth.userID == nil {
                safety.reset()
            } else {
                await safety.load()
                await clubs.refreshUnread()
            }
        }
        // Check for new club messages whenever the app comes back.
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active, auth.userID != nil else { return }
            Task { await clubs.refreshUnread() }
        }
        .sheet(item: $paywall.trigger) { trigger in
            PaywallView(trigger: trigger)
                .environmentObject(subscriptions)
        }
        .onChange(of: subscriptions.isSubscribed) { _, isSubscribed in
            themeManager.enforceFreeTier(isSubscribed: isSubscribed)
            if !isSubscribed {
                notifications.setEveningReminderEnabled(false)
            }
        }
        .onAppear {
            guard !hasShownOnboardingPaywall, !subscriptions.isSubscribed else { return }
            hasShownOnboardingPaywall = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) {
                paywall.present(.onboarding)
            }
        }
    }
}

#Preview {
    ContentView()
}
