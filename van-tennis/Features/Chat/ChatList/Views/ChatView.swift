import SwiftUI

struct ChatView: View {
    @EnvironmentObject private var appState: AppState
    @StateObject private var viewModel = ChatListViewModel()
    @State private var navigationPath: [TennisEvent] = []

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
                await viewModel.loadEvents(appState: appState)
                await openRequestedChatEventIfNeeded()
            }
            .onChange(of: appState.userProfile?.hostedEvents) { _, _ in
                Task {
                    await viewModel.loadEvents(appState: appState)
                    await openRequestedChatEventIfNeeded()
                }
            }
            .onChange(of: appState.userProfile?.participatedEvents) { _, _ in
                Task {
                    await viewModel.loadEvents(appState: appState)
                    await openRequestedChatEventIfNeeded()
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
                Button {
                    onOpenProfile()
                } label: {
                    Image("profile")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 40, height: 40)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(AppContent.string("common.profile"))

                Spacer()
            }

            Text(AppContent.string("chat.title"))
                .font(.system(size: 32, weight: .bold))
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

            guard let latestMessage = appState.cachedChatMessages(eventID: event.id)?.last else {
                return nil
            }

            return ChatConversationPreview(
                event: event,
                latestMessage: latestMessage,
                hasUnreadMessages: appState.unreadChatCount(eventID: event.id) > 0
            )
        }
        .sorted { $0.latestMessage.sentAt > $1.latestMessage.sentAt }
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
    let latestMessage: ChatRoomMessage
    let hasUnreadMessages: Bool

    var id: UUID {
        event.id
    }

    var eventDisplayName: String {
        "\(event.court.displayName) (\(DateFormattingHelper.eventDateString(from: event.startTime)))"
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
                        .font(.headline)
                        .foregroundStyle(RallyDiscoverStyle.ink)
                        .lineLimit(1)

                    Spacer(minLength: 8)

                    Text(DateFormattingHelper.shortDateTimeString(from: preview.latestMessage.sentAt))
                        .font(.caption)
                        .foregroundStyle(RallyDiscoverStyle.mutedText)
                }

                Text(latestMessagePreviewText)
                    .font(.subheadline)
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
        let body = Constants.Chat.displayBody(for: preview.latestMessage.body)

        if Constants.Chat.isSystemMessage(preview.latestMessage.body) {
            return body
        }

        return "\(preview.latestMessage.senderDisplayName): \(body)"
    }
}

#Preview {
    ChatView()
        .environmentObject(AppState())
}
