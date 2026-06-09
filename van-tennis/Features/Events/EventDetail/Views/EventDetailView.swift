import SwiftUI

struct EventDetailView: View {
    let onEventCancelled: (UUID) -> Void

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var appState: AppState
    @State private var event: TennisEvent
    @StateObject private var viewModel = EventDetailViewModel()
    @State private var isShowingCancelConfirmation = false
    @State private var isCancelling = false

    init(
        event: TennisEvent,
        onEventCancelled: @escaping (UUID) -> Void = { _ in }
    ) {
        _event = State(initialValue: event)
        self.onEventCancelled = onEventCancelled
    }

    var body: some View {
        Form {
            Section("Event") {
                LabeledContent("Type", value: event.eventType.displayName)
                LabeledContent("Status", value: event.status.displayName)
                LabeledContent("Skill Level", value: event.skillLevel.rawValue)
                LabeledContent("Max Players", value: maxPlayersText)
            }

            Section("Time") {
                LabeledContent("Start", value: Self.dateTimeFormatter.string(from: event.startTime))
                LabeledContent("End", value: Self.dateTimeFormatter.string(from: event.endTime))
            }

            Section("Location") {
                LabeledContent("City", value: event.city.displayName)
                LabeledContent("Court", value: event.court.displayName)
            }

            HostSummaryView(host: viewModel.hostProfile)
            ParticipantListView(participants: viewModel.participantProfiles)

            Section("Event ID") {
                Text(event.id.uuidString)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
            }

            if viewModel.isLoading {
                Section {
                    HStack {
                        Spacer()
                        ProgressView()
                        Spacer()
                    }
                }
            }

            if let errorMessage = viewModel.errorMessage {
                Section {
                    Text(errorMessage)
                        .foregroundStyle(.red)
                }
            }

            if isCurrentUserHost {
                Section {
                    Button(role: .destructive) {
                        isShowingCancelConfirmation = true
                    } label: {
                        if isCancelling {
                            HStack {
                                Spacer()
                                ProgressView()
                                Spacer()
                            }
                        } else {
                            Text("Cancel Event")
                        }
                    }
                    .disabled(isCancelling)
                }
            }

            if canJoinEvent {
                Section {
                    Button("Join Event") {
                        // TODO: Implement join event action.
                    }
                    .frame(maxWidth: .infinity)
                    .buttonStyle(.borderedProminent)
                }
            }
        }
        .navigationTitle("Event Detail")
        .navigationBarTitleDisplayMode(.inline)
        .confirmationDialog(
            "Cancel this event?",
            isPresented: $isShowingCancelConfirmation,
            titleVisibility: .visible
        ) {
            Button("Cancel Event", role: .destructive) {
                Task {
                    await cancelEvent()
                }
            }

            Button("Keep Event", role: .cancel) {}
        } message: {
            Text("This will delete the event and remove it from your hosted events.")
        }
        .task {
            await viewModel.loadDetails(for: event)
        }
        .refreshable {
            await viewModel.loadDetails(for: event)
        }
    }

    private var isCurrentUserHost: Bool {
        appState.supabaseSession?.user.id == event.hostID
    }

    private var canJoinEvent: Bool {
        guard let currentUserID = appState.supabaseSession?.user.id else {
            return false
        }

        return event.hostID != currentUserID && !event.participants.contains(currentUserID)
    }

    private var maxPlayersText: String {
        guard let maxPlayers = event.maxPlayers else {
            return "Unlimited"
        }

        return "\(maxPlayers)"
    }

    private func cancelEvent() async {
        isCancelling = true
        viewModel.errorMessage = nil

        do {
            try await appState.cancelHostedEvent(event)
            onEventCancelled(event.id)
            dismiss()
        } catch {
            viewModel.errorMessage = error.localizedDescription
        }

        isCancelling = false
    }

    private static let dateTimeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()
}

#Preview {
    NavigationStack {
        EventDetailView(
            event: TennisEvent(
                id: UUID(),
                hostID: UUID(),
                startTime: Date(),
                endTime: Calendar.current.date(byAdding: .hour, value: 2, to: Date()) ?? Date(),
                eventType: .practice,
                maxPlayers: 4,
                city: .burnaby,
                court: .bcitCourt,
                skillLevel: .three,
                status: .upcoming,
                participants: [UUID()],
                createdAt: nil,
                updatedAt: nil
            )
        )
        .environmentObject(AppState())
    }
}
