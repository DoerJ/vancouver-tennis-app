import SwiftUI

struct MainTabView: View {
    @EnvironmentObject private var appState: AppState
    @State private var selectedTab: MainTab = .find
    @State private var findResetTrigger = 0
    @State private var isShowingProfile = false
    @State private var isShowingNotifications = false
    @State private var selectedJoinRequestNotificationID: UUID?
    @State private var requestedChatEventID: UUID?
    @State private var requestedEventDetailID: UUID?
    @State private var isMainTabBarHidden = false

    var body: some View {
        ZStack(alignment: .bottom) {
            selectedContent
                .safeAreaInset(edge: .bottom) {
                    Color.clear.frame(height: isMainTabBarHidden ? 0 : 82)
                }

            if !isMainTabBarHidden {
                MainTabBar(
                    selectedTab: selectedTab,
                    hasUnreadMyEvents: appState.hasUnreadMyEvents,
                    hasUnreadChats: appState.hasUnreadChats
                ) { tab in
                    selectTab(tab)
                }
                .padding(.horizontal, 26)
                .padding(.bottom, 12)
            }
        }
        .onPreferenceChange(MainTabBarHiddenPreferenceKey.self) { isHidden in
            isMainTabBarHidden = isHidden
        }
        .sheet(isPresented: $isShowingProfile) {
            UserProfileView {
                isShowingProfile = false
            }
                .environmentObject(appState)
        }
        .sheet(
            isPresented: $isShowingNotifications,
            onDismiss: {
                selectedJoinRequestNotificationID = nil
            }
        ) {
            NotificationListView(initialJoinRequestNotificationID: selectedJoinRequestNotificationID) {
                isShowingNotifications = false
                selectedJoinRequestNotificationID = nil
                isShowingProfile = true
            }
            .environmentObject(appState)
        }
        .onReceive(NotificationCenter.default.publisher(for: NotificationService.remoteNotificationDidOpenNotification)) { notification in
            guard appState.authenticationState == .signedIn else {
                return
            }

            guard let context = notification.object as? NotificationService.OpenedNotificationContext else {
                return
            }

            _ = NotificationService.consumePendingOpenedNotificationContext()
            handleOpenedNotification(context)
        }
        .onAppear {
            appState.startProfileRealtimeFromMainTabIfNeeded()

            guard appState.authenticationState == .signedIn,
                  let context = NotificationService.consumePendingOpenedNotificationContext() else {
                return
            }

            handleOpenedNotification(context)
        }
    }

    @ViewBuilder
    private var selectedContent: some View {
        switch selectedTab {
        case .find:
            EventDiscoveryListView(
                resetTrigger: findResetTrigger,
                requestedEventDetailID: requestedEventDetailID,
                onRequestedEventDetailOpened: {
                    requestedEventDetailID = nil
                },
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
            ChatView(
                requestedChatEventID: requestedChatEventID,
                onRequestedChatEventOpened: {
                    requestedChatEventID = nil
                }
            ) {
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

    private func handleOpenedNotification(_ context: NotificationService.OpenedNotificationContext) {
        if context.rawNotificationType == Constants.Chat.messageNotificationType,
           let relatedEventID = context.relatedEventID {
            isShowingProfile = false
            isShowingNotifications = false
            selectedJoinRequestNotificationID = nil
            requestedEventDetailID = nil
            requestedChatEventID = relatedEventID
            selectedTab = .chat
            return
        }

        if (context.notificationType == .approveJoinRequest || context.notificationType == .rejectJoinRequest),
           let relatedEventID = context.relatedEventID {
            isShowingProfile = false
            isShowingNotifications = false
            selectedJoinRequestNotificationID = nil
            requestedChatEventID = nil
            requestedEventDetailID = relatedEventID
            selectedTab = .find
            return
        }

        selectedJoinRequestNotificationID = context.notificationType == .eventJoined
            ? context.notificationID
            : nil
        requestedChatEventID = nil
        requestedEventDetailID = nil
        isShowingProfile = false
        isShowingNotifications = true
    }

}

struct MainTabBarHiddenPreferenceKey: PreferenceKey {
    static let defaultValue = false

    static func reduce(value: inout Bool, nextValue: () -> Bool) {
        value = value || nextValue()
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
        return "\(iconBaseName)_\(isSelected ? "filled" : "lined")"
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
    let hasUnreadMyEvents: Bool
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
                                .fill(MainTabBarStyle.badge)
                                .frame(width: 11, height: 11)
                                .offset(x: -7, y: 6)
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
            return hasUnreadMyEvents
        case .chat:
            return hasUnreadChats
        }
    }
}

private enum MainTabBarStyle {
    static let background = Color(red: 0.57, green: 0.66, blue: 0.34)
    static let badge = Color(red: 0.20, green: 0.36, blue: 0.12)
    static let shadow = Color(red: 0.16, green: 0.27, blue: 0.18).opacity(0.16)
}
