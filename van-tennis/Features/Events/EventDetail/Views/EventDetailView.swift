import SwiftUI

struct EventDetailView: View {
    let onEventCancelled: (UUID) -> Void

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var appState: AppState
    @State private var event: TennisEvent
    @StateObject private var viewModel = EventDetailViewModel()
    @State private var isShowingCancelConfirmation = false
    @State private var isShowingMaxPlayersEditor = false
    @State private var isShowingReportSheet = false
    @State private var isShowingReportSubmittedAlert = false
    @State private var isCancelling = false
    @State private var hasRequestedToJoin = false
    @State private var selectedReportReason: ReportReason = .harassment
    @State private var selectedReportedUserIDs: Set<UUID> = []
    @State private var reportDescription = ""
    @State private var reportErrorMessage: String?

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
                LabeledContent("Skill Level", value: event.skillLevel.rawValue)
                LabeledContent("Max Players", value: maxPlayersText)

                if !isEventEnded && isCurrentUserHost {
                    Button {
                        isShowingMaxPlayersEditor = true
                    } label: {
                        Label("Edit Max Players", systemImage: "person.2")
                    }
                    .disabled(isEventNotFound)
                }
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

            if !isEventEnded && canOpenChat {
                Section {
                    NavigationLink {
                        ChatRoomView(event: event)
                    } label: {
                        Label("Chat", systemImage: "message")
                            .frame(maxWidth: .infinity)
                    }
                    .disabled(isEventNotFound)
                }
            }

            if !isEventEnded && isCurrentUserHost {
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
                    .disabled(isCancelling || isEventNotFound)
                }
            }

            if !isEventEnded && canJoinEvent {
                Section {
                    Button {
                        Task {
                            await joinEvent()
                        }
                    } label: {
                        if viewModel.isJoining {
                            HStack {
                                Spacer()
                                ProgressView()
                                Spacer()
                            }
                        } else if hasRequestedToJoin {
                            Text("Waiting for host to approve")
                        } else {
                            Text("Join Event")
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .buttonStyle(.borderedProminent)
                    .disabled(viewModel.isJoining || hasRequestedToJoin || isEventNotFound)
                }
            }

            if !isEventEnded && isCurrentUserParticipant {
                Section {
                    Button(role: .destructive) {
                        Task {
                            await leaveEvent()
                        }
                    } label: {
                        if viewModel.isLeaving {
                            HStack {
                                Spacer()
                                ProgressView()
                                Spacer()
                            }
                        } else {
                            Text("Leave Event")
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .buttonStyle(.bordered)
                    .disabled(viewModel.isLeaving || isEventNotFound)
                }
            }

            if !isEventEnded && canReportEvent {
                Section {
                    Button(role: .destructive) {
                        prepareReportSheet()
                    } label: {
                        Text("Report Event")
                    }
                    .frame(maxWidth: .infinity)
                    .buttonStyle(.bordered)
                    .disabled(isEventNotFound)
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
            .disabled(isEventNotFound || isEventEnded)

            Button("Keep Event", role: .cancel) {}
        } message: {
            Text("This will delete the event and remove it from your hosted events.")
        }
        .task {
            await loadEventDetails()
        }
        .refreshable {
            await loadEventDetails()
        }
        .sheet(isPresented: $isShowingReportSheet) {
            ReportEventSheet(
                selectedReason: $selectedReportReason,
                selectedReportedUserIDs: $selectedReportedUserIDs,
                reportDescription: $reportDescription,
                errorMessage: reportErrorMessage,
                isSubmitting: viewModel.isSubmittingReport,
                reportableProfiles: reportableProfiles,
                currentUserID: appState.userProfile?.id,
                onSubmit: submitReport
            )
        }
        .sheet(isPresented: $isShowingMaxPlayersEditor) {
            EditMaxPlayersSheet(
                currentPlayerCount: event.playerCount,
                initialMaxPlayers: event.maxPlayers
            ) { maxPlayers in
                let updatedEvent = try await viewModel.updateMaxPlayers(
                    maxPlayers,
                    for: event
                )
                event = updatedEvent
                appState.applyUpdatedEvent(updatedEvent)
            }
        }
        .alert("Report Received", isPresented: $isShowingReportSubmittedAlert) {
            Button("OK") {}
        } message: {
            Text("We have received your report and will review it. We will notify you of the results.")
        }
    }

    private var isCurrentUserHost: Bool {
        appState.supabaseSession?.user.id == event.hostID
    }

    private var canJoinEvent: Bool {
        guard let currentUserID = appState.supabaseSession?.user.id else {
            return false
        }

        return event.hostID != currentUserID
            && !event.participants.contains(currentUserID)
            && !event.isFull
    }

    private var isCurrentUserParticipant: Bool {
        guard let currentUserID = appState.supabaseSession?.user.id else {
            return false
        }

        return event.participants.contains(currentUserID)
    }

    private var canReportEvent: Bool {
        (isCurrentUserHost && !event.participants.isEmpty) || isCurrentUserParticipant
    }

    private var canOpenChat: Bool {
        isCurrentUserHost || isCurrentUserParticipant
    }

    private var isEventNotFound: Bool {
        viewModel.errorMessage == EventDetailViewModelError.eventNotFound.errorDescription
    }

    private var isEventEnded: Bool {
        event.endTime <= Date()
    }

    private var reportableProfiles: [UserProfile] {
        var seenProfileIDs: Set<UUID> = []
        var profiles: [UserProfile] = []

        if let hostProfile = viewModel.hostProfile, seenProfileIDs.insert(hostProfile.id).inserted {
            profiles.append(hostProfile)
        }

        for participantProfile in viewModel.participantProfiles where seenProfileIDs.insert(participantProfile.id).inserted {
            profiles.append(participantProfile)
        }

        return profiles
    }

    private var maxPlayersText: String {
        guard let maxPlayers = event.maxPlayers else {
            return "Unlimited"
        }

        return "\(maxPlayers)"
    }

    private func loadEventDetails() async {
        guard let latestEvent = await viewModel.loadDetails(for: event) else {
            return
        }

        event = latestEvent
        hasRequestedToJoin = await viewModel.hasRequestedToJoin(
            event: latestEvent,
            currentUserID: appState.userProfile?.id
        )
    }

    private func prepareReportSheet() {
        selectedReportReason = .harassment
        selectedReportedUserIDs = []
        reportDescription = ""
        reportErrorMessage = nil
        isShowingReportSheet = true
    }

    private func submitReport() async {
        guard let currentUser = appState.userProfile else {
            reportErrorMessage = "No authenticated user was found."
            return
        }

        do {
            try await viewModel.submitReport(
                event: event,
                reporter: currentUser,
                reportedUserIDs: Array(selectedReportedUserIDs),
                reason: selectedReportReason,
                details: reportDescription
            )
            isShowingReportSheet = false
            isShowingReportSubmittedAlert = true
        } catch {
            reportErrorMessage = error.localizedDescription
        }
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

    private func joinEvent() async {
        guard let currentUser = appState.userProfile else {
            viewModel.errorMessage = "No authenticated user was found."
            return
        }

        do {
            try await viewModel.joinEvent(event, currentUser: currentUser)
            hasRequestedToJoin = true
        } catch {
            viewModel.errorMessage = error.localizedDescription
        }
    }

    private func leaveEvent() async {
        guard let currentUser = appState.userProfile else {
            viewModel.errorMessage = "No authenticated user was found."
            return
        }

        do {
            try await viewModel.leaveEvent(event, currentUser: currentUser)
            dismiss()
        } catch {
            viewModel.errorMessage = error.localizedDescription
        }
    }

    private static let dateTimeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()
}

private struct EditMaxPlayersSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var hasPlayerLimit: Bool
    @State private var maxPlayers: Int
    @State private var isSaving = false
    @State private var errorMessage: String?

    let currentPlayerCount: Int
    let onSave: (Int?) async throws -> Void

    init(
        currentPlayerCount: Int,
        initialMaxPlayers: Int?,
        onSave: @escaping (Int?) async throws -> Void
    ) {
        self.currentPlayerCount = currentPlayerCount
        self.onSave = onSave
        _hasPlayerLimit = State(initialValue: initialMaxPlayers != nil)
        _maxPlayers = State(initialValue: max(initialMaxPlayers ?? currentPlayerCount, currentPlayerCount))
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Player Limit") {
                    Toggle("Limit players", isOn: $hasPlayerLimit)

                    if hasPlayerLimit {
                        Stepper(
                            "Max players: \(maxPlayers)",
                            value: $maxPlayers,
                            in: currentPlayerCount...max(currentPlayerCount, 100)
                        )

                        Text("The event currently has \(currentPlayerCount) players including the host.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    } else {
                        Text("This event will allow unlimited players.")
                            .foregroundStyle(.secondary)
                    }
                }

                if let errorMessage {
                    Section {
                        Text(errorMessage)
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("Edit Max Players")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .disabled(isSaving)
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button(isSaving ? "Saving..." : "Save") {
                        Task {
                            await save()
                        }
                    }
                    .disabled(isSaving)
                }
            }
        }
    }

    private func save() async {
        isSaving = true
        errorMessage = nil

        do {
            try await onSave(hasPlayerLimit ? maxPlayers : nil)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }

        isSaving = false
    }
}

private struct ReportEventSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var selectedReason: ReportReason
    @Binding var selectedReportedUserIDs: Set<UUID>
    @Binding var reportDescription: String

    let errorMessage: String?
    let isSubmitting: Bool
    let reportableProfiles: [UserProfile]
    let currentUserID: UUID?
    let onSubmit: () async -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section("Reason") {
                    Picker("Reason", selection: $selectedReason) {
                        ForEach(ReportReason.allCases) { reason in
                            Text(reason.displayName).tag(reason)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                Section("Who to Report") {
                    if reportableProfiles.isEmpty {
                        Text("No players available")
                            .foregroundStyle(.secondary)
                    } else {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(reportableProfiles, id: \.id) { profile in
                                    reportProfileChip(profile)
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }

                Section("Details") {
                    TextEditor(text: $reportDescription)
                        .frame(minHeight: 120)
                }

                if let errorMessage {
                    Section {
                        Text(errorMessage)
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("Report Event")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .disabled(isSubmitting)
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button(isSubmitting ? "Submitting..." : "Submit") {
                        Task {
                            await onSubmit()
                        }
                    }
                    .disabled(isSubmitting || selectedReportedUserIDs.isEmpty || reportDescription.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }

    private func reportProfileChip(_ profile: UserProfile) -> some View {
        let isCurrentUser = profile.id == currentUserID
        let isSelected = selectedReportedUserIDs.contains(profile.id)

        return Button {
            guard !isCurrentUser else {
                return
            }

            if isSelected {
                selectedReportedUserIDs.remove(profile.id)
            } else {
                selectedReportedUserIDs.insert(profile.id)
            }
        } label: {
            HStack(spacing: 6) {
                Text(profile.displayName)
                    .font(.subheadline)

                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.caption)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .frame(minHeight: 36)
        }
        .buttonStyle(.bordered)
        .disabled(isCurrentUser)
        .opacity(isCurrentUser ? 0.45 : 1)
    }
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
