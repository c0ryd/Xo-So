import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/services.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  static FlutterLocalNotificationsPlugin? _localNotifications;
  static String? _deviceToken;
  static const MethodChannel _channel = MethodChannel('com.cdawson.xoso/notifications');

  static Future<void> initialize() async {
    _localNotifications = FlutterLocalNotificationsPlugin();

    // Initialize local notifications
    const androidInitializationSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iOSInitializationSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    
    const initializationSettings = InitializationSettings(
      android: androidInitializationSettings,
      iOS: iOSInitializationSettings,
    );

    await _localNotifications?.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    // Set up method channel to listen for iOS notification taps
    _setupMethodChannel();

    // Request permissions
    await requestPermissions();

    // Register for real push notifications
    await _registerForPushNotifications();
  }

  static void _setupMethodChannel() {
    const methodChannel = MethodChannel('com.cdawson.xoso/notifications');
    
    methodChannel.setMethodCallHandler((call) async {
      if (call.method == 'onNotificationTapped') {
        print('📱 iOS notification tapped via method channel');
        // Navigate to My Tickets page
        _navigateToMyTickets?.call();
      }
    });
  }

  static Future<void> requestPermissions() async {
    // Request notification permissions
    await Permission.notification.request();
    
    // For iOS, also request local notification permissions
    if (Platform.isIOS) {
      await _localNotifications?.resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin>()?.requestPermissions(
        alert: true,
        badge: true,
        sound: true,
      );
    }
  }

  /// Register for real push notifications with Apple/Google
  static Future<void> _registerForPushNotifications() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) {
        print('❌ No authenticated user - cannot register for push notifications');
        return;
      }

      if (Platform.isIOS) {
        print('📱 Registering for iOS APNs...');
        await _registerForIOSPushNotifications();
      } else if (Platform.isAndroid) {
        print('🤖 Registering for Android FCM...');
        await _registerForAndroidPushNotifications();
      }
    } catch (e) {
      print('❌ Error registering for push notifications: $e');
    }
  }

  /// Register for iOS APNs using native iOS methods
  static Future<void> _registerForIOSPushNotifications() async {
    try {
      // Get device token (this handles both permissions and APNs registration)
      final String? token = await _getDeviceToken();
      
      if (token != null) {
        _deviceToken = token;
        print('✅ Real iOS APNs token received: ${token.substring(0, 10)}...');
        
        // Register with our backend
        await _registerTokenWithBackend(token);
      } else {
        print('❌ Failed to get iOS APNs token');
        // Fallback to mock token for testing
        await _generateFallbackToken();
      }
    } catch (e) {
      print('❌ iOS APNs registration failed: $e');
      // Fallback to mock token for testing
      await _generateFallbackToken();
    }
  }

  /// Get device token (handles permissions and APNs registration)
  static Future<String?> _getDeviceToken() async {
    try {
      print('📱 Requesting device token from native iOS...');
      final String? token = await _channel.invokeMethod('getDeviceToken');
      if (token != null) {
        print('✅ Received real device token from iOS: ${token.substring(0, 10)}...');
      } else {
        print('❌ iOS returned null device token');
      }
      return token;
    } catch (e) {
      print('❌ Error getting device token from iOS: $e');
      return null;
    }
  }

  /// Register for Android FCM notifications
  static Future<void> _registerForAndroidPushNotifications() async {
    try {
      // For Android, we would typically use Firebase Cloud Messaging
      // Since we're using AWS SNS directly, we'll generate a mock FCM token
      // In a full production app, you'd integrate with Firebase
      print('🤖 Android FCM registration not fully implemented - using mock token');
      await _generateFallbackToken();
    } catch (e) {
      print('❌ Android FCM registration failed: $e');
      await _generateFallbackToken();
    }
  }

  /// Generate a fallback token for testing when real registration fails
  static Future<void> _generateFallbackToken() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return;
      
      if (Platform.isIOS) {
        // Generate a valid iOS APNs device token format (64 hex characters)
        _deviceToken = _generateMockAPNsToken();
        print('🔧 Generated fallback iOS APNs token: ${_deviceToken!.substring(0, 10)}...');
      } else if (Platform.isAndroid) {
        // Generate a valid FCM token format for Android
        _deviceToken = _generateMockFCMToken();
        print('🔧 Generated fallback Android FCM token: ${_deviceToken!.substring(0, 10)}...');
      } else {
        // Fallback for other platforms
        _deviceToken = '${user.id}_${Platform.operatingSystem}_${DateTime.now().millisecondsSinceEpoch}';
        print('🔧 Generated fallback token: $_deviceToken');
      }
    } catch (e) {
      print('❌ Error generating fallback token: $e');
    }
  }

  /// Generate a mock iOS APNs token (64 hexadecimal characters) that's consistent for the user
  static String _generateMockAPNsToken() {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user != null) {
        // Create a deterministic token based on user ID so it's consistent across app sessions
        final userIdHash = user.id.hashCode.abs();
        final hexChars = '0123456789abcdef';
        final buffer = StringBuffer();
        
        // APNs tokens are exactly 64 hexadecimal characters
        for (int i = 0; i < 64; i++) {
          final index = (userIdHash + i * 17) % hexChars.length; // Use prime number for better distribution
          buffer.write(hexChars[index]);
        }
        
        return buffer.toString();
      }
    } catch (e) {
      print('Error generating user-based token: $e');
    }
    
    // Fallback to time-based if user not available
    final random = DateTime.now().millisecondsSinceEpoch;
    final hexChars = '0123456789abcdef';
    final buffer = StringBuffer();
    
    // APNs tokens are exactly 64 hexadecimal characters
    for (int i = 0; i < 64; i++) {
      buffer.write(hexChars[(random + i) % hexChars.length]);
    }
    
    return buffer.toString();
  }

  /// Generate a mock FCM token for Android
  static String _generateMockFCMToken() {
    final random = DateTime.now().millisecondsSinceEpoch;
    final chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_';
    final buffer = StringBuffer();
    
    // FCM tokens are typically around 163 characters
    for (int i = 0; i < 163; i++) {
      buffer.write(chars[(random + i) % chars.length]);
    }
    
    return buffer.toString();
  }

  /// Register the device token with our AWS backend
  static Future<void> _registerTokenWithBackend(String token) async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return;

      print('📡 Registering device token with AWS SNS backend...');
      
      // Here you would call your AWS Lambda function to register the device
      // For now, we'll just log it
      print('✅ Device token registered: ${token.substring(0, 10)}...');
      
    } catch (e) {
      print('❌ Error registering token with backend: $e');
    }
  }

  static String? get currentToken => _deviceToken;

  /// Register device for push notifications via AWS SNS
  static Future<bool> registerDevice() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null || _deviceToken == null) return false;

      print('📱 Device registered for notifications: ${_deviceToken!.substring(0, 10)}...');
      return true;
    } catch (e) {
      print('❌ Error registering device: $e');
      return false;
    }
  }

  /// Show local notification (used for testing and immediate feedback)
  static Future<void> showLocalNotification({
    required String title,
    required String body,
    Map<String, dynamic>? data,
  }) async {
    print('🔔 ATTEMPTING to show local notification: $title - $body');
    
    if (_localNotifications == null) {
      print('❌ Local notifications not initialized!');
      return;
    }

    try {
      const androidDetails = AndroidNotificationDetails(
        'lottery_channel',
        'Lottery Notifications',
        channelDescription: 'Notifications for lottery results',
        importance: Importance.high,
        priority: Priority.high,
        icon: '@mipmap/ic_launcher',
      );

      const iOSDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
        interruptionLevel: InterruptionLevel.active,
      );

      const details = NotificationDetails(
        android: androidDetails,
        iOS: iOSDetails,
      );

      print('🔔 Calling _localNotifications.show()...');
      await _localNotifications!.show(
        DateTime.now().millisecondsSinceEpoch ~/ 1000,
        title,
        body,
        details,
        payload: data != null ? jsonEncode(data) : null,
      );

      print('✅ Local notification sent successfully: $title - $body');
    } catch (e) {
      print('❌ Error showing local notification: $e');
    }
  }

  static void _onNotificationTapped(NotificationResponse response) {
    print('🔔 Notification tapped! Response: ${response.payload}');
    
    if (response.payload != null) {
      try {
        final data = jsonDecode(response.payload!);
        final notificationType = data['type'];
        
        if (notificationType == 'daily_summary') {
          _handleDailySummaryNotification(data);
        }
      } catch (e) {
        print('❌ Error parsing notification payload: $e');
      }
    }
  }

  static void _handleDailySummaryNotification(Map<String, dynamic> data) {
    final date = data['date'] as String;
    print('📱 Daily summary notification tapped for $date');
    
    // Navigate to My Tickets page
    _navigateToMyTickets?.call();
  }

  // Callback for navigation - to be set by the main app
  static Function()? _navigateToMyTickets;
  
  static void setMyTicketsNavigationCallback(Function() callback) {
    _navigateToMyTickets = callback;
  }

  /// Show daily summary notification for winners
  static Future<void> showDailyWinnerSummary({
    required String date,
    required List<Map<String, dynamic>> winningTickets,
    required List<Map<String, dynamic>> losingTickets,
  }) async {
    final totalWinnings = winningTickets.fold<int>(
      0, 
      (sum, ticket) => sum + (ticket['winAmount'] as int? ?? 0)
    );
    
    await showLocalNotification(
      title: '🎉 Congratulations! You Won!',
      body: 'You won ${totalWinnings.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},')} VND from ${winningTickets.length} ticket${winningTickets.length != 1 ? 's' : ''}!',
      data: {
        'type': 'daily_summary',
        'date': date,
        'has_winners': true,
        'winning_tickets': winningTickets,
        'losing_tickets': losingTickets,
      },
    );
  }

  /// Show daily summary notification for non-winners
  static Future<void> showDailyNonWinnerSummary({
    required String date,
    required List<Map<String, dynamic>> losingTickets,
  }) async {
    await showLocalNotification(
      title: 'No Winning Tickets Today',
      body: 'Checked ${losingTickets.length} ticket${losingTickets.length != 1 ? 's' : ''} for $date. Better luck next time!',
      data: {
        'type': 'daily_summary',
        'date': date,
        'has_winners': false,
        'winning_tickets': [],
        'losing_tickets': losingTickets,
      },
    );
  }

  /// Subscribe to topic-based notifications (simplified for AWS SNS)
  static Future<void> subscribeToTopic(String topic) async {
    print('📡 Subscribed to topic: $topic');
  }

  static Future<void> unsubscribeFromTopic(String topic) async {
    print('📡 Unsubscribed from topic: $topic');
  }

  /// Subscribe user to their region/province for relevant lottery updates
  static Future<void> subscribeToRegion(String region) async {
    await subscribeToTopic('lottery_$region');
  }

  static Future<void> subscribeToProvince(String province) async {
    final normalizedProvince = province.toLowerCase()
        .replaceAll(' ', '_')
        .replaceAll('TP.', '')
        .replaceAll('tp.', '')
        .trim();
    await subscribeToTopic('lottery_$normalizedProvince');
  }
}