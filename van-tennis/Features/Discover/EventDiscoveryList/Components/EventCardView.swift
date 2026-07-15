import SwiftUI

struct EventCardView: View {
    let event: TennisEvent
    let hostProfile: UserProfile?
    let hostDisplayNameOverride: String?
    let showsHostSocialTags: Bool

    init(
        event: TennisEvent,
        hostProfile: UserProfile? = nil,
        hostDisplayNameOverride: String? = nil,
        showsHostSocialTags: Bool = true
    ) {
        self.event = event
        self.hostProfile = hostProfile
        self.hostDisplayNameOverride = hostDisplayNameOverride
        self.showsHostSocialTags = showsHostSocialTags
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(event.court.displayName)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(RallyDiscoverStyle.ink)

                    Text(event.city.displayName)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(RallyDiscoverStyle.mutedText)
                }

                Spacer()

                HStack(spacing: 6) {
                    if event.isFull {
                        Text(AppContent.string("events.card.full"))
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 9)
                            .padding(.vertical, 5)
                            .background(RallyDiscoverStyle.redBadge)
                            .clipShape(Capsule())
                    }

                    TimelineView(
                        .periodic(
                            from: Date(),
                            by: Constants.EventDiscovery.cardTimelineRefreshInterval
                        )
                    ) { context in
                        Text(upcomingTimeText(now: context.date))
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(RallyDiscoverStyle.primaryGreen)
                            .clipShape(Capsule())
                            .shadow(color: RallyDiscoverStyle.shadow, radius: 9, x: 0, y: 8)
                    }
                }
            }

            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 10) {
                    Image(systemName: "tennisball")
                        .font(.system(size: 22, weight: .regular))
                        .frame(width: 24)
                        .foregroundStyle(RallyDiscoverStyle.ink)

                    Text(AppContent.string("events.card.levelLabel"))
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(RallyDiscoverStyle.mutedText)

                    eventBadge(
                        event.skillLevel.rawValue,
                        color: skillLevelBadgeColor
                    )
                    eventBadge(
                        event.eventType.displayName,
                        color: RallyDiscoverStyle.yellowBadge
                    )
                }

                HStack(spacing: 10) {
                    Image("playing_tennis")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 24, height: 24)
                        .accessibilityHidden(true)

                    Text(hostLabel)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(RallyDiscoverStyle.mutedText)

                    if showsHostSocialTags, let hostProfile, !hostProfile.socialTags.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 6) {
                                ForEach(hostProfile.socialTags, id: \.self) { tag in
                                    socialTagBadge(tag)
                                }
                            }
                        }
                    }
                }

                HStack(spacing: 10) {
                    Image(systemName: "clock")
                        .font(.system(size: 19, weight: .regular))
                        .frame(width: 24)
                        .foregroundStyle(RallyDiscoverStyle.ink)

                    Text(AppContent.string("events.card.timeLabel", timeRangeText))
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(RallyDiscoverStyle.mutedText)
                        .lineLimit(1)
                        .minimumScaleFactor(0.82)
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 26)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RallyDiscoverStyle.card)
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .shadow(color: RallyDiscoverStyle.shadow.opacity(0.58), radius: 18, x: 0, y: 8)
    }

    private var timeRangeText: String {
        "\(Self.dateFormatter.string(from: event.startTime)) - \(Self.timeFormatter.string(from: event.endTime))"
    }

    private var hostLabel: String {
        if let hostDisplayNameOverride {
            return AppContent.string("events.card.hostLabel", hostDisplayNameOverride)
        }

        if let hostProfile {
            return AppContent.string("events.card.hostLabel", hostProfile.displayName)
        }

        return AppContent.string("events.card.hostFallback")
    }

    private var skillLevelBadgeColor: Color {
        Constants.SkillLevelStyle.badgeColor(for: event.skillLevel)
    }

    private func eventBadge(_ text: String, color: Color) -> some View {
        Text(text)
            .font(.system(size: 10, weight: .semibold))
            .foregroundStyle(.white)
            .frame(minWidth: 71)
            .padding(.horizontal, 8)
            .frame(height: 22)
            .background(color, in: Capsule())
    }

    private func socialTagBadge(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 10, weight: .semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 12)
            .frame(height: 22)
            .background(RallyDiscoverStyle.accentGreen, in: Capsule())
    }

    private func upcomingTimeText(now: Date) -> String {
        let calendar = Calendar.current

        if event.startTime <= now && now < event.endTime {
            return AppContent.string("events.card.inProgress")
        }

        if event.endTime <= now {
            return AppContent.string("events.card.ended")
        }

        if calendar.isDateInTomorrow(event.startTime) {
            return AppContent.string("events.card.tomorrow")
        }

        let secondsUntilStart = event.startTime.timeIntervalSince(now)
        let hoursUntilStart = Int(ceil(secondsUntilStart / 3_600))

        if hoursUntilStart < 24 {
            return AppContent.string(hoursUntilStart == 1 ? "events.card.inHour" : "events.card.inHours", hoursUntilStart)
        }

        let startOfToday = calendar.startOfDay(for: now)
        let startOfEventDay = calendar.startOfDay(for: event.startTime)
        let daysUntilStart = calendar.dateComponents([.day], from: startOfToday, to: startOfEventDay).day ?? 1
        let displayDays = max(daysUntilStart, 1)

        return AppContent.string(displayDays == 1 ? "events.card.inDay" : "events.card.inDays", displayDays)
    }

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return formatter
    }()
}

#Preview {
    EventCardView(
        event: TennisEvent(
            id: UUID(),
            hostID: UUID(),
            startTime: Date(),
            endTime: Calendar.current.date(byAdding: .hour, value: 2, to: Date()) ?? Date(),
            eventType: .practice,
            maxPlayers: 4,
            city: .burnaby,
            court: .bcitCourt,
            skillLevel: .three,
            status: .upcoming,
            participants: [UUID()],
            createdAt: nil,
            updatedAt: nil
        )
    )
    .padding()
}
