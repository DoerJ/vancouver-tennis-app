import SwiftUI

struct MyEventsView: View {
    @EnvironmentObject private var appState: AppState
    @StateObject private var viewModel = MyEventsViewModel()

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.isLoading && viewModel.events.isEmpty {
                    ProgressView("Loading events")
                } else if let errorMessage = viewModel.errorMessage, viewModel.events.isEmpty {
                    ContentUnavailableView(
                        "Unable to load events",
                        systemImage: "exclamationmark.triangle",
                        description: Text(errorMessage)
                    )
                } else {
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            if viewModel.events.isEmpty {
                                ContentUnavailableView(
                                    "No events yet",
                                    systemImage: "calendar.badge.exclamationmark",
                                    description: Text("Events you host or join will appear here.")
                                )
                                .frame(maxWidth: .infinity)
                                .padding(.top, 80)
                            } else {
                                ForEach(viewModel.events) { event in
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
            .navigationTitle("My Events")
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
