import SwiftUI

struct CreateEventView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var appState: AppState
    @StateObject private var viewModel: CreateEventViewModel
    @State private var isPreparingToSave = false
    @State private var activeTimePicker: CreateEventTimePicker?
    private let onEventCreated: (TennisEvent) -> Void

    init(
        creatorSkillLevel: SkillLevel,
        onEventCreated: @escaping (TennisEvent) -> Void = { _ in }
    ) {
        self.onEventCreated = onEventCreated
        _viewModel = StateObject(
            wrappedValue: CreateEventViewModel(creatorSkillLevel: creatorSkillLevel)
        )
    }

    var body: some View {
        ZStack {
            RallyDiscoverStyle.surface
                .ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    header

                    formCard

                    if let errorMessage = viewModel.errorMessage {
                        Text(errorMessage)
                            .font(.footnote.weight(.medium))
                            .foregroundStyle(RallyDiscoverStyle.redBadge)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 14)
                            .background(RallyDiscoverStyle.card)
                            .clipShape(RoundedRectangle(cornerRadius: 24))
                    }
                }
                .padding(.horizontal, 13)
                .padding(.top, 18)
                .padding(.bottom, 28)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .navigationBar)
        .onChange(of: viewModel.startTime) { newStartTime in
            let earliestEndTime = Calendar.current.date(
                byAdding: .minute,
                value: Constants.Event.minimumDurationMinutes,
                to: newStartTime
            ) ?? newStartTime

            if viewModel.endTime < earliestEndTime {
                viewModel.endTime = earliestEndTime
            }

            let latestEndTime = Calendar.current.date(
                byAdding: .hour,
                value: Constants.Event.maximumDurationHours,
                to: newStartTime
            ) ?? newStartTime

            if viewModel.endTime > latestEndTime {
                viewModel.endTime = latestEndTime
            }
        }
        .popover(item: $activeTimePicker) { picker in
            timePickerPopover(for: picker)
        }
    }

    private var isSaving: Bool {
        isPreparingToSave || viewModel.isSaving
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 34) {
            HStack {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 28, weight: .medium))
                        .foregroundStyle(RallyDiscoverStyle.ink)
                        .frame(width: 40, height: 40)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(AppContent.string("common.cancel"))

                Spacer()

                Button {
                    Task {
                        await saveEvent()
                    }
                } label: {
                    Text(isSaving ? AppContent.string("events.create.creating") : AppContent.string("events.create.createButton"))
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 18)
                        .frame(height: 34)
                        .background(RallyDiscoverStyle.primaryGreen, in: Capsule())
                }
                .buttonStyle(.plain)
                .disabled(isSaving)
                .opacity(isSaving ? 0.7 : 1)
            }
            .padding(.horizontal, 16)

            Text(AppContent.string("events.create.title"))
                .font(.system(size: 32, weight: .bold))
                .foregroundStyle(RallyDiscoverStyle.ink)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 16)
        }
        .padding(.top, 17)
    }

    private var formCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 24) {
                timeSection

                createDivider

                eventSection

                createDivider

                playersSection

                createDivider

                locationSection
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 52)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RallyDiscoverStyle.card)
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .shadow(color: RallyDiscoverStyle.shadow.opacity(0.58), radius: 18, x: 0, y: 8)
    }

    private var timeSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionTitle(AppContent.string("events.create.time"))

            timeRow(
                label: AppContent.string("events.create.start"),
                selection: $viewModel.startTime,
                datePicker: .startDate,
                timePicker: .startTime,
                dateRange: viewModel.earliestAllowedStartTime...viewModel.latestAllowedStartTime,
                color: RallyDiscoverStyle.accentGreen
            )

            timeRow(
                label: AppContent.string("events.create.end"),
                selection: $viewModel.endTime,
                datePicker: .endDate,
                timePicker: .endTime,
                dateRange: viewModel.earliestAllowedEndTime...viewModel.latestAllowedEndTime,
                color: RallyDiscoverStyle.primaryGreen,
                systemImage: "clock.badge.checkmark"
            )
        }
    }

    private var eventSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionTitle(AppContent.string("events.create.event"))

            HStack(spacing: 10) {
                Image(systemName: "tennisball")
                    .font(.system(size: 22, weight: .regular))
                    .foregroundStyle(RallyDiscoverStyle.ink)
                    .frame(width: 28)

                Text(AppContent.string("events.create.type"))
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(.black)
                    .frame(width: 52, alignment: .leading)

                HStack(spacing: 10) {
                    ForEach(EventType.allCases) { type in
                        Button {
                            viewModel.eventType = type
                        } label: {
                            HStack(spacing: 4) {
                                if viewModel.eventType == type {
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 8, weight: .bold))
                                }

                                Text(type.displayName)
                                    .lineLimit(1)
                            }
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(width: 72, height: 22)
                            .background(eventTypeColor(type), in: Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            HStack(spacing: 10) {
                Image(systemName: "tennisball")
                    .font(.system(size: 22, weight: .regular))
                    .foregroundStyle(RallyDiscoverStyle.ink)
                    .frame(width: 28)

                Text(AppContent.string("events.create.skillLevel"))
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(.black)

                Text(viewModel.creatorSkillLevel.rawValue)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 71, height: 22)
                    .background(skillLevelBadgeColor, in: Capsule())

                Spacer()
            }
        }
    }

    private var playersSection: some View {
        VStack(alignment: .leading, spacing: 22) {
            sectionTitle(AppContent.string("events.create.players"))

            HStack(spacing: 12) {
                Image("playing_tennis")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 24, height: 24)

                Text(AppContent.string("events.create.maxPlayers", viewModel.maxPlayers))
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(.black)
            }

            Slider(
                value: maxPlayersSliderValue,
                in: Double(Constants.Event.minimumPlayerLimit)...Double(Constants.Event.maximumPlayerLimit),
                step: 1
            )
            .tint(RallyDiscoverStyle.accentGreen)
        }
    }

    private var locationSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionTitle(AppContent.string("events.create.location"))

            HStack(spacing: 10) {
                Image("pin_drop")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 28, height: 28)

                Text(AppContent.string("events.create.city"))
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(.black)
                    .frame(width: 52, alignment: .leading)

                Menu {
                    ForEach(EventCity.allCases) { city in
                        Button {
                            viewModel.city = city
                        } label: {
                            if viewModel.city == city {
                                Label(city.displayName, systemImage: "checkmark")
                            } else {
                                Text(city.displayName)
                            }
                        }
                    }
                } label: {
                    badgeLabel(viewModel.city.displayName, width: 98, color: RallyDiscoverStyle.accentGreen)
                }
                .buttonStyle(.plain)

                Spacer()
            }

            HStack(spacing: 10) {
                Image(systemName: "sportscourt")
                    .font(.system(size: 22, weight: .regular))
                    .foregroundStyle(RallyDiscoverStyle.ink)
                    .frame(width: 28)

                Text(AppContent.string("events.create.court"))
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(.black)
                    .frame(width: 52, alignment: .leading)

                Menu {
                    ForEach(viewModel.city.courts) { court in
                        Button {
                            viewModel.court = court
                        } label: {
                            if viewModel.court == court {
                                Label(court.displayName, systemImage: "checkmark")
                            } else {
                                Text(court.displayName)
                            }
                        }
                    }
                } label: {
                    badgeLabel(viewModel.court.displayName, width: 154, color: RallyDiscoverStyle.primaryGreen)
                }
                .buttonStyle(.plain)

                Spacer()
            }
        }
    }

    private func sectionTitle(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 16, weight: .bold))
            .foregroundStyle(RallyDiscoverStyle.ink)
    }

    private var createDivider: some View {
        Rectangle()
            .fill(Color.black.opacity(0.1))
            .frame(height: 1)
            .padding(.leading, 2)
    }

    private func badgeLabel(_ text: String, width: CGFloat, color: Color) -> some View {
        Text(text)
            .font(.system(size: 10, weight: .semibold))
            .foregroundStyle(.white)
            .lineLimit(1)
            .minimumScaleFactor(0.75)
            .frame(width: width, height: 27)
            .background(color, in: Capsule())
            .shadow(color: RallyDiscoverStyle.shadow, radius: 9, x: 0, y: 8)
    }

    private func timeRow(
        label: String,
        selection: Binding<Date>,
        datePicker: CreateEventTimePicker,
        timePicker: CreateEventTimePicker,
        dateRange: ClosedRange<Date>,
        color: Color,
        systemImage: String = "clock"
    ) -> some View {
        HStack(spacing: 10) {
            Image(systemName: systemImage)
                .font(.system(size: 21, weight: .regular))
                .foregroundStyle(RallyDiscoverStyle.ink)
                .frame(width: 28)

            Text(label)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(.black)
                .frame(width: 50, alignment: .leading)

            timePickerBadge(
                text: Self.badgeDateFormatter.string(from: selection.wrappedValue),
                picker: datePicker,
                color: color
            )

            timePickerBadge(
                text: Self.badgeTimeFormatter.string(from: selection.wrappedValue),
                picker: timePicker,
                color: color
            )
        }
    }

    private func timePickerBadge(
        text: String,
        picker: CreateEventTimePicker,
        color: Color
    ) -> some View {
        Button {
            activeTimePicker = picker
        } label: {
            Text(text)
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
                .frame(width: 88, height: 27)
                .background(color, in: Capsule())
                .shadow(color: RallyDiscoverStyle.shadow, radius: 9, x: 0, y: 8)
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func timePickerPopover(for picker: CreateEventTimePicker) -> some View {
        VStack(spacing: 16) {
            if picker.isDatePicker {
                DatePicker(
                    "",
                    selection: dateSelection(for: picker),
                    in: dateRange(for: picker),
                    displayedComponents: .date
                )
                .datePickerStyle(.graphical)
                .labelsHidden()
            } else {
                DatePicker(
                    "",
                    selection: dateSelection(for: picker),
                    in: dateRange(for: picker),
                    displayedComponents: .hourAndMinute
                )
                .datePickerStyle(.wheel)
                .labelsHidden()
            }

            Button {
                activeTimePicker = nil
            } label: {
                Text(AppContent.string("common.ok"))
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Color(.systemBackground))
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
                    .background(Color(.label), in: Capsule())
            }
            .buttonStyle(.plain)
        }
        .padding(20)
        .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: Self.timePickerBadgeCornerRadius))
        .presentationDetents([.medium])
        .presentationCornerRadius(Self.timePickerBadgeCornerRadius)
    }

    private func dateSelection(for picker: CreateEventTimePicker) -> Binding<Date> {
        switch picker {
        case .startDate, .startTime:
            return $viewModel.startTime
        case .endDate, .endTime:
            return $viewModel.endTime
        }
    }

    private func dateRange(for picker: CreateEventTimePicker) -> ClosedRange<Date> {
        switch picker {
        case .startDate, .startTime:
            return viewModel.earliestAllowedStartTime...viewModel.latestAllowedStartTime
        case .endDate, .endTime:
            return viewModel.earliestAllowedEndTime...viewModel.latestAllowedEndTime
        }
    }

    private var maxPlayersSliderValue: Binding<Double> {
        Binding {
            Double(viewModel.maxPlayers)
        } set: { value in
            viewModel.maxPlayers = Int(value.rounded())
        }
    }

    private var skillLevelBadgeColor: Color {
        switch viewModel.creatorSkillLevel {
        case .one:
            return RallyDiscoverStyle.primaryGreen
        case .two:
            return RallyDiscoverStyle.orangeBadge
        case .three:
            return RallyDiscoverStyle.redBadge
        case .four:
            return RallyDiscoverStyle.accentGreen
        }
    }

    private func eventTypeColor(_ type: EventType) -> Color {
        switch type {
        case .practice:
            return RallyDiscoverStyle.accentGreen
        case .casual:
            return RallyDiscoverStyle.yellowBadge
        case .match:
            return RallyDiscoverStyle.orangeBadge
        }
    }

    private func saveEvent() async {
        guard !isSaving else {
            return
        }

        guard appState.supabaseSession != nil else {
            return
        }

        isPreparingToSave = true
        defer {
            isPreparingToSave = false
        }

        do {
            let activeHostedEvents = try await appState.activeHostedEventsForCurrentUser()

            guard let event = await viewModel.save(activeHostedEvents: activeHostedEvents) else {
                return
            }

            appState.updateCachedEvents([event])
            try await appState.appendHostedEvent(event.id)
            onEventCreated(event)
            dismiss()
        } catch {
            viewModel.errorMessage = error.localizedDescription
        }
    }

    private static let badgeDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, yyyy"
        return formatter
    }()

    private static let badgeTimeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter
    }()

    private static let timePickerBadgeCornerRadius: CGFloat = 13.5
}

#Preview {
    NavigationStack {
        CreateEventView(creatorSkillLevel: .three)
            .environmentObject(AppState())
    }
}

private enum CreateEventTimePicker: String, Identifiable {
    case startDate
    case startTime
    case endDate
    case endTime

    var id: String {
        rawValue
    }

    var isDatePicker: Bool {
        switch self {
        case .startDate, .endDate:
            return true
        case .startTime, .endTime:
            return false
        }
    }
}
