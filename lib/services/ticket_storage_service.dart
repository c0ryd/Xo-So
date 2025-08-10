import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:amazon_cognito_identity_dart_2/cognito.dart';
import 'package:amazon_cognito_identity_dart_2/sig_v4.dart';
import 'notification_service.dart';

class TicketStorageService {
  static const String _apiGatewayBaseUrl = 'https://u9maewv4ch.execute-api.ap-southeast-1.amazonaws.com';
  static const String _identityPoolId = 'ap-southeast-1:9728af83-62a8-410f-a585-53de188a5079';
  static const String _awsRegion = 'ap-southeast-1';


  /// Store a scanned ticket in AWS DynamoDB for processing after the drawing
  static Future<bool> storeTicket({
    required String ticketNumber,
    required String province,
    required String drawDate,
    required String region,
    required String ocrRawText,
  }) async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) {
        print('Error: User not authenticated');
        return false;
      }

      // Get device token for notifications
      final deviceToken = NotificationService.currentToken;
      if (deviceToken == null) {
        print('Warning: Device token not available, notifications may not work');
      }

      // Prepare the payload
      final payload = {
        'userId': user.id,
        'ticketNumber': ticketNumber,
        'province': province,
        'drawDate': drawDate,
        'region': region,
        'deviceToken': deviceToken,
        'userEmail': user.email ?? '',
        'scannedAt': DateTime.now().toUtc().toIso8601String(),
        'ocrRawText': ocrRawText,
      };

      print('Storing ticket with payload: $payload');

      // Get AWS credentials for authenticated API call
      final credentials = await _getAwsCredentials();
      
      // Create signed request for API Gateway
      final awsSigV4Client = AwsSigV4Client(
        credentials.accessKeyId!,
        credentials.secretAccessKey!,
        _apiGatewayBaseUrl,
        sessionToken: credentials.sessionToken,
        region: _awsRegion,
      );
      
      final signedRequest = SigV4Request(
        awsSigV4Client,
        method: 'POST',
        path: '/dev/storeTicket',
        headers: {'Content-Type': 'application/json'},
        body: payload,
      );
      
      print('Making authenticated request to: ${signedRequest.url}');
      
      final response = await http.post(
        Uri.parse(signedRequest.url!),
        headers: signedRequest.headers?.cast<String, String>(),
        body: signedRequest.body,
      );

      print('Store ticket response: ${response.statusCode} - ${response.body}');
      print('Request URL: ${signedRequest.url}');
      print('Payload sent: ${json.encode(payload)}');

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        if (responseData['success'] == true) {
          if (responseData['isDuplicate'] == true) {
            print('Duplicate ticket detected - existing ID: ${responseData['ticketId']}');
            print('Message: ${responseData['message']}');
          } else {
            print('Ticket stored successfully with ID: ${responseData['ticketId']}');
          }
          
          // Subscribe user to notifications for this province/region
          await _subscribeToRelevantNotifications(province, region);
          
          return true;
        }
      }

      print('❌ STORAGE FAILED: Status=${response.statusCode}, Response=${response.body}');
      print('URL: ${signedRequest.url}');
      return false;

    } catch (e) {
      print('Error storing ticket: $e');
      return false;
    }
  }

  /// Get user's stored tickets from AWS
  static Future<List<Map<String, dynamic>>> getUserTickets({int limit = 50}) async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) {
        print('Error: User not authenticated');
        return [];
      }

      // This would require another Lambda function to get user tickets
      // For now, we'll return an empty list
      // TODO: Implement get_user_tickets Lambda function
      
      return [];
    } catch (e) {
      print('Error getting user tickets: $e');
      return [];
    }
  }

  /// Check if a ticket should be stored (ALL tickets are now stored)
  static bool shouldStoreTicket(String drawDate) {
    try {
      // Parse the ticket date (expected format: DD-MM-YYYY)
      final dateParts = drawDate.split('-');
      if (dateParts.length != 3) return false;
      
      final ticketDate = DateTime(
        int.parse(dateParts[2]), // year
        int.parse(dateParts[1]), // month
        int.parse(dateParts[0])  // day
      );
      
      // Get current Vietnam time (simplified - using local time)
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      
      // CHANGED: Always store ALL tickets regardless of time or date
      // This allows tickets to be stored even after drawings have occurred
      print('Ticket date: $ticketDate');
      print('Today: $today');
      print('Current time: $now');
      print('Storing ALL tickets - no time restrictions');
      
      return true;
    } catch (e) {
      print('Error parsing date for storage check: $e');
      return false;
    }
  }



  /// Subscribe user to relevant notifications based on province and region
  static Future<void> _subscribeToRelevantNotifications(String province, String region) async {
    try {
      // Subscribe to regional notifications
      await NotificationService.subscribeToRegion(region);
      
      // Subscribe to province-specific notifications
      await NotificationService.subscribeToProvince(province);
      
      print('Subscribed to notifications for $province ($region)');
    } catch (e) {
      print('Error subscribing to notifications: $e');
    }
  }

  /// Convert date from DD-MM-YYYY to YYYY-MM-DD format for API
  static String convertDateToApiFormat(String dateStr) {
    try {
      final parts = dateStr.split('-');
      if (parts.length != 3) return dateStr;
      
      return '${parts[2]}-${parts[1].padLeft(2, '0')}-${parts[0].padLeft(2, '0')}';
    } catch (e) {
      return dateStr;
    }
  }

  /// Get region for a city (same logic as in main app)
  static String? getRegionForCity(String cityName, Map<String, dynamic> citiesData) {
    if (citiesData.isEmpty) return null;
    
    for (final region in citiesData['regions']) {
      final cities = region['cities'] as List;
      if (cities.contains(cityName)) {
        final englishName = region['english_name'] as String;
        // Convert to the format expected by the API
        switch (englishName.toLowerCase()) {
          case 'northern':
            return 'north';
          case 'central':
            return 'central';
          case 'southern':
            return 'south';
          default:
            return englishName.toLowerCase();
        }
      }
    }
    
    // Fallback for special cases
    if (cityName.contains('Hồ Chí Minh') || cityName.contains('TP.')) {
      return 'south';
    }
    
    return null;
  }

  /// Get AWS credentials using Cognito Identity Pool
  static Future<CognitoCredentials> _getAwsCredentials() async {
    try {
      // Create a dummy user pool for unauthenticated access
      final userPool = CognitoUserPool(
        'ap-southeast-1_dummy12345', // Dummy user pool ID
        'dummy1234567890abcdef1234567890' // Dummy client ID
      );
      
      // Create Cognito credentials for unauthenticated access
      final credentials = CognitoCredentials(_identityPoolId, userPool);
      
      // Get AWS credentials for unauthenticated access (pass null for unauthenticated)
      await credentials.getAwsCredentials(null);
      
      print('✅ AWS credentials obtained successfully');
      return credentials;
    } catch (e) {
      print('❌ AWS authentication failed: $e');
      throw Exception('AWS authentication failed: $e');
    }
  }
}
