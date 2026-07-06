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
            Group {
                if viewModel.isLoading && viewModel.events.isEmpty {
                    ProgressView(AppContent.string("common.loadingEvents"))
                } else if let errorMessage = viewModel.errorMessage, viewModel.events.isEmpty {
                    ContentUnavailableView(
                        AppContent.string("common.unableToLoadEvents"),
                        systemImage: "exclamationmark.triangle",
                        description: Text(errorMessage)
                    )
                } else {
                    ScrollView {
                        LazyVStack(spacing: 12) {
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
                                            EventCardView(event: event)
                                        }
                                        .buttonStyle(.plain)

                                    }
                                }
                            }
                        }
                        .padding()
                        .frame(maxWidth: .infinity)
                    }
                    .scrollBounceBehavior(.always)
                    .refreshable {
                        refreshMyEvents(showsLoading: viewModel.events.isEmpty)
                    }
                }
            }
            .onAppear {
                Task {
                    await loadMyEvents(showsLoading: true)
                }
            }
            .navigationTitle(AppContent.string("myEvents.title"))
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        onOpenProfile()
                    } label: {
                        Image(systemName: "person.circle")
                    }
                    .accessibilityLabel(AppContent.string("common.profile"))
                }
            }
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
}

#Preview {
    MyEventsView()
        .environmentObject(AppState())
}
