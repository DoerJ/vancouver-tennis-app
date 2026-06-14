import SwiftUI

struct EventCardView: View {
    let event: TennisEvent

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(event.city.displayName)
                        .font(.headline)

                    Text(event.court.displayName)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                TimelineView(.periodic(from: Date(), by: 60)) { context in
                    Text(upcomingTimeText(now: context.date))
                        .font(.caption)
                        .fontWeight(.semibold)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(.thinMaterial)
                        .clipShape(Capsule())
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                Label("Skill level \(event.skillLevel.rawValue)", systemImage: "figure.tennis")
                Label(timeRangeText, systemImage: "clock")
            }
            .font(.subheadline)
            .foregroundStyle(.secondary)
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private var timeRangeText: String {
        "\(Self.dateFormatter.string(from: event.startTime)) - \(Self.timeFormatter.string(from: event.endTime))"
    }

    private func upcomingTimeText(now: Date) -> String {
        let calendar = Calendar.current

        if event.startTime <= now {
            return event.endTime > now ? "In progress" : "Ended"
        }

        if calendar.isDateInTomorrow(event.startTime) {
            return "Tomorrow"
        }

        let secondsUntilStart = event.startTime.timeIntervalSince(now)
        let hoursUntilStart = Int(ceil(secondsUntilStart / 3_600))

        if hoursUntilStart < 24 {
            return "In \(hoursUntilStart) \(hoursUntilStart == 1 ? "hour" : "hours")"
        }

        let startOfToday = calendar.startOfDay(for: now)
        let startOfEventDay = calendar.startOfDay(for: event.startTime)
        let daysUntilStart = calendar.dateComponents([.day], from: startOfToday, to: startOfEventDay).day ?? 1
        let displayDays = max(daysUntilStart, 1)

        return "In \(displayDays) \(displayDays == 1 ? "day" : "days")"
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
