import SwiftUI

struct EventDetailView: View {
    let onEventCancelled: (UUID) -> Void

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var appState: AppState
    @State private var event: TennisEvent
    @StateObject private var viewModel = EventDetailViewModel()
    @State private var isShowingCancelConfirmation = false
    @State private var isShowingLeaveConfirmation = false
    @State private var isShowingReportSheet = false
    @State private var isShowingReportSubmittedAlert = false
    @State private var isCancelling = false
    @State private var hasRequestedToJoin = false
    @State private var selectedReportReasons: Set<ReportReason> = []
    @State private var selectedReportedUserIDs: Set<UUID> = []
    @State private var reportDescription = ""
    @State private var reportErrorMessage: String?
    @State private var pendingMaxPlayers: Int?

    init(
        event: TennisEvent,
        onEventCancelled: @escaping (UUID) -> Void = { _ in }
    ) {
        _event = State(initialValue: event)
        self.onEventCancelled = onEventCancelled
    }

    var body: some View {
        ZStack {
            RallyDiscoverStyle.surface
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 0) {
                    eventHero

                    detailSheet
                        .padding(.top, -34)
                }
                .padding(.bottom, 118)
            }
            .refreshable {
                await loadEventDetails()
            }
            .ignoresSafeArea(edges: .top)

            floatingBackButton
                .padding(.leading, 18)
                .padding(.top, 24)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
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
        .confirmationDialog(
            AppContent.string("events.detail.leaveEventTitle"),
            isPresented: $isShowingLeaveConfirmation,
            titleVisibility: .visible
        ) {
            Button(AppContent.string("events.detail.leaveEvent"), role: .destructive) {
                Task {
                    await leaveEvent()
                }
            }
            .disabled(isEventNotFound || isEventEnded)

            Button(AppContent.string("events.detail.stayEvent"), role: .cancel) {}
        } message: {
            Text(AppContent.string("events.detail.leaveConfirmation"))
        }
        .task {
            await loadEventDetails()
        }
        .sheet(isPresented: $isShowingReportSheet) {
            ReportEventView(
                selectedReasons: $selectedReportReasons,
                selectedReportedUserIDs: $selectedReportedUserIDs,
                reportDescription: $reportDescription,
                errorMessage: reportErrorMessage,
                isSubmitting: viewModel.isSubmittingReport,
                reportableProfiles: reportableProfiles,
                currentUserID: appState.userProfile?.id,
                onSubmit: submitReport
            )
        }
        .alert(AppContent.string("events.detail.reportReceivedTitle"), isPresented: $isShowingReportSubmittedAlert) {
            Button(AppContent.string("common.ok")) {}
        } message: {
            Text(AppContent.string("events.detail.reportReceivedMessage"))
        }
    }

    private var eventHero: some View {
        EventDetailHeroView(
            showsSaveButton: shouldShowSaveButton,
            showsReportButton: shouldShowReportButton,
            isReportButtonEnabled: isReportButtonEnabled,
            canSave: canSaveMaxPlayers,
            isSaving: viewModel.isUpdatingMaxPlayers,
            onReport: prepareReportSheet,
            onSave: {
                Task {
                    await savePendingMaxPlayers()
                }
            }
        )
        .frame(height: 430)
        .clipped()
    }

    private var floatingBackButton: some View {
        Button {
            dismiss()
        } label: {
            Image(systemName: "chevron.left")
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 44, height: 44)
                .background(Color.black.opacity(0.28), in: Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(AppContent.string("common.back"))
    }

    private var shouldShowSaveButton: Bool {
        !isEventEnded && isCurrentUserHost && !isEventNotFound
    }

    private var shouldShowReportButton: Bool {
        !isEventEnded && canReportEvent && !isEventNotFound
    }

    private var isReportButtonEnabled: Bool {
        !event.participants.isEmpty
    }

    private var canSaveMaxPlayers: Bool {
        guard let pendingMaxPlayers else {
            return false
        }

        return event.maxPlayers.map { $0 != pendingMaxPlayers } ?? true
    }

    private var displayedMaxPlayers: Int? {
        pendingMaxPlayers ?? event.maxPlayers
    }

    private var displayedPlayerCountText: String {
        guard let displayedMaxPlayers else {
            return "\(1 + event.participants.count) / Unlimited"
        }

        return "\(1 + event.participants.count) / \(displayedMaxPlayers)"
    }

    private var detailSheet: some View {
        VStack(alignment: .leading, spacing: 28) {
            RoundedRectangle(cornerRadius: 3)
                .fill(Color.black.opacity(0.18))
                .frame(width: 58, height: 5)
                .frame(maxWidth: .infinity)
                .padding(.top, 18)

            detailHeader

            EventDetailSpecGrid(
                specs: eventDetailSpecs,
                playersSpec: EventDetailSpec(
                    title: AppContent.string("events.detail.players"),
                    value: displayedPlayerCountText,
                    systemImage: "person.2"
                ),
                canEditPlayers: !isEventEnded && isCurrentUserHost && !isEventNotFound,
                playerCount: event.playerCount,
                maxPlayers: displayedMaxPlayers,
                isUpdatingPlayers: viewModel.isUpdatingMaxPlayers,
                onSelectMaxPlayers: stageMaxPlayers
            )

            VStack(alignment: .leading, spacing: 14) {
                detailInfoRow(
                    title: AppContent.string("events.detail.start"),
                    value: Self.dateTimeFormatter.string(from: event.startTime),
                    systemImage: "clock"
                )

                detailInfoRow(
                    title: AppContent.string("events.detail.end"),
                    value: Self.dateTimeFormatter.string(from: event.endTime),
                    systemImage: "clock.badge.checkmark"
                )

                detailInfoRow(
                    title: AppContent.string("events.detail.city"),
                    value: event.city.displayName,
                    imageName: "pin_drop"
                )
            }

            playerSection

            stateSection

            actionSection
        }
        .padding(.horizontal, 30)
        .padding(.bottom, 34)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 34, style: .continuous)
                .fill(Color.white)
                .shadow(color: RallyDiscoverStyle.shadow.opacity(0.34), radius: 18, x: 0, y: -4)
        )
    }

    private var detailHeader: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Text(event.court.displayName)
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(RallyDiscoverStyle.ink)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)

                Spacer(minLength: 10)

                Text(event.skillLevel.rawValue)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(minWidth: 71)
                    .padding(.horizontal, 8)
                    .frame(height: 22)
                    .background(skillLevelBadgeColor, in: Capsule())
            }

            Text(detailSummaryText)
                .font(.system(size: 17, weight: .medium))
                .foregroundStyle(RallyDiscoverStyle.mutedText)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var playerSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            EventDetailSectionTitle(AppContent.string("events.host.title"))

            if let hostProfile = viewModel.hostProfile {
                EventDetailProfileCard(
                    profile: hostProfile,
                    fallbackTitle: AppContent.string("events.host.fallback"),
                    titleSuffix: isCurrentUserHost ? AppContent.string("events.participants.you") : nil
                )
            } else {
                EventDetailUnavailableProfileCard(text: AppContent.string("events.host.unavailable"))
            }

            EventDetailSectionTitle(AppContent.string("events.participants.title"))
                .padding(.top, 8)

            if viewModel.participantProfiles.isEmpty {
                Text(AppContent.string("events.participants.none"))
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(RallyDiscoverStyle.mutedText)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(16)
                    .background(RallyDiscoverStyle.surface, in: RoundedRectangle(cornerRadius: 16))
            } else {
                VStack(spacing: 10) {
                    ForEach(viewModel.participantProfiles, id: \.id) { participant in
                        EventDetailProfileCard(
                            profile: participant,
                            fallbackTitle: AppContent.string("events.participants.fallback"),
                            titleSuffix: participant.id == appState.userProfile?.id ? AppContent.string("events.participants.you") : nil
                        )
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var stateSection: some View {
        if viewModel.isLoading {
            HStack {
                Spacer()
                ProgressView()
                Spacer()
            }
            .padding(.vertical, 8)
        }

        if let errorMessage = viewModel.errorMessage {
            Text(errorMessage)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.red)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(12)
                .background(Color.red.opacity(0.08), in: RoundedRectangle(cornerRadius: 14))
        }
    }

    private var actionSection: some View {
        VStack(spacing: 12) {
            if !isEventEnded && canOpenChat {
                NavigationLink {
                    ChatRoomView(event: event)
                } label: {
                    HStack(spacing: 8) {
                        Image("chat_filled")
                            .resizable()
                            .renderingMode(.template)
                            .scaledToFit()
                            .frame(width: 24, height: 24)

                        Text(AppContent.string("events.detail.chat"))
                    }
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(EventDetailChatButtonStyle())
                .disabled(isEventNotFound)
            }

            if !isEventEnded && canJoinEvent {
                Button {
                    Task {
                        await joinEvent()
                    }
                } label: {
                    if viewModel.isJoining {
                        ProgressView()
                            .tint(.white)
                            .frame(maxWidth: .infinity)
                    } else if hasRequestedToJoin {
                        Text(AppContent.string("events.detail.waitingApproval"))
                            .frame(maxWidth: .infinity)
                    } else {
                        Text(AppContent.string("events.detail.joinEvent"))
                            .frame(maxWidth: .infinity)
                    }
                }
                .buttonStyle(EventDetailPrimaryButtonStyle())
                .disabled(viewModel.isJoining || hasRequestedToJoin || isEventNotFound)
            }

            if !isEventEnded && isCurrentUserHost {
                Button(role: .destructive) {
                    isShowingCancelConfirmation = true
                } label: {
                    if isCancelling {
                        ProgressView()
                            .tint(.white)
                            .frame(maxWidth: .infinity)
                    } else {
                        HStack(spacing: 8) {
                            Image("disabled_by_default")
                                .resizable()
                                .renderingMode(.template)
                                .scaledToFit()
                                .frame(width: 22, height: 22)

                            Text(AppContent.string("events.detail.cancelEvent"))
                        }
                            .frame(maxWidth: .infinity)
                    }
                }
                .buttonStyle(EventDetailCancelButtonStyle())
                .disabled(isCancelling || isEventNotFound)
            }

            if !isEventEnded && isCurrentUserParticipant {
                Button(role: .destructive) {
                    isShowingLeaveConfirmation = true
                } label: {
                    if viewModel.isLeaving {
                        ProgressView()
                            .tint(.white)
                            .frame(maxWidth: .infinity)
                    } else {
                        HStack(spacing: 8) {
                            Image("login_white")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 22, height: 22)

                            Text(AppContent.string("events.detail.leaveEvent"))
                        }
                            .frame(maxWidth: .infinity)
                    }
                }
                .buttonStyle(EventDetailCancelButtonStyle())
                .disabled(viewModel.isLeaving || isEventNotFound)
            }

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
        isCurrentUserHost || isCurrentUserParticipant
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

    private var eventDetailSpecs: [EventDetailSpec] {
        [
            EventDetailSpec(
                title: detailDateTitle,
                value: detailStartTimeText,
                systemImage: "calendar"
            ),
            EventDetailSpec(
                title: AppContent.string("events.detail.court"),
                value: event.court.displayName,
                systemImage: "sportscourt"
            ),
            EventDetailSpec(
                title: AppContent.string("events.detail.type"),
                value: event.eventType.displayName,
                imageName: "playing_tennis"
            )
        ]
    }

    private var detailSummaryText: String {
        AppContent.string(
            "events.card.hostLabel",
            viewModel.hostProfile?.displayName ?? AppContent.string("events.card.hostFallback")
        )
    }

    private var detailDateTitle: String {
        let calendar = Calendar.current

        if calendar.isDateInToday(event.startTime) {
            return AppContent.string("events.card.today")
        }

        if calendar.isDateInTomorrow(event.startTime) {
            return AppContent.string("events.card.tomorrow")
        }

        return Self.shortDateFormatter.string(from: event.startTime)
    }

    private var detailStartTimeText: String {
        Self.timeFormatter.string(from: event.startTime)
    }

    private var skillLevelBadgeColor: Color {
        Constants.SkillLevelStyle.badgeColor(for: event.skillLevel)
    }

    private func detailInfoRow(title: String, value: String, systemImage: String? = nil, imageName: String? = nil) -> some View {
        HStack(spacing: 12) {
            detailInfoIcon(systemImage: systemImage, imageName: imageName)

            Text(title)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(RallyDiscoverStyle.mutedText)

            Spacer(minLength: 10)

            Text(value)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(RallyDiscoverStyle.ink)
                .multilineTextAlignment(.trailing)
        }
        .padding(.vertical, 2)
    }

    @ViewBuilder
    private func detailInfoIcon(systemImage: String?, imageName: String?) -> some View {
        if let imageName {
            Image(imageName)
                .resizable()
                .renderingMode(.template)
                .scaledToFit()
                .foregroundStyle(.black)
                .frame(width: 26, height: 26)
                .accessibilityHidden(true)
        } else if let systemImage {
            Image(systemName: systemImage)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(.black)
                .frame(width: 26)
        }
    }

    private func loadEventDetails() async {
        guard let latestEvent = await viewModel.loadDetails(for: event) else {
            return
        }

        event = latestEvent
        pendingMaxPlayers = nil
        hasRequestedToJoin = await viewModel.hasRequestedToJoin(
            event: latestEvent,
            currentUserID: appState.userProfile?.id
        )
    }

    private func prepareReportSheet() {
        guard isReportButtonEnabled else {
            return
        }

        selectedReportReasons = []
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
                reasons: Array(selectedReportReasons),
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

    private func stageMaxPlayers(_ maxPlayers: Int) {
        pendingMaxPlayers = maxPlayers
    }

    private func savePendingMaxPlayers() async {
        guard let pendingMaxPlayers, canSaveMaxPlayers else {
            return
        }

        do {
            let updatedEvent = try await viewModel.updateMaxPlayers(pendingMaxPlayers, for: event)
            event = updatedEvent
            self.pendingMaxPlayers = nil
            appState.applyUpdatedEvent(updatedEvent)
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

    private static let shortDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter
    }()

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return formatter
    }()
}

private struct EventDetailHeroView: View {
    let showsSaveButton: Bool
    let showsReportButton: Bool
    let isReportButtonEnabled: Bool
    let canSave: Bool
    let isSaving: Bool
    let onReport: () -> Void
    let onSave: () -> Void

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .top) {
                Image("login")
                    .resizable()
                    .scaledToFill()
                    .frame(width: geometry.size.width, height: geometry.size.height + 48)
                    .offset(y: 24)
                    .clipped()

                EventDetailTopBarView(
                    showsSaveButton: showsSaveButton,
                    showsReportButton: showsReportButton,
                    isReportButtonEnabled: isReportButtonEnabled,
                    canSave: canSave,
                    isSaving: isSaving,
                    onReport: onReport,
                    onSave: onSave
                )
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
            .clipped()
        }
    }
}

private struct EventDetailTopBarView: View {
    let showsSaveButton: Bool
    let showsReportButton: Bool
    let isReportButtonEnabled: Bool
    let canSave: Bool
    let isSaving: Bool
    let onReport: () -> Void
    let onSave: () -> Void

    var body: some View {
        HStack {
            Spacer()

            if showsReportButton {
                Button {
                    onReport()
                } label: {
                    HStack(spacing: 6) {
                        Image("flag")
                            .resizable()
                            .renderingMode(.template)
                            .scaledToFit()
                            .frame(width: 16, height: 16)

                        Text(AppContent.string("events.detail.reportButton"))
                            .lineLimit(1)
                    }
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 14)
                    .frame(height: 34)
                    .background(
                        isReportButtonEnabled
                            ? Color(red: 250 / 255, green: 71 / 255, blue: 32 / 255)
                            : Color.black.opacity(0.28),
                        in: Capsule()
                    )
                }
                .buttonStyle(.plain)
                .disabled(!isReportButtonEnabled)
            }

            if showsSaveButton {
                Button {
                    onSave()
                } label: {
                    Text(isSaving ? AppContent.string("common.saving") : AppContent.string("common.save"))
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 18)
                        .frame(height: 34)
                        .background(canSave ? RallyDiscoverStyle.primaryGreen : Color.black.opacity(0.28), in: Capsule())
                }
                .buttonStyle(.plain)
                .disabled(!canSave || isSaving)
            }
        }
        .padding(.horizontal, 18)
        .padding(.top, 72)
        .frame(maxWidth: .infinity, alignment: .top)
    }
}

private struct EventDetailSpec: Identifiable {
    let id = UUID()
    let title: String
    let value: String
    let systemImage: String?
    let imageName: String?

    init(title: String, value: String, systemImage: String? = nil, imageName: String? = nil) {
        self.title = title
        self.value = value
        self.systemImage = systemImage
        self.imageName = imageName
    }
}

private struct EventDetailSpecGrid: View {
    let specs: [EventDetailSpec]
    let playersSpec: EventDetailSpec
    let canEditPlayers: Bool
    let playerCount: Int
    let maxPlayers: Int?
    let isUpdatingPlayers: Bool
    let onSelectMaxPlayers: (Int) -> Void

    var body: some View {
        LazyVGrid(
            columns: Array(repeating: GridItem(.flexible(), spacing: 14), count: 2),
            spacing: 14
        ) {
            ForEach(specs) { spec in
                EventDetailSpecCard(spec: spec)
            }

            EventDetailPlayersSpecCard(
                spec: playersSpec,
                canEdit: canEditPlayers,
                playerCount: playerCount,
                maxPlayers: maxPlayers,
                isUpdating: isUpdatingPlayers,
                onSelectMaxPlayers: onSelectMaxPlayers
            )
        }
    }
}

private struct EventDetailSpecCard: View {
    let spec: EventDetailSpec

    var body: some View {
        VStack(spacing: 8) {
            icon
                .frame(height: 22)

            Text(spec.title)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(RallyDiscoverStyle.mutedText)
                .lineLimit(1)

            Text(spec.value)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(RallyDiscoverStyle.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.74)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 78)
        .padding(.horizontal, 8)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(.white)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color(red: 0.88, green: 0.90, blue: 0.84), lineWidth: 1)
        )
    }

    @ViewBuilder
    private var icon: some View {
        if let imageName = spec.imageName {
            Image(imageName)
                .resizable()
                .renderingMode(.template)
                .scaledToFit()
                .foregroundStyle(.black)
                .frame(width: 22, height: 22)
                .accessibilityHidden(true)
        } else if let systemImage = spec.systemImage {
            Image(systemName: systemImage)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(.black)
        }
    }
}

private struct EventDetailPlayersSpecCard: View {
    let spec: EventDetailSpec
    let canEdit: Bool
    let playerCount: Int
    let maxPlayers: Int?
    let isUpdating: Bool
    let onSelectMaxPlayers: (Int) -> Void

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: spec.systemImage ?? "person.2")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(.black)
                .frame(height: 22)

            Text(spec.title)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(RallyDiscoverStyle.mutedText)
                .lineLimit(1)

            HStack(spacing: 6) {
                Text(spec.value)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(RallyDiscoverStyle.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.74)

                if canEdit {
                    playerLimitMenu
                }
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 78)
        .padding(.horizontal, 8)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(.white)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color(red: 0.88, green: 0.90, blue: 0.84), lineWidth: 1)
        )
    }

    private var playerLimitMenu: some View {
        Menu {
            ForEach(availablePlayerLimits, id: \.self) { playerLimit in
                Button {
                    onSelectMaxPlayers(playerLimit)
                } label: {
                    if maxPlayers == playerLimit {
                        Label("\(playerLimit)", systemImage: "checkmark")
                    } else {
                        Text("\(playerLimit)")
                    }
                }
            }
        } label: {
            if isUpdating {
                ProgressView()
                    .controlSize(.small)
            } else {
                Image("pencil")
                    .resizable()
                    .renderingMode(.template)
                    .scaledToFit()
                    .foregroundStyle(.black)
                    .frame(width: 14, height: 14)
                    .accessibilityLabel(AppContent.string("events.detail.editMaxPlayers"))
            }
        }
        .disabled(isUpdating)
    }

    private var availablePlayerLimits: [Int] {
        let lowerBound = max(playerCount, Constants.Event.minimumPlayerLimit)
        let upperBound = max(lowerBound, Constants.Event.maximumPlayerLimit)
        return Array(lowerBound...upperBound)
    }
}

private struct EventDetailSectionTitle: View {
    let title: String

    init(_ title: String) {
        self.title = title
    }

    var body: some View {
        Text(title)
            .font(.system(size: 17, weight: .bold))
            .foregroundStyle(RallyDiscoverStyle.ink)
    }
}

private struct EventDetailProfileCard: View {
    let profile: UserProfile
    let fallbackTitle: String
    let titleSuffix: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(displayTitle)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(RallyDiscoverStyle.ink)

                Spacer(minLength: 8)

                Text(profile.skillLevel?.rawValue ?? AppContent.string("events.host.skillNotSet"))
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(minWidth: 71)
                    .padding(.horizontal, 8)
                    .frame(height: 22)
                    .background(skillLevelBadgeColor, in: Capsule())
            }

            if !profile.socialTags.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(profile.socialTags, id: \.self) { tag in
                            Text(tag)
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 10)
                                .frame(height: 22)
                                .background(RallyDiscoverStyle.accentGreen, in: Capsule())
                        }
                    }
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RallyDiscoverStyle.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var displayTitle: String {
        let title = profile.displayName.isEmpty ? fallbackTitle : profile.displayName

        guard let titleSuffix else {
            return title
        }

        return "\(title) \(titleSuffix)"
    }

    private var skillLevelBadgeColor: Color {
        Constants.SkillLevelStyle.badgeColor(for: profile.skillLevel)
    }
}

private struct EventDetailUnavailableProfileCard: View {
    let text: String

    var body: some View {
        Label(text, systemImage: "person.crop.circle.badge.questionmark")
            .font(.system(size: 15, weight: .medium))
            .foregroundStyle(RallyDiscoverStyle.mutedText)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .background(RallyDiscoverStyle.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

private struct EventDetailPrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 16, weight: .semibold))
            .foregroundStyle(.white)
            .frame(minHeight: 52)
            .padding(.horizontal, 18)
            .background(RallyDiscoverStyle.primaryGreen.opacity(configuration.isPressed ? 0.78 : 1), in: Capsule())
    }
}

private struct EventDetailChatButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 16, weight: .semibold))
            .foregroundStyle(.black)
            .frame(minHeight: 52)
            .padding(.horizontal, 18)
            .background(Color(red: 0.97, green: 0.97, blue: 0.96).opacity(configuration.isPressed ? 0.72 : 1))
            .clipShape(Capsule())
            .shadow(color: RallyDiscoverStyle.shadow.opacity(0.95), radius: 18, x: 0, y: 8)
            .shadow(color: Color.black.opacity(0.05), radius: 6, x: 0, y: 2)
    }
}

private struct EventDetailSecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 16, weight: .semibold))
            .foregroundStyle(RallyDiscoverStyle.ink)
            .frame(minHeight: 52)
            .padding(.horizontal, 18)
            .background(RallyDiscoverStyle.surface.opacity(configuration.isPressed ? 0.72 : 1), in: RoundedRectangle(cornerRadius: 16))
    }
}

private struct EventDetailDestructiveButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 16, weight: .semibold))
            .foregroundStyle(.red)
            .frame(minHeight: 52)
            .padding(.horizontal, 18)
            .background(Color.red.opacity(configuration.isPressed ? 0.16 : 0.10), in: Capsule())
    }
}

private struct EventDetailCancelButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 16, weight: .semibold))
            .foregroundStyle(.white)
            .frame(minHeight: 52)
            .padding(.horizontal, 18)
            .background(Color(red: 0.98, green: 0.28, blue: 0.13).opacity(configuration.isPressed ? 0.82 : 1), in: Capsule())
    }
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
