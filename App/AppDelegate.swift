import UIKit
import CloudKit
import CloudKitService

/// SwiftUI `@main` App'i `UIApplicationDelegateAdaptor` ile bu sınıfa bağlanır.
/// Sorumluluklar:
///   - APNs'e remote notification kayıt
///   - Gelen silent push'ları `PushNotificationHandler` üzerinden ayrıştırma
///   - SwiftData/CloudKit otomatik sync zaten fetch'i yapıyor; biz sadece
///     uygulamanın gerçek zamanlı güncellemeyi karşıladığını işaretliyoruz.
final class AppDelegate: NSObject, UIApplicationDelegate {
    var pushSink: ((PushNotificationHandler.Outcome) -> Void)?

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        application.registerForRemoteNotifications()
        return true
    }

    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        // CloudKit silent push için APNs token'ı doğrudan kullanmıyoruz —
        // CKSubscription tarafından handle ediliyor. Token loglamak için yer.
    }

    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        // Sandbox/development'ta beklenen — sessizce yut.
    }

    func application(
        _ application: UIApplication,
        didReceiveRemoteNotification userInfo: [AnyHashable: Any],
        fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void
    ) {
        let outcome = PushNotificationHandler.handle(userInfo: userInfo)
        pushSink?(outcome)
        switch outcome {
        case .databaseChanged: completionHandler(.newData)
        case .ignored: completionHandler(.noData)
        }
    }
}
