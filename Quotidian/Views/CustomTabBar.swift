import SwiftUI

enum AppTab: CaseIterable {
    case today, library, profile

    var systemImage: String {
        switch self {
        case .today: "house.fill"
        case .library: "bookmark.fill"
        case .profile: "person.fill"
        }
    }
}

struct CustomTabBar: View {
    @Binding var selection: AppTab

    var body: some View {
        HStack(spacing: 0) {
            ForEach(AppTab.allCases, id: \.self) { tab in
                Button {
                    withAnimation(.easeOut(duration: 0.2)) {
                        selection = tab
                    }
                } label: {
                    Image(systemName: tab.systemImage)
                        .font(.system(size: 18))
                        .foregroundStyle(selection == tab ? Theme.accent : Theme.textSecondary)
                        .frame(maxWidth: .infinity)
                }
            }
        }
        .padding(.vertical, 16)
        .padding(.horizontal, 8)
        .background(Capsule().fill(Theme.surfaceElevated))
        .overlay(Capsule().stroke(Theme.divider, lineWidth: 1))
        .padding(.horizontal, 60)
    }
}

#Preview {
    ZStack {
        Theme.background.ignoresSafeArea()
        VStack {
            Spacer()
            CustomTabBar(selection: .constant(.today))
                .padding(.bottom, 16)
        }
    }
}
