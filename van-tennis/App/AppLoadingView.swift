import SwiftUI

struct AppLoadingView: View {
    var body: some View {
        GeometryReader { proxy in
            ZStack {
                Image("Photos/launch_screen")
                    .resizable()
                    .scaledToFill()
                    .frame(width: proxy.size.width, height: proxy.size.height)
                    .clipped()
                    .ignoresSafeArea()

                Image("app_logo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 195, height: 142)
                    .accessibilityLabel(AppContent.string("app.name"))
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
        .ignoresSafeArea()
    }
}

#Preview {
    AppLoadingView()
}
