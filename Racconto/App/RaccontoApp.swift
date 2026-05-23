import SwiftUI

@main
struct RaccontoApp: App {
    @State private var authViewModel = AuthViewModel()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(authViewModel)
        }
    }
}

struct RootView: View {
    @Environment(AuthViewModel.self) private var authViewModel
    @Environment(\.horizontalSizeClass) private var sizeClass

    var body: some View {
        if authViewModel.isAuthenticated {
            if sizeClass == .regular {
                PadRootView()
            } else {
                PhoneRootView()
            }
        } else {
            LandingView(authViewModel: authViewModel)
        }
    }
}
