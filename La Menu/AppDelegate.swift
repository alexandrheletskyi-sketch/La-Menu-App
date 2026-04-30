import UIKit
import UserNotifications
import OneSignalFramework

final class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {

        print("🧱 PUSH DEBUG: App didFinishLaunching")

        UNUserNotificationCenter.current().delegate = self

        UNUserNotificationCenter.current().getNotificationSettings { settings in
            print("🧱 PUSH DEBUG: authorizationStatus =", settings.authorizationStatus.rawValue)
            print("🧱 PUSH DEBUG: alertSetting =", settings.alertSetting.rawValue)
            print("🧱 PUSH DEBUG: soundSetting =", settings.soundSetting.rawValue)
            print("🧱 PUSH DEBUG: badgeSetting =", settings.badgeSetting.rawValue)
            print("🧱 PUSH DEBUG: notificationCenterSetting =", settings.notificationCenterSetting.rawValue)
            print("🧱 PUSH DEBUG: lockScreenSetting =", settings.lockScreenSetting.rawValue)
        }

        application.registerForRemoteNotifications()

        OneSignal.Debug.setLogLevel(.LL_VERBOSE)
        OneSignal.Debug.setAlertLevel(.LL_NONE)

        print("🧱 PUSH DEBUG: OneSignal verbose logs enabled")

        return true
    }

    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        let token = deviceToken.map { String(format: "%02.2hhx", $0) }.joined()
        print("🧱 PUSH DEBUG: APNs device token =", token)
    }

    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        print("🧱 PUSH DEBUG: Failed to register APNs token =", error.localizedDescription)
    }

    // Спрацює, коли пуш приходить, а додаток відкритий
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        print("🧱 PUSH DEBUG: Notification received while app is foreground")
        print("🧱 PUSH DEBUG: title =", notification.request.content.title)
        print("🧱 PUSH DEBUG: body =", notification.request.content.body)
        print("🧱 PUSH DEBUG: userInfo =", notification.request.content.userInfo)

        completionHandler([.banner, .sound, .badge, .list])
    }

    // Спрацює, коли користувач натиснув на пуш
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        print("🧱 PUSH DEBUG: Notification tapped")
        print("🧱 PUSH DEBUG: actionIdentifier =", response.actionIdentifier)
        print("🧱 PUSH DEBUG: title =", response.notification.request.content.title)
        print("🧱 PUSH DEBUG: body =", response.notification.request.content.body)
        print("🧱 PUSH DEBUG: userInfo =", response.notification.request.content.userInfo)

        completionHandler()
    }
}
