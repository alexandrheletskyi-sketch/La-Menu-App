import Foundation
import OneSignalFramework

final class OneSignalForegroundHandler: NSObject, OSNotificationLifecycleListener {

    func onWillDisplay(event: OSNotificationWillDisplayEvent) {
        let notification = event.notification

        print("""
        🟣 [OneSignal Foreground] PUSH RECEIVED
        title: \(notification.title ?? "nil")
        body: \(notification.body ?? "nil")
        notificationId: \(notification.notificationId)
        additionalData: \(notification.additionalData ?? [:])
        """)

        // Щоб пуш показувався навіть коли додаток відкритий
        event.notification.display()
    }
}
