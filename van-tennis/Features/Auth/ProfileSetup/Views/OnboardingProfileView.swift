import SwiftUI

struct OnboardingProfileView: View {
    @EnvironmentObject private var appState: AppState
    @State private var selectedLevel: SkillLevel?
    @State private var selectedGender: Gender?
    @State private var isSaving = false
    @State private var errorMessage: String?

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            VStack(spacing: 8) {
                Text("Complete your profile")
                    .font(.largeTitle)
                    .fontWeight(.semibold)

                Text("Choose the tennis skill level and gender that best match you.")
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

            Spacer()
        }
        .padding(24)
        .onAppear {
            selectedLevel = appState.userProfile?.skillLevel
            selectedGender = appState.userProfile?.gender
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
                gender: selectedGender
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
