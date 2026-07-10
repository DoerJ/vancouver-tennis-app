import SwiftUI

struct ChatRoomView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var appState: AppState
    @State private var messages: [ChatRoomMessage] = []
    @State private var draftMessage = ""
    @State private var isLoading = false
    @State private var isSending = false
    @State private var errorMessage: String?
    @FocusState private var isComposerFocused: Bool

    let event: TennisEvent
    private let chatMessageService = ChatMessageService()
    private let profileService = ProfileService()

    var body: some View {
        VStack(spacing: 0) {
            chatHeader

            Rectangle()
                .fill(Color.black.opacity(0.1))
                .frame(height: 1)
                .padding(.horizontal, 46)

            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 36) {
                        if isLoading && messages.isEmpty {
                            ProgressView(AppContent.string("chat.loadingMessages"))
                                .padding(.top, 80)
                        } else if messages.isEmpty {
                            emptyState
                                .padding(.top, 80)
                        } else {
                            ForEach(messages) { message in
                                messageRow(message)
                                    .id(message.id)
                            }
                        }
                    }
                    .padding(.horizontal, 18)
                    .padding(.top, 38)
                    .padding(.bottom, 28)
                    .frame(maxWidth: .infinity)
                }
                .scrollDismissesKeyboard(.interactively)
                .onChange(of: messages) { _, messages in
                    scrollToLatestMessage(with: proxy, messages: messages)
                }
                .onChange(of: isComposerFocused) { _, isFocused in
                    guard isFocused else {
                        return
                    }

                    Task {
                        try? await Task.sleep(nanoseconds: 250_000_000)
                        await MainActor.run {
                            scrollToLatestMessage(with: proxy, messages: messages)
                        }
                    }
                }
            }

            Rectangle()
                .fill(Color.black.opacity(0.1))
                .frame(height: 1)
                .padding(.horizontal, 46)

            if let errorMessage {
                Text(errorMessage)
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(RallyDiscoverStyle.redBadge)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 22)
                    .padding(.top, 8)
            }

            if draftMessageExceedsLimit {
                Text(AppContent.string("chat.messageLengthError", Constants.Chat.maximumMessageLength))
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(RallyDiscoverStyle.redBadge)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 22)
                    .padding(.top, errorMessage == nil ? 8 : 2)
            }

            composer
        }
        .background(Color.white)
        .ignoresSafeArea(.container, edges: .bottom)
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .task {
            await loadMessagesIfNeeded()
        }
        .onChange(of: appState.chatMessagesRevision) { _, _ in
            syncMessagesFromCache()
        }
        .onAppear {
            appState.openChat(eventID: event.id)
        }
        .onDisappear {
            appState.closeChat(eventID: event.id)
        }
        .preference(key: MainTabBarHiddenPreferenceKey.self, value: true)
    }

    private var chatHeader: some View {
        ZStack {
            Text(event.court.displayName)
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(RallyDiscoverStyle.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.78)
                .padding(.horizontal, 70)

            HStack {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 24, weight: .medium))
                        .foregroundStyle(RallyDiscoverStyle.ink)
                        .frame(width: 44, height: 44)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(AppContent.string("common.back"))

                Spacer()
            }
        }
        .padding(.horizontal, 25)
        .padding(.top, 42)
        .padding(.bottom, 17)
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "message")
                .font(.system(size: 28))
                .foregroundStyle(RallyDiscoverStyle.mutedText)

            Text(AppContent.string("chat.emptyRoom.title"))
                .font(.system(size: 15, weight: .semibold))
                .lineSpacing(2)
                .foregroundStyle(Color.black.opacity(0.5))

            Text(AppContent.string("chat.emptyRoom.description"))
                .font(.system(size: 13, weight: .medium))
                .lineSpacing(2)
                .foregroundStyle(Color.black.opacity(0.5))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }

    private var composer: some View {
        HStack(alignment: .bottom, spacing: 16) {
            TextField(
                text: $draftMessage,
                axis: .vertical
            ) {
                Text(AppContent.string("chat.messagePlaceholder"))
                    .foregroundStyle(Color.black.opacity(0.3))
            }
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(RallyDiscoverStyle.ink)
                .lineLimit(1...4)
                .focused($isComposerFocused)
                .padding(.horizontal, 18)
                .padding(.vertical, 14)
                .background(RallyDiscoverStyle.surface)
                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                .shadow(color: RallyDiscoverStyle.shadow.opacity(0.95), radius: 18, x: 0, y: 8)
                .shadow(color: Color.black.opacity(0.05), radius: 6, x: 0, y: 2)

            Button {
                Task {
                    await sendMessage()
                }
            } label: {
                if isSending {
                    ProgressView()
                        .tint(.white)
                        .frame(width: 77, height: 35)
                } else {
                    Text(AppContent.string("chat.send"))
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 77, height: 35)
                }
            }
            .background(RallyDiscoverStyle.accentGreen, in: Capsule())
            .shadow(color: RallyDiscoverStyle.shadow, radius: 18, x: 0, y: 8)
            .disabled(isSending || trimmedDraftMessage.isEmpty || draftMessageExceedsLimit)
            .opacity(isSending || trimmedDraftMessage.isEmpty || draftMessageExceedsLimit ? 0.55 : 1)
        }
        .padding(.horizontal, 23)
        .padding(.top, 30)
        .padding(.bottom, 30)
    }

    @MainActor
    private func appendMessage(_ message: ChatRoomMessage) {
        if !messages.contains(where: { $0.id == message.id }) {
            messages.append(message)
            messages.sort { $0.sentAt < $1.sentAt }
        }

        appState.appendCachedChatMessage(message, eventID: event.id)
        print("ChatRoomView: cache revision \(appState.chatMessagesRevision), visible messages \(messages.count).")
    }

    @MainActor
    private func syncMessagesFromCache() {
        guard let cachedMessages = appState.cachedChatMessages(eventID: event.id) else {
            return
        }

        messages = cachedMessages
        print("ChatRoomView: synced \(messages.count) cached messages for event \(event.id).")
    }

    @ViewBuilder
    private func messageRow(_ message: ChatRoomMessage) -> some View {
        if Constants.Chat.isSystemMessage(message.body) {
            systemMessageRow(message)
        } else {
            let isCurrentUser = message.senderID == appState.userProfile?.id

            VStack(alignment: isCurrentUser ? .trailing : .leading, spacing: 8) {
                Text(message.senderDisplayName)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Color.black.opacity(0.6))
                    .padding(.horizontal, 5)

                messageBubble(message, isCurrentUser: isCurrentUser)

                Text(Self.sentTimeFormatter.string(from: message.sentAt))
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Color.black.opacity(0.6))
                    .padding(.horizontal, 5)
            }
            .frame(maxWidth: .infinity, alignment: isCurrentUser ? .trailing : .leading)
        }
    }

    private func systemMessageRow(_ message: ChatRoomMessage) -> some View {
        Text(Constants.Chat.displayBody(for: message.body))
            .font(.caption)
            .foregroundStyle(RallyDiscoverStyle.mutedText)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(RallyDiscoverStyle.surface)
            .clipShape(Capsule())
            .frame(maxWidth: .infinity, alignment: .center)
    }

    private func scrollToLatestMessage(with proxy: ScrollViewProxy, messages: [ChatRoomMessage]) {
        guard let lastMessageID = messages.last?.id else {
            return
        }

        withAnimation {
            proxy.scrollTo(lastMessageID, anchor: .bottom)
        }
    }

    private func messageBubble(_ message: ChatRoomMessage, isCurrentUser: Bool) -> some View {
        ViewThatFits(in: .horizontal) {
            bubbleText(message, isCurrentUser: isCurrentUser)
                .fixedSize(horizontal: true, vertical: false)

            bubbleText(message, isCurrentUser: isCurrentUser)
                .frame(maxWidth: 194, alignment: .leading)
        }
        .frame(maxWidth: 226, alignment: isCurrentUser ? .trailing : .leading)
    }

    private func bubbleText(_ message: ChatRoomMessage, isCurrentUser: Bool) -> some View {
        Text(Constants.Chat.displayBody(for: message.body))
            .font(.system(size: isCurrentUser ? 12 : 13, weight: .medium))
            .lineSpacing(2)
            .foregroundStyle(isCurrentUser ? .white : Color.black.opacity(0.5))
            .multilineTextAlignment(.leading)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(
                isCurrentUser
                    ? RallyDiscoverStyle.accentGreen
                    : RallyDiscoverStyle.surface,
                in: Capsule()
            )
            .shadow(color: RallyDiscoverStyle.shadow.opacity(isCurrentUser ? 1 : 0.58), radius: 18, x: 0, y: 8)
    }

    private func loadMessagesIfNeeded() async {
        // Load chat messages from cache first
        if let cachedMessages = appState.cachedChatMessages(eventID: event.id) {
            messages = cachedMessages
            return
        }

        await loadMessages()
    }

    private func loadMessages() async {
        isLoading = true
        errorMessage = nil

        do {
            let chatMessages = try await chatMessageService.fetchMessages(eventID: event.id)
            let senderIDs = Array(Set(chatMessages.map(\.senderID)))
            let profilesByID = try await profileService.fetchProfiles(userIDs: senderIDs)
                .reduce(into: [UUID: UserProfile]()) { profiles, profile in
                    profiles[profile.id] = profile
                }

            messages = chatMessages.map { message in
                ChatRoomMessage(
                    id: message.id,
                    senderID: message.senderID,
                    senderDisplayName: profilesByID[message.senderID]?.displayName ?? AppContent.string("chat.unknownPlayer"),
                    body: message.body,
                    sentAt: message.createdAt
                )
            }
            appState.updateCachedChatMessages(messages, eventID: event.id)
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    private func sendMessage() async {
        let trimmedMessage = trimmedDraftMessage

        guard !trimmedMessage.isEmpty else {
            return
        }

        guard !draftMessageExceedsLimit else {
            errorMessage = AppContent.string("chat.messageLengthError", Constants.Chat.maximumMessageLength)
            return
        }

        guard let currentUser = appState.userProfile else {
            errorMessage = AppContent.string("errors.noAuthenticatedUser")
            return
        }

        isSending = true
        errorMessage = nil

        do {
            let createdMessage = try await chatMessageService.createMessage(
                NewChatMessage(
                    eventID: event.id,
                    senderID: currentUser.id,
                    body: trimmedMessage
                )
            )

            let message = ChatRoomMessage(
                id: createdMessage.id,
                senderID: createdMessage.senderID,
                senderDisplayName: currentUser.displayName,
                body: createdMessage.body,
                sentAt: createdMessage.createdAt
            )

            await appendMessage(message)
            draftMessage = ""
            isComposerFocused = false
        } catch {
            errorMessage = error.localizedDescription
        }

        isSending = false
    }

    private var trimmedDraftMessage: String {
        draftMessage.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var draftMessageExceedsLimit: Bool {
        draftMessage.count > Constants.Chat.maximumMessageLength
    }

    private static let sentTimeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return formatter
    }()
}

#Preview {
    NavigationStack {
        ChatRoomView(
            event: TennisEvent(
                id: UUID(),
                hostID: UUID(),
                startTime: Date(),
                endTime: Calendar.current.date(byAdding: .hour, value: 2, to: Date()) ?? Date(),
                eventType: .practice,
                maxPlayers: 4,
                city: .burnaby,
                court: .bcitCourt,
                skillLevel: .three,
                status: .upcoming,
                participants: [],
                createdAt: nil,
                updatedAt: nil
            )
        )
        .environmentObject(AppState())
    }
}
