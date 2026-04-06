import SwiftUI
import OneSignalFramework

@main
struct La_MenuApp: App {
    @State private var authViewModel = AuthViewModel()
    @State private var showSplash = true

    init() {
        OneSignal.initialize("df5dd380-c618-4a4b-b4ca-0ff14eaeb667", withLaunchOptions: nil)

        OneSignal.Notifications.requestPermission({ accepted in
            print("Push accepted: \(accepted)")
        }, fallbackToSettings: true)
    }

    var body: some Scene {
        WindowGroup {
            ZStack {
                RootView()
                    .environment(authViewModel)

                if showSplash {
                    SplashView()
                        .transition(.opacity)
                        .zIndex(1)
                }
            }
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        showSplash = false
                    }
                }
            }
        }
    }
}
