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
            Section(AppContent.string("events.detail.event")) {
                LabeledContent(AppContent.string("events.detail.type"), value: event.eventType.displayName)
                LabeledContent(AppContent.string("events.create.skillLevel"), value: event.skillLevel.rawValue)
                LabeledContent(AppContent.string("events.detail.players"), value: maxPlayersText)

                if !isEventEnded && isCurrentUserHost {
                    Button {
                        isShowingMaxPlayersEditor = true
                    } label: {
                        Label(AppContent.string("events.detail.editMaxPlayers"), systemImage: "person.2")
                    }
                    .disabled(isEventNotFound)
                }
            }

            Section(AppContent.string("events.detail.time")) {
                LabeledContent(AppContent.string("events.detail.start"), value: Self.dateTimeFormatter.string(from: event.startTime))
                LabeledContent(AppContent.string("events.detail.end"), value: Self.dateTimeFormatter.string(from: event.endTime))
            }

            Section(AppContent.string("events.detail.location")) {
                LabeledContent(AppContent.string("events.detail.city"), value: event.city.displayName)
                LabeledContent(AppContent.string("events.detail.court"), value: event.court.displayName)
            }

            HostSummaryView(host: viewModel.hostProfile)
            ParticipantListView(
                participants: viewModel.participantProfiles,
                currentUserID: appState.userProfile?.id
            )

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
                        Label(AppContent.string("events.detail.chat"), systemImage: "message")
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
                            Text(AppContent.string("events.detail.cancelEvent"))
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
                            Text(AppContent.string("events.detail.waitingApproval"))
                        } else {
                            Text(AppContent.string("events.detail.joinEvent"))
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
                            Text(AppContent.string("events.detail.leaveEvent"))
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
                        Text(AppContent.string("events.detail.reportEvent"))
                    }
                    .frame(maxWidth: .infinity)
                    .buttonStyle(.bordered)
                    .disabled(isEventNotFound)
                }
            }
        }
        .navigationTitle(AppContent.string("events.detail.title"))
        .navigationBarTitleDisplayMode(.inline)
        .confirmationDialog(
            AppContent.string("events.detail.cancelEventTitle"),
            isPresented: $isShowingCancelConfirmation,
            titleVisibility: .visible
        ) {
            Button(AppContent.string("events.detail.cancelEvent"), role: .destructive) {
                Task {
                    await cancelEvent()
                }
            }
            .disabled(isEventNotFound || isEventEnded)

            Button(AppContent.string("events.detail.keepEvent"), role: .cancel) {}
        } message: {
            Text(AppContent.string("events.detail.cancelConfirmation"))
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
        .alert(AppContent.string("events.detail.reportReceivedTitle"), isPresented: $isShowingReportSubmittedAlert) {
            Button(AppContent.string("common.ok")) {}
        } message: {
            Text(AppContent.string("events.detail.reportReceivedMessage"))
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
            return "\(1 + event.participants.count) / Unlimited"
        }

        return "\(1 + event.participants.count) / \(maxPlayers)"
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
            reportErrorMessage = AppContent.string("errors.noAuthenticatedUser")
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
            viewModel.errorMessage = AppContent.string("errors.noAuthenticatedUser")
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
            viewModel.errorMessage = AppContent.string("errors.noAuthenticatedUser")
            return
        }

        do {
            try await viewModel.leaveEvent(event, currentUser: currentUser)
            appState.removeCachedEvent(event.id)
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
                Section(AppContent.string("events.create.players")) {
                    Toggle(AppContent.string("events.create.limitPlayers"), isOn: $hasPlayerLimit)

                    if hasPlayerLimit {
                        Stepper(
                            AppContent.string("events.create.maxPlayers", maxPlayers),
                            value: $maxPlayers,
                            in: currentPlayerCount...max(
                                currentPlayerCount,
                                Constants.Event.maximumPlayerLimit
                            )
                        )

                        Text(AppContent.string("events.detail.editMaxPlayersInfo", currentPlayerCount))
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    } else {
                        Text(AppContent.string("events.detail.unlimitedPlayersInfo"))
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
            .navigationTitle(AppContent.string("events.detail.editMaxPlayers"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(AppContent.string("common.cancel")) {
                        dismiss()
                    }
                    .disabled(isSaving)
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button(isSaving ? AppContent.string("common.saving") : AppContent.string("common.save")) {
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
                Section(AppContent.string("events.detail.reportReason")) {
                    Picker(AppContent.string("events.detail.reportReason"), selection: $selectedReason) {
                        ForEach(ReportReason.allCases) { reason in
                            Text(reason.displayName).tag(reason)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                Section(AppContent.string("events.detail.reportWho")) {
                    if reportableProfiles.isEmpty {
                        Text(AppContent.string("events.detail.noReportablePlayers"))
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

                Section {
                    TextEditor(text: $reportDescription)
                        .frame(minHeight: 120)
                } header: {
                    HStack {
                        Text(AppContent.string("events.detail.reportDetails"))

                        Spacer()

                        Text(AppContent.string("events.detail.optional"))
                            .font(.caption)
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
            .navigationTitle(AppContent.string("events.detail.reportEvent"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(AppContent.string("common.cancel")) {
                        dismiss()
                    }
                    .disabled(isSubmitting)
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button(isSubmitting ? AppContent.string("events.detail.submitting") : AppContent.string("events.detail.submit")) {
                        Task {
                            await onSubmit()
                        }
                    }
                    .disabled(isSubmitting || selectedReportedUserIDs.isEmpty)
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
