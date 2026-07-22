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

            CustomTabBar(selection: $selectedTab)
                .padding(.bottom, 8)
                .ignoresSafeArea(.keyboard, edges: .bottom)
        }
        .environmentObject(library)
        .environmentObject(streak)
        .environmentObject(notifications)
    }
}

#Preview {
    ContentView()
}
