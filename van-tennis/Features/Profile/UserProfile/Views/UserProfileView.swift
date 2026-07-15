import SwiftUI

struct UserProfileView: View {
    @EnvironmentObject private var appState: AppState
    @StateObject private var viewModel = UserProfileViewModel()
    @State private var isSigningOut = false
    @State private var isShowingLogOutConfirmation = false
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

                            if let skillLevelErrorMessage = viewModel.skillLevelErrorMessage {
                                Text(skillLevelErrorMessage)
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
                AppContent.string("profile.logOutTitle"),
                isPresented: $isShowingLogOutConfirmation,
                titleVisibility: .visible
            ) {
                Button(AppContent.string("common.logOut"), role: .destructive) {
                    Task {
                        isSigningOut = true
                        await appState.signOut()
                        isSigningOut = false
                    }
                }

                Button(AppContent.string("common.cancel"), role: .cancel) {}
            } message: {
                Text(AppContent.string("profile.logOutConfirmation"))
            }
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
        .onAppear {
            viewModel.syncProfileIfNeeded(appState.userProfile)
        }
        .onChange(of: appState.userProfile) { _, profile in
            viewModel.syncProfileIfNeeded(profile)
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
                    let didSave = await viewModel.saveProfileChanges(
                        currentProfile: appState.userProfile,
                        appState: appState
                    )

                    if didSave {
                        isDisplayNameFocused = false
                    }
                }
            } label: {
                Text(viewModel.isSavingProfile ? AppContent.string("common.saving") : AppContent.string("common.save"))
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 18)
                    .frame(height: 34)
                    .background(saveProfileButtonColor, in: Capsule())
                    .shadow(color: RallyDiscoverStyle.shadow.opacity(canSaveProfile ? 0.58 : 0), radius: 18, x: 0, y: 8)
            }
            .buttonStyle(.plain)
            .disabled(!canSaveProfile || viewModel.isSavingProfile)
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
                .disabled(appState.userProfile == nil || viewModel.isSavingProfile)
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

                if let skillLevel = viewModel.selectedSkillLevel ?? appState.userProfile?.skillLevel {
                    skillLevelMenu(selectedSkillLevel: skillLevel)
                }
            }

            HStack(alignment: .center, spacing: 14) {
                Text(AppContent.string("profile.genderDisplayLabel"))
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(.black)

                genderMenu(selectedGender: viewModel.selectedGender ?? appState.userProfile?.gender)
                    .accessibilityLabel(genderAccessibilityLabel)
            }

            VStack(alignment: .leading, spacing: 10) {
                if displayedSocialTags.isEmpty {
                    HStack(spacing: 10) {
                        socialTagsLabel
                        socialTagsToggleButton
                    }
                } else {
                    socialTagsLabel

                    ProfileTagFlowLayout(horizontalSpacing: 12, verticalSpacing: 8) {
                        ForEach(displayedSocialTags, id: \.self) { tag in
                            profileBadge(tag, color: RallyDiscoverStyle.accentGreen)
                        }

                        socialTagsToggleButton
                    }
                }
            }

            if viewModel.showsSocialTagOptions {
                profileDivider

                ProfileTagFlowLayout(horizontalSpacing: 8, verticalSpacing: 8) {
                    ForEach(Constants.SocialProfile.tagOptions, id: \.self) { tag in
                        socialTagOption(tag)
                    }
                }
                .padding(.top, -8)
            }
        }
    }

    private var actionButtons: some View {
        VStack(spacing: 12) {
            if let deleteAccountErrorMessage = viewModel.deleteAccountErrorMessage {
                Text(deleteAccountErrorMessage)
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(RallyDiscoverStyle.redBadge)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            Button(role: .destructive) {
                isShowingLogOutConfirmation = true
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "rectangle.portrait.and.arrow.right")
                        .font(.system(size: 22, weight: .medium))

                    Text(isSigningOut ? AppContent.string("common.signingOut") : AppContent.string("common.logOut"))
                }
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(ProfileChatLikeButtonStyle())
            .disabled(isSigningOut)

            Button(role: .destructive) {
                isShowingDeleteAccountConfirmation = true
            } label: {
                HStack(spacing: 10) {
                    Image("delete_forever")
                        .resizable()
                        .renderingMode(.template)
                        .scaledToFit()
                        .frame(width: 24, height: 24)

                    Text(viewModel.isDeletingAccount ? AppContent.string("profile.deletingAccount") : AppContent.string("profile.deleteAccount"))
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(ProfileCancelLikeButtonStyle())
            .disabled(viewModel.isDeletingAccount)
        }
    }

    private var profileDisplayName: String {
        appState.userProfile?.displayName ?? AppContent.string("profile.fallbackTitle")
    }

    private var canSaveProfile: Bool {
        viewModel.canSaveProfile(currentProfile: appState.userProfile)
    }

    private var saveProfileButtonColor: Color {
        RallyDiscoverStyle.primaryGreen.opacity(canSaveProfile ? 1 : 0.45)
    }

    private var profileDivider: some View {
        Rectangle()
            .fill(Color.black.opacity(0.1))
            .frame(height: 1)
            .padding(.leading, 2)
    }

    private var displayedSocialTags: [String] {
        Constants.SocialProfile.tagOptions.filter { appState.userProfile?.socialTags.contains($0) == true }
    }

    @ViewBuilder
    private func genderIcon(for gender: Gender?) -> some View {
        switch gender {
        case .male:
            Image("face_male")
                .resizable()
                .scaledToFit()
                .frame(width: 24, height: 24)
        case .female:
            Image("face_female")
                .resizable()
                .scaledToFit()
                .frame(width: 24, height: 24)
        case .nonBinary, .preferNotToSay, nil:
            Image("face_non_binary")
                .resizable()
                .scaledToFit()
                .frame(width: 24, height: 24)
        }
    }

    private var genderAccessibilityLabel: String {
        guard let gender = viewModel.selectedGender ?? appState.userProfile?.gender else {
            return AppContent.string("profile.genderNotSet")
        }

        return AppContent.string("profile.genderValue", gender.displayName)
    }

    private var socialTagsLabel: some View {
        Text(AppContent.string("profile.socialTagsDisplayLabel"))
            .font(.system(size: 15, weight: .medium))
            .foregroundStyle(.black)
    }

    private var socialTagsToggleButton: some View {
        Button {
            viewModel.toggleSocialTagOptions()
        } label: {
            Image(viewModel.showsSocialTagOptions ? "minus" : "add_box")
                .resizable()
                .renderingMode(.template)
                .scaledToFit()
                .foregroundStyle(RallyDiscoverStyle.ink)
                .opacity(0.5)
                .frame(width: 24, height: 24)
        }
        .buttonStyle(.plain)
        .disabled(viewModel.isSavingProfile)
        .accessibilityLabel(AppContent.string("profile.editSocialTags"))
        .frame(height: 22)
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

    private func socialTagOption(_ tag: String) -> some View {
        Button {
            viewModel.toggleSocialTag(tag)
        } label: {
            HStack(spacing: 5) {
                Text(tag)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)

                if viewModel.selectedSocialTags.contains(tag) {
                    Image(systemName: "checkmark")
                        .font(.system(size: 8, weight: .bold))
                }
            }
            .font(.system(size: 10, weight: .semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 10)
            .frame(height: 22)
            .background(
                viewModel.selectedSocialTags.contains(tag)
                    ? RallyDiscoverStyle.primaryGreen
                    : RallyDiscoverStyle.accentGreen,
                in: Capsule()
            )
        }
        .buttonStyle(.plain)
        .disabled(viewModel.isSavingProfile)
    }

    private func skillLevelMenu(selectedSkillLevel: SkillLevel) -> some View {
        Menu {
            ForEach(SkillLevel.allCases) { skillLevel in
                Button {
                    viewModel.selectSkillLevel(skillLevel)
                } label: {
                    if skillLevel == selectedSkillLevel {
                        Label(skillLevel.rawValue, systemImage: "checkmark")
                    } else {
                        Text(skillLevel.rawValue)
                    }
                }
            }
        } label: {
            HStack(spacing: 5) {
                Text(selectedSkillLevel.rawValue)
            }
            .font(.system(size: 10, weight: .semibold))
            .foregroundStyle(.white)
            .frame(minWidth: 71)
            .padding(.horizontal, 8)
            .frame(height: 22)
            .background(Constants.SkillLevelStyle.badgeColor(for: selectedSkillLevel), in: Capsule())
            .shadow(color: RallyDiscoverStyle.shadow.opacity(0.58), radius: 18, x: 0, y: 8)
        }
        .disabled(viewModel.isSavingProfile)
    }

    private func genderMenu(selectedGender: Gender?) -> some View {
        Menu {
            ForEach(Gender.allCases) { gender in
                Button {
                    viewModel.selectGender(gender)
                } label: {
                    if gender == selectedGender {
                        Label(gender.displayName, systemImage: "checkmark")
                    } else {
                        Text(gender.displayName)
                    }
                }
            }
        } label: {
            HStack(spacing: 8) {
                genderIcon(for: selectedGender)
                    .frame(width: 24, height: 24)

                Image(systemName: "chevron.down")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Color.black.opacity(0.45))
            }
            .frame(height: 32)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(viewModel.isSavingProfile)
    }

    private func startDisplayNameEditing() {
        viewModel.startDisplayNameEditing(profile: appState.userProfile)
        isDisplayNameFocused = true
    }
}

private struct ProfileChatLikeButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 16, weight: .semibold))
            .foregroundStyle(.black)
            .frame(minHeight: 52)
            .padding(.horizontal, 18)
            .background(Color(red: 0.97, green: 0.97, blue: 0.96).opacity(configuration.isPressed ? 0.72 : 1))
            .clipShape(Capsule())
            .shadow(color: RallyDiscoverStyle.shadow.opacity(0.95), radius: 18, x: 0, y: 8)
            .shadow(color: Color.black.opacity(0.05), radius: 6, x: 0, y: 2)
    }
}

private struct ProfileCancelLikeButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 16, weight: .semibold))
            .foregroundStyle(.white)
            .frame(minHeight: 52)
            .padding(.horizontal, 18)
            .background(Color(red: 0.98, green: 0.28, blue: 0.13).opacity(configuration.isPressed ? 0.82 : 1), in: Capsule())
    }
}

private struct ProfileTagFlowLayout: Layout {
    let horizontalSpacing: CGFloat
    let verticalSpacing: CGFloat

    func sizeThatFits(
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var currentRowWidth: CGFloat = 0
        var currentRowHeight: CGFloat = 0
        var totalHeight: CGFloat = 0
        var widestRow: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            let proposedRowWidth = currentRowWidth == 0 ? size.width : currentRowWidth + horizontalSpacing + size.width

            if proposedRowWidth > maxWidth, currentRowWidth > 0 {
                totalHeight += currentRowHeight + verticalSpacing
                widestRow = max(widestRow, currentRowWidth)
                currentRowWidth = size.width
                currentRowHeight = size.height
            } else {
                currentRowWidth = proposedRowWidth
                currentRowHeight = max(currentRowHeight, size.height)
            }
        }

        totalHeight += currentRowHeight
        widestRow = max(widestRow, currentRowWidth)

        return CGSize(width: proposal.width ?? widestRow, height: totalHeight)
    }

    func placeSubviews(
        in bounds: CGRect,
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) {
        var origin = bounds.origin
        var currentRowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            let proposedMaxX = origin.x == bounds.minX ? origin.x + size.width : origin.x + horizontalSpacing + size.width

            if proposedMaxX > bounds.maxX, origin.x > bounds.minX {
                origin.x = bounds.minX
                origin.y += currentRowHeight + verticalSpacing
                currentRowHeight = 0
            } else if origin.x > bounds.minX {
                origin.x += horizontalSpacing
            }

            subview.place(
                at: origin,
                proposal: ProposedViewSize(width: size.width, height: size.height)
            )
            origin.x += size.width
            currentRowHeight = max(currentRowHeight, size.height)
        }
    }
}

#Preview {
    UserProfileView()
        .environmentObject(AppState())
}
