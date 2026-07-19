import SwiftUI

struct ReviewParticipantJoinRequestView: View {
    let notification: NotificationEvent

    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = ReviewParticipantJoinRequestViewModel()

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 44, height: 44)
                        .background(Color.black.opacity(0.28), in: Circle())
                }
                .accessibilityLabel(AppContent.string("common.back"))
                .padding(.top, 24)

                Text(AppContent.string("joinRequest.title"))
                    .font(.system(size: 32, weight: .bold))
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
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(RallyDiscoverStyle.redBadge)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            if let profile = viewModel.senderProfile {
                Text(AppContent.string("joinRequest.requestingPlayer"))
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(RallyDiscoverStyle.ink)
                    .padding(.bottom, 6)

                HStack(spacing: 10) {
                    Text(AppContent.string("joinRequest.nameValue", profile.displayName))
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(.black)

                    genderIcon(for: profile.gender)
                        .frame(width: 24, height: 24)

                    Spacer(minLength: 0)
                }

                if let skillLevel = profile.skillLevel {
                    HStack(spacing: 12) {
                        Text(AppContent.string("joinRequest.skillLevelLabel"))
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(.black)

                        skillLevelBadge(skillLevel)
                    }
                }

                if !profile.socialTags.isEmpty {
                    HStack(alignment: .top, spacing: 12) {
                        Text(tagLabel(for: profile.gender))
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(.black)

                        JoinRequestTagFlowLayout(horizontalSpacing: 10, verticalSpacing: 8) {
                            ForEach(profile.socialTags, id: \.self) { tag in
                                socialTagBadge(tag)
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
            Rectangle()
                .fill(Color.black.opacity(0.10))
                .frame(maxWidth: 301)
                .frame(height: 1)

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
                .buttonStyle(JoinRequestApproveButtonStyle())
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
                .buttonStyle(JoinRequestRejectButtonStyle())
                .disabled(actionButtonsAreDisabled)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func skillLevelBadge(_ skillLevel: SkillLevel) -> some View {
        Text(skillLevel.rawValue)
            .font(.system(size: 10, weight: .semibold))
            .foregroundStyle(.white)
            .frame(width: 71, height: 22)
            .background(Constants.SkillLevelStyle.badgeColor(for: skillLevel), in: Capsule())
            .shadow(color: RallyDiscoverStyle.shadow, radius: 9, x: 0, y: 8)
    }

    private func socialTagBadge(_ tag: String) -> some View {
        Text(tag)
            .font(.system(size: 10, weight: .semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 14)
            .frame(height: 22)
            .background(RallyDiscoverStyle.accentGreen, in: Capsule())
            .shadow(color: RallyDiscoverStyle.shadow, radius: 9, x: 0, y: 8)
    }

    private func genderIcon(for gender: Gender?) -> some View {
        switch gender {
        case .male:
            Image("face_male")
                .resizable()
                .scaledToFit()
        case .female:
            Image("face_female")
                .resizable()
                .scaledToFit()
        case .nonBinary, .preferNotToSay, nil:
            Image("face_non_binary")
                .resizable()
                .scaledToFit()
        }
    }

    private func tagLabel(for gender: Gender?) -> String {
        switch gender {
        case .male:
            return AppContent.string("joinRequest.hisTags")
        case .female:
            return AppContent.string("joinRequest.herTags")
        case .nonBinary, .preferNotToSay, nil:
            return AppContent.string("joinRequest.theirTags")
        }
    }

    private var actionButtonsAreDisabled: Bool {
        viewModel.isApproving
            || viewModel.isDisapproving
            || viewModel.hasCompletedReview
            || !viewModel.canReviewJoinRequest
    }
}

private struct JoinRequestApproveButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(.white)
            .frame(width: 140, height: 40)
            .background(RallyDiscoverStyle.primaryGreen.opacity(configuration.isPressed ? 0.78 : 1), in: Capsule())
            .opacity(configuration.isPressed ? 0.88 : 1)
    }
}

private struct JoinRequestRejectButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(.white)
            .frame(width: 140, height: 40)
            .background(Color.black.opacity(configuration.isPressed ? 0.40 : 0.50), in: Capsule())
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
