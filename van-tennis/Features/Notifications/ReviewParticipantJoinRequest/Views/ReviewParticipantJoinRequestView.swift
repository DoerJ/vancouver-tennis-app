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
                Section("Player") {
                    LabeledContent("Name", value: profile.displayName)

                    if let skillLevel = profile.skillLevel {
                        LabeledContent("Skill Level", value: skillLevel.rawValue)
                    }

                    if let gender = profile.gender {
                        LabeledContent("Gender", value: gender.displayName)
                    }

                    if let email = profile.email {
                        LabeledContent("Email", value: email)
                    }
                }
            }

            Section("Request") {
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
                        Text("Approve")
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
                        Text("Disapprove")
                    }
                }
                .disabled(actionButtonsAreDisabled)
                .buttonStyle(.bordered)
            }
        }
        .navigationTitle("Join Request")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await viewModel.loadSenderProfile(senderID: notification.sender)
        }
    }

    private var actionButtonsAreDisabled: Bool {
        viewModel.isApproving || viewModel.isDisapproving || viewModel.hasCompletedReview
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
