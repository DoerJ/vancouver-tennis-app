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
                        "No hosted events",
                        systemImage: "calendar.badge.exclamationmark",
                        description: Text("Events you create will appear here.")
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
                        await loadHostedEvents()
                    }
                }
            }
            .onAppear {
                Task {
                    await loadHostedEvents()
                }
            }
            .navigationTitle("My Events")
        }
    }

    private func loadHostedEvents() async {
        await viewModel.loadEvents(
            hostedEventIDs: appState.userProfile?.hostedEvents ?? []
        )
    }
}

#Preview {
    MyEventsView()
        .environmentObject(AppState())
}
