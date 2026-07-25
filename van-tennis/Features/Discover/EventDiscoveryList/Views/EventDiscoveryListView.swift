import SwiftUI

struct EventDiscoveryListView: View {
    @EnvironmentObject private var appState: AppState
    @StateObject private var viewModel = EventDiscoveryListViewModel()
    @State private var navigationPath: [EventDiscoveryRoute] = []
    let resetTrigger: Int
    let onOpenProfile: () -> Void
    let onOpenNotifications: () -> Void

    init(
        resetTrigger: Int = 0,
        onOpenProfile: @escaping () -> Void = {},
        onOpenNotifications: @escaping () -> Void = {}
    ) {
        self.resetTrigger = resetTrigger
        self.onOpenProfile = onOpenProfile
        self.onOpenNotifications = onOpenNotifications
    }

    var body: some View {
        NavigationStack(path: $navigationPath) {
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
                        discoverHeader
                            .padding(.horizontal, 28)
                            .padding(.top, 18)

                        eventFilters
                            .padding(.horizontal, 28)
                            .padding(.top, 24)

                        ScrollView {
                            LazyVStack(spacing: 28) {
                                if viewModel.filteredEvents.isEmpty {
                                    emptyEventsView
                                        .frame(maxWidth: .infinity)
                                        .padding(.top, 80)
                                } else {
                                    ForEach(viewModel.filteredEvents) { event in
                                        NavigationLink(value: EventDiscoveryRoute.eventDetail(event)) {
                                            EventCardView(
                                                event: event,
                                                hostProfile: viewModel.hostProfilesByID[event.hostID]
                                            )
                                        }
                                        .buttonStyle(.plain)
                                    }

                                    if viewModel.isLoadingNextPage {
                                        ProgressView()
                                            .padding(.vertical, 12)
                                    }
                                }
                            }
                            .padding(.horizontal, 13)
                            .padding(.top, 48)
                            .padding(.bottom, 24)
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
            .navigationBarTitleDisplayMode(.inline)
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(for: EventDiscoveryRoute.self) { route in
                switch route {
                case .eventDetail(let event):
                    EventDetailView(event: event)
                case .createEvent(let skillLevel):
                    CreateEventView(creatorSkillLevel: skillLevel) { event in
                        viewModel.cacheHostProfile(appState.userProfile)
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

    private var discoverHeader: some View {
        VStack(alignment: .leading, spacing: 34) {
            HStack(alignment: .center) {
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

                HStack(spacing: 18) {
                    if let skillLevel = appState.userProfile?.skillLevel {
                        NavigationLink(value: EventDiscoveryRoute.createEvent(skillLevel)) {
                            Image(systemName: "plus.square")
                                .font(.system(size: 28, weight: .regular))
                                .foregroundStyle(RallyDiscoverStyle.ink)
                        }
                        .accessibilityLabel(AppContent.string("discover.createEvent"))
                    }

                    Button {
                        onOpenNotifications()
                    } label: {
                        Image(notificationIconName)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 31, height: 31)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(AppContent.string("tabs.notifications"))
                }
            }

            Text(AppContent.string("discover.title"))
                .font(.system(size: 32, weight: .bold))
                .foregroundStyle(RallyDiscoverStyle.ink)
        }
    }

    private var notificationIconName: String {
        appState.hasUnreadNotifications ? "bell_orange" : "Bell"
    }

    private var eventFilters: some View {
        HStack(spacing: 8) {
            Image(systemName: "slider.horizontal.3")
                .font(.system(size: 23, weight: .regular))
                .foregroundStyle(RallyDiscoverStyle.ink)
                .frame(width: 28, height: 28)

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
                Text(
                    FilterDisplayHelper.selectedTitle(
                        defaultTitle: AppContent.string("discover.filters.location"),
                        selectedTitle: viewModel.selectedCityFilter.displayName,
                        allTitle: AppContent.string("events.filters.all")
                    )
                )
                    .lineLimit(1)
            }
            .buttonStyle(RallyFilterPillButtonStyle())

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
                Text(
                    FilterDisplayHelper.selectedTitle(
                        defaultTitle: AppContent.string("discover.filters.level"),
                        selectedTitle: viewModel.selectedSkillLevelFilter.displayName,
                        allTitle: AppContent.string("events.filters.all")
                    )
                )
                    .lineLimit(1)
            }
            .buttonStyle(RallyFilterPillButtonStyle())

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
                Text(
                    FilterDisplayHelper.selectedTitle(
                        defaultTitle: AppContent.string("discover.filters.type"),
                        selectedTitle: viewModel.selectedEventTypeFilter.displayName,
                        allTitle: AppContent.string("events.filters.all")
                    )
                )
                    .lineLimit(1)
            }
            .buttonStyle(RallyFilterPillButtonStyle())

            Button {
                guard viewModel.resetFilters() else {
                    return
                }

                Task {
                    await viewModel.loadEvents()
                }
            } label: {
                Image(systemName: "arrow.counterclockwise")
                    .font(.system(size: 18, weight: .semibold))
                    .frame(width: 32, height: 32)
            }
            .buttonStyle(.plain)
            .foregroundStyle(hasActiveFilters ? RallyDiscoverStyle.ink : RallyDiscoverStyle.mutedText.opacity(0.55))
            .disabled(!hasActiveFilters)
            .accessibilityLabel(AppContent.string("discover.resetFilters"))
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
            RallyEmptyState(
                iconName: "playing_tennis",
                title: AppContent.string("discover.empty.title"),
                description: AppContent.string("discover.empty.description"),
                titleFontSize: 17,
                descriptionFontSize: 15
            )
        } else {
            RallyEmptyState(
                iconName: "playing_tennis",
                title: AppContent.string("discover.emptyFiltered.title"),
                description: AppContent.string("discover.emptyFiltered.description"),
                titleFontSize: 17,
                descriptionFontSize: 15
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

enum RallyDiscoverStyle {
    static let background = Color(red: 0.82, green: 0.94, blue: 0.88)
    static let surface = Color(red: 0.97, green: 0.97, blue: 0.96)
    static let card = Color.white
    static let ink = Color(red: 0.13, green: 0.13, blue: 0.14)
    static let mutedText = Color(red: 0.47, green: 0.49, blue: 0.45)
    static let primaryGreen = Color(red: 0.20, green: 0.36, blue: 0.12)
    static let accentGreen = Color(red: 0.57, green: 0.66, blue: 0.34)
    static let redBadge = Color(red: 0.98, green: 0.28, blue: 0.13)
    static let avatarBackground = Color(red: 0.98, green: 0.93, blue: 0.78)
    static let sun = Color(red: 0.98, green: 0.64, blue: 0.25)
    static let shadow = Color(red: 0.16, green: 0.27, blue: 0.18).opacity(0.12)
}
