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
    @State private var selectedTab: AppTab = .today

    var body: some View {
        ZStack(alignment: .bottom) {
            Theme.background.ignoresSafeArea()

            Group {
                switch selectedTab {
                case .today: TodayView()
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
    }
}

#Preview {
    ContentView()
}
