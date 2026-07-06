import SwiftUI

struct EventDiscoveryListView: View {
    @EnvironmentObject private var appState: AppState
    @StateObject private var viewModel = EventDiscoveryListViewModel()
    @State private var navigationPath: [EventDiscoveryRoute] = []
    let resetTrigger: Int
    let onOpenProfile: () -> Void

    init(resetTrigger: Int = 0, onOpenProfile: @escaping () -> Void = {}) {
        self.resetTrigger = resetTrigger
        self.onOpenProfile = onOpenProfile
    }

    var body: some View {
        NavigationStack(path: $navigationPath) {
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
                    VStack(spacing: 0) {
                        eventFilters
                            .padding([.horizontal, .top])

                        ScrollView {
                            LazyVStack(spacing: 12) {
                                if viewModel.filteredEvents.isEmpty {
                                    emptyEventsView
                                        .frame(maxWidth: .infinity)
                                        .padding(.top, 80)
                                } else {
                                    ForEach(viewModel.filteredEvents) { event in
                                        NavigationLink(value: EventDiscoveryRoute.eventDetail(event)) {
                                            EventCardView(event: event)
                                        }
                                        .buttonStyle(.plain)
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
                            return canScroll
                                && geometry.contentOffset.y > 0
                                && distanceToBottom < Constants.EventDiscovery.paginationTriggerDistance
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
            .navigationTitle(AppContent.string("discover.title"))
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    HStack {
                        if let skillLevel = appState.userProfile?.skillLevel {
                            NavigationLink(value: EventDiscoveryRoute.createEvent(skillLevel)) {
                                Image(systemName: "plus")
                            }
                            .accessibilityLabel(AppContent.string("discover.createEvent"))
                        }

                        Button {
                            onOpenProfile()
                        } label: {
                            Image(systemName: "person.circle")
                        }
                        .accessibilityLabel(AppContent.string("common.profile"))
                    }
                }
            }
            .navigationDestination(for: EventDiscoveryRoute.self) { route in
                switch route {
                case .eventDetail(let event):
                    EventDetailView(event: event)
                case .createEvent(let skillLevel):
                    CreateEventView(creatorSkillLevel: skillLevel) { event in
                        viewModel.applyCreatedEvent(event)
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
        .onChange(of: viewModel.selectedSkillLevelFilter) {
            guard !viewModel.consumeShouldSkipNextFilterReload() else {
                return
            }

            Task {
                await viewModel.loadEvents()
            }
        }
        .onChange(of: viewModel.selectedEventTypeFilter) {
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
        .onChange(of: resetTrigger) {
            navigationPath = []
        }
    }

    private var eventFilters: some View {
        HStack(spacing: 8) {
            Menu {
                ForEach(EventCityFilter.options) { filter in
                    Button {
                        viewModel.selectedCityFilter = filter
                    } label: {
                        if filter == viewModel.selectedCityFilter {
                            Label(filter.displayName, systemImage: "checkmark")
                        } else {
                            Text(filter.displayName)
                        }
                    }
                }
            } label: {
                Label(viewModel.selectedCityFilter.displayName, systemImage: "mappin.and.ellipse")
                    .lineLimit(1)
            }
            .font(.subheadline)
            .padding(.horizontal, 10)
            .frame(height: 36)
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 8))

            Menu {
                ForEach(EventSkillLevelFilter.options) { filter in
                    Button {
                        viewModel.selectedSkillLevelFilter = filter
                    } label: {
                        if filter == viewModel.selectedSkillLevelFilter {
                            Label(filter.displayName, systemImage: "checkmark")
                        } else {
                            Text(filter.displayName)
                        }
                    }
                }
            } label: {
                Label(viewModel.selectedSkillLevelFilter.displayName, systemImage: "figure.tennis")
                    .lineLimit(1)
            }
            .font(.subheadline)
            .padding(.horizontal, 10)
            .frame(height: 36)
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 8))

            Menu {
                ForEach(EventTypeFilter.options) { filter in
                    Button {
                        viewModel.selectedEventTypeFilter = filter
                    } label: {
                        if filter == viewModel.selectedEventTypeFilter {
                            Label(filter.displayName, systemImage: "checkmark")
                        } else {
                            Text(filter.displayName)
                        }
                    }
                }
            } label: {
                Label(viewModel.selectedEventTypeFilter.displayName, systemImage: "tennisball")
                    .lineLimit(1)
            }
            .font(.subheadline)
            .padding(.horizontal, 10)
            .frame(height: 36)
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 8))

            Button {
                guard viewModel.resetFilters() else {
                    return
                }

                Task {
                    await viewModel.loadEvents()
                }
            } label: {
                Image(systemName: "arrow.counterclockwise")
                    .frame(width: 36, height: 36)
            }
            .buttonStyle(.plain)
            .foregroundStyle(hasActiveFilters ? .primary : .secondary)
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .disabled(!hasActiveFilters)
            .accessibilityLabel(AppContent.string("discover.resetFilters"))

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var hasActiveFilters: Bool {
        viewModel.selectedCityFilter != .all
            || viewModel.selectedSkillLevelFilter != .all
            || viewModel.selectedEventTypeFilter != .all
    }

    @ViewBuilder
    private var emptyEventsView: some View {
        if viewModel.selectedCityFilter == .all
            && viewModel.selectedSkillLevelFilter == .all
            && viewModel.selectedEventTypeFilter == .all {
            ContentUnavailableView(
                AppContent.string("discover.empty.title"),
                systemImage: "calendar.badge.exclamationmark",
                description: Text(AppContent.string("discover.empty.description"))
            )
        } else {
            ContentUnavailableView(
                AppContent.string("discover.emptyFiltered.title"),
                systemImage: "line.3.horizontal.decrease.circle",
                description: Text(AppContent.string("discover.emptyFiltered.description"))
            )
        }
    }
}

private enum EventDiscoveryRoute: Hashable {
    case eventDetail(TennisEvent)
    case createEvent(SkillLevel)
}

#Preview {
    EventDiscoveryListView()
        .environmentObject(AppState())
}
