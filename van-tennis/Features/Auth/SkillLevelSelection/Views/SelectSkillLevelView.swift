import SwiftUI

struct SelectSkillLevelView: View {
    @EnvironmentObject private var appState: AppState
    @State private var selectedLevel: SkillLevel?
    @State private var isSaving = false
    @State private var errorMessage: String?

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            VStack(spacing: 8) {
                Text("Select your level")
                    .font(.largeTitle)
                    .fontWeight(.semibold)

                Text("Choose the tennis skill level that best matches you.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            VStack(spacing: 12) {
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

            if let errorMessage {
                Text(errorMessage)
                    .font(.footnote)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
            }

            Button {
                Task {
                    await saveSkillLevel()
                }
            } label: {
                Text(isSaving ? "Saving..." : "Continue")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(selectedLevel == nil || isSaving)

            Spacer()
        }
        .padding(24)
    }

    private func saveSkillLevel() async {
        guard let selectedLevel else {
            return
        }

        isSaving = true
        errorMessage = nil

        do {
            try await appState.updateProfile(skillLevel: selectedLevel)
        } catch {
            errorMessage = error.localizedDescription
        }

        isSaving = false
    }
}

#Preview {
    SelectSkillLevelView()
        .environmentObject(AppState())
}
