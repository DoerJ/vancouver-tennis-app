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
            Group {
                if isLoading {
                    ProgressView("Loading chats...")
                } else if let errorMessage {
                    ContentUnavailableView(
                        "Unable to load chats",
                        systemImage: "exclamationmark.triangle",
                        description: Text(errorMessage)
                    )
                } else if conversationPreviews.isEmpty {
                    ContentUnavailableView(
                        "No chats yet",
                        systemImage: "message",
                        description: Text("Your conversations will appear here.")
                    )
                } else {
                    List(conversationPreviews) { preview in
                        NavigationLink {
                            ChatRoomView(event: preview.event)
                        } label: {
                            ChatConversationCard(preview: preview)
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("Chat")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        onOpenProfile()
                    } label: {
                        Image(systemName: "person.circle")
                    }
                    .accessibilityLabel("Profile")
                }
            }
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
        "\(event.eventType.displayName) at \(event.court.displayName)"
    }
}

private struct ChatConversationCard: View {
    let preview: ChatConversationPreview

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Text(preview.eventDisplayName)
                    .font(.headline)
                    .foregroundStyle(.primary)
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
                        .accessibilityLabel("\(preview.unreadCount) unread messages")
                }

                Text(Self.timestampFormatter.string(from: preview.latestMessage.sentAt))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Text("\(preview.latestMessage.senderDisplayName): \(preview.latestMessage.body)")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(2)
        }
        .padding(.vertical, 8)
        .accessibilityElement(children: .combine)
    }

    private static let timestampFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.doesRelativeDateFormatting = true
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter
    }()
}

#Preview {
    ChatView()
        .environmentObject(AppState())
}
