import SwiftUI

struct OnboardingProfileView: View {
    @EnvironmentObject private var appState: AppState
    @State private var selectedLevel: SkillLevel?
    @State private var selectedGender: Gender?
    @State private var selectedSocialTags: Set<String> = []
    @State private var isSaving = false
    @State private var errorMessage: String?

    private let socialTagOptions = ["intj", "enfp", "software engineer"]

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                VStack(spacing: 8) {
                    Text("Complete your profile")
                        .font(.largeTitle)
                        .fontWeight(.semibold)

                    Text("Choose the tennis skill level, gender, and tags that best match you.")
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }

                VStack(spacing: 12) {
                    Text("Skill Level")
                        .font(.headline)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    ForEach(SkillLevel.allCases) { level in
                        Button {
                            selectedLevel = level
                        } label: {
                            HStack {
                                Text(level.rawValue)
                                    .font(.headline)

                                Spacer()

                                if selectedLevel == level {
                                    Image(systemName: "checkmark.circle.fill")
                                }
                            }
                            .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.large)
                    }
                }

                VStack(spacing: 12) {
                    Text("Gender")
                        .font(.headline)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    ForEach(Gender.allCases) { gender in
                        Button {
                            selectedGender = gender
                        } label: {
                            HStack {
                                Text(gender.displayName)
                                    .font(.headline)

                                Spacer()

                                if selectedGender == gender {
                                    Image(systemName: "checkmark.circle.fill")
                                }
                            }
                            .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.large)
                    }
                }

                VStack(spacing: 12) {
                    Text("Social Tags")
                        .font(.headline)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    HStack(spacing: 8) {
                        ForEach(socialTagOptions, id: \.self) { tag in
                            Button {
                                toggleSocialTag(tag)
                            } label: {
                                HStack(spacing: 6) {
                                    Text(tag)
                                        .font(.subheadline)

                                    if selectedSocialTags.contains(tag) {
                                        Image(systemName: "checkmark")
                                            .font(.caption)
                                    }
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .frame(minHeight: 36)
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                if let errorMessage {
                    Text(errorMessage)
                        .font(.footnote)
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                }

                Button {
                    Task {
                        await saveProfile()
                    }
                } label: {
                    Text(isSaving ? "Saving..." : "Continue")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(selectedLevel == nil || selectedGender == nil || isSaving)
            }
            .padding(24)
            .frame(maxWidth: .infinity)
        }
        .onAppear {
            selectedLevel = appState.userProfile?.skillLevel
            selectedGender = appState.userProfile?.gender
            selectedSocialTags = Set(appState.userProfile?.socialTags ?? [])
        }
    }

    private func toggleSocialTag(_ tag: String) {
        if selectedSocialTags.contains(tag) {
            selectedSocialTags.remove(tag)
        } else {
            selectedSocialTags.insert(tag)
        }
    }

    private func saveProfile() async {
        guard let selectedLevel, let selectedGender else {
            return
        }

        isSaving = true
        errorMessage = nil

        do {
            try await appState.updateProfile(
                skillLevel: selectedLevel,
                gender: selectedGender,
                socialTags: socialTagOptions.filter { selectedSocialTags.contains($0) }
            )
        } catch {
            errorMessage = error.localizedDescription
        }

        isSaving = false
    }
}

#Preview {
    OnboardingProfileView()
        .environmentObject(AppState())
}
