import SwiftUI

struct RootView: View {
    @Environment(AuthViewModel.self) private var auth

    var body: some View {
        Group {
            if auth.isLoading {
                ProgressView("Loading...")
            } else if !auth.isAuthenticated {
                LoginView()
            } else if auth.needsOnboarding {
                OnboardingView()
            } else {
                MainTabView()
            }
        }
        .task {
            await auth.checkSession()
        }
    }
}
