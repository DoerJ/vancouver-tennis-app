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
                        .rallyLoadingStatusStyle()
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
                                    RallyEmptyState(
                                        iconName: "playing_tennis",
                                        title: AppContent.string("myEvents.empty.title"),
                                        description: AppContent.string("myEvents.empty.description"),
                                        titleFontSize: 17,
                                        descriptionFontSize: 15
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
                                                    hostProfile: viewModel.hostProfile(
                                                        for: event,
                                                        currentUserProfile: appState.userProfile
                                                    ),
                                                    hostDisplayNameOverride: viewModel.hostDisplayNameOverride(
                                                        for: event,
                                                        currentUserID: appState.userProfile?.id
                                                    ),
                                                    showsHostSocialTags: !viewModel.isHostedByCurrentUser(
                                                        event,
                                                        currentUserID: appState.userProfile?.id
                                                    )
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
                            viewModel.refreshEvents(appState: appState, showsLoading: viewModel.events.isEmpty)
                        }
                    }
                }
            }
            .onAppear {
                Task {
                    await viewModel.loadEvents(appState: appState, showsLoading: true)
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

}

#Preview {
    MyEventsView()
        .environmentObject(AppState())
}
