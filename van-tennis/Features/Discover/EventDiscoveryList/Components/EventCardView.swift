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
                            .background(RallyDiscoverStyle.orangeBadge)
                            .clipShape(Capsule())
                    }

                    TimelineView(
                        .periodic(
                            from: Date(),
                            by: Constants.EventDiscovery.cardTimelineRefreshInterval
                        )
                    ) { context in
                        Text(
                            EventTimeDisplayHelper.upcomingTimeText(
                                startTime: event.startTime,
                                endTime: event.endTime,
                                now: context.date
                            )
                        )
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

                    SkillLevelBadge(event.skillLevel)
                    RallyBadge(
                        event.eventType.displayName,
                        color: Constants.EventTypeStyle.badgeColor(for: event.eventType)
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
                                    SocialTagBadge(tag)
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
        "\(DateFormattingHelper.eventDateTimeString(from: event.startTime)) - \(DateFormattingHelper.timeString(from: event.endTime))"
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
            participants: [UUID()],
            createdAt: nil,
            updatedAt: nil
        )
    )
    .padding()
}
