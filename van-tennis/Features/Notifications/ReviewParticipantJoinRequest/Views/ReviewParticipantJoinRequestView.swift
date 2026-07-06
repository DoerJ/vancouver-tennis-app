import SwiftUI

struct ReviewParticipantJoinRequestView: View {
    let notification: NotificationEvent

    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = ReviewParticipantJoinRequestViewModel()

    var body: some View {
        Form {
            if viewModel.isLoading {
                Section {
                    HStack {
                        Spacer()
                        ProgressView()
                        Spacer()
                    }
                }
            }

            if let errorMessage = viewModel.errorMessage {
                Section {
                    Text(errorMessage)
                        .foregroundStyle(.red)
                }
            }

            if let profile = viewModel.senderProfile {
                Section(AppContent.string("joinRequest.player")) {
                    LabeledContent(AppContent.string("joinRequest.name"), value: profile.displayName)

                    if let skillLevel = profile.skillLevel {
                        LabeledContent(AppContent.string("profile.skillLevel"), value: skillLevel.rawValue)
                    }

                    if let gender = profile.gender {
                        LabeledContent(AppContent.string("joinRequest.gender"), value: gender.displayName)
                    }
                }

                if !profile.socialTags.isEmpty {
                    Section(AppContent.string("joinRequest.socialTags")) {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(profile.socialTags, id: \.self) { tag in
                                    Text(tag)
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 6)
                                        .background(.secondary.opacity(0.12), in: Capsule())
                                }
                            }
                            .padding(.vertical, 2)
                        }
                    }
                }
            }

            Section(AppContent.string("joinRequest.request")) {
                Text(notification.body)

                Button {
                    Task {
                        let didCompleteReview = await viewModel.approveJoinRequest(
                            notification: notification,
                            currentUser: appState.userProfile
                        )

                        if didCompleteReview {
                            dismiss()
                        }
                    }
                } label: {
                    if viewModel.isApproving {
                        HStack {
                            Spacer()
                            ProgressView()
                            Spacer()
                        }
                    } else {
                        Text(AppContent.string("joinRequest.approve"))
                    }
                }
                .disabled(actionButtonsAreDisabled)
                .buttonStyle(.borderedProminent)

                Button(role: .destructive) {
                    Task {
                        let didCompleteReview = await viewModel.rejectJoinRequest(
                            notification: notification,
                            currentUser: appState.userProfile
                        )

                        if didCompleteReview {
                            dismiss()
                        }
                    }
                } label: {
                    if viewModel.isDisapproving {
                        HStack {
                            Spacer()
                            ProgressView()
                            Spacer()
                        }
                    } else {
                        Text(AppContent.string("joinRequest.disapprove"))
                    }
                }
                .disabled(actionButtonsAreDisabled)
                .buttonStyle(.bordered)
            }
        }
        .navigationTitle(AppContent.string("joinRequest.title"))
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await viewModel.loadReviewDetails(notification: notification)
        }
    }

    private var actionButtonsAreDisabled: Bool {
        viewModel.isApproving
            || viewModel.isDisapproving
            || viewModel.hasCompletedReview
            || !viewModel.canReviewJoinRequest
    }
}

#Preview {
    NavigationStack {
        ReviewParticipantJoinRequestView(
            notification: NotificationEvent(
                id: UUID(),
                sender: UUID(),
                recipients: [UUID()],
                notificationType: .eventJoined,
                title: "Player wants to join your event",
                body: "Alex wants to join your event at Central Park Court.",
                relatedEventID: UUID(),
                readBy: [],
                createdAt: Date(),
                updatedAt: nil
            )
        )
        .environmentObject(AppState())
    }
}
