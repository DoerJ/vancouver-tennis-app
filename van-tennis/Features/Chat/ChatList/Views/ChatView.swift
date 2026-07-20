import SwiftUI

struct ChatView: View {
    @EnvironmentObject private var appState: AppState
    @StateObject private var viewModel = ChatListViewModel()

    let onOpenProfile: () -> Void

    init(onOpenProfile: @escaping () -> Void = {}) {
        self.onOpenProfile = onOpenProfile
    }

    var body: some View {
        NavigationStack {
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
                                NavigationLink {
                                    ChatRoomView(event: preview.event)
                                } label: {
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
            }
            .onChange(of: appState.userProfile?.hostedEvents) { _, _ in
                Task {
                    await viewModel.loadEvents(appState: appState)
                }
            }
            .onChange(of: appState.userProfile?.participatedEvents) { _, _ in
                Task {
                    await viewModel.loadEvents(appState: appState)
                }
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
            description: AppContent.string("chat.emptyList.description")
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
                unreadCount: appState.unreadChatCount(eventID: event.id)
            )
        }
        .sorted { $0.latestMessage.sentAt > $1.latestMessage.sentAt }
    }
}

private struct ChatConversationPreview: Identifiable {
    let event: TennisEvent
    let latestMessage: ChatRoomMessage
    let unreadCount: Int

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
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Text(preview.eventDisplayName)
                    .font(.headline)
                    .foregroundStyle(RallyDiscoverStyle.ink)
                    .lineLimit(1)

                Spacer(minLength: 8)

                if preview.unreadCount > 0 {
                    Text(
                        preview.unreadCount > Constants.Chat.maximumDisplayedUnreadCount
                            ? Constants.Chat.maximumDisplayedUnreadText
                            : "\(preview.unreadCount)"
                    )
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(Color.red, in: Capsule())
                        .accessibilityLabel(AppContent.string("chat.unreadAccessibility", preview.unreadCount))
                }

                Text(DateFormattingHelper.shortDateTimeString(from: preview.latestMessage.sentAt))
                    .font(.caption)
                    .foregroundStyle(RallyDiscoverStyle.mutedText)
            }

            Text(latestMessagePreviewText)
                .font(.subheadline)
                .foregroundStyle(RallyDiscoverStyle.mutedText)
                .lineLimit(2)
        }
        .padding(.top, 8)
        .padding(.bottom, 16)
        .background(Color.white)
        .overlay(alignment: .bottom) {
            RallyDivider(width: 301)
        }
        .accessibilityElement(children: .combine)
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
