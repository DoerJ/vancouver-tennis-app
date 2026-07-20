import SwiftUI

struct CreateEventView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var appState: AppState
    @StateObject private var viewModel: CreateEventViewModel
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

                    createButton
                }
                .padding(.horizontal, 13)
                .padding(.top, 18)
                .padding(.bottom, 128)
            }

            floatingBackButton
                .padding(.leading, 18)
                .padding(.top, 17)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .navigationBarBackButtonHidden(true)
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
        viewModel.isSaving
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 34) {
            Text(AppContent.string("events.create.title"))
                .font(.system(size: 32, weight: .bold))
                .foregroundStyle(RallyDiscoverStyle.ink)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 16)
        }
        .padding(.top, 91)
    }

    private var floatingBackButton: some View {
        RallyCircularBackButton {
            dismiss()
        }
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

    private var createButton: some View {
        Button {
            Task {
                await saveEvent()
            }
        } label: {
            Text(isSaving ? AppContent.string("events.create.creating") : AppContent.string("events.create.createButton"))
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(RallyPrimaryActionButtonStyle(showsShadow: true))
        .disabled(isSaving)
        .opacity(isSaving ? 0.7 : 1)
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

                SkillLevelBadge(viewModel.creatorSkillLevel, width: 71, minWidth: nil)

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
                    RallyBadge(
                        viewModel.city.displayName,
                        color: RallyDiscoverStyle.accentGreen,
                        width: 98,
                        minWidth: nil,
                        height: 27,
                        showsShadow: true
                    )
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
                    RallyBadge(
                        viewModel.court.displayName,
                        color: RallyDiscoverStyle.primaryGreen,
                        minWidth: 98,
                        maxWidth: 210,
                        height: 27,
                        horizontalPadding: 14,
                        minimumScaleFactor: 0.72,
                        showsShadow: true
                    )
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
        RallyDivider(leadingPadding: 2)
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
                text: DateFormattingHelper.fullDateBadgeString(from: selection.wrappedValue),
                picker: datePicker,
                color: color
            )

            timePickerBadge(
                text: DateFormattingHelper.timeBadgeString(from: selection.wrappedValue),
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
            RallyBadge(
                text,
                color: color,
                fontSize: 9,
                width: 88,
                minWidth: nil,
                height: 27,
                showsShadow: true
            )
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
        guard let event = await viewModel.createEvent(appState: appState) else {
            return
        }

        onEventCreated(event)
        dismiss()
    }

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
