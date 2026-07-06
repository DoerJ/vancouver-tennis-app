import SwiftUI

struct ChatRoomView: View {
    @EnvironmentObject private var appState: AppState
    @State private var messages: [ChatRoomMessage] = []
    @State private var draftMessage = ""
    @State private var isLoading = false
    @State private var isSending = false
    @State private var errorMessage: String?

    let event: TennisEvent
    private let chatMessageService = ChatMessageService()
    private let profileService = ProfileService()

    var body: some View {
        VStack(spacing: 0) {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 12) {
                        if isLoading && messages.isEmpty {
                            ProgressView(AppContent.string("chat.loadingMessages"))
                                .padding(.top, 80)
                        } else if messages.isEmpty {
                            ContentUnavailableView(
                                AppContent.string("chat.emptyRoom.title"),
                                systemImage: "message",
                                description: Text(AppContent.string("chat.emptyRoom.description"))
                            )
                            .padding(.top, 80)
                        } else {
                            ForEach(messages) { message in
                                messageRow(message)
                                    .id(message.id)
                            }
                        }
                    }
                    .padding()
                    .frame(maxWidth: .infinity)
                }
                .onChange(of: messages) { _, messages in
                    guard let lastMessageID = messages.last?.id else {
                        return
                    }

                    withAnimation {
                        proxy.scrollTo(lastMessageID, anchor: .bottom)
                    }
                }
            }

            Divider()

            if let errorMessage {
                Text(errorMessage)
                    .font(.footnote)
                    .foregroundStyle(.red)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal)
                    .padding(.top, 8)
            }

            if draftMessageExceedsLimit {
                Text(AppContent.string("chat.messageLengthError", Constants.Chat.maximumMessageLength))
                    .font(.footnote)
                    .foregroundStyle(.red)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal)
                    .padding(.top, errorMessage == nil ? 8 : 2)
            }

            HStack(alignment: .bottom, spacing: 8) {
                TextField(AppContent.string("chat.messagePlaceholder"), text: $draftMessage, axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                    .lineLimit(1...4)

                Button(isSending ? AppContent.string("chat.sending") : AppContent.string("chat.send")) {
                    Task {
                        await sendMessage()
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(isSending || trimmedDraftMessage.isEmpty || draftMessageExceedsLimit)
            }
            .padding()
        }
        .navigationTitle(event.court.displayName)
        .navigationBarTitleDisplayMode(.inline)
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

            VStack(alignment: isCurrentUser ? .trailing : .leading, spacing: 4) {
                Text(message.senderDisplayName)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text(Constants.Chat.displayBody(for: message.body))
                    .font(.body)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .foregroundStyle(isCurrentUser ? .white : .primary)
                    .background(isCurrentUser ? Color.accentColor : Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 8))

                Text(Self.sentTimeFormatter.string(from: message.sentAt))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: isCurrentUser ? .trailing : .leading)
        }
    }

    private func systemMessageRow(_ message: ChatRoomMessage) -> some View {
        Text(Constants.Chat.displayBody(for: message.body))
            .font(.caption)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color(.tertiarySystemGroupedBackground))
            .clipShape(Capsule())
            .frame(maxWidth: .infinity, alignment: .center)
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
