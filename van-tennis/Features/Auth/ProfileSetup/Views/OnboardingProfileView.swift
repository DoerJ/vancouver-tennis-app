import SwiftUI

struct OnboardingProfileView: View {
    @EnvironmentObject private var appState: AppState
    @StateObject private var viewModel = OnboardingProfileViewModel()
    @State private var selectedLevel: SkillLevel?
    @State private var selectedGender: Gender?
    @State private var selectedSocialTags: Set<String> = []
    @State private var socialTagsErrorMessage: String?

    private var canCreateProfile: Bool {
        selectedLevel != nil && selectedGender != nil && !viewModel.isSaving
    }

    var body: some View {
        ZStack {
            Color.white
                .ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    header

                    Text(AppContent.string("auth.onboarding.skillLevel"))
                        .font(.rally(size: 16, weight: .bold))
                        .foregroundStyle(RallyDiscoverStyle.ink)
                        .padding(.top, 84)

                    skillLevelSelector
                        .padding(.top, 30)

                    Text(Constants.SkillLevelStyle.description(for: selectedLevel ?? .one))
                        .font(.rally(size: 15, weight: .medium))
                        .foregroundStyle(Color.black.opacity(0.5))
                        .lineSpacing(4)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, 24)

                    onboardingDivider
                        .padding(.top, 32)

                    genderSection
                        .padding(.top, 30)

                    onboardingDivider
                        .padding(.top, 28)

                    Text(AppContent.string("auth.onboarding.socialTags"))
                        .font(.rally(size: 16, weight: .bold))
                        .foregroundStyle(RallyDiscoverStyle.ink)
                        .padding(.top, 30)

                    socialTagsSection
                        .padding(.top, 24)

                    if let socialTagsErrorMessage {
                        inlineError(socialTagsErrorMessage)
                            .padding(.top, 12)
                    }

                    if let errorMessage = viewModel.errorMessage {
                        inlineError(errorMessage)
                            .padding(.top, 20)
                    }

                    createButton
                        .padding(.top, 40)
                }
                .padding(.horizontal, 29)
                .padding(.top, 88)
                .padding(.bottom, 128)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.white)
            }

            VStack {
                HStack {
                    LanguageMenuButton()

                    Spacer()
                }
                .padding(.horizontal, 29)
                .padding(.top, 20)

                Spacer()
            }
        }
        .onAppear {
            selectedLevel = appState.userProfile?.skillLevel ?? .one
            selectedGender = appState.userProfile?.gender
            selectedSocialTags = Set(appState.userProfile?.socialTags ?? [])
        }
    }

    private var header: some View {
        HStack(alignment: .top) {
            Text(AppContent.string("auth.onboarding.title"))
                .font(.rally(size: 32, weight: .bold))
                .foregroundStyle(RallyDiscoverStyle.ink)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 18)
        }
    }

    private var createButton: some View {
        Button {
            Task {
                await viewModel.saveProfile(
                    selectedLevel: selectedLevel,
                    selectedGender: selectedGender,
                    selectedSocialTags: selectedSocialTags,
                    appState: appState
                )
            }
        } label: {
            Text(viewModel.isSaving ? AppContent.string("common.saving") : AppContent.string("auth.onboarding.create"))
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(RallyPrimaryActionButtonStyle(isEnabled: canCreateProfile, showsShadow: canCreateProfile))
        .disabled(!canCreateProfile)
        .padding(.horizontal, 16)
    }

    private var skillLevelSelector: some View {
        GeometryReader { geometry in
            ZStack(alignment: .topLeading) {
                Capsule()
                    .fill(Color.black.opacity(0.05))
                    .frame(height: 5)
                    .offset(y: 8)

                let progressWidth = geometry.size.width * selectedSkillProgress
                Capsule()
                    .fill(RallyDiscoverStyle.accentGreen)
                    .frame(width: max(progressWidth, 0), height: 5)
                    .offset(y: 8)

                HStack {
                    ForEach(SkillLevel.allCases) { level in
                        Circle()
                            .fill(level == selectedLevel ? RallyDiscoverStyle.primaryGreen : RallyDiscoverStyle.accentGreen)
                            .frame(
                                width: level == selectedLevel ? 17 : 13,
                                height: level == selectedLevel ? 17 : 13
                            )

                        if level != SkillLevel.allCases.last {
                            Spacer()
                        }
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 22, alignment: .center)

                selectedSkillBadge
                    .position(
                        x: clampedSkillBadgeCenter(in: geometry.size.width),
                        y: 44
                    )
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        selectSkillLevel(at: value.location.x, width: geometry.size.width)
                    }
                )
        }
        .frame(height: 56)
        .padding(.horizontal, 14)
    }

    private var selectedSkillBadge: some View {
        SkillLevelBadge(
            selectedLevel ?? .one,
            width: 72,
            minWidth: nil,
            showsShadow: true,
            shadowRadius: 9
        )
    }

    private var genderSection: some View {
        HStack(spacing: 22) {
            Text(AppContent.string("auth.onboarding.gender"))
                .font(.rally(size: 16, weight: .bold))
                .foregroundStyle(RallyDiscoverStyle.ink)

            Menu {
                ForEach(Gender.allCases) { gender in
                    Button {
                        selectedGender = gender
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
            }
            .buttonStyle(.plain)

            Spacer()
        }
    }

    private var socialTagsSection: some View {
        OnboardingTagFlowLayout(horizontalSpacing: 18, verticalSpacing: 20) {
            ForEach(Constants.SocialProfile.tagOptions, id: \.self) { tag in
                tagButton(tag)
            }
        }
    }

    private func tagButton(_ tag: String) -> some View {
        Button {
            toggleSocialTag(tag)
        } label: {
            SocialTagBadge(
                tag,
                color: tagColor(for: tag),
                horizontalPadding: 14,
                showsShadow: true,
                shadowRadius: 9,
                showsCheckmark: selectedSocialTags.contains(tag),
                checkmarkSize: 7
            )
        }
        .buttonStyle(.plain)
    }

    private var onboardingDivider: some View {
        RallyDivider(horizontalPadding: 14)
    }

    private var selectedSkillProgress: CGFloat {
        let levels = SkillLevel.allCases
        guard let selectedLevel,
              let index = levels.firstIndex(of: selectedLevel),
              levels.count > 1 else {
            return 0
        }

        return CGFloat(index) / CGFloat(levels.count - 1)
    }

    private func tagColor(for tag: String) -> Color {
        selectedSocialTags.contains(tag) ? RallyDiscoverStyle.primaryGreen : RallyDiscoverStyle.accentGreen
    }

    private func toggleSocialTag(_ tag: String) {
        if selectedSocialTags.contains(tag) {
            selectedSocialTags.remove(tag)
            socialTagsErrorMessage = nil
        } else if selectedSocialTags.count >= Constants.SocialProfile.maximumSelectedTags {
            socialTagsErrorMessage = AppContent.string(
                "profile.socialTagsLimit",
                Constants.SocialProfile.maximumSelectedTags
            )
        } else {
            selectedSocialTags.insert(tag)
            socialTagsErrorMessage = nil
        }
    }

    private func inlineError(_ message: String) -> some View {
        Text(message)
            .font(.rally(size: 13, weight: .semibold))
            .foregroundStyle(RallyDiscoverStyle.redBadge)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
    }

    private func selectSkillLevel(at xPosition: CGFloat, width: CGFloat) {
        let levels = SkillLevel.allCases
        guard width > 0, levels.count > 1 else {
            selectedLevel = levels.first
            return
        }

        let clampedXPosition = min(max(xPosition, 0), width)
        let progress = clampedXPosition / width
        let index = Int((progress * CGFloat(levels.count - 1)).rounded())
        selectedLevel = levels[min(max(index, 0), levels.count - 1)]
    }

    private func clampedSkillBadgeCenter(in width: CGFloat) -> CGFloat {
        let badgeHalfWidth: CGFloat = 36
        let indicatorXPosition = width * selectedSkillProgress

        guard width > badgeHalfWidth * 2 else {
            return width / 2
        }

        return min(max(indicatorXPosition, badgeHalfWidth), width - badgeHalfWidth)
    }

}

private struct OnboardingTagFlowLayout: Layout {
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
    OnboardingProfileView()
        .environmentObject(AppState())
}
