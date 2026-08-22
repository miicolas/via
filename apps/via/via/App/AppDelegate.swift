import UIKit
import UserNotifications

@MainActor
final class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        let center = UNUserNotificationCenter.current()
        center.delegate = self
        let mute = UNNotificationAction(
            identifier: Self.muteActionIdentifier,
            title: "Ne plus recevoir",
            options: [.destructive, .authenticationRequired]
        )
        let categories = NotificationCategory.allCases.map { category in
            UNNotificationCategory(
                identifier: "via.notification.\(category.rawValue)",
                actions: [mute],
                intentIdentifiers: [],
                options: [.customDismissAction]
            )
        }
        center.setNotificationCategories(Set(categories))
        return true
    }

    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        PushNotificationManager.shared.didRegisterForRemoteNotifications(deviceToken: deviceToken)
    }

    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        PushNotificationManager.shared.didFailToRegisterForRemoteNotifications(error: error)
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound, .badge])
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        if response.actionIdentifier == Self.muteActionIdentifier {
            if let scheduleID = response.notification.request.content.userInfo["scheduleId"] as? String {
                NotificationScheduleCoordinator.shared.mute(scheduleID: scheduleID)
            }
            PushNotificationManager.shared.muteNotification(from: response)
        } else {
            PushNotificationManager.shared.didReceiveNotificationResponse(response)
        }
        completionHandler()
    }

    static let muteActionIdentifier = "via.notification.mute"
}
