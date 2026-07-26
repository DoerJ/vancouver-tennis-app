import SwiftUI

struct ChatRoomView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var appState: AppState
    @StateObject private var viewModel = ChatRoomViewModel()
    @FocusState private var isComposerFocused: Bool

    let event: TennisEvent

    var body: some View {
        VStack(spacing: 0) {
            chatHeader

            RallyDivider(horizontalPadding: 46)

            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 36) {
                        if viewModel.isLoading && viewModel.messages.isEmpty {
                            ProgressView(AppContent.string("chat.loadingMessages"))
                                .rallyLoadingStatusStyle()
                                .padding(.top, 80)
                        } else if viewModel.messages.isEmpty {
                            emptyState
                                .padding(.top, 80)
                        } else {
                            ForEach(viewModel.messages) { message in
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
                .onChange(of: viewModel.messages) { _, messages in
                    scrollToLatestMessage(with: proxy, messages: messages)
                }
                .onChange(of: isComposerFocused) { _, isFocused in
                    guard isFocused else {
                        return
                    }

                    Task {
                        try? await Task.sleep(nanoseconds: 250_000_000)
                        await MainActor.run {
                            scrollToLatestMessage(with: proxy, messages: viewModel.messages)
                        }
                    }
                }
            }

            RallyDivider(horizontalPadding: 46)

            if let errorMessage = viewModel.errorMessage {
                Text(errorMessage)
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(RallyDiscoverStyle.redBadge)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 22)
                    .padding(.top, 8)
            }

            if viewModel.draftMessageExceedsLimit {
                Text(AppContent.string("chat.messageLengthError", Constants.Chat.maximumMessageLength))
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(RallyDiscoverStyle.redBadge)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 22)
                    .padding(.top, viewModel.errorMessage == nil ? 8 : 2)
            }

            composer
        }
        .background(Color.white)
        .ignoresSafeArea(.container, edges: .bottom)
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .task {
            await viewModel.loadMessages(eventID: event.id, appState: appState)
        }
        .onChange(of: appState.chatMessagesRevision) { _, _ in
            viewModel.syncMessagesFromCache(eventID: event.id, appState: appState)
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
                RallyCircularBackButton {
                    dismiss()
                }

                Spacer()
            }
        }
        .padding(.horizontal, 25)
        .padding(.top, 42)
        .padding(.bottom, 17)
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image("chat_lined")
                .resizable()
                .renderingMode(.template)
                .scaledToFit()
                .foregroundStyle(RallyDiscoverStyle.mutedText)
                .frame(width: 34, height: 34)
                .accessibilityHidden(true)

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
                text: $viewModel.draftMessage,
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
                    let didSend = await viewModel.sendMessage(eventID: event.id, appState: appState)
                    if didSend {
                        isComposerFocused = false
                    }
                }
            } label: {
                if viewModel.isSending {
                    ProgressView()
                        .tint(.white)
                        .frame(width: 86, height: 40)
                } else {
                    Text(AppContent.string("chat.send"))
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 86, height: 40)
                }
            }
            .background(RallyDiscoverStyle.accentGreen, in: Capsule())
            .shadow(color: RallyDiscoverStyle.shadow, radius: 18, x: 0, y: 8)
            .disabled(viewModel.isSending || viewModel.trimmedDraftMessage.isEmpty || viewModel.draftMessageExceedsLimit)
            .opacity(viewModel.isSending || viewModel.trimmedDraftMessage.isEmpty || viewModel.draftMessageExceedsLimit ? 0.55 : 1)
        }
        .padding(.horizontal, 23)
        .padding(.top, 30)
        .padding(.bottom, 30)
    }

    @ViewBuilder
    private func messageRow(_ message: ChatRoomMessage) -> some View {
        if Constants.Chat.isSystemMessage(message.body) {
            systemMessageRow(message)
        } else {
            let isCurrentUser = message.senderID == appState.userProfile?.id

            VStack(alignment: isCurrentUser ? .trailing : .leading, spacing: 8) {
                Text(message.senderDisplayName)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Color.black.opacity(0.6))
                    .padding(.horizontal, 5)

                messageBubble(message, isCurrentUser: isCurrentUser)

                Text(DateFormattingHelper.timeString(from: message.sentAt))
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Color.black.opacity(0.6))
                    .padding(.horizontal, 5)
            }
            .frame(maxWidth: .infinity, alignment: isCurrentUser ? .trailing : .leading)
        }
    }

    private func systemMessageRow(_ message: ChatRoomMessage) -> some View {
        Text(systemMessageDisplayText(message))
            .font(.caption)
            .foregroundStyle(RallyDiscoverStyle.mutedText)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(RallyDiscoverStyle.surface)
            .clipShape(Capsule())
            .frame(maxWidth: .infinity, alignment: .center)
    }

    private func systemMessageDisplayText(_ message: ChatRoomMessage) -> String {
        let displayBody = Constants.Chat.displayBody(for: message.body)

        guard message.senderID == appState.userProfile?.id else {
            return displayBody
        }

        if displayBody.hasSuffix(" has joined the room.") {
            return "You joined the room."
        }

        if displayBody.hasSuffix(" has left the room.") {
            return "You left the room."
        }

        return displayBody
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
                .frame(maxWidth: 214, alignment: .leading)
        }
        .frame(maxWidth: 246, alignment: isCurrentUser ? .trailing : .leading)
    }

    private func bubbleText(_ message: ChatRoomMessage, isCurrentUser: Bool) -> some View {
        Text(Constants.Chat.displayBody(for: message.body))
            .font(.system(size: 15, weight: .medium))
            .lineSpacing(2)
            .foregroundStyle(isCurrentUser ? .white : Color.black.opacity(0.5))
            .multilineTextAlignment(.leading)
            .padding(.horizontal, 18)
            .padding(.vertical, 12)
            .background(
                isCurrentUser
                    ? RallyDiscoverStyle.accentGreen
                    : RallyDiscoverStyle.surface,
                in: Capsule()
            )
            .shadow(color: RallyDiscoverStyle.shadow.opacity(isCurrentUser ? 1 : 0.95), radius: 18, x: 0, y: 8)
            .shadow(color: Color.black.opacity(isCurrentUser ? 0 : 0.05), radius: 6, x: 0, y: 2)
    }

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
                participants: [],
                createdAt: nil,
                updatedAt: nil
            )
        )
        .environmentObject(AppState())
    }
}
