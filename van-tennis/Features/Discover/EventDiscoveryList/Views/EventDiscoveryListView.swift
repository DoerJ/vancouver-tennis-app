import SwiftUI

struct EventDiscoveryListView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        NavigationStack {
            Text("Find tennis events")
                .navigationTitle("Find Events")
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        if let skillLevel = appState.userProfile?.skillLevel {
                            NavigationLink {
                                CreateEventView(creatorSkillLevel: skillLevel)
                            } label: {
                                Image(systemName: "plus")
                            }
                            .accessibilityLabel("Create Event")
                        }
                    }
                }
        }
    }
}

#Preview {
    EventDiscoveryListView()
        .environmentObject(AppState())
}
