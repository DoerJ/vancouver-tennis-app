import SwiftUI

struct ChatView: View {
    @EnvironmentObject private var appState: AppState
    @State private var events: [TennisEvent] = []
    @State private var isLoading = false
    @State private var errorMessage: String?

    let onOpenProfile: () -> Void
    private let eventService = EventService()

    init(onOpenProfile: @escaping () -> Void = {}) {
        self.onOpenProfile = onOpenProfile
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.white
                    .ignoresSafeArea()

                if isLoading {
                    ProgressView(AppContent.string("chat.loadingList"))
                } else if let errorMessage {
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
                await loadEvents()
            }
            .onChange(of: appState.userProfile?.hostedEvents) { _, _ in
                Task {
                    await loadEvents()
                }
            }
            .onChange(of: appState.userProfile?.participatedEvents) { _, _ in
                Task {
                    await loadEvents()
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
        VStack(spacing: 10) {
            Image("chat_lined")
                .resizable()
                .renderingMode(.template)
                .scaledToFit()
                .foregroundStyle(RallyDiscoverStyle.ink)
                .frame(width: 34, height: 34)
                .accessibilityHidden(true)

            Text(AppContent.string("chat.emptyList.title"))
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(RallyDiscoverStyle.ink)
                .multilineTextAlignment(.center)

            Text(AppContent.string("chat.emptyList.description"))
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(RallyDiscoverStyle.mutedText)
                .multilineTextAlignment(.center)
                .lineSpacing(2)
        }
        .padding(.horizontal, 28)
    }

    private var conversationPreviews: [ChatConversationPreview] {
        events.compactMap { event in
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

    private func loadEvents() async {
        guard let profile = appState.userProfile else {
            events = []
            isLoading = false
            errorMessage = nil
            return
        }

        let eventIDs = Array(Set(profile.hostedEvents + profile.participatedEvents))
        guard !eventIDs.isEmpty else {
            events = []
            isLoading = false
            errorMessage = nil
            return
        }

        isLoading = events.isEmpty
        errorMessage = nil

        do {
            events = appState.cachedEvents(ids: eventIDs)
                .sorted { $0.startTime < $1.startTime }

            let missingEventIDs = appState.missingCachedEventIDs(ids: eventIDs)
            if !missingEventIDs.isEmpty {
                let fetchedEvents = try await eventService.fetchEvents(ids: missingEventIDs)
                appState.updateCachedEvents(fetchedEvents)

                events = appState.cachedEvents(ids: eventIDs)
                    .sorted { $0.startTime < $1.startTime }
            }

            let uncachedMessageEventIDs = events
                .map(\.id)
                .filter { appState.cachedChatMessages(eventID: $0) == nil }

            if !uncachedMessageEventIDs.isEmpty {
                await appState.preloadCachedChatMessages(eventIDs: uncachedMessageEventIDs)
            }
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
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
        "\(event.court.displayName) (\(Self.eventDateFormatter.string(from: event.startTime)))"
    }

    private static let eventDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter
    }()
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

                Text(Self.timestampFormatter.string(from: preview.latestMessage.sentAt))
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
            Rectangle()
                .fill(Color.black.opacity(0.1))
                .frame(width: 301, height: 1)
                .frame(maxWidth: .infinity, alignment: .center)
        }
        .accessibilityElement(children: .combine)
    }

    private static let timestampFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.doesRelativeDateFormatting = true
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter
    }()

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
