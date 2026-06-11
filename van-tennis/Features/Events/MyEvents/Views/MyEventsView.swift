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
                } else if viewModel.events.isEmpty {
                    ContentUnavailableView(
                        "No events yet",
                        systemImage: "calendar.badge.exclamationmark",
                        description: Text("Events you host or join will appear here.")
                    )
                } else {
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(viewModel.events) { event in
                                NavigationLink {
                                    EventDetailView(event: event) { eventID in
                                        viewModel.removeEvent(id: eventID)
                                    }
                                } label: {
                                    EventCardView(event: event)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding()
                    }
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
        await viewModel.loadEvents(
            currentUserID: appState.userProfile?.id,
            showsLoading: showsLoading
        )
    }

    private func refreshMyEvents(showsLoading: Bool) {
        viewModel.refreshEvents(
            currentUserID: appState.userProfile?.id,
            showsLoading: showsLoading
        )
    }
}

#Preview {
    MyEventsView()
        .environmentObject(AppState())
}
