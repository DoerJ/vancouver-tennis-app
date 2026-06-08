import SwiftUI

struct EventDiscoveryListView: View {
    @EnvironmentObject private var appState: AppState
    @StateObject private var viewModel = EventDiscoveryListViewModel()

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
                    VStack(spacing: 0) {
                        cityFilterPicker
                            .padding([.horizontal, .top])

                        ScrollView {
                            LazyVStack(spacing: 12) {
                                if viewModel.filteredEvents.isEmpty {
                                    emptyEventsView
                                        .frame(maxWidth: .infinity)
                                        .padding(.top, 80)
                                } else {
                                    ForEach(viewModel.filteredEvents) { event in
                                        EventCardView(event: event)
                                    }

                                    if viewModel.isLoadingNextPage {
                                        ProgressView()
                                            .padding(.vertical, 12)
                                    }
                                }
                            }
                            .padding()
                            .frame(maxWidth: .infinity)
                        }
                        .onScrollGeometryChange(for: Bool.self) { geometry in
                            let distanceToBottom = geometry.contentSize.height - geometry.containerSize.height - geometry.contentOffset.y
                            let canScroll = geometry.contentSize.height > geometry.containerSize.height
                            return canScroll && geometry.contentOffset.y > 0 && distanceToBottom < 80
                        } action: { wasNearBottom, isNearBottom in
                            guard !wasNearBottom, isNearBottom else {
                                return
                            }

                            Task {
                                await viewModel.loadNextPage()
                            }
                        }
                        .refreshable {
                            await viewModel.loadEvents()
                        }
                    }
                }
            }
            .navigationTitle("Find Events")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    if let skillLevel = appState.userProfile?.skillLevel {
                        NavigationLink {
                            CreateEventView(creatorSkillLevel: skillLevel) { event in
                                viewModel.applyCreatedEvent(event)
                            }
                        } label: {
                            Image(systemName: "plus")
                        }
                        .accessibilityLabel("Create Event")
                    }
                }
            }
        }
        .onAppear {
            Task {
                await viewModel.loadInitialEventsIfNeeded()
            }
        }
        .onChange(of: viewModel.selectedCityFilter) {
            guard !viewModel.consumeShouldSkipNextFilterReload() else {
                return
            }

            Task {
                await viewModel.loadEvents()
            }
        }
        .onChange(of: appState.eventsRevision) {
            Task {
                await viewModel.loadEvents()
            }
        }
    }

    private var cityFilterPicker: some View {
        Picker("City", selection: $viewModel.selectedCityFilter) {
            ForEach(EventCityFilter.options) { filter in
                Text(filter.displayName).tag(filter)
            }
        }
        .pickerStyle(.segmented)
    }

    @ViewBuilder
    private var emptyEventsView: some View {
        if viewModel.selectedCityFilter == .all {
            ContentUnavailableView(
                "No tennis events",
                systemImage: "calendar.badge.exclamationmark",
                description: Text("Created events will appear here.")
            )
        } else {
            ContentUnavailableView(
                "No events in \(viewModel.selectedCityFilter.displayName)",
                systemImage: "line.3.horizontal.decrease.circle",
                description: Text("Try a different city filter.")
            )
        }
    }
}

#Preview {
    EventDiscoveryListView()
        .environmentObject(AppState())
}
