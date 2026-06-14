import SwiftUI

struct ChatView: View {
    let onOpenProfile: () -> Void

    init(onOpenProfile: @escaping () -> Void = {}) {
        self.onOpenProfile = onOpenProfile
    }

    var body: some View {
        NavigationStack {
            ContentUnavailableView(
                "No chats yet",
                systemImage: "message",
                description: Text("Your conversations will appear here.")
            )
            .navigationTitle("Chat")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        onOpenProfile()
                    } label: {
                        Image(systemName: "person.circle")
                    }
                    .accessibilityLabel("Profile")
                }
            }
        }
    }
}

#Preview {
    ChatView()
}
