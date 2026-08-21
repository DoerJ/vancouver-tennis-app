import SwiftUI

struct UserProfileView: View {
    @EnvironmentObject private var appState: AppState
    let onSaveCompleted: () -> Void
    @StateObject private var viewModel = UserProfileViewModel()
    @State private var isSigningOut = false
    @State private var isShowingLogOutConfirmation = false
    @State private var isShowingDeleteAccountConfirmation = false
    @State private var isShowingAvatarPicker = false
    @FocusState private var isDisplayNameFocused: Bool
    private let profileAvatarSize: CGFloat = 56

    init(onSaveCompleted: @escaping () -> Void = {}) {
        self.onSaveCompleted = onSaveCompleted
    }

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
                                    .font(.rally(size: 13, weight: .medium))
                                    .foregroundStyle(RallyDiscoverStyle.redBadge)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }

                            if let skillLevelErrorMessage = viewModel.skillLevelErrorMessage {
                                Text(skillLevelErrorMessage)
                                    .font(.rally(size: 13, weight: .medium))
                                    .foregroundStyle(RallyDiscoverStyle.redBadge)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }

                        }
                        .padding(.top, 56)

                        profileDetails
                            .padding(.top, 32)

                        actionButtons
                            .padding(.top, 62)

                        legalLinks
                            .padding(.top, 28)
                            .frame(maxWidth: .infinity, alignment: .center)

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
            .sheet(isPresented: $isShowingAvatarPicker) {
                AvatarPickerView()
                    .environmentObject(appState)
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
                .font(.rally(size: 32, weight: .bold))
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
                        onSaveCompleted()
                    }
                }
            } label: {
                Text(viewModel.isSavingProfile ? AppContent.string("common.saving") : AppContent.string("common.save"))
                    .font(.rally(size: 13, weight: .semibold))
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
            Button {
                isShowingAvatarPicker = true
            } label: {
                profileAvatarView
            }
            .buttonStyle(.plain)
            .disabled(viewModel.isSavingProfile)
            .accessibilityLabel(AppContent.string("profile.avatarPickerOpen"))

            HStack(spacing: 4) {
                if viewModel.isEditingDisplayName {
                    TextField(AppContent.string("profile.displayName"), text: $viewModel.editedDisplayName)
                        .font(.rally(size: 18, weight: .bold))
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
                        .font(.rally(size: 18, weight: .bold))
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

    private var profileAvatarView: some View {
        ProfileAvatarImageView(
            url: appState.userProfile?.avatarURL,
            size: profileAvatarSize
        )
        .contentShape(Circle())
    }

    private var profileDetails: some View {
        VStack(alignment: .leading, spacing: 24) {
            HStack(alignment: .center, spacing: 14) {
                Text(AppContent.string("profile.skillLevelDisplayLabel"))
                    .font(.rally(size: 15, weight: .medium))
                    .foregroundStyle(.black)

                if let skillLevel = viewModel.selectedSkillLevel ?? appState.userProfile?.skillLevel {
                    skillLevelMenu(selectedSkillLevel: skillLevel)
                }
            }

            HStack(alignment: .center, spacing: 14) {
                Text(AppContent.string("profile.genderDisplayLabel"))
                    .font(.rally(size: 15, weight: .medium))
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
                            SocialTagBadge(tag, showsShadow: true, shadowOpacity: 0.58)
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

                if let socialTagsErrorMessage = viewModel.socialTagsErrorMessage {
                    Text(socialTagsErrorMessage)
                        .font(.rally(size: 13, weight: .medium))
                        .foregroundStyle(RallyDiscoverStyle.redBadge)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
    }

    private var actionButtons: some View {
        VStack(spacing: 12) {
            if let deleteAccountErrorMessage = viewModel.deleteAccountErrorMessage {
                Text(deleteAccountErrorMessage)
                    .font(.rally(size: 13, weight: .medium))
                    .foregroundStyle(RallyDiscoverStyle.redBadge)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            Button {
                isShowingLogOutConfirmation = true
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "rectangle.portrait.and.arrow.right")
                        .font(.rally(size: 22, weight: .medium))

                    Text(isSigningOut ? AppContent.string("common.signingOut") : AppContent.string("common.logOut"))
                }
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(RallyPrimaryActionButtonStyle())
            .disabled(isSigningOut)

            Button {
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
            .buttonStyle(RallyGreenOutlineActionButtonStyle())
            .disabled(viewModel.isDeletingAccount)
        }
    }

    private var legalLinks: some View {
        VStack(spacing: 8) {
            NavigationLink {
                TermsOfServiceView()
            } label: {
                legalLinkText(AppContent.string("profile.termsOfService"))
            }
            .buttonStyle(.plain)

            NavigationLink {
                PrivacyPolicyView()
            } label: {
                legalLinkText(AppContent.string("profile.privacyPolicy"))
            }
            .buttonStyle(.plain)
        }
    }

    private func legalLinkText(_ text: String) -> some View {
        Text(text)
            .font(.rally(size: 13, weight: .medium))
            .foregroundStyle(RallyDiscoverStyle.ink.opacity(0.65))
            .underline()
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
        RallyDivider(leadingPadding: 2)
    }

    private var displayedSocialTags: [String] {
        Constants.SocialProfile.tagOptions.filter { appState.userProfile?.socialTags.contains($0) == true }
    }

    private var genderAccessibilityLabel: String {
        guard let gender = viewModel.selectedGender ?? appState.userProfile?.gender else {
            return AppContent.string("profile.genderNotSet")
        }

        return AppContent.string("profile.genderValue", gender.displayName)
    }

    private var socialTagsLabel: some View {
        Text(AppContent.string("profile.socialTagsDisplayLabel"))
            .font(.rally(size: 15, weight: .medium))
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

    private func socialTagOption(_ tag: String) -> some View {
        Button {
            viewModel.toggleSocialTag(tag)
        } label: {
            SocialTagBadge(
                tag,
                color: viewModel.selectedSocialTags.contains(tag)
                    ? RallyDiscoverStyle.primaryGreen
                    : RallyDiscoverStyle.accentGreen,
                horizontalPadding: 10,
                showsCheckmark: viewModel.selectedSocialTags.contains(tag)
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
            SkillLevelBadge(selectedSkillLevel, showsShadow: true, shadowOpacity: 0.58)
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
                GenderIconView(selectedGender, size: 24)

                Image(systemName: "chevron.down")
                    .font(.rally(size: 11, weight: .semibold))
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
