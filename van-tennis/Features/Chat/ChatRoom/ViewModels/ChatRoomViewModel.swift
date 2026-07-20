import Combine
import Foundation

@MainActor
final class ChatRoomViewModel: ObservableObject {
    @Published private(set) var messages: [ChatRoomMessage] = []
    @Published var draftMessage = ""
    @Published private(set) var isLoading = false
    @Published private(set) var isSending = false
    @Published private(set) var errorMessage: String?

    private let chatMessageService = ChatMessageService()
    private let profileService = ProfileService()

    var trimmedDraftMessage: String {
        draftMessage.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var draftMessageExceedsLimit: Bool {
        draftMessage.count > Constants.Chat.maximumMessageLength
    }

    func loadMessagesIfNeeded(eventID: UUID, appState: AppState) async {
        // Load chat messages from cache first.
        if syncMessagesFromCache(eventID: eventID, appState: appState) {
            return
        }

        await loadMessages(eventID: eventID, appState: appState)
    }

    func loadMessages(eventID: UUID, appState: AppState) async {
        isLoading = true
        errorMessage = nil
        defer {
            isLoading = false
        }

        do {
            let chatMessages = try await chatMessageService.fetchMessages(eventID: eventID)
            let senderIDs = Array(Set(chatMessages.map(\.senderID)))
            let profilesByID = try await profileService.fetchProfiles(userIDs: senderIDs)
                .reduce(into: [UUID: UserProfile]()) { profiles, profile in
                    profiles[profile.id] = profile
                }

            let roomMessages = chatMessages.map { message in
                ChatRoomMessage(
                    id: message.id,
                    senderID: message.senderID,
                    senderDisplayName: profilesByID[message.senderID]?.displayName ?? AppContent.string("chat.unknownPlayer"),
                    body: message.body,
                    sentAt: message.createdAt
                )
            }

            messages = roomMessages
            appState.updateCachedChatMessages(roomMessages, eventID: eventID)
        } catch is CancellationError {
            // Expected if the room disappears while messages are loading.
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    @discardableResult
    func sendMessage(eventID: UUID, appState: AppState) async -> Bool {
        guard !isSending else {
            return false
        }

        let trimmedMessage = trimmedDraftMessage

        guard !trimmedMessage.isEmpty else {
            return false
        }

        guard !draftMessageExceedsLimit else {
            errorMessage = AppContent.string("chat.messageLengthError", Constants.Chat.maximumMessageLength)
            return false
        }

        guard let currentUser = appState.userProfile else {
            errorMessage = AppContent.string("errors.noAuthenticatedUser")
            return false
        }

        isSending = true
        errorMessage = nil
        defer {
            isSending = false
        }

        do {
            let createdMessage = try await chatMessageService.createMessage(
                NewChatMessage(
                    eventID: eventID,
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

            appendMessage(message, eventID: eventID, appState: appState)
            draftMessage = ""
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    @discardableResult
    func syncMessagesFromCache(eventID: UUID, appState: AppState) -> Bool {
        guard let cachedMessages = appState.cachedChatMessages(eventID: eventID) else {
            return false
        }

        messages = cachedMessages
        print("ChatRoomViewModel: synced \(messages.count) cached messages for event \(eventID).")
        return true
    }

    private func appendMessage(_ message: ChatRoomMessage, eventID: UUID, appState: AppState) {
        if !messages.contains(where: { $0.id == message.id }) {
            messages.append(message)
            messages.sort { $0.sentAt < $1.sentAt }
        }

        appState.appendCachedChatMessage(message, eventID: eventID)
        print("ChatRoomViewModel: cache revision \(appState.chatMessagesRevision), visible messages \(messages.count).")
    }
}
