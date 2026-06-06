import SwiftUI

struct UserProfileView: View {
    var body: some View {
        NavigationStack {
            Text("Your tennis profile")
                .navigationTitle("Profile")
        }
    }
}

#Preview {
    UserProfileView()
}
