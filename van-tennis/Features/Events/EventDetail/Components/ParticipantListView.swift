import SwiftUI

struct ParticipantListView: View {
    let participants: [UserProfile]
    let currentUserID: UUID?

    var body: some View {
        Section(AppContent.string("events.participants.title")) {
            if participants.isEmpty {
                Label(AppContent.string("events.participants.none"), systemImage: "person.2.slash")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(participants) { participant in
                    ProfileSummaryRow(
                        profile: participant,
                        fallbackTitle: AppContent.string("events.participants.fallback"),
                        titleSuffix: participant.id == currentUserID
                            ? AppContent.string("events.participants.you")
                            : nil
                    )
                }
            }
        }
    }
}
