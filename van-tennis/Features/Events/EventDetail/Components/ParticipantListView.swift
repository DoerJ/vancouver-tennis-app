import SwiftUI

struct ParticipantListView: View {
    let participants: [UserProfile]

    var body: some View {
        Section("Participants") {
            if participants.isEmpty {
                Label("No participants yet", systemImage: "person.2.slash")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(participants) { participant in
                    ProfileSummaryRow(
                        profile: participant,
                        fallbackTitle: "Participant"
                    )
                }
            }
        }
    }
}
