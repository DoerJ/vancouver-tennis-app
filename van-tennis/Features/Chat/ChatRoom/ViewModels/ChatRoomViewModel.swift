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

    func loadMessages(eventID: UUID, appState: AppState) async {
        print("ChatDebug: [RoomVM] loadMessages started. eventID=\(eventID).")
        isLoading = true
        errorMessage = nil
        defer {
            isLoading = false
            print("ChatDebug: [RoomVM] loadMessages finished. eventID=\(eventID), visibleCount=\(messages.count), error=\(errorMessage ?? "none").")
        }

        do {
            let chatMessages = try await chatMessageService.fetchMessages(eventID: eventID)
            print("ChatDebug: [RoomVM] fetched messages from Supabase. eventID=\(eventID), fetchedCount=\(chatMessages.count).")
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
                    senderAvatarURL: profilesByID[message.senderID]?.avatarURL,
                    body: message.body,
                    sentAt: message.createdAt
                )
            }

            messages = roomMessages
            appState.updateCachedChatMessages(roomMessages, eventID: eventID)
            print("ChatDebug: [RoomVM] loaded messages into visible list and cache. eventID=\(eventID), visibleCount=\(messages.count).")
        } catch is CancellationError {
            // Expected if the room disappears while messages are loading.
            print("ChatDebug: [RoomVM] loadMessages cancelled. eventID=\(eventID).")
        } catch {
            errorMessage = error.localizedDescription
            print("ChatDebug: [RoomVM] loadMessages failed. eventID=\(eventID), error=\(error.localizedDescription).")
        }
    }

    @discardableResult
    func sendMessage(eventID: UUID, appState: AppState) async -> Bool {
        guard !isSending else {
            print("ChatDebug: [RoomVM] send ignored because another send is in progress. eventID=\(eventID).")
            return false
        }

        let trimmedMessage = trimmedDraftMessage

        guard !trimmedMessage.isEmpty else {
            print("ChatDebug: [RoomVM] send ignored because draft is empty. eventID=\(eventID).")
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
            print("ChatDebug: [RoomVM] sending message insert request. eventID=\(eventID), senderID=\(currentUser.id), bodyLength=\(trimmedMessage.count).")
            let createdMessage = try await chatMessageService.createMessage(
                NewChatMessage(
                    eventID: eventID,
                    senderID: currentUser.id,
                    body: trimmedMessage
                )
            )
            print("ChatDebug: [RoomVM] message insert returned. eventID=\(eventID), messageID=\(createdMessage.id), senderID=\(createdMessage.senderID).")

            let message = ChatRoomMessage(
                id: createdMessage.id,
                senderID: createdMessage.senderID,
                senderDisplayName: currentUser.displayName,
                senderAvatarURL: currentUser.avatarURL,
                body: createdMessage.body,
                sentAt: createdMessage.createdAt
            )

            appendMessage(message, eventID: eventID, appState: appState)
            syncMessagesFromCache(eventID: eventID, appState: appState)
            draftMessage = ""
            print("ChatDebug: [RoomVM] send flow completed. eventID=\(eventID), messageID=\(createdMessage.id), visibleCount=\(messages.count).")
            return true
        } catch {
            errorMessage = error.localizedDescription
            print("ChatDebug: [RoomVM] send failed. eventID=\(eventID), error=\(error.localizedDescription).")
            return false
        }
    }

    @discardableResult
    func syncMessagesFromCache(eventID: UUID, appState: AppState) -> Bool {
        guard let cachedMessages = appState.cachedChatMessages(eventID: eventID) else {
            print("ChatDebug: [RoomVM] cache sync skipped; no cache for event. eventID=\(eventID).")
            return false
        }

        messages = cachedMessages
        print("ChatDebug: [RoomVM] synced messages from cache. eventID=\(eventID), cachedCount=\(cachedMessages.count), visibleCount=\(messages.count).")
        return true
    }

    private func appendMessage(_ message: ChatRoomMessage, eventID: UUID, appState: AppState) {
        if !messages.contains(where: { $0.id == message.id }) {
            messages.append(message)
            messages.sort { $0.sentAt < $1.sentAt }
            print("ChatDebug: [RoomVM] appended message to visible list. eventID=\(eventID), messageID=\(message.id), visibleCount=\(messages.count).")
        } else {
            print("ChatDebug: [RoomVM] visible list already contains message. eventID=\(eventID), messageID=\(message.id), visibleCount=\(messages.count).")
        }

        appState.appendCachedChatMessage(message, eventID: eventID)
        print("ChatDebug: [RoomVM] requested cache append. eventID=\(eventID), messageID=\(message.id), cacheRevision=\(appState.chatMessagesRevision), visibleCount=\(messages.count).")
    }
}
