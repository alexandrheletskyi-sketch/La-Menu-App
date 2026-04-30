import SwiftUI
import OneSignalFramework

@main
struct La_MenuApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    @State private var authViewModel = AuthViewModel()
    @State private var showSplash = true

    private let foregroundHandler = OneSignalForegroundHandler()

    init() {
        OneSignal.Debug.setLogLevel(.LL_VERBOSE)

        OneSignal.initialize("df5dd380-c618-4a4b-b4ca-0ff14eaeb667", withLaunchOptions: nil)

        OneSignal.Notifications.addForegroundLifecycleListener(foregroundHandler)

        print("🟢 [OneSignal] initialized")
        print("🟢 [OneSignal] app id: df5dd380-c618-4a4b-b4ca-0ff14eaeb667")
        print("🟢 [OneSignal] onesignalId after init: \(OneSignal.User.onesignalId ?? "nil")")
        print("🟢 [OneSignal] push token after init: \(OneSignal.User.pushSubscription.token ?? "nil")")
        print("🟢 [OneSignal] push id after init: \(OneSignal.User.pushSubscription.id ?? "nil")")
        print("🟢 [OneSignal] opted in after init: \(OneSignal.User.pushSubscription.optedIn)")

        OneSignal.Notifications.requestPermission({ accepted in
            print("🔔 [OneSignal] permission accepted: \(accepted)")
            print("🔔 [OneSignal] onesignalId: \(OneSignal.User.onesignalId ?? "nil")")
            print("🔔 [OneSignal] push token: \(OneSignal.User.pushSubscription.token ?? "nil")")
            print("🔔 [OneSignal] push id: \(OneSignal.User.pushSubscription.id ?? "nil")")
            print("🔔 [OneSignal] opted in: \(OneSignal.User.pushSubscription.optedIn)")
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

                print("🟣 [App] Root appeared")
                print("🟣 [OneSignal] onesignalId onAppear: \(OneSignal.User.onesignalId ?? "nil")")
                print("🟣 [OneSignal] push token onAppear: \(OneSignal.User.pushSubscription.token ?? "nil")")
                print("🟣 [OneSignal] push id onAppear: \(OneSignal.User.pushSubscription.id ?? "nil")")
                print("🟣 [OneSignal] opted in onAppear: \(OneSignal.User.pushSubscription.optedIn)")
            }
        }
    }
}
