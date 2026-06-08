import SwiftUI

struct CreateEventView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var appState: AppState
    @StateObject private var viewModel: CreateEventViewModel
    private let onEventCreated: (TennisEvent) -> Void

    init(
        creatorSkillLevel: SkillLevel,
        onEventCreated: @escaping (TennisEvent) -> Void = { _ in }
    ) {
        self.onEventCreated = onEventCreated
        _viewModel = StateObject(
            wrappedValue: CreateEventViewModel(creatorSkillLevel: creatorSkillLevel)
        )
    }

    var body: some View {
        Form {
            Section("Time") {
                DatePicker(
                    "Start",
                    selection: $viewModel.startTime,
                    displayedComponents: [.date, .hourAndMinute]
                )

                DatePicker(
                    "End",
                    selection: $viewModel.endTime,
                    displayedComponents: [.date, .hourAndMinute]
                )
            }

            Section("Event") {
                Picker("Type", selection: $viewModel.eventType) {
                    ForEach(EventType.allCases) { type in
                        Text(type.displayName).tag(type)
                    }
                }

                LabeledContent("Skill Level", value: viewModel.creatorSkillLevel.rawValue)
            }

            Section("Players") {
                Toggle("Limit players", isOn: $viewModel.hasPlayerLimit)

                if viewModel.hasPlayerLimit {
                    Stepper(
                        "Max players: \(viewModel.maxPlayers)",
                        value: $viewModel.maxPlayers,
                        in: 1...20
                    )
                } else {
                    Text("Unlimited players")
                        .foregroundStyle(.secondary)
                }
            }

            Section("Location") {
                Picker("City", selection: $viewModel.city) {
                    ForEach(EventCity.allCases) { city in
                        Text(city.displayName).tag(city)
                    }
                }

                Picker("Court", selection: $viewModel.court) {
                    ForEach(viewModel.city.courts) { court in
                        Text(court.displayName).tag(court)
                    }
                }
            }

            if let errorMessage = viewModel.errorMessage {
                Section {
                    Text(errorMessage)
                        .foregroundStyle(.red)
                }
            }
        }
        .navigationTitle("Create Event")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(viewModel.isSaving ? "Saving..." : "Save") {
                    Task {
                        guard let hostID = appState.supabaseSession?.user.id else {
                            return
                        }

                        if let event = await viewModel.save(hostID: hostID) {
                            onEventCreated(event)
                            dismiss()
                        }
                    }
                }
                .disabled(viewModel.isSaving)
            }
        }
    }
}

#Preview {
    NavigationStack {
        CreateEventView(creatorSkillLevel: .three)
            .environmentObject(AppState())
    }
}
