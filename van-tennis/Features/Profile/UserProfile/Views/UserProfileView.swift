import SwiftUI

struct UserProfileView: View {
    @EnvironmentObject private var appState: AppState
    @StateObject private var viewModel = UserProfileViewModel()
    @State private var isSigningOut = false
    @State private var isShowingDeleteAccountConfirmation = false
    @FocusState private var isDisplayNameFocused: Bool

    var body: some View {
        NavigationStack {
            ZStack {
                RallyDiscoverStyle.card
                    .ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        profileTitleRow
                            .padding(.top, 79)

                        VStack(alignment: .leading, spacing: 10) {
                            profileIdentityRow

                            if let displayNameErrorMessage = viewModel.displayNameErrorMessage {
                                Text(displayNameErrorMessage)
                                    .font(.footnote.weight(.medium))
                                    .foregroundStyle(RallyDiscoverStyle.redBadge)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }
                        .padding(.top, 56)

                        profileDetails
                            .padding(.top, 32)

                        actionButtons
                            .padding(.top, 62)

                        Spacer(minLength: 120)
                    }
                    .padding(.horizontal, 29)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .background {
                    RoundedRectangle(cornerRadius: 24)
                        .fill(RallyDiscoverStyle.card)
                        .ignoresSafeArea(edges: .bottom)
                        .padding(.top, 28)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar(.hidden, for: .navigationBar)
            .confirmationDialog(
                AppContent.string("profile.deleteAccountTitle"),
                isPresented: $isShowingDeleteAccountConfirmation,
                titleVisibility: .visible
            ) {
                Button(AppContent.string("profile.deleteAccount"), role: .destructive) {
                    Task {
                        await viewModel.deleteAccount(appState: appState)
                    }
                }

                Button(AppContent.string("common.cancel"), role: .cancel) {}
            } message: {
                Text(AppContent.string("profile.deleteConfirmation"))
            }
            .alert(AppContent.string("profile.accountDeletedTitle"), isPresented: $viewModel.isShowingAccountDeletedAlert) {
                Button(AppContent.string("common.ok")) {
                    appState.finishDeletedAccountFlow()
                }
            } message: {
                Text(AppContent.string("profile.accountDeletedMessage"))
            }
        }
        .onChange(of: appState.userProfile?.displayName) { _, displayName in
            viewModel.syncDisplayNameIfNeeded(displayName)
        }
    }

    private var profileTitleRow: some View {
        HStack(alignment: .center) {
            Text(AppContent.string("profile.title"))
                .font(.system(size: 32, weight: .bold))
                .foregroundStyle(RallyDiscoverStyle.ink)

            Spacer()

            Button {
                Task {
                    let didSave = await viewModel.saveDisplayName(
                        currentDisplayName: appState.userProfile?.displayName,
                        appState: appState
                    )

                    if didSave {
                        isDisplayNameFocused = false
                    }
                }
            } label: {
                Text(viewModel.isSavingDisplayName ? AppContent.string("common.saving") : AppContent.string("common.save"))
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 18)
                    .frame(height: 34)
                    .background(saveDisplayNameButtonColor, in: Capsule())
                    .shadow(color: RallyDiscoverStyle.shadow.opacity(canSaveDisplayName ? 0.58 : 0), radius: 18, x: 0, y: 8)
            }
            .buttonStyle(.plain)
            .disabled(!canSaveDisplayName || viewModel.isSavingDisplayName)
        }
    }

    private var profileIdentityRow: some View {
        HStack(spacing: 26) {
            Image("profile")
                .resizable()
                .scaledToFit()
                .frame(width: 56, height: 56)
                .accessibilityHidden(true)

            HStack(spacing: 4) {
                if viewModel.isEditingDisplayName {
                    TextField(AppContent.string("profile.displayName"), text: $viewModel.editedDisplayName)
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(RallyDiscoverStyle.ink)
                        .textInputAutocapitalization(.words)
                        .submitLabel(.done)
                        .focused($isDisplayNameFocused)
                        .frame(maxWidth: 160, alignment: .leading)
                        .onSubmit {
                            isDisplayNameFocused = false
                        }
                } else {
                    Text(profileDisplayName)
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(RallyDiscoverStyle.ink)
                        .lineLimit(1)
                        .minimumScaleFactor(0.82)
                        .frame(maxWidth: 160, alignment: .leading)
                }

                Button {
                    startDisplayNameEditing()
                } label: {
                    Image("pencil")
                        .resizable()
                        .renderingMode(.template)
                        .scaledToFit()
                        .foregroundStyle(RallyDiscoverStyle.ink)
                        .frame(width: 24, height: 24)
                        .frame(width: 32, height: 44)
                }
                .buttonStyle(.plain)
                .disabled(appState.userProfile == nil || viewModel.isSavingDisplayName)
                .accessibilityLabel(AppContent.string("profile.edit"))
            }

            Spacer()
        }
    }

    private var profileDetails: some View {
        VStack(alignment: .leading, spacing: 24) {
            HStack(alignment: .center, spacing: 14) {
                Text(AppContent.string("profile.skillLevelDisplayLabel"))
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(.black)

                if let skillLevel = appState.userProfile?.skillLevel {
                    profileBadge(skillLevel.rawValue, color: RallyDiscoverStyle.primaryGreen)
                }

                Spacer(minLength: 12)

                Text(AppContent.string("profile.genderDisplayLabel"))
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(.black)

                Image(systemName: genderIconName)
                    .font(.system(size: 19, weight: .semibold))
                    .foregroundStyle(RallyDiscoverStyle.ink)
                    .accessibilityLabel(genderAccessibilityLabel)
            }

            HStack(alignment: .center, spacing: 22) {
                Text(AppContent.string("profile.socialTagsDisplayLabel"))
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(.black)

                if let socialTags = appState.userProfile?.socialTags, !socialTags.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(socialTags, id: \.self) { tag in
                                profileBadge(tag, color: RallyDiscoverStyle.accentGreen)
                            }
                        }
                    }
                }
            }
        }
    }

    private var actionButtons: some View {
        VStack(spacing: 24) {
            if let deleteAccountErrorMessage = viewModel.deleteAccountErrorMessage {
                Text(deleteAccountErrorMessage)
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(RallyDiscoverStyle.redBadge)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            Button(role: .destructive) {
                Task {
                    isSigningOut = true
                    await appState.signOut()
                    isSigningOut = false
                }
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "rectangle.portrait.and.arrow.right")
                        .font(.system(size: 22, weight: .medium))

                    Text(isSigningOut ? AppContent.string("common.signingOut") : AppContent.string("common.logOut"))
                        .font(.system(size: 13, weight: .semibold))
                }
                .foregroundStyle(.black)
                .frame(maxWidth: .infinity)
                .frame(height: 40)
                .background(RallyDiscoverStyle.surface, in: Capsule())
                .shadow(color: RallyDiscoverStyle.shadow.opacity(0.42), radius: 18, x: 0, y: 8)
            }
            .buttonStyle(.plain)
            .disabled(isSigningOut)

            Button(role: .destructive) {
                isShowingDeleteAccountConfirmation = true
            } label: {
                HStack(spacing: 10) {
                    Image("disabled_by_default")
                        .resizable()
                        .renderingMode(.template)
                        .scaledToFit()
                        .frame(width: 24, height: 24)

                    Text(viewModel.isDeletingAccount ? AppContent.string("profile.deletingAccount") : AppContent.string("profile.deleteAccount"))
                        .font(.system(size: 13, weight: .semibold))
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 40)
                .background(RallyDiscoverStyle.redBadge, in: Capsule())
                .shadow(color: RallyDiscoverStyle.shadow.opacity(0.58), radius: 18, x: 0, y: 8)
            }
            .buttonStyle(.plain)
            .disabled(viewModel.isDeletingAccount)
        }
        .padding(.horizontal, 17)
    }

    private var profileDisplayName: String {
        appState.userProfile?.displayName ?? AppContent.string("profile.fallbackTitle")
    }

    private var canSaveDisplayName: Bool {
        viewModel.canSaveDisplayName(currentDisplayName: appState.userProfile?.displayName)
    }

    private var saveDisplayNameButtonColor: Color {
        canSaveDisplayName ? RallyDiscoverStyle.primaryGreen : Color.gray.opacity(0.45)
    }

    private var genderIconName: String {
        switch appState.userProfile?.gender {
        case .male:
            return "person.circle"
        case .female:
            return "face.smiling"
        case .nonBinary:
            return "person.2.circle"
        case .preferNotToSay, nil:
            return "face.smiling"
        }
    }

    private var genderAccessibilityLabel: String {
        guard let gender = appState.userProfile?.gender else {
            return AppContent.string("profile.genderNotSet")
        }

        return AppContent.string("profile.genderValue", gender.displayName)
    }

    private func profileBadge(_ text: String, color: Color) -> some View {
        Text(text)
            .font(.system(size: 10, weight: .semibold))
            .foregroundStyle(.white)
            .frame(minWidth: 71)
            .padding(.horizontal, 8)
            .frame(height: 22)
            .background(color, in: Capsule())
            .shadow(color: RallyDiscoverStyle.shadow.opacity(0.58), radius: 18, x: 0, y: 8)
    }

    private func startDisplayNameEditing() {
        viewModel.startDisplayNameEditing(profile: appState.userProfile)
        isDisplayNameFocused = true
    }
}

#Preview {
    UserProfileView()
        .environmentObject(AppState())
}
