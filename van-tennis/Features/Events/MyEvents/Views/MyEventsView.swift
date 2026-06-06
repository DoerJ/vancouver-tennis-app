import SwiftUI

struct MyEventsView: View {
    var body: some View {
        NavigationStack {
            Text("Your tennis events")
                .navigationTitle("My Events")
        }
    }
}

#Preview {
    MyEventsView()
}
