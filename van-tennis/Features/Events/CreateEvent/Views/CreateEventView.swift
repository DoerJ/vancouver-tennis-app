import SwiftUI

struct CreateEventView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var appState: AppState
    @StateObject private var viewModel: CreateEventViewModel
    @State private var isPreparingToSave = false
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
            Section(AppContent.string("events.create.time")) {
                DatePicker(
                    AppContent.string("events.create.start"),
                    selection: $viewModel.startTime,
                    in: viewModel.earliestAllowedStartTime...viewModel.latestAllowedStartTime,
                    displayedComponents: [.date, .hourAndMinute]
                )

                DatePicker(
                    AppContent.string("events.create.end"),
                    selection: $viewModel.endTime,
                    in: viewModel.earliestAllowedEndTime...viewModel.latestAllowedEndTime,
                    displayedComponents: [.date, .hourAndMinute]
                )
            }

            Section(AppContent.string("events.create.event")) {
                Picker(AppContent.string("events.create.type"), selection: $viewModel.eventType) {
                    ForEach(EventType.allCases) { type in
                        Text(type.displayName).tag(type)
                    }
                }

                LabeledContent(AppContent.string("events.create.skillLevel"), value: viewModel.creatorSkillLevel.rawValue)
            }

            Section(AppContent.string("events.create.players")) {
                Toggle(AppContent.string("events.create.limitPlayers"), isOn: $viewModel.hasPlayerLimit)

                if viewModel.hasPlayerLimit {
                    Stepper(
                        AppContent.string("events.create.maxPlayers", viewModel.maxPlayers),
                        value: $viewModel.maxPlayers,
                        in: Constants.Event.minimumPlayerLimit...Constants.Event.maximumPlayerLimit
                    )
                } else {
                    Text(AppContent.string("events.create.unlimitedPlayers"))
                        .foregroundStyle(.secondary)
                }
            }

            Section(AppContent.string("events.create.location")) {
                Picker(AppContent.string("events.create.city"), selection: $viewModel.city) {
                    ForEach(EventCity.allCases) { city in
                        Text(city.displayName).tag(city)
                    }
                }

                Picker(AppContent.string("events.create.court"), selection: $viewModel.court) {
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
        .navigationTitle(AppContent.string("events.create.title"))
        .onChange(of: viewModel.startTime) { newStartTime in
            let earliestEndTime = Calendar.current.date(
                byAdding: .minute,
                value: Constants.Event.minimumDurationMinutes,
                to: newStartTime
            ) ?? newStartTime

            if viewModel.endTime < earliestEndTime {
                viewModel.endTime = earliestEndTime
            }

            let latestEndTime = Calendar.current.date(
                byAdding: .hour,
                value: Constants.Event.maximumDurationHours,
                to: newStartTime
            ) ?? newStartTime

            if viewModel.endTime > latestEndTime {
                viewModel.endTime = latestEndTime
            }
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(isSaving ? AppContent.string("common.saving") : AppContent.string("common.save")) {
                    Task {
                        guard !isSaving else {
                            return
                        }

                        guard appState.supabaseSession != nil else {
                            return
                        }

                        isPreparingToSave = true
                        defer {
                            isPreparingToSave = false
                        }

                        do {
                            let activeHostedEvents = try await appState.activeHostedEventsForCurrentUser()

                            guard let event = await viewModel.save(activeHostedEvents: activeHostedEvents) else {
                                return
                            }

                            appState.updateCachedEvents([event])
                            try await appState.appendHostedEvent(event.id)
                            onEventCreated(event)
                            dismiss()
                        } catch {
                            viewModel.errorMessage = error.localizedDescription
                        }
                    }
                }
                .disabled(isSaving)
            }
        }
    }

    private var isSaving: Bool {
        isPreparingToSave || viewModel.isSaving
    }
}

#Preview {
    NavigationStack {
        CreateEventView(creatorSkillLevel: .three)
            .environmentObject(AppState())
    }
}
