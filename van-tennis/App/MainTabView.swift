import SwiftUI

struct MainTabView: View {
    @EnvironmentObject private var appState: AppState
    @State private var selectedTab: MainTab = .find
    @State private var findResetTrigger = 0
    @State private var isShowingProfile = false
    @State private var isShowingNotifications = false

    var body: some View {
        ZStack(alignment: .bottom) {
            selectedContent
                .safeAreaInset(edge: .bottom) {
                    Color.clear.frame(height: 82)
                }

            MainTabBar(
                selectedTab: selectedTab,
                hasMyEvents: hasMyEvents,
                hasUnreadChats: appState.hasUnreadChats
            ) { tab in
                selectTab(tab)
            }
            .padding(.horizontal, 26)
            .padding(.bottom, 12)
        }
        .sheet(isPresented: $isShowingProfile) {
            UserProfileView()
                .environmentObject(appState)
        }
        .sheet(isPresented: $isShowingNotifications) {
            NotificationListView {
                isShowingNotifications = false
                isShowingProfile = true
            }
            .environmentObject(appState)
        }
    }

    @ViewBuilder
    private var selectedContent: some View {
        switch selectedTab {
        case .find:
            EventDiscoveryListView(
                resetTrigger: findResetTrigger,
                onOpenProfile: {
                    isShowingProfile = true
                },
                onOpenNotifications: {
                    isShowingNotifications = true
                }
            )
        case .myEvents:
            MyEventsView {
                isShowingProfile = true
            }
        case .chat:
            ChatView {
                isShowingProfile = true
            }
        }
    }

    private func selectTab(_ tab: MainTab) {
        selectedTab = tab

        if tab == .find {
            findResetTrigger += 1
        }
    }

    private var hasMyEvents: Bool {
        guard let profile = appState.userProfile else {
            return false
        }

        return !profile.hostedEvents.isEmpty || !profile.participatedEvents.isEmpty
    }

}

private enum MainTab: Hashable, CaseIterable {
    case find
    case myEvents
    case chat

    var title: String {
        switch self {
        case .find:
            return AppContent.string("tabs.find")
        case .myEvents:
            return AppContent.string("tabs.myEvents")
        case .chat:
            return AppContent.string("tabs.chat")
        }
    }

    func iconName(isSelected: Bool) -> String {
        "\(iconBaseName)_\(isSelected ? "filled" : "lined")"
    }

    private var iconBaseName: String {
        switch self {
        case .find:
            return "home"
        case .myEvents:
            return "calendar"
        case .chat:
            return "chat"
        }
    }

    var iconSize: CGSize {
        switch self {
        case .find:
            return CGSize(width: 29, height: 29)
        case .myEvents:
            return CGSize(width: 29, height: 29)
        case .chat:
            return CGSize(width: 39, height: 39)
        }
    }
}

#Preview {
    MainTabView()
        .environmentObject(AppState())
}

private struct MainTabBar: View {
    let selectedTab: MainTab
    let hasMyEvents: Bool
    let hasUnreadChats: Bool
    let onSelect: (MainTab) -> Void

    var body: some View {
        HStack(spacing: 0) {
            ForEach(MainTab.allCases, id: \.self) { tab in
                Button {
                    onSelect(tab)
                } label: {
                    ZStack(alignment: .topTrailing) {
                        Image(tab.iconName(isSelected: selectedTab == tab))
                            .resizable()
                            .scaledToFit()
                            .opacity(selectedTab == tab ? 1 : 0.72)
                            .frame(width: tab.iconSize.width, height: tab.iconSize.height)
                            .frame(width: 54, height: 44)

                        if showsBadge(for: tab) {
                            Circle()
                                .fill(Color.red)
                                .frame(width: 8, height: 8)
                                .offset(x: -8, y: 7)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(tab.title)
                .accessibilityAddTraits(selectedTab == tab ? .isSelected : [])
            }
        }
        .padding(.horizontal, 22)
        .frame(maxWidth: 364)
        .frame(height: 64)
        .background(MainTabBarStyle.background)
        .clipShape(Capsule())
        .shadow(color: MainTabBarStyle.shadow, radius: 18, x: 0, y: 8)
    }

    private func showsBadge(for tab: MainTab) -> Bool {
        switch tab {
        case .find:
            return false
        case .myEvents:
            return hasMyEvents
        case .chat:
            return hasUnreadChats
        }
    }
}

private enum MainTabBarStyle {
    static let background = Color(red: 0.57, green: 0.66, blue: 0.34)
    static let shadow = Color(red: 0.16, green: 0.27, blue: 0.18).opacity(0.16)
}
