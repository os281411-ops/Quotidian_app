//
//  QuotidianApp.swift
//  Quotidian
//
//  Created by Oliver Scott on 20/07/2026.
//

import SwiftUI

@main
struct QuotidianApp: App {
    @State private var showSplash = true

    var body: some Scene {
        WindowGroup {
            ZStack {
                ContentView()
                if showSplash {
                    SplashView()
                        .transition(.opacity)
                }
            }
            .preferredColorScheme(.dark)
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.3) {
                    withAnimation(.easeOut(duration: 0.5)) {
                        showSplash = false
                    }
                }
            }
        }
    }
}
