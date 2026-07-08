import SwiftUI

struct MyEventsView: View {
    @EnvironmentObject private var appState: AppState
    @StateObject private var viewModel = MyEventsViewModel()
    let onOpenProfile: () -> Void

    init(onOpenProfile: @escaping () -> Void = {}) {
        self.onOpenProfile = onOpenProfile
    }

    var body: some View {
        NavigationStack {
            ZStack {
                RallyDiscoverStyle.surface
                    .ignoresSafeArea()

                if viewModel.isLoading && viewModel.events.isEmpty {
                    ProgressView(AppContent.string("common.loadingEvents"))
                } else if let errorMessage = viewModel.errorMessage, viewModel.events.isEmpty {
                    ContentUnavailableView(
                        AppContent.string("common.unableToLoadEvents"),
                        systemImage: "exclamationmark.triangle",
                        description: Text(errorMessage)
                    )
                } else {
                    VStack(spacing: 0) {
                        myEventsHeader
                            .padding(.horizontal, 28)
                            .padding(.top, 18)

                        ScrollView {
                            LazyVStack(spacing: 28) {
                                if let errorMessage = viewModel.errorMessage {
                                    Text(errorMessage)
                                        .font(.footnote)
                                        .foregroundStyle(.red)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                }

                                if viewModel.events.isEmpty {
                                    ContentUnavailableView(
                                        AppContent.string("myEvents.empty.title"),
                                        systemImage: "calendar.badge.exclamationmark",
                                        description: Text(AppContent.string("myEvents.empty.description"))
                                    )
                                    .frame(maxWidth: .infinity)
                                    .padding(.top, 80)
                                } else {
                                    ForEach(viewModel.events) { event in
                                        VStack(spacing: 8) {
                                            NavigationLink {
                                                EventDetailView(event: event) { eventID in
                                                    viewModel.removeEvent(id: eventID)
                                                    appState.removeCachedEvent(eventID)
                                                }
                                            } label: {
                                                EventCardView(
                                                    event: event,
                                                    hostProfile: hostProfile(for: event),
                                                    hostDisplayNameOverride: hostDisplayNameOverride(for: event),
                                                    showsHostSocialTags: !isHostedByCurrentUser(event)
                                                )
                                            }
                                            .buttonStyle(.plain)
                                        }
                                    }
                                }
                            }
                            .padding(.horizontal, 13)
                            .padding(.top, 48)
                            .padding(.bottom, 24)
                            .frame(maxWidth: .infinity)
                        }
                        .scrollBounceBehavior(.always)
                        .refreshable {
                            refreshMyEvents(showsLoading: viewModel.events.isEmpty)
                        }
                    }
                }
            }
            .onAppear {
                Task {
                    await loadMyEvents(showsLoading: true)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar(.hidden, for: .navigationBar)
        }
    }

    private var myEventsHeader: some View {
        VStack(alignment: .leading, spacing: 34) {
            HStack {
                Button {
                    onOpenProfile()
                } label: {
                    Image("profile")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 40, height: 40)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(AppContent.string("common.profile"))

                Spacer()
            }

            Text(AppContent.string("myEvents.title"))
                .font(.system(size: 32, weight: .bold))
                .foregroundStyle(RallyDiscoverStyle.ink)
        }
    }

    private func loadMyEvents(showsLoading: Bool) async {
        if let eventIDs = await viewModel.loadEvents(
            currentUserID: appState.userProfile?.id,
            showsLoading: showsLoading
        ) {
            appState.updateCachedEvents(
                hostedEvents: eventIDs.hostedEvents,
                participatedEvents: eventIDs.participatedEvents
            )
        }
    }

    private func refreshMyEvents(showsLoading: Bool) {
        viewModel.refreshEvents(
            currentUserID: appState.userProfile?.id,
            showsLoading: showsLoading
        ) { eventIDs in
            if let eventIDs {
                appState.updateCachedEvents(
                    hostedEvents: eventIDs.hostedEvents,
                    participatedEvents: eventIDs.participatedEvents
                )
            }
        }
    }

    private func isHostedByCurrentUser(_ event: TennisEvent) -> Bool {
        event.hostID == appState.userProfile?.id
    }

    private func hostDisplayNameOverride(for event: TennisEvent) -> String? {
        isHostedByCurrentUser(event) ? AppContent.string("events.card.hostYou") : nil
    }

    private func hostProfile(for event: TennisEvent) -> UserProfile? {
        if isHostedByCurrentUser(event) {
            return viewModel.currentUserProfile ?? appState.userProfile
        }

        return viewModel.hostProfilesByID[event.hostID]
    }
}

#Preview {
    MyEventsView()
        .environmentObject(AppState())
}
