import SwiftUI

struct AvatarPickerView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.displayScale) private var displayScale
    @EnvironmentObject private var appState: AppState
    @StateObject private var viewModel = AvatarPickerViewModel()

    private let avatarSize: CGFloat = 78

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                header

                RallyDiscoverStyle.card
                    .overlay {
                        content
                            .padding(.horizontal, 24)
                            .padding(.top, 18)
                            .padding(.bottom, 28)
                    }
            }
            .background(RallyDiscoverStyle.card.ignoresSafeArea())
            .toolbar(.hidden, for: .navigationBar)
        }
        .presentationDetents([.medium, .large])
        .onAppear {
            viewModel.syncSelectedAvatarIfNeeded(currentAvatarURL: appState.userProfile?.avatarURL)
        }
        .task {
            await viewModel.loadAvatarOptions()
        }
    }

    private var header: some View {
        ZStack {
            Text(AppContent.string("profile.avatarPickerTitle"))
                .font(.rally(size: 17, weight: .semibold))
                .foregroundStyle(RallyDiscoverStyle.ink)
                .frame(maxWidth: .infinity, alignment: .center)

            doneButtonControl
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .padding(.horizontal, 24)
        .padding(.top, 18)
        .padding(.bottom, 10)
        .background(RallyDiscoverStyle.card)
    }

    @ViewBuilder
    private var content: some View {
        if viewModel.isLoadingAvatarOptions && viewModel.avatarOptions.isEmpty {
            ProgressView(AppContent.string("profile.avatarPickerLoading"))
                .rallyLoadingStatusStyle()
        } else if let errorMessage = viewModel.errorMessage,
                  viewModel.avatarOptions.isEmpty {
            Text(errorMessage)
                .font(.rally(size: 14, weight: .medium))
                .foregroundStyle(RallyDiscoverStyle.redBadge)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                .multilineTextAlignment(.center)
        } else if viewModel.avatarOptions.isEmpty {
            Text(AppContent.string("profile.avatarPickerEmpty"))
                .font(.rally(size: 15, weight: .medium))
                .foregroundStyle(RallyDiscoverStyle.ink.opacity(0.5))
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        } else {
            ScrollView {
                LazyVGrid(
                    columns: [
                        GridItem(.flexible(), spacing: 18),
                        GridItem(.flexible(), spacing: 18),
                        GridItem(.flexible(), spacing: 18)
                    ],
                    spacing: 20
                ) {
                    ForEach(viewModel.avatarOptions) { avatar in
                        avatarButton(avatar)
                    }
                }
                .padding(.top, 12)
            }
        }
    }

    private var doneButtonControl: some View {
        Text(viewModel.isSavingAvatar ? AppContent.string("common.saving") : AppContent.string("common.done"))
            .font(.rally(size: 13, weight: .semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 18)
            .frame(height: 34)
            .background {
                Capsule()
                    .fill(doneButtonColor)
            }
            .contentShape(Capsule())
            .opacity(viewModel.isSavingAvatar ? 0.8 : 1)
            .onTapGesture {
                guard canSaveAvatar,
                      !viewModel.isSavingAvatar
                else {
                    return
                }

                Task {
                    let didSave = await viewModel.saveSelectedAvatar(
                        currentAvatarURL: appState.userProfile?.avatarURL,
                        appState: appState
                    )

                    if didSave {
                        dismiss()
                    }
                }
            }
            .accessibilityAddTraits(.isButton)
            .accessibilityLabel(AppContent.string("common.done"))
    }

    private func avatarButton(_ avatar: ProfileAvatarOption) -> some View {
        Button {
            viewModel.selectAvatar(avatar)
        } label: {
            ZStack(alignment: .topTrailing) {
                avatarImage(avatar)

                if isSelectedAvatar(avatar) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.rally(size: 22, weight: .semibold))
                        .foregroundStyle(RallyDiscoverStyle.primaryGreen)
                        .background(Color.white, in: Circle())
                        .offset(x: 2, y: -2)
                }
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
        .disabled(viewModel.isSavingAvatar)
        .task(id: avatar.id) {
            if let avatarURL = avatar.url {
                await viewModel.loadImage(
                    for: avatarURL,
                    size: avatarSize,
                    displayScale: displayScale
                )
            }
        }
    }

    @ViewBuilder
    private func avatarImage(_ avatar: ProfileAvatarOption) -> some View {
        if let avatarURL = avatar.url {
            AvatarImageView(
                image: viewModel.image(
                    for: avatarURL,
                    size: avatarSize,
                    displayScale: displayScale
                ),
                size: avatarSize
            )
        } else {
            ProfileAvatarImageView(url: nil, size: avatarSize)
        }
    }

    private func isSelectedAvatar(_ avatar: ProfileAvatarOption) -> Bool {
        viewModel.selectedAvatarURL == avatar.url
    }

    private var canSaveAvatar: Bool {
        viewModel.canSaveAvatar(currentAvatarURL: appState.userProfile?.avatarURL)
    }

    private var doneButtonColor: Color {
        RallyDiscoverStyle.primaryGreen.opacity(canSaveAvatar ? 1 : 0.45)
    }
}
