import SwiftUI

struct ChatView: View {
    @EnvironmentObject private var appState: AppState
    @StateObject private var viewModel = ChatListViewModel()
    @State private var navigationPath: [TennisEvent] = []
    @State private var hasLoadedInitialChats = false

    let requestedChatEventID: UUID?
    let onRequestedChatEventOpened: () -> Void
    let onOpenProfile: () -> Void

    init(
        requestedChatEventID: UUID? = nil,
        onRequestedChatEventOpened: @escaping () -> Void = {},
        onOpenProfile: @escaping () -> Void = {}
    ) {
        self.requestedChatEventID = requestedChatEventID
        self.onRequestedChatEventOpened = onRequestedChatEventOpened
        self.onOpenProfile = onOpenProfile
    }

    var body: some View {
        NavigationStack(path: $navigationPath) {
            ZStack {
                Color.white
                    .ignoresSafeArea()

                if viewModel.isLoading {
                    ProgressView(AppContent.string("chat.loadingList"))
                        .rallyLoadingStatusStyle()
                } else if let errorMessage = viewModel.errorMessage {
                    ContentUnavailableView(
                        AppContent.string("chat.unableToLoad"),
                        systemImage: "exclamationmark.triangle",
                        description: Text(errorMessage)
                    )
                } else {
                    VStack(spacing: 0) {
                        chatHeader
                            .padding(.horizontal, 28)
                            .padding(.top, 18)

                        if conversationPreviews.isEmpty {
                            ScrollView {
                                emptyConversationView
                                    .frame(maxWidth: .infinity)
                                    .padding(.top, 80)
                            }
                            .padding(.top, 48)
                        } else {
                            List(conversationPreviews) { preview in
                                NavigationLink(value: preview.event) {
                                    ChatConversationCard(preview: preview)
                                }
                                .listRowBackground(Color.white)
                                .listRowSeparator(.hidden)
                            }
                            .listStyle(.plain)
                            .scrollContentBackground(.hidden)
                            .background(Color.white)
                            .padding(.top, 34)
                        }
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar(.hidden, for: .navigationBar)
            .task {
                appState.openChatList()
                // When enter chat list view, always refresh the chat list from Supabase to ensure the latest events are displayed.
                // This is to handle the case where the user turned off APNs
                await loadChats(refreshFromSupabase: true)
                hasLoadedInitialChats = true
            }
            .onAppear {
                guard hasLoadedInitialChats else {
                    return
                }

                Task {
                    appState.openChatList()
                    await loadChats(refreshFromSupabase: true)
                }
            }
            .onChange(of: appState.userProfile?.hostedEvents) { _, _ in
                Task {
                    await loadChats(refreshFromSupabase: false)
                }
            }
            .onChange(of: appState.userProfile?.participatedEvents) { _, _ in
                Task {
                    await loadChats(refreshFromSupabase: false)
                }
            }
            .onChange(of: appState.chatMessagesRevision) { _, _ in
                Task {
                    await loadChats(refreshFromSupabase: false)
                }
            }
            .onChange(of: requestedChatEventID) { _, _ in
                Task {
                    await openRequestedChatEventIfNeeded()
                }
            }
            .navigationDestination(for: TennisEvent.self) { event in
                ChatRoomView(event: event)
            }
        }
    }

    private var chatHeader: some View {
        VStack(alignment: .leading, spacing: 34) {
            HStack(alignment: .center) {
                ProfileAvatarHeaderButton(avatarURL: appState.userProfile?.avatarURL) {
                    onOpenProfile()
                }

                LanguageMenuButton()
                    .padding(.leading, 8)

                Spacer()
            }

            Text(AppContent.string("chat.title"))
                .font(.rally(size: 32, weight: .bold))
                .foregroundStyle(RallyDiscoverStyle.ink)
        }
    }

    private var emptyConversationView: some View {
        RallyEmptyState(
            iconName: "chat_lined",
            title: AppContent.string("chat.emptyList.title"),
            description: AppContent.string("chat.emptyList.description"),
            titleFontSize: 17,
            descriptionFontSize: 15
        )
    }

    private var conversationPreviews: [ChatConversationPreview] {
        viewModel.events.compactMap { event in
            guard event.endTime > Date() else {
                return nil
            }

            return ChatConversationPreview(
                event: event,
                latestMessage: appState.cachedChatMessages(eventID: event.id)?.last,
                hasUnreadMessages: appState.hasUnreadChatMessages(eventID: event.id),
                currentUserID: appState.userProfile?.id
            )
        }
        .sorted { first, second in
            switch (first.latestMessage?.sentAt, second.latestMessage?.sentAt) {
            case let (firstDate?, secondDate?):
                return firstDate > secondDate
            case (_?, nil):
                return true
            case (nil, _?):
                return false
            case (nil, nil):
                return first.event.startTime < second.event.startTime
            }
        }
    }

    private func loadChats(refreshFromSupabase: Bool) async {
        await viewModel.loadEvents(appState: appState, refreshFromSupabase: refreshFromSupabase)
        await openRequestedChatEventIfNeeded()
    }

    private func openRequestedChatEventIfNeeded() async {
        guard let requestedChatEventID else {
            return
        }

        if let event = viewModel.events.first(where: { $0.id == requestedChatEventID }) {
            openChatEvent(event)
            return
        }

        await viewModel.loadEvents(appState: appState)

        if let event = viewModel.events.first(where: { $0.id == requestedChatEventID }) {
            openChatEvent(event)
        }
    }

    private func openChatEvent(_ event: TennisEvent) {
        if navigationPath.last?.id != event.id {
            navigationPath.append(event)
        }

        onRequestedChatEventOpened()
    }
}

private struct ChatConversationPreview: Identifiable {
    let event: TennisEvent
    let latestMessage: ChatRoomMessage?
    let hasUnreadMessages: Bool
    let currentUserID: UUID?

    var id: UUID {
        event.id
    }

    var eventDisplayName: String {
        "\(event.courtDisplayName) (\(DateFormattingHelper.eventDateString(from: event.startTime)))"
    }
}

private struct ChatConversationCard: View {
    let preview: ChatConversationPreview

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            unreadIndicator
                .padding(.top, 14)

            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .firstTextBaseline, spacing: 12) {
                    Text(preview.eventDisplayName)
                        .font(.rally(size: 17, weight: .semibold))
                        .foregroundStyle(RallyDiscoverStyle.ink)
                        .lineLimit(1)

                    Spacer(minLength: 8)

                    if let sentAt = preview.latestMessage?.sentAt {
                        Text(DateFormattingHelper.shortDateTimeString(from: sentAt))
                            .font(.rally(size: 12))
                            .foregroundStyle(RallyDiscoverStyle.mutedText)
                    }
                }

                Text(latestMessagePreviewText)
                    .font(.rally(size: 15))
                    .foregroundStyle(RallyDiscoverStyle.mutedText)
                    .lineLimit(2)
            }
        }
        .padding(.top, 8)
        .padding(.bottom, 16)
        .background(Color.white)
        .overlay(alignment: .bottom) {
            RallyDivider(width: 301)
        }
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private var unreadIndicator: some View {
        if preview.hasUnreadMessages {
            Circle()
                .fill(Color(red: 0.20, green: 0.36, blue: 0.12))
                .frame(width: 8, height: 8)
                .accessibilityHidden(true)
        }
    }

    private var latestMessagePreviewText: String {
        guard let latestMessage = preview.latestMessage else {
            return AppContent.string("chat.emptyRoom.title")
        }

        let body = Constants.Chat.displayBody(for: latestMessage.body)

        if Constants.Chat.isSystemMessage(latestMessage.body) {
            return systemMessagePreviewText(body: body, senderID: latestMessage.senderID)
        }

        return "\(senderDisplayName(for: latestMessage)): \(body)"
    }

    private func senderDisplayName(for message: ChatRoomMessage) -> String {
        message.senderID == preview.currentUserID
            ? AppContent.string("chat.self")
            : message.senderDisplayName
    }

    private func systemMessagePreviewText(body: String, senderID: UUID) -> String {
        guard senderID == preview.currentUserID else {
            return body
        }

        if body.hasSuffix(" has joined the room.") {
            return "You joined the room."
        }

        if body.hasSuffix(" has left the room.") {
            return "You left the room."
        }

        return body
    }
}

#Preview {
    ChatView()
        .environmentObject(AppState())
}
