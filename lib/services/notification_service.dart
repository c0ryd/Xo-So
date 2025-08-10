import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  static FlutterLocalNotificationsPlugin? _localNotifications;
  static String? _deviceToken;

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

    // Request permissions
    await requestPermissions();

    // Generate device token (combination of device info + user ID)
    await _generateDeviceToken();
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

  static Future<String?> _generateDeviceToken() async {
    try {
      // Create a unique device identifier using device info + user ID
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return null;
      
      // Simple device token - in production, you'd want something more sophisticated
      final deviceInfo = Platform.isIOS ? 'ios' : 'android';
      _deviceToken = '${user.id}_${deviceInfo}_${DateTime.now().millisecondsSinceEpoch}';
      
      print('Generated device token: $_deviceToken');
      return _deviceToken;
    } catch (e) {
      print('Error generating device token: $e');
      return null;
    }
  }

  static String? get currentToken => _deviceToken;

  /// Register device for push notifications via AWS SNS
  static Future<bool> registerDevice() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null || _deviceToken == null) return false;

      // In a real implementation, this would call your AWS SNS registration endpoint
      // For now, we'll just store the device token locally
      print('Device registered for notifications: $_deviceToken');
      return true;
    } catch (e) {
      print('Error registering device: $e');
      return false;
    }
  }

  /// Show local notification (used for testing and immediate feedback)
  static Future<void> showLocalNotification({
    required String title,
    required String body,
    Map<String, dynamic>? data,
  }) async {
    if (_localNotifications == null) return;

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
    );

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iOSDetails,
    );

    await _localNotifications!.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title,
      body,
      details,
      payload: data != null ? jsonEncode(data) : null,
    );
  }

  static void _onNotificationTapped(NotificationResponse response) {
    if (response.payload != null) {
      final data = jsonDecode(response.payload!);
      final notificationType = data['type'];
      
      if (notificationType == 'winner_notification') {
        _handleWinnerNotification(data);
      } else if (notificationType == 'ticket_stored') {
        _handleTicketStoredNotification(data);
      }
    }
  }

  static void _handleWinnerNotification(Map<String, dynamic> data) {
    // Extract winner information
    final ticketNumber = data['ticketNumber'];
    final winAmount = data['winAmount'];
    final matchedTiers = data['matchedTiers'];
    
    print('Winner notification handled: $ticketNumber won $winAmount');
    
    // TODO: Navigate to winner details screen or show winner dialog
    // This would be implemented based on your app's navigation structure
  }

  static void _handleTicketStoredNotification(Map<String, dynamic> data) {
    final ticketNumber = data['ticketNumber'];
    final drawDate = data['drawDate'];
    
    print('Ticket stored notification: $ticketNumber for draw date $drawDate');
  }

  /// Show notification when ticket is successfully stored
  static Future<void> showTicketStoredNotification({
    required String ticketNumber,
    required String drawDate,
    required String province,
  }) async {
    await showLocalNotification(
      title: '✅ Ticket Stored Successfully',
      body: 'Ticket $ticketNumber for $province ($drawDate) will be checked automatically',
      data: {
        'type': 'ticket_stored',
        'ticketNumber': ticketNumber,
        'drawDate': drawDate,
        'province': province,
      },
    );
  }

  /// Show notification when user wins (this would typically come from AWS SNS)
  static Future<void> showWinnerNotification({
    required String ticketNumber,
    required int winAmount,
    required List<String> matchedTiers,
  }) async {
    final formattedAmount = '${winAmount.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), 
      (Match m) => '${m[1]},'
    )}₫';

    await showLocalNotification(
      title: '🎉 Congratulations! You Won! 🎉',
      body: 'Your ticket $ticketNumber won $formattedAmount!',
      data: {
        'type': 'winner_notification',
        'ticketNumber': ticketNumber,
        'winAmount': winAmount.toString(),
        'matchedTiers': matchedTiers,
      },
    );
  }

  /// Subscribe to topic-based notifications (simplified for AWS SNS)
  static Future<void> subscribeToTopic(String topic) async {
    // In a real AWS SNS implementation, this would subscribe the device to a topic
    print('Subscribed to topic: $topic');
  }

  static Future<void> unsubscribeFromTopic(String topic) async {
    // In a real AWS SNS implementation, this would unsubscribe from a topic
    print('Unsubscribed from topic: $topic');
  }

  /// Subscribe user to their region/province for relevant lottery updates
  static Future<void> subscribeToRegion(String region) async {
    await subscribeToTopic('lottery_$region');
  }

  static Future<void> subscribeToProvince(String province) async {
    // Normalize province name for topic
    final normalizedProvince = province.toLowerCase()
        .replaceAll(' ', '_')
        .replaceAll('TP.', '')
        .replaceAll('tp.', '')
        .trim();
    await subscribeToTopic('lottery_$normalizedProvince');
  }
}