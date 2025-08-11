import UIKit
import Flutter
import UserNotifications

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    
    // Set notification center delegate to handle foreground notifications
    UNUserNotificationCenter.current().delegate = self
    
    // Set up Flutter method channel for notifications (matching notification_service.dart)
    let controller : FlutterViewController = window?.rootViewController as! FlutterViewController
    let notificationChannel = FlutterMethodChannel(name: "com.cdawson.xoso/notifications",
                                                  binaryMessenger: controller.binaryMessenger)
    
    notificationChannel.setMethodCallHandler({
      (call: FlutterMethodCall, result: @escaping FlutterResult) -> Void in
      
      switch call.method {
      case "getDeviceToken":
        self.registerForPushNotifications(result: result)
      default:
        result(FlutterMethodNotImplemented)
      }
    })
    
    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
  
  // MARK: - UNUserNotificationCenterDelegate
  
  /// Handle notifications when app is in foreground
  override func userNotificationCenter(_ center: UNUserNotificationCenter, 
                            willPresent notification: UNNotification, 
                            withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
    print("📱 Foreground notification: \(notification.request.content.title) - \(notification.request.content.body)")
    
    // Show notification even when app is in foreground
    completionHandler([.alert, .sound, .badge])
  }
  
  /// Handle notification taps
  override func userNotificationCenter(_ center: UNUserNotificationCenter, 
                            didReceive response: UNNotificationResponse, 
                            withCompletionHandler completionHandler: @escaping () -> Void) {
    print("📱 Notification tapped: \(response.notification.request.content.title)")
    
    // Forward the notification tap to Flutter
    if let controller = window?.rootViewController as? FlutterViewController {
      let notificationChannel = FlutterMethodChannel(name: "com.cdawson.xoso/notifications", binaryMessenger: controller.binaryMessenger)
      
      // Extract notification data
      let userInfo = response.notification.request.content.userInfo
      print("📱 Notification userInfo: \(userInfo)")
      
      // Send to Flutter
      notificationChannel.invokeMethod("onNotificationTapped", arguments: userInfo)
    }
    
    completionHandler()
  }
  
  /// Request notification permissions and register for APNs
  private func registerForPushNotifications(result: @escaping FlutterResult) {
    UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
      DispatchQueue.main.async {
        if let error = error {
          print("❌ Error requesting notification permissions: \(error)")
          result(FlutterError(code: "PERMISSION_ERROR", message: error.localizedDescription, details: nil))
        } else if granted {
          print("📱 Notification permissions granted, registering for remote notifications...")
          UIApplication.shared.registerForRemoteNotifications()
          
          // Store the result callback to return the token later
          self.pendingTokenResult = result
          
          // Set timeout for APNs registration
          DispatchQueue.main.asyncAfter(deadline: .now() + 10.0) {
            if self.pendingTokenResult != nil {
              print("❌ APNs registration timed out")
              self.pendingTokenResult?(FlutterError(code: "TIMEOUT", message: "APNs registration timed out", details: nil))
              self.pendingTokenResult = nil
            }
          }
        } else {
          print("❌ Notification permissions denied")
          result(FlutterError(code: "PERMISSION_DENIED", message: "Notification permissions denied", details: nil))
        }
      }
    }
  }

  
  // Store the Flutter result callback
  private var pendingTokenResult: FlutterResult?
  
  /// Called when APNs registration succeeds
  override func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
    let tokenString = deviceToken.map { String(format: "%02.2hhx", $0) }.joined()
    print("✅ APNs registration successful! Token: \(tokenString.prefix(10))...")
    
    // Send token back to Flutter
    if let result = pendingTokenResult {
      result(tokenString)
      pendingTokenResult = nil
    }
  }
  
  /// Called when APNs registration fails
  override func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
    print("❌ APNs registration failed: \(error)")
    
    // Send failure back to Flutter
    if let result = pendingTokenResult {
      result(nil)
      pendingTokenResult = nil
    }
  }
  
  /// Handle incoming push notifications when app is in foreground
  override func application(_ application: UIApplication, didReceiveRemoteNotification userInfo: [AnyHashable : Any], fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
    
    print("📱 Received remote notification: \(userInfo)")
    
    // Process the notification
    if let aps = userInfo["aps"] as? [String: Any] {
      if let alert = aps["alert"] as? [String: Any] {
        let title = alert["title"] as? String ?? "Lottery Results"
        let body = alert["body"] as? String ?? "Check your tickets!"
        
        print("📱 Push notification: \(title) - \(body)")
      }
    }
    
    completionHandler(.newData)
  }
}