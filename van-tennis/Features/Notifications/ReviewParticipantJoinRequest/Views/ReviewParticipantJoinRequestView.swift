import SwiftUI

struct ReviewParticipantJoinRequestView: View {
    let notification: NotificationEvent

    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = ReviewParticipantJoinRequestViewModel()

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {
                RallyCircularBackButton {
                    dismiss()
                }
                .padding(.top, 24)

                Text(AppContent.string("joinRequest.title"))
                    .font(.rally(size: 32, weight: .bold))
                    .foregroundStyle(RallyDiscoverStyle.ink)
                    .padding(.top, 28)

                requesterSection
                    .padding(.top, 112)

                requestActions
                    .padding(.top, 42)
            }
            .padding(.horizontal, 29)
            .padding(.bottom, 48)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(Color.white.ignoresSafeArea())
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .task {
            await viewModel.loadReviewDetails(notification: notification)
        }
        .alert(
            AppContent.string("joinRequest.requestCancelledTitle"),
            isPresented: requestCancelledAlertIsPresented
        ) {
            Button(AppContent.string("common.delete")) {
                Task {
                    await deleteCurrentNotificationAndDismiss()
                }
            }
        } message: {
            Text(viewModel.requestCancelledMessage ?? AppContent.string("joinRequest.requestCancelled"))
        }
    }

    @ViewBuilder
    private var requesterSection: some View {
        VStack(alignment: .leading, spacing: 22) {
            if viewModel.isLoading {
                HStack {
                    Spacer()
                    ProgressView()
                    Spacer()
                }
                .frame(minHeight: 180)
            }

            if let errorMessage = viewModel.errorMessage {
                Text(errorMessage)
                    .font(.rally(size: 13, weight: .semibold))
                    .foregroundStyle(RallyDiscoverStyle.redBadge)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            if let profile = viewModel.senderProfile {
                Text(AppContent.string("joinRequest.requestingPlayer"))
                    .font(.rally(size: 16, weight: .bold))
                    .foregroundStyle(RallyDiscoverStyle.ink)
                    .padding(.bottom, 6)

                HStack(spacing: 10) {
                    Text(AppContent.string("joinRequest.nameValue", profile.displayName))
                        .font(.rally(size: 15, weight: .medium))
                        .foregroundStyle(.black)

                    GenderIconView(profile.gender, size: 24)

                    Spacer(minLength: 0)
                }

                if let skillLevel = profile.skillLevel {
                    HStack(spacing: 12) {
                        Text(AppContent.string("joinRequest.skillLevelLabel"))
                            .font(.rally(size: 15, weight: .medium))
                            .foregroundStyle(.black)

                        SkillLevelBadge(skillLevel, width: 71, minWidth: nil, showsShadow: true, shadowRadius: 9)
                    }
                }

                if !profile.socialTags.isEmpty {
                    HStack(alignment: .top, spacing: 12) {
                        Text(GenderDisplayHelper.socialTagsLabel(for: profile.gender))
                            .font(.rally(size: 15, weight: .medium))
                            .foregroundStyle(.black)

                        JoinRequestTagFlowLayout(horizontalSpacing: 10, verticalSpacing: 8) {
                            ForEach(profile.socialTags, id: \.self) { tag in
                                SocialTagBadge(
                                    tag,
                                    horizontalPadding: 14,
                                    showsShadow: true,
                                    shadowOpacity: 1,
                                    shadowRadius: 9
                                )
                            }
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var requestActions: some View {
        VStack(spacing: 24) {
            RallyDivider(width: 301)

            if viewModel.canReviewJoinRequest {
                HStack(spacing: 28) {
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
                            ProgressView()
                                .tint(.white)
                                .frame(maxWidth: .infinity)
                        } else {
                            Text(AppContent.string("joinRequest.approve"))
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .buttonStyle(RallyCompactPrimaryButtonStyle())
                    .disabled(actionButtonsAreDisabled)

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
                            ProgressView()
                                .tint(.white)
                                .frame(maxWidth: .infinity)
                        } else {
                            Text(AppContent.string("joinRequest.reject"))
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .buttonStyle(RallyCompactMutedButtonStyle())
                    .disabled(actionButtonsAreDisabled)
                }
            } else {
                Button(role: .destructive) {
                    Task {
                        let didDeleteNotification = await viewModel.deleteJoinRequestNotification(
                            notification: notification,
                            currentUser: appState.userProfile
                        )

                        if didDeleteNotification {
                            appState.removeCachedNotification(notification.id)
                            dismiss()
                        }
                    }
                } label: {
                    HStack(spacing: 10) {
                        if viewModel.isDeleting {
                            ProgressView()
                                .tint(.white)
                        } else {
                            Image("delete_forever")
                                .resizable()
                                .renderingMode(.template)
                                .scaledToFit()
                                .frame(width: 24, height: 24)

                            Text(AppContent.string("common.delete"))
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(RallyDestructiveActionButtonStyle())
                .disabled(deleteButtonIsDisabled)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var actionButtonsAreDisabled: Bool {
        viewModel.isApproving
            || viewModel.isDisapproving
            || viewModel.hasCompletedReview
            || !viewModel.canReviewJoinRequest
    }

    private var deleteButtonIsDisabled: Bool {
        viewModel.isLoading
            || viewModel.isDeleting
            || viewModel.hasCompletedReview
            || viewModel.canReviewJoinRequest
    }

    private var requestCancelledAlertIsPresented: Binding<Bool> {
        Binding(
            get: {
                viewModel.requestCancelledMessage != nil
            },
            set: { isPresented in
                if !isPresented {
                    viewModel.requestCancelledMessage = nil
                }
            }
        )
    }

    private func deleteCurrentNotificationAndDismiss() async {
        let didDeleteNotification = await viewModel.deleteJoinRequestNotification(
            notification: notification,
            currentUser: appState.userProfile
        )

        if didDeleteNotification {
            appState.removeCachedNotification(notification.id)
            dismiss()
        }
    }
}

private struct JoinRequestTagFlowLayout: Layout {
    let horizontalSpacing: CGFloat
    let verticalSpacing: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? 0
        var currentRowWidth: CGFloat = 0
        var currentRowHeight: CGFloat = 0
        var totalHeight: CGFloat = 0
        var widestRow: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            let shouldWrap = currentRowWidth > 0 && currentRowWidth + horizontalSpacing + size.width > maxWidth

            if shouldWrap {
                totalHeight += currentRowHeight + verticalSpacing
                widestRow = max(widestRow, currentRowWidth)
                currentRowWidth = size.width
                currentRowHeight = size.height
            } else {
                currentRowWidth += currentRowWidth == 0 ? size.width : horizontalSpacing + size.width
                currentRowHeight = max(currentRowHeight, size.height)
            }
        }

        totalHeight += currentRowHeight
        widestRow = max(widestRow, currentRowWidth)

        return CGSize(width: maxWidth > 0 ? maxWidth : widestRow, height: totalHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var origin = bounds.origin
        var currentRowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            let shouldWrap = origin.x > bounds.minX && origin.x + size.width > bounds.maxX

            if shouldWrap {
                origin.x = bounds.minX
                origin.y += currentRowHeight + verticalSpacing
                currentRowHeight = 0
            }

            subview.place(
                at: origin,
                proposal: ProposedViewSize(width: size.width, height: size.height)
            )

            origin.x += size.width + horizontalSpacing
            currentRowHeight = max(currentRowHeight, size.height)
        }
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
